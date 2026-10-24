local _, U = ...
local groups = {}
local WIDTH, HEIGHT, ICON_GAP = 248 * .8, 22, 2
local function pixel() return 1 / UIParent:GetEffectiveScale() end
local texture = 'Interface\\Buttons\\WHITE8X8'
local function color(e)
    local class = U.classes and U.classes[U.Name(e.player)] or e.ability.class
    local c = RAID_CLASS_COLORS[class]
    return c or {r=.65,g=.65,b=.65}
end
local function makeGroup(kind, label, x)
    local f = CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
    f:SetSize(WIDTH,HEIGHT); f:SetClampedToScreen(true); f:SetMovable(true)
    f.rows={}; f.kind=kind
    -- An overlay is interactive only in unlock mode; no permanent header or padding.
    f.mover=CreateFrame('Frame',nil,f,'BackdropTemplate'); f.mover:SetAllPoints()
    f.mover:SetFrameLevel(f:GetFrameLevel()+10)
    U.Style.Panel(f.mover,{.10,.09,.07,.8},U.Style.accent)
    f.mover.label=f.mover:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
    U.Style.Font(f.mover.label,'GameFontNormalSmall',true); f.mover.label:SetPoint('CENTER'); f.mover.label:SetText(label..' — drag')
    f.mover:EnableMouse(true); f.mover:RegisterForDrag('LeftButton')
    f.mover:SetScript('OnDragStart',function() if not U.db.locked then f:StartMoving() end end)
    f.mover:SetScript('OnDragStop',function()
        f:StopMovingOrSizing()
        U.db.positions[kind]={x=f:GetLeft()-UIParent:GetLeft(),y=f:GetTop()-UIParent:GetBottom()}
    end)
    local pos=U.db.positions[kind]
    if pos then f:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',pos.x,pos.y)
    else f:SetPoint('CENTER',UIParent,'CENTER',x,40) end
    return f
end
local function makeRow(parent, i)
    local row=CreateFrame('StatusBar',nil,parent)
    row:SetSize(WIDTH-HEIGHT-ICON_GAP,HEIGHT); row:SetStatusBarTexture(texture)
    row:SetPoint('TOPLEFT',HEIGHT+ICON_GAP,-(i-1)*(HEIGHT+pixel()))
    row.bg=row:CreateTexture(nil,'BACKGROUND'); row.bg:SetAllPoints(); row.bg:SetColorTexture(.09,.09,.10,.9)
    row.icon=row:CreateTexture(nil,'ARTWORK'); row.icon:SetSize(22,22); row.icon:SetPoint('RIGHT',row,'LEFT',-2,0)
    row.icon:SetTexCoord(.08,.92,.08,.92)
    row.name=row:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); U.Style.Font(row.name); row.name:SetPoint('LEFT',5,0)
    row.name:SetWidth(WIDTH-HEIGHT-ICON_GAP-48); row.name:SetJustifyH('LEFT')
    row.time=row:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); U.Style.Font(row.time); row.time:SetPoint('RIGHT',-4,0)
    row:EnableMouse(true)
    row:SetScript('OnEnter',function(self)
        GameTooltip:SetOwner(self,'ANCHOR_RIGHT')
        GameTooltip:SetText(self.entry.ability.name)
        GameTooltip:AddLine(self.entry.player .. ' — ' .. self.entry.trigger,1,1,1)
        GameTooltip:AddLine('Estimated cooldown: '..self.entry.duration..' sec',.8,.8,.8)
        GameTooltip:Show()
    end)
    row:SetScript('OnLeave',function() GameTooltip:Hide() end)
    return row
end
local function paint(row,now)
    local e=row.entry
    local remaining=math.max(0,e.expires-now)
    row:SetMinMaxValues(0,e.duration); row:SetValue(remaining>0 and remaining or e.duration)
    row.time:SetText(remaining>0 and string.format(remaining<10 and '%.1f' or '%.0f',remaining) or '')
    row.ready=remaining==0
end
local driver=CreateFrame('Frame')
local elapsed=0
local function tick(_,dt)
    elapsed=elapsed+dt; if elapsed<.05 then return end; elapsed=0
    local now,changed=GetTime(),false
    for _,f in pairs(groups) do
        for _,row in ipairs(f.rows) do
            if row:IsShown() then
                if not row.ready and row.entry.expires<=now then changed=true end
                paint(row,now)
            end
        end
    end
    if changed then U.RefreshDisplay() end
end
function U.RefreshDisplay()
    if not groups.kick then
        groups.kick=makeGroup('kick','Kicks',-160)
        groups.stop=makeGroup('stop','Stops',160)
    end
    local now,active=GetTime(),false
    for kind,f in pairs(groups) do
        local list=U.Order(kind,now)
        f.mover:SetShown(not U.db.locked)
        f:SetHeight(math.max(HEIGHT,#list*HEIGHT+math.max(0,#list-1)*pixel()))
        f:SetShown(#list>0 or not U.db.locked)
        for i,e in ipairs(list) do
            local row=f.rows[i] or makeRow(f,i); f.rows[i]=row; row.entry=e
            row:ClearAllPoints(); row:SetPoint('TOPLEFT',HEIGHT+ICON_GAP,-(i-1)*(HEIGHT+pixel()))
            row.icon:SetTexture(e.ability.icon); row.name:SetText(e.player:match('^[^-]+'))
            local c=color(e); row:SetStatusBarColor(c.r,c.g,c.b,.95)
            row:Show(); paint(row,now)
            if e.expires>now then active=true end
        end
        for i=#list+1,#f.rows do f.rows[i]:Hide() end
    end
    driver:SetScript('OnUpdate',active and tick or nil)
end

function U.RestoreDisplayPositions()
    for kind,f in pairs(groups) do
        f:ClearAllPoints()
        local pos=U.db.positions[kind]
        if pos then f:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',pos.x,pos.y)
        else f:SetPoint('CENTER',UIParent,'CENTER',kind=='kick' and -160 or 160,40) end
    end
end
