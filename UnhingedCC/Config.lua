local _, U = ...
local S = U.Style
local window, body, tab, lock, status
local priorityRows={}
-- Pool config widgets and regions across redraws; WoW frames cannot be destroyed.
local activePool
local function frame(kind,name,parent,template)
    if not activePool then return CreateFrame(kind,name,parent,template) end
    local key=kind..(template or '')
    local pool=activePool.frames[key] or {}; activePool.frames[key]=pool
    local n=(activePool.counts[key] or 0)+1; activePool.counts[key]=n
    local f=pool[n]
    if not f then f=CreateFrame(kind,name,parent,template); pool[n]=f end
    for _,script in ipairs({'OnClick','OnTextChanged','OnEditFocusLost','OnEnterPressed','OnEscapePressed','OnEnter','OnLeave'}) do
        if f:HasScript(script) then f:SetScript(script,nil) end
    end
    f:SetParent(parent); f:ClearAllPoints(); f:Show()
    return f
end
local function region(parent,kind,font)
    if not activePool then
        return kind=='font' and parent:CreateFontString(nil,'OVERLAY',font) or parent:CreateTexture(nil,'ARTWORK')
    end
    local key=kind..(font or '')
    local pool=activePool.regions[key] or {}; activePool.regions[key]=pool
    local n=(activePool.counts[key] or 0)+1; activePool.counts[key]=n
    local r=pool[n]
    if not r then r=kind=='font' and parent:CreateFontString(nil,'OVERLAY',font) or parent:CreateTexture(nil,'ARTWORK'); pool[n]=r end
    r:SetParent(parent); r:ClearAllPoints(); r:Show(); return r
end
local function label(parent,text,x,y,font,title)
    local l=region(parent,'font',font or 'GameFontHighlightSmall'); S.Font(l,font,title); l:SetTextColor(unpack(S.text))
    l:SetPoint('TOPLEFT',x,y); l:SetText(text); return l
end
local function button(parent,text,x,y,w,fn)
    local b=frame('Button',nil,parent,'BackdropTemplate'); b:SetSize(w or 100,24)
    S.Button(b); b:SetPoint('TOPLEFT',x,y); b:SetText(text); b:SetScript('OnClick',fn); return b
end
local function edit(parent,x,y,w,value,numeric)
    local b=frame('EditBox',nil,parent,'BackdropTemplate'); b:SetSize(w,24); b:SetPoint('TOPLEFT',x,y)
    S.Input(b); b:SetAutoFocus(false); b:SetNumeric(false); b:SetMaxLetters(100); if numeric then b:SetNumeric(true); b:SetMaxLetters(3); b:SetTextInsets(4,4,0,0) end
    b:SetText(value or ''); b:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    b:SetScript('OnEnterPressed',function(self) self:ClearFocus() end)
    return b
end
local function report(text) status:SetText(text or '') end
local function change(fn)
    local copy=assert(U.Validate(U.db))
    copy.positions=U.db.positions; copy.locked=U.db.locked
    fn(copy)
    local ok,err=U.Commit(copy); report(err)
    return ok
end
local promptFrame
local function prompt(title,message,options)
    if not promptFrame then
        local shield=CreateFrame('Frame',nil,window); shield:SetAllPoints(); shield:SetFrameStrata('DIALOG'); shield:SetFrameLevel(window:GetFrameLevel()+50); shield:EnableMouse(true)
        local popup=CreateFrame('Frame',nil,shield,'BackdropTemplate'); popup:SetSize(470,228); popup:SetPoint('CENTER'); popup:EnableMouse(true); S.Panel(popup,S.bg,S.header)
        popup.shield=shield; promptFrame=popup
        popup.title=S.TitleBar(popup,'').title
        popup.message=label(popup,'',20,-52); popup.message:SetWidth(430); popup.message:SetHeight(58); popup.message:SetJustifyH('LEFT')
        popup.input=edit(popup,20,-112,430,''); popup.input:SetMaxLetters(40)
        popup.error=label(popup,'',20,-151); popup.error:SetWidth(430); popup.error:SetTextColor(1,.45,.45)
        popup.accept=button(popup,'Yes',254,-184,94,function()
            local ok,err=popup.action(popup.input:GetText())
            if ok then popup:Hide() elseif err then popup.error:SetText(err) end
        end)
        popup.cancel=button(popup,'No',356,-184,94,function() popup:Hide() end)
        popup.input:SetScript('OnEnterPressed',function() popup.accept:GetScript('OnClick')(popup.accept) end)
        popup.input:SetScript('OnEscapePressed',function() popup:Hide() end)
        popup:SetScript('OnHide',function() shield:Hide() end)
    end
    local popup=promptFrame
    popup.title:SetText(title); popup.message:SetText(message); popup.error:SetText(''); popup.action=options.accept
    popup.accept:SetText(options.button or 'Yes'); popup.cancel:SetText(options.cancel or 'No')
    popup.input:SetText(options.value or ''); popup.input:SetShown(options.name==true)
    popup.shield:Show(); popup:Show()
    if options.name then popup.input:SetFocus() end
end
local function refreshPresets()
    if not window or not window.presetContent then return end
    local names=U.PresetNames(); local buttons=window.presetButtons
    for i,name in ipairs(names) do
        local b=buttons[i]
        if not b then b=button(window.presetContent,'',0,-(i-1)*32,180,function() end); buttons[i]=b; b:SetHeight(28); b.caption:SetWidth(166) end
        b:SetText(name); b.presetName=name; b:Show()
        b:SetScript('OnClick',function()
            prompt('Load preset','Replace the current setup with "'..name..'"?',{accept=function()
                local ok,err=U.LoadPreset(name)
                if ok then U.RenderConfig() end
                return ok,err
            end})
        end)
    end
    for i=#names+1,#buttons do buttons[i]:Hide() end
    window.presetContent:SetHeight(math.max(1,#names*32))
end
local function savePreset()
    prompt('Save Preset','Preset name',{name=true,button='Save',cancel='Cancel',accept=function(name)
        local ok,err,existing=U.SavePreset(name)
        if existing then
            prompt('Replace preset','A preset named "'..existing..'" already exists. Replace it?',{accept=function()
                local saved,reason=U.SavePreset(existing,true); if saved then refreshPresets() end
                return saved,reason
            end})
            return false
        end
        if ok then refreshPresets() end
        return ok,err
    end})
end
local dialog
local function textDialog(title,text,onImport)
    if not dialog then
        dialog=CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
        dialog:SetSize(720,440); dialog:SetPoint('CENTER'); dialog:SetFrameStrata('DIALOG'); dialog:EnableMouse(true)
        dialog:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
        S.Panel(dialog,S.bg,S.header)
        dialog.title=S.TitleBar(dialog,'').title
        local scroll=S.Scroll(dialog)
        scroll:SetPoint('TOPLEFT',20,-55); scroll:SetSize(655,300)
        local box=CreateFrame('EditBox',nil,scroll); box:SetMultiLine(true); S.Font(box,'ChatFontNormal')
        box:SetSize(650,300); box:SetAutoFocus(false); box:SetMaxLetters(32769); box:SetTextInsets(8,8,6,6)
        scroll:SetScrollChild(box); dialog.box=box
        box:SetScript('OnEscapePressed',function() dialog:Hide() end)
        box:SetScript('OnTextChanged',function(self,user)
            if dialog.readonly and user then self:SetText(dialog.output) end
        end)
        dialog.message=label(dialog,'Ctrl+C to copy. Ctrl+V to paste.',20,-370)
        dialog.apply=button(dialog,'Import',460,-395,100,function()
            local c,err=U.Import(dialog.box:GetText())
            if not c then dialog.message:SetText(err); return end
            c.positions=U.db.positions; c.locked=U.db.locked
            U.Commit(c); dialog:Hide(); U.RenderConfig(); U.Print('Setup imported.')
        end)
        button(dialog,'Close',575,-395,100,function() dialog:Hide() end)
    end
    dialog.readonly=not onImport; dialog.output=text or ''; dialog.title:SetText(title); dialog.box:SetText(dialog.output); dialog.apply:SetShown(onImport==true)
    dialog.message:SetText(onImport and 'Import replaces party assignments and priorities. Positions stay unchanged.' or 'Ctrl+C to copy.')
    dialog:Show(); dialog.box:SetFocus(); dialog.box:HighlightText()
end
local picker
local function abilityTooltip(b,spellID,extra)
    local enter=b:GetScript('OnEnter'); local leave=b:GetScript('OnLeave')
    b:SetScript('OnEnter',function(self)
        if enter then enter(self) end
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
        if spellID then
            GameTooltip:SetSpellByID(spellID)
        else
            GameTooltip:SetText('Add ability')
            if extra then GameTooltip:AddLine(extra,.7,.68,.63,true) end
        end
        GameTooltip:Show()
    end)
    b:SetScript('OnLeave',function(self) if leave then leave(self) end; GameTooltip:Hide() end)
end
local function renderPicker()
    local content=picker.content
    activePool=picker.pool; activePool.counts={}
    for _,pool in pairs(activePool.frames) do for _,f in ipairs(pool) do f:Hide() end end
    for _,pool in pairs(activePool.regions) do for _,r in ipairs(pool) do r:Hide() end end
    local query=picker.search:GetText():lower()
    local list={}
    for id,a in pairs(U.Abilities) do
        if (not picker.classFilter or a.class==picker.classFilter) and a.kind==(picker.slot==1 and 'kick' or 'stop') and (a.name..' '..a.class..' '..(a.note or '')):lower():find(query,1,true) then
            list[#list+1]={id=id,ability=a}
        end
    end
    table.sort(list,function(a,b) return a.ability.class..a.ability.name..a.id < b.ability.class..b.ability.name..b.id end)
    for i,item in ipairs(list) do
        local a=item.ability
        local b=button(content,a.name,((i-1)%3)*136,-math.floor((i-1)/3)*38,132,function()
            local ok=change(function(c) U.AssignAbility(c,picker.player,picker.slot,item.id) end)
            if ok then picker:Hide(); U.RenderConfig() end
        end)
        b:SetHeight(34); b.abilityID=item.id
        b.caption:ClearAllPoints(); b.caption:SetPoint('LEFT',38,0); b.caption:SetWidth(88); b.caption:SetHeight(28); b.caption:SetJustifyH('LEFT')
        local icon=region(b,'texture'); icon:SetSize(26,26); icon:SetPoint('LEFT',4,0); icon:SetTexture(a.icon); icon:SetTexCoord(.08,.92,.08,.92)
        abilityTooltip(b,item.id)
    end
    if #list==0 then label(content,'No matching abilities.',10,-15) end
    content:SetHeight(math.max(1,math.ceil(#list/3)*38)); picker.scroll:SetVerticalScroll(0)
    activePool=nil
end
local function chooseAbility(anchor,p,s)
    if not picker then
        picker=CreateFrame('Frame',nil,window,'BackdropTemplate'); picker:SetSize(440,430)
        picker:SetFrameStrata('DIALOG'); picker:EnableMouse(true); S.Panel(picker,S.bg,S.header)
        picker:SetPoint('CENTER',window,'CENTER',140,0)
        picker.title=S.TitleBar(picker,'').title
        picker.search=edit(picker,16,-44,230,'')
        picker.search:SetScript('OnTextChanged',function(_,user) if user then renderPicker() end end)
        picker.scroll=S.Scroll(picker); picker.scroll:SetPoint('TOPLEFT',16,-94); picker.scroll:SetSize(408,290)
        picker.content=CreateFrame('Frame',nil,picker.scroll); picker.content:SetSize(408,1); picker.scroll:SetScrollChild(picker.content)
        picker.pool={frames={},regions={},counts={}}
        button(picker,'Clear slot',16,-394,100,function()
            if change(function(c) U.AssignAbility(c,picker.player,picker.slot,0) end) then picker:Hide(); U.RenderConfig() end
        end)
        label(picker,'Search abilities',16,-72)
        local classes={{'All classes',false},{'Death Knight','DEATHKNIGHT'},{'Demon Hunter','DEMONHUNTER'},{'Druid','DRUID'},{'Evoker','EVOKER'},{'Hunter','HUNTER'},{'Mage','MAGE'},{'Monk','MONK'},{'Paladin','PALADIN'},{'Priest','PRIEST'},{'Rogue','ROGUE'},{'Shaman','SHAMAN'},{'Warlock','WARLOCK'},{'Warrior','WARRIOR'},{'Racial','RACIAL'}}
        picker.classButton=button(picker,'All classes',254,-44,170,function() picker.classMenu:SetShown(not picker.classMenu:IsShown()) end)
        picker.classMenu=CreateFrame('Frame',nil,picker,'BackdropTemplate'); picker.classMenu:SetSize(170,#classes*23+8)
        picker.classMenu:SetPoint('TOPLEFT',254,-70); picker.classMenu:SetFrameLevel(picker:GetFrameLevel()+20); S.Panel(picker.classMenu,nil,S.header)
        for i,item in ipairs(classes) do
            local b=button(picker.classMenu,item[1],4,-4-(i-1)*23,162,function()
                picker.classFilter=item[2]; picker.classButton:SetText(item[1]); picker.classMenu:Hide(); renderPicker()
            end); b:SetHeight(23)
        end
        picker.classMenu:Hide()
    end
    picker.player=p; picker.slot=s; picker.classMenu:Hide()
    picker.title:SetText(s==1 and 'Choose an interrupt' or 'Choose crowd control')
    picker.search:SetText(''); renderPicker(); picker:Show(); picker.search:SetFocus()
end
local function party()
    label(body,'Party members',20,-5,'GameFontNormalSmall'):SetTextColor(unpack(S.gold))
    label(body,'Kick',341,-5,'GameFontNormalSmall'):SetTextColor(unpack(S.gold))
    label(body,'Crowd control',420,-5,'GameFontNormalSmall'):SetTextColor(unpack(S.gold))
    for p=1,5 do
        local player=U.db.players[p]; local y=-31-(p-1)*84
        local card=frame('Frame',nil,body,'BackdropTemplate'); card:SetSize(862,74); card:SetPoint('TOPLEFT',12,y); S.Panel(card)
        label(card,tostring(p),18,-27,'GameFontHighlightSmall'):SetTextColor(unpack(S.muted))
        label(card,'Character',52,-10,'GameFontNormalSmall')
        local name=edit(card,52,-33,230,player.name); name:SetMaxLetters(80)
        name:SetScript('OnEditFocusLost',function(self)
            local value=self:GetText():match('^%s*(.-)%s*$')
            if not change(function(c) c.players[p].name=value end) then self:SetText(U.db.players[p].name) end
        end)
        for slot=1,5 do
            local a=U.Abilities[player.slots[slot].spell]
            local x=slot==1 and 320 or 398+(slot-2)*58
            local b=button(card,a and '' or '+',x,-12,44,function() chooseAbility(nil,p,slot) end)
            b:SetHeight(44); b.playerIndex=p; b.slotIndex=slot
            if a then
                local icon=region(b,'texture'); icon:SetSize(40,40); icon:SetPoint('CENTER'); icon:SetTexture(a.icon); icon:SetTexCoord(.08,.92,.08,.92)
            end
            abilityTooltip(b,a and player.slots[slot].spell,slot==1 and 'Kick slot' or ('Stop slot '..(slot-1)))
        end
        local total=0; for _,slot in ipairs(player.slots) do if slot.spell~=0 then total=total+1 end end
        label(card,total..' / 5 assigned',674,-29)
    end
    label(body,'Click an icon to change an ability.',20,-465)
    body:SetHeight(490)
end
local function layoutPriorities()
    local y=-4
    for _,kind in ipairs({'kick','stop'}) do
        if body.headings and body.headings[kind] then body.headings[kind]:ClearAllPoints(); body.headings[kind]:SetPoint('TOPLEFT',body,'TOPLEFT',15,y); y=y-28
            local columns=body.columns[kind]; columns:ClearAllPoints(); columns:SetPoint('TOPLEFT',body,'TOPLEFT',15,y); y=y-30
        end
        for p=1,5 do
            local list={}
            for s=1,5 do
                local a=U.db.players[p].slots[s]
                if U.Abilities[a.spell] and U.Abilities[a.spell].kind==kind then list[#list+1]={s=s,priority=a.priority} end
            end
            if #list>0 and kind=='stop' then
                local h=body.playerHeadings[p]; h:ClearAllPoints(); h:SetPoint('TOPLEFT',body,'TOPLEFT',20,y); y=y-24
            end
            table.sort(list,function(a,b) if a.priority==b.priority then return a.s<b.s end; return a.priority<b.priority end)
            -- Kicks sorted globally below; stops stay grouped under the party member.
            if kind=='stop' then
                for _,a in ipairs(list) do local r=priorityRows[p..':'..a.s]; r:ClearAllPoints(); r:SetPoint('TOPLEFT',body,'TOPLEFT',15,y); y=y-48 end
            end
        end
        if kind=='kick' then
            local list={}
            for p=1,5 do if priorityRows[p..':1'] then list[#list+1]={p=p,priority=U.db.players[p].slots[1].priority} end end
            table.sort(list,function(a,b) if a.priority==b.priority then return a.p<b.p end; return a.priority<b.priority end)
            for _,a in ipairs(list) do local r=priorityRows[a.p..':1']; r:ClearAllPoints(); r:SetPoint('TOPLEFT',body,'TOPLEFT',15,y); y=y-48 end
        end
        y=y-15
    end
    body:SetHeight(math.max(480,-y))
end
local function priorities()
    priorityRows={}; body.headings={}; body.playerHeadings={}; body.columns={}
    for _,kind in ipairs({'kick','stop'}) do
        local section=frame('Frame',nil,body,'BackdropTemplate'); section:SetSize(862,24); S.Fill(section,S.section); body.headings[kind]=section
        label(section,kind=='kick' and 'Kicks' or 'Stops',12,-4,'GameFontNormal',true):SetTextColor(unpack(S.gold))
        local h=frame('Frame',nil,body,'BackdropTemplate'); h:SetSize(862,24); S.Fill(h,S.tableHeader); body.columns[kind]=h
        for _,column in ipairs({{'Order',8},{'Player / ability',92},{'Chat ID',320},{'Cooldown (s)',560},{'Macro',680}}) do
            label(h,column[1],column[2],-5):SetTextColor(unpack(S.tableText))
        end
    end
    for p=1,5 do
        local player=U.db.players[p]
        body.playerHeadings[p]=label(body,player.name,0,0,'GameFontNormal',true); body.playerHeadings[p]:SetTextColor(unpack(S.gold))
        local hasStops=false
        for s=1,5 do
            local slot=player.slots[s]; local a=U.Abilities[slot.spell]
            if a then
                if s>1 then hasStops=true end
                local r=frame('Frame',nil,body,'BackdropTemplate'); S.Panel(r); r:SetSize(862,44); priorityRows[p..':'..s]=r
                local pr=edit(r,8,-10,36,tostring(slot.priority),true); pr.playerIndex=p; pr.slotIndex=s
                pr:SetScript('OnTextChanged',function(self,user)
                    local n=tonumber(self:GetText())
                    if user and n and n>=1 and n<=999 then
                        if change(function(c) c.players[p].slots[s].priority=n end) then layoutPriorities() end
                    end
                end)
                pr:SetScript('OnEditFocusLost',function(self) self:SetText(U.db.players[p].slots[s].priority) end)
                local iconButton=frame('Button',nil,r); iconButton:SetSize(28,28); iconButton:SetPoint('TOPLEFT',56,-8); iconButton:EnableMouse(true); iconButton.spellID=slot.spell
                local icon=region(iconButton,'texture'); icon:SetAllPoints(); icon:SetTexture(a.icon); icon:SetTexCoord(.08,.92,.08,.92)
                abilityTooltip(iconButton,slot.spell)
                local title=label(r,s==1 and player.name or a.name,92,s==1 and -6 or -14); title:SetWidth(215); title:SetJustifyH('LEFT')
                if s==1 then label(r,a.name,92,-24):SetTextColor(unpack(S.muted)) end
                local tr=label(r,U.Trigger(player,s),320,-14); tr:SetWidth(226); tr:SetJustifyH('LEFT')
                local cd=edit(r,560,-10,64,tostring(slot.override or a.cooldown)); cd:SetMaxLetters(8)
                cd:SetScript('OnEditFocusLost',function(self)
                    local text=self:GetText(); local n=tonumber(text)
                    if text~='' and not n then report('Enter seconds, or clear to reset.'); self:SetText(U.db.players[p].slots[s].override or a.cooldown); return end
                    change(function(c) c.players[p].slots[s].override=n~=a.cooldown and n or nil end); self:SetText(U.db.players[p].slots[s].override or a.cooldown)
                end)
                cd:SetScript('OnEnter',function(self) GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText('Default: '..a.cooldown..' seconds'); GameTooltip:AddLine('Clear to reset.',.7,.75,.85); GameTooltip:Show() end)
                cd:SetScript('OnLeave',function() GameTooltip:Hide() end)
                button(r,'Copy',672,-10,76,function() local text,err=U.Macro(p,s); if text then textDialog('Copy ability macro',text) else report(err) end end)
                button(r,'Create',756,-10,76,function() local id,result=U.CreateAbilityMacro(p,s); report(id and ('Created '..result..' in character macros.') or result) end)
            end
        end
        body.playerHeadings[p]:SetShown(hasStops)
    end
    layoutPriorities()
end
function U.RenderConfig()
    if not window then return end
    if picker then picker:Hide() end
    if body then body:Hide() end
    window.pages=window.pages or {}
    body=window.pages[tab]
    if not body then
        body=CreateFrame('Frame',nil,window.scroll); window.pages[tab]=body
        body.pool={frames={},regions={},counts={}}
    end
    activePool=body.pool; activePool.counts={}
    for _,pool in pairs(activePool.frames) do for _,f in ipairs(pool) do f:Hide() end end
    for _,pool in pairs(activePool.regions) do for _,r in ipairs(pool) do r:Hide() end end
    body:SetSize(890,490); body:Show(); window.scroll:SetScrollChild(body); window.scroll:SetVerticalScroll(0)
    lock:SetText(U.db.locked and 'Unlock Bars' or 'Lock Bars')
    window.heading:SetText(tab==1 and 'Party Setup' or 'Prioritisation')
    window.description:SetText(tab==1 and 'Party members and abilities' or 'Lower numbers take priority. Leave cooldowns blank to use the default.')
    for i,b in ipairs(window.tabs) do b.selected=i==tab; S.Panel(b,b.selected and S.selected or nil,S.border) end
    if tab==1 then party() else priorities() end
    activePool=nil
    window.reset:SetShown(tab==1); refreshPresets()
end
function U.OpenConfig()
    if not window then
        window=CreateFrame('Frame','UnhingedCCOptions',UIParent,'BackdropTemplate'); window:SetSize(1140,720); window:SetPoint('CENTER'); window:SetFrameStrata('HIGH')
        window:SetScale(math.min(1,(UIParent:GetWidth()-40)/1140,(UIParent:GetHeight()-40)/720))
        window:SetClampedToScreen(true); window:EnableMouse(true)
        S.TitleBar(window,'UnhingedCC')
        S.Fill(window,S.bg)
        window:SetScript('OnHide',function() if promptFrame then promptFrame:Hide() end; if picker then picker:Hide() end; if dialog then dialog:Hide() end end)
        tinsert(UISpecialFrames,'UnhingedCCOptions')
        local side=CreateFrame('Frame',nil,window,'BackdropTemplate'); side:SetSize(210,686); side:SetPoint('TOPLEFT',1,-32); S.Fill(side,S.sidebar)
        local divider=side:CreateTexture(nil,'OVERLAY'); divider:SetColorTexture(unpack(S.border)); divider:SetWidth(S.Pixel(side)); divider:SetPoint('TOPRIGHT'); divider:SetPoint('BOTTOMRIGHT')
        window.side=side; window.divider=divider
        label(side,'Settings',20,-28,'GameFontNormalLarge'):SetTextColor(unpack(S.gold))
        window.tabs={
            button(side,'Party Setup',12,-80,186,function() tab=1; U.RenderConfig() end),
            button(side,'Prioritisation',12,-108,186,function() tab=2; U.RenderConfig() end),
        }
        for _,b in ipairs(window.tabs) do b:SetHeight(28) end
        label(side,'Display',20,-205,'GameFontNormalSmall',true):SetTextColor(unpack(S.gold))
        lock=button(side,'Unlock Bars',12,-235,186,function() U.db.locked=not U.db.locked; U.RefreshDisplay(); lock:SetText(U.db.locked and 'Unlock Bars' or 'Lock Bars') end)
        lock:SetHeight(32)
        label(side,'Share',20,-315,'GameFontNormalSmall',true):SetTextColor(unpack(S.gold))
        button(side,'Export',12,-345,88,function() textDialog('Export UnhingedCC config',U.Export(U.db)) end)
        button(side,'Import',110,-345,88,function() textDialog('Import UnhingedCC config','',true) end)
        label(side,'Presets',20,-394,'GameFontNormalSmall',true):SetTextColor(unpack(S.gold))
        window.presetScroll=S.Scroll(side); window.presetScroll:SetPoint('TOPLEFT',12,-420); window.presetScroll:SetSize(186,218)
        window.presetContent=CreateFrame('Frame',nil,window.presetScroll); window.presetContent:SetSize(180,1); window.presetScroll:SetScrollChild(window.presetContent)
        window.presetButtons={}
        label(side,'0.5.1',20,-651)
        window.heading=label(window,'',240,-50,'GameFontNormalLarge'); window.heading:SetTextColor(unpack(S.gold))
        window.description=label(window,'',240,-80); window.description:SetTextColor(unpack(S.muted))
        local line=window:CreateTexture(nil,'ARTWORK'); line:SetColorTexture(unpack(S.border)); line:SetSize(874,1/window:GetEffectiveScale()); line:SetPoint('TOPLEFT',240,-106)
        window.scroll=S.Scroll(window); window.scroll:SetPoint('TOPLEFT',226,-130); window.scroll:SetSize(895,505)
        button(window,'Save Preset',976,-658,142,savePreset)
        window.reset=button(window,'Reset All',242,-658,120,function()
            prompt('Reset setup','Reset party members, abilities, priorities and cooldown settings? Bar positions, lock state, saved presets and macros will be kept.',{button='Reset',cancel='Cancel',accept=function()
                local ok,err=U.ResetConfig(); if ok then U.RenderConfig() end
                return ok,err
            end})
        end)
        status=label(window,'',242,-686); status:SetTextColor(.95,.65,.3)
        tab=1
    end
    S.RefreshFonts(); window:Show(); U.RenderConfig(); report((U.blocked or 0)>0 and ('Unreadable chat messages: '..U.blocked) or '')
end

function U.RefreshConfigLines()
    if window then
        window.divider:SetWidth(S.Pixel(window.side))
    end
end
