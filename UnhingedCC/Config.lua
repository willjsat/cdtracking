local _, U = ...
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
    local l=region(parent,'font',font or 'GameFontHighlightSmall')
    l:SetPoint('TOPLEFT',x,y); l:SetText(text); return l
end
local function button(parent,text,x,y,w,fn)
    local b=frame('Button',nil,parent,'UIPanelButtonTemplate'); b:SetSize(w or 100,24)
    b:SetPoint('TOPLEFT',x,y); b:SetText(text); b:SetScript('OnClick',fn); return b
end
local function edit(parent,x,y,w,value,numeric)
    local b=frame('EditBox',nil,parent,'InputBoxTemplate'); b:SetSize(w,24); b:SetPoint('TOPLEFT',x,y)
    b:SetAutoFocus(false); b:SetNumeric(false); b:SetMaxLetters(100); if numeric then b:SetNumeric(true); b:SetMaxLetters(3) end
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
        dialog:SetBackdropColor(.07,.07,.09,1); dialog:SetBackdropBorderColor(.4,.3,.6,1)
        dialog.title=label(dialog,'',20,-15,'GameFontNormalLarge')
        local scroll=CreateFrame('ScrollFrame',nil,dialog,'UIPanelScrollFrameTemplate')
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
local function chooseAbility(anchor,p,s)
    if picker then picker:Hide() end
    if not picker then
    picker=CreateFrame('Frame',nil,window,'BackdropTemplate'); picker:SetSize(320,330)
    picker:SetFrameStrata('DIALOG'); picker:SetPoint('TOPLEFT',window,'TOPLEFT',540,-100)
    picker:EnableMouse(true); picker:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8'}); picker:SetBackdropColor(.08,.08,.1,1)
    picker.title=label(picker,'',12,-10,'GameFontNormal')
    button(picker,'X',280,-5,28,function() picker:Hide() end)
    local scroll=CreateFrame('ScrollFrame',nil,picker,'UIPanelScrollFrameTemplate'); scroll:SetPoint('TOPLEFT',8,-38); scroll:SetSize(280,280)
    local content=CreateFrame('Frame',nil,scroll); content:SetSize(275,1); scroll:SetScrollChild(content)
    picker.scroll=scroll
    picker.content=content; picker.pool={frames={},regions={},counts={}}
    end
    picker.title:SetText(s==1 and 'Choose a kick' or 'Choose a stop')
    local content=picker.content
    picker.scroll:SetVerticalScroll(0)
    activePool=picker.pool; activePool.counts={}
    for _,pool in pairs(activePool.frames) do for _,f in ipairs(pool) do f:Hide() end end
    for _,pool in pairs(activePool.regions) do for _,r in ipairs(pool) do r:Hide() end end
    local list={{id=0,name='Clear slot'}}
    for id,a in pairs(U.Abilities) do if a.kind==(s==1 and 'kick' or 'stop') then list[#list+1]={id=id,name=a.name,class=a.class} end end
    table.sort(list,function(a,b) if a.id==0 or b.id==0 then return a.id==0 end; return a.class..a.name < b.class..b.name end)
    for i,item in ipairs(list) do
        local b=button(content,(item.class and item.class..' — ' or '')..item.name,25,-(i-1)*27,245,function()
            change(function(c) c.players[p].slots[s].spell=item.id; c.players[p].slots[s].override=nil end)
            picker:Hide(); U.RenderConfig()
        end)
        if item.id~=0 then local icon=region(b,'texture'); icon:SetSize(22,22); icon:SetPoint('RIGHT',b,'LEFT',-3,0); icon:SetTexture(U.Abilities[item.id].icon) end
    end
    content:SetHeight(#list*27)
    activePool=nil; picker:Show()
end
local function party()
    label(body,'Player (Name-Realm recommended)',15,-5,'GameFontNormal')
    label(body,'Slot 1: Kick                  Slot 2: Stop                  Slot 3: Stop                  Slot 4: Stop                  Slot 5: Stop',235,-5,'GameFontNormalSmall')
    for p=1,5 do
        local player=U.db.players[p]; local y=-35-(p-1)*78
        local name=edit(body,20,y,190,player.name)
        name:SetScript('OnEditFocusLost',function(self)
            local value=self:GetText():match('^%s*(.-)%s*$')
            if not change(function(c) c.players[p].name=value end) then self:SetText(U.db.players[p].name) end
        end)
        for s=1,5 do
            local a=U.Abilities[player.slots[s].spell]
            local b=button(body,a and a.name or '+ Select',235+(s-1)*129,y,123,function() chooseAbility(nil,p,s) end)
            b:SetNormalFontObject('GameFontHighlightSmall')
            if a then
                local icon=region(body,'texture'); icon:SetSize(20,20); icon:SetPoint('TOPLEFT',245+(s-1)*129,y-28); icon:SetTexture(a.icon)
                label(body,tostring(player.slots[s].override or a.cooldown)..' sec',270+(s-1)*129,y-32)
            end
        end
    end
    label(body,'Save names with Enter or click away. Configure chat values, cooldown overrides and macros in Prioritisation.',15,-445)
    label(body,'Chat announcements estimate usage, even if /cast fails. Unreadable combat chat cannot trigger timers.',15,-472)
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
    label(body,'Priority     Player / Ability                                     Exact chat value                       CD seconds       Macro',15,-5,'GameFontNormalSmall')
    for _,kind in ipairs({'kick','stop'}) do body.headings[kind]=label(body,kind=='kick' and 'Kicks' or 'Stops',0,0,'GameFontNormalLarge') end
    for p=1,5 do
        local player=U.db.players[p]
        body.playerHeadings[p]=label(body,player.name,0,0,'GameFontNormal')
        local hasStops=false
        for s=1,5 do
            local slot=player.slots[s]; local a=U.Abilities[slot.spell]
            if a then
                if s>1 then hasStops=true end
                local r=frame('Frame',nil,body); r:SetSize(880,30); priorityRows[p..':'..s]=r
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
                local tr=edit(r,390,0,185,U.Trigger(player,s)); tr:SetMaxLetters(100)
                tr:SetScript('OnEditFocusLost',function(self)
                    if not change(function(c) c.players[p].slots[s].trigger=self:GetText() end) then self:SetText(U.Trigger(U.db.players[p],s)) end
                end)
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
    if tab==1 then party() else priorities() end
    activePool=nil
end
function U.OpenConfig()
    if not window then
        window=CreateFrame('Frame','UnhingedCCOptions',UIParent,'BackdropTemplate'); window:SetSize(950,650); window:SetPoint('CENTER'); window:SetFrameStrata('HIGH')
        window:SetClampedToScreen(true); window:EnableMouse(true); window:SetMovable(true); window:RegisterForDrag('LeftButton')
        window:SetScript('OnDragStart',window.StartMoving); window:SetScript('OnDragStop',window.StopMovingOrSizing)
        window:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1})
        window:SetBackdropColor(.055,.055,.075,.98); window:SetBackdropBorderColor(.4,.3,.6,1)
        tinsert(UISpecialFrames,'UnhingedCCOptions')
        label(window,'UnhingedCC',20,-16,'GameFontNormalLarge')
        button(window,'Close',840,-12,90,function() window:Hide() end)
        button(window,'Party Setup',20,-50,130,function() tab=1; U.RenderConfig() end)
        button(window,'Prioritisation',155,-50,130,function() tab=2; U.RenderConfig() end)
        lock=button(window,'Unlock Bars',310,-50,120,function() U.db.locked=not U.db.locked; U.RefreshDisplay(); lock:SetText(U.db.locked and 'Unlock Bars' or 'Lock Bars') end)
        button(window,'Export',660,-50,100,function() textDialog('Export UnhingedCC config',U.Export(U.db)) end)
        button(window,'Import',770,-50,100,function() textDialog('Import UnhingedCC config','',true) end)
        status=label(window,'',20,-610); status:SetTextColor(1,.6,.3)
        label(window,'Blank CD = baseline. Smaller priority = earlier. Ready abilities first; active timers ordered by remaining time.',20,-585)
        window.scroll=CreateFrame('ScrollFrame',nil,window,'UIPanelScrollFrameTemplate'); window.scroll:SetPoint('TOPLEFT',15,-94); window.scroll:SetSize(900,480)
        window.recycle=CreateFrame('Frame',nil,window); window.recycle:Hide()
        tab=1
    end
    window:Show(); U.RenderConfig(); report('Unreadable chat events skipped: '..(U.blocked or 0)..'. /ucc status shows the current count.')
end
