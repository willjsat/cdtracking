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
    for _,script in ipairs({'OnClick','OnTextChanged','OnEditFocusLost','OnEnterPressed','OnEscapePressed'}) do
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
local function label(parent,text,x,y,font)
    local l=region(parent,'font',font or 'GameFontHighlightSmall'); l:SetTextColor(.8,.83,.88)
    l:SetPoint('TOPLEFT',x,y); l:SetText(text); return l
end
local function button(parent,text,x,y,w,fn)
    local b=frame('Button',nil,parent,'BackdropTemplate'); b:SetSize(w or 100,24)
    S.Button(b); b:SetPoint('TOPLEFT',x,y); b:SetText(text); b:SetScript('OnClick',fn); return b
end
local function edit(parent,x,y,w,value,numeric)
    local b=frame('EditBox',nil,parent,'BackdropTemplate'); b:SetSize(w,24); b:SetPoint('TOPLEFT',x,y)
    S.Input(b); b:SetAutoFocus(false); b:SetNumeric(false); b:SetMaxLetters(100); if numeric then b:SetNumeric(true); b:SetMaxLetters(3) end
    b:SetText(value or ''); b:SetScript('OnEscapePressed',function(self) self:ClearFocus() end)
    b:SetScript('OnEnterPressed',function(self) self:ClearFocus() end)
    return b
end
local function report(text) status:SetText(text or '') end
local function change(fn)
    local copy=assert(U.Import(U.Export(U.db)))
    copy.positions=U.db.positions; copy.locked=U.db.locked
    fn(copy)
    local ok,err=U.Commit(copy); report(err)
    return ok
end
local dialog
local function textDialog(title,text,onImport)
    if not dialog then
        dialog=CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
        dialog:SetSize(720,440); dialog:SetPoint('CENTER'); dialog:SetFrameStrata('DIALOG'); dialog:EnableMouse(true)
        dialog:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
        S.Panel(dialog,S.bg,S.accent)
        dialog.title=label(dialog,'',20,-15,'GameFontNormalLarge')
        local scroll=S.Scroll(dialog)
        scroll:SetPoint('TOPLEFT',20,-55); scroll:SetSize(655,300)
        local box=CreateFrame('EditBox',nil,scroll); box:SetMultiLine(true); box:SetFontObject(ChatFontNormal)
        box:SetSize(650,300); box:SetAutoFocus(false); box:SetMaxLetters(32769)
        scroll:SetScrollChild(box); dialog.box=box
        box:SetScript('OnEscapePressed',function() dialog:Hide() end)
        dialog.message=label(dialog,'Ctrl+C to copy. Ctrl+V to paste.',20,-370)
        dialog.apply=button(dialog,'Import',460,-395,100,function()
            local c,err=U.Import(dialog.box:GetText())
            if not c then dialog.message:SetText(err); return end
            c.positions=U.db.positions; c.locked=U.db.locked
            U.Commit(c); dialog:Hide(); U.RenderConfig(); U.Print('Imported party setup and priorities. Active timers retained only for unchanged assignments.')
        end)
        button(dialog,'Close',575,-395,100,function() dialog:Hide() end)
    end
    dialog.title:SetText(title); dialog.box:SetText(text or ''); dialog.apply:SetShown(onImport==true)
    dialog.message:SetText(onImport and 'Import replaces party assignments and priorities. Positions stay unchanged.' or 'Ctrl+C to copy. Macro lines must remain on separate lines.')
    dialog:Show(); dialog.box:SetFocus(); dialog.box:HighlightText()
end
local picker
local function abilityTooltip(b,a,extra)
    local enter=b:GetScript('OnEnter'); local leave=b:GetScript('OnLeave')
    b:SetScript('OnEnter',function(self)
        if enter then enter(self) end
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText(a and a.name or 'Add ability')
        if a then
            GameTooltip:AddLine(a.class..' • '..a.cooldown..' sec baseline',.8,.83,.88)
            if a.note then GameTooltip:AddLine(a.note,.25,.85,.7,true) end
        end
        if extra then GameTooltip:AddLine(extra,.7,.73,.78,true) end
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
        if a.kind==(picker.slot==1 and 'kick' or 'stop') and (a.name..' '..a.class..' '..(a.note or '')):lower():find(query,1,true) then
            list[#list+1]={id=id,ability=a}
        end
    end
    table.sort(list,function(a,b) return a.ability.class..a.ability.name..a.id < b.ability.class..b.ability.name..b.id end)
    for i,item in ipairs(list) do
        local a=item.ability
        local b=button(content,a.name,((i-1)%4)*101,-math.floor((i-1)/4)*78,96,function()
            local ok=change(function(c) c.players[picker.player].slots[picker.slot].spell=item.id; c.players[picker.player].slots[picker.slot].override=nil end)
            if ok then picker:Hide(); U.RenderConfig() end
        end)
        b:SetHeight(72); b.abilityID=item.id
        b.caption:ClearAllPoints(); b.caption:SetPoint('BOTTOM',0,5); b.caption:SetWidth(92); b.caption:SetHeight(25)
        local icon=region(b,'texture'); icon:SetSize(32,32); icon:SetPoint('TOP',0,-5); icon:SetTexture(a.icon); icon:SetTexCoord(.08,.92,.08,.92)
        abilityTooltip(b,a,'Spell ID: '..item.id..' • click to assign')
    end
    if #list==0 then label(content,'No matching abilities.',10,-15) end
    content:SetHeight(math.max(1,math.ceil(#list/4)*78)); picker.scroll:SetVerticalScroll(0)
    activePool=nil
end
local function chooseAbility(anchor,p,s)
    if not picker then
        picker=CreateFrame('Frame',nil,window,'BackdropTemplate'); picker:SetSize(440,435)
        picker:SetFrameStrata('DIALOG'); picker:EnableMouse(true); S.Panel(picker,S.bg,S.accent)
        picker:SetPoint('CENTER',window,'CENTER',140,0)
        picker.title=label(picker,'',16,-16,'GameFontNormalLarge')
        button(picker,'X',400,-10,26,function() picker:Hide() end)
        picker.search=edit(picker,16,-50,408,'')
        picker.search:SetScript('OnTextChanged',function(_,user) if user then renderPicker() end end)
        picker.scroll=S.Scroll(picker); picker.scroll:SetPoint('TOPLEFT',16,-92); picker.scroll:SetSize(408,290)
        picker.content=CreateFrame('Frame',nil,picker.scroll); picker.content:SetSize(408,1); picker.scroll:SetScrollChild(picker.content)
        picker.pool={frames={},regions={},counts={}}
        button(picker,'Clear slot',16,-397,100,function()
            if change(function(c) c.players[picker.player].slots[picker.slot].spell=0; c.players[picker.player].slots[picker.slot].override=nil end) then picker:Hide(); U.RenderConfig() end
        end)
        label(picker,'Search name, class or spec • scroll for more',130,-404)
    end
    picker.player=p; picker.slot=s
    picker.title:SetText(s==1 and 'Choose an interrupt' or 'Choose crowd control')
    picker.search:SetText(''); renderPicker(); picker:Show(); picker.search:SetFocus()
end
local function party()
    label(body,'PARTY MEMBERS',20,-5,'GameFontNormalSmall')
    label(body,'KICK',341,-5,'GameFontNormalSmall')
    label(body,'CROWD CONTROL',420,-5,'GameFontNormalSmall')
    for p=1,5 do
        local player=U.db.players[p]; local y=-31-(p-1)*84
        local card=frame('Frame',nil,body,'BackdropTemplate'); card:SetSize(862,74); card:SetPoint('TOPLEFT',12,y); S.Panel(card)
        label(card,string.format('%02d',p),14,-26,'GameFontNormalLarge'):SetTextColor(unpack(S.accent))
        label(card,'CHARACTER NAME',52,-10,'GameFontNormalSmall')
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
            abilityTooltip(b,a,slot==1 and 'Kick slot • click to change' or ('Stop slot '..(slot-1)..' • click to change'))
        end
        local total=0; for _,slot in ipairs(player.slots) do if slot.spell~=0 then total=total+1 end end
        label(card,total..' / 5 assigned',674,-29)
    end
    label(body,'Click an icon to change it, or + to add an ability. Hover for names and cooldowns.',20,-465)
    body:SetHeight(490)
end
local function layoutPriorities()
    local y=-32
    for _,kind in ipairs({'kick','stop'}) do
        if body.headings and body.headings[kind] then body.headings[kind]:ClearAllPoints(); body.headings[kind]:SetPoint('TOPLEFT',body,'TOPLEFT',15,y); y=y-25 end
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
                for _,a in ipairs(list) do local r=priorityRows[p..':'..a.s]; r:ClearAllPoints(); r:SetPoint('TOPLEFT',body,'TOPLEFT',15,y); y=y-34 end
            end
        end
        if kind=='kick' then
            local list={}
            for p=1,5 do if priorityRows[p..':1'] then list[#list+1]={p=p,priority=U.db.players[p].slots[1].priority} end end
            table.sort(list,function(a,b) if a.priority==b.priority then return a.p<b.p end; return a.priority<b.priority end)
            for _,a in ipairs(list) do local r=priorityRows[a.p..':1']; r:ClearAllPoints(); r:SetPoint('TOPLEFT',body,'TOPLEFT',15,y); y=y-34 end
        end
        y=y-15
    end
    body:SetHeight(math.max(480,-y))
end
local function priorities()
    priorityRows={}; body.headings={}; body.playerHeadings={}
    label(body,'Priority     Player / Ability                                     Tracking ID (read-only)                       CD seconds       Macro',15,-5,'GameFontNormalSmall')
    for _,kind in ipairs({'kick','stop'}) do body.headings[kind]=label(body,kind=='kick' and 'Kicks' or 'Stops',0,0,'GameFontNormalLarge') end
    for p=1,5 do
        local player=U.db.players[p]
        body.playerHeadings[p]=label(body,player.name,0,0,'GameFontNormal')
        local hasStops=false
        for s=1,5 do
            local slot=player.slots[s]; local a=U.Abilities[slot.spell]
            if a then
                if s>1 then hasStops=true end
                local r=frame('Frame',nil,body,'BackdropTemplate'); S.Panel(r); r:SetSize(862,30); priorityRows[p..':'..s]=r
                local pr=edit(r,5,0,35,tostring(slot.priority),true)
                pr:SetScript('OnTextChanged',function(self,user)
                    local n=tonumber(self:GetText())
                    if user and n and n>=1 and n<=999 then
                        if change(function(c) c.players[p].slots[s].priority=n end) then layoutPriorities() end
                    end
                end)
                pr:SetScript('OnEditFocusLost',function(self) self:SetText(U.db.players[p].slots[s].priority) end)
                local icon=region(r,'texture'); icon:SetSize(24,24); icon:SetPoint('TOPLEFT',52,0); icon:SetTexture(a.icon)
                local title=label(r,(s==1 and player.name..' — ' or '')..a.name,82,-5); title:SetWidth(295); title:SetJustifyH('LEFT')
                local tr=label(r,U.Trigger(player,s),390,-5); tr:SetWidth(185); tr:SetJustifyH('LEFT')
                local cd=edit(r,595,0,64,tostring(slot.override or '')); cd:SetMaxLetters(8)
                cd:SetScript('OnEditFocusLost',function(self)
                    local text=self:GetText(); local n=tonumber(text)
                    if text~='' and not n then report('Enter a cooldown in seconds, or leave blank for baseline.'); self:SetText(U.db.players[p].slots[s].override or ''); return end
                    if not change(function(c) c.players[p].slots[s].override=n end) then self:SetText(U.db.players[p].slots[s].override or '') end
                end)
                button(r,'Copy',680,0,65,function() local text,err=U.Macro(p,s); if text then textDialog('Copy ability macro',text) else report(err) end end)
                button(r,'Create',750,0,65,function() U.CreateAbilityMacro(p,s) end)
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
    window.description:SetText(tab==1 and 'Build your party. Choose an interrupt and four crowd-control abilities per player.' or 'Set your rotation order and cooldown overrides. Tracking IDs are generated automatically.')
    for i,b in ipairs(window.tabs) do b.selected=i==tab; S.Panel(b,b.selected and {.12,.22,.22,1} or nil,b.selected and S.accent or nil) end
    if tab==1 then party() else priorities() end
    activePool=nil
end
function U.OpenConfig()
    if not window then
        window=CreateFrame('Frame','UnhingedCCOptions',UIParent,'BackdropTemplate'); window:SetSize(1140,720); window:SetPoint('CENTER'); window:SetFrameStrata('HIGH')
        window:SetScale(math.min(1,(UIParent:GetWidth()-40)/1140,(UIParent:GetHeight()-40)/720))
        window:SetClampedToScreen(true); window:EnableMouse(true); window:SetMovable(true); window:RegisterForDrag('LeftButton')
        window:SetScript('OnDragStart',window.StartMoving); window:SetScript('OnDragStop',window.StopMovingOrSizing)
        S.Panel(window,S.bg)
        window:SetScript('OnHide',function() if picker then picker:Hide() end; if dialog then dialog:Hide() end end)
        tinsert(UISpecialFrames,'UnhingedCCOptions')
        local side=CreateFrame('Frame',nil,window,'BackdropTemplate'); side:SetSize(210,718); side:SetPoint('TOPLEFT',1,-1); S.Panel(side,{.07,.08,.095,1})
        label(side,'UnhingedCC',20,-28,'GameFontNormalLarge'):SetTextColor(unpack(S.accent))
        label(side,'PARTY COOLDOWNS',20,-58)
        label(side,'CONFIGURATION',20,-114,'GameFontNormalSmall')
        window.tabs={
            button(side,'Party Setup',12,-145,186,function() tab=1; U.RenderConfig() end),
            button(side,'Prioritisation',12,-185,186,function() tab=2; U.RenderConfig() end),
        }
        for _,b in ipairs(window.tabs) do b:SetHeight(34) end
        label(side,'DISPLAY',20,-260,'GameFontNormalSmall')
        lock=button(side,'Unlock Bars',12,-290,186,function() U.db.locked=not U.db.locked; U.RefreshDisplay(); lock:SetText(U.db.locked and 'Unlock Bars' or 'Lock Bars') end)
        lock:SetHeight(32)
        label(side,'SHARE SETUP',20,-370,'GameFontNormalSmall')
        button(side,'Export',12,-400,88,function() textDialog('Export UnhingedCC config',U.Export(U.db)) end)
        button(side,'Import',110,-400,88,function() textDialog('Import UnhingedCC config','',true) end)
        label(side,'0.2.1  •  Retail 12.1.5',20,-680)
        window.heading=label(window,'',240,-30,'GameFontNormalHuge')
        window.description=label(window,'',240,-71)
        button(window,'Close',1030,-24,86,function() window:Hide() end)
        local line=window:CreateTexture(nil,'ARTWORK'); line:SetColorTexture(unpack(S.border)); line:SetSize(874,1); line:SetPoint('TOPLEFT',240,-106)
        window.scroll=S.Scroll(window); window.scroll:SetPoint('TOPLEFT',226,-130); window.scroll:SetSize(895,505)
        label(window,'Blank CD = baseline. Ready abilities first; cooling abilities ordered by time remaining. Scroll for more.',242,-658)
        status=label(window,'',242,-686); status:SetTextColor(.95,.65,.3)
        tab=1
    end
    window:Show(); U.RenderConfig(); report('Unreadable chat events skipped: '..(U.blocked or 0)..'. /ucc status shows the current count.')
end
