local _, U = ...
local groups = {}
local texture = 'Interface\\Buttons\\WHITE8X8'
local function color(e)
    local class = U.classes and U.classes[U.Name(e.player)] or e.ability.class
    local c = RAID_CLASS_COLORS[class]
    return c or {r=.65,g=.65,b=.65}
end
local function makeGroup(kind, label, x)
    local f = CreateFrame('Frame',nil,UIParent,'BackdropTemplate')
    f:SetSize(248,25); f:SetClampedToScreen(true); f:SetMovable(true)
    f:SetBackdrop({bgFile=texture}); f:SetBackdropColor(.06,.06,.07,.85)
    f.label=f:CreateFontString(nil,'OVERLAY','GameFontNormalSmall')
    f.label:SetPoint('TOPLEFT',5,-4); f.label:SetText(label)
    f.rows={}; f.kind=kind
    f:EnableMouse(true); f:RegisterForDrag('LeftButton')
    f:SetScript('OnDragStart',function(self) if not U.db.locked then self:StartMoving() end end)
    f:SetScript('OnDragStop',function(self)
        self:StopMovingOrSizing()
        U.db.positions[kind]={x=self:GetLeft()-UIParent:GetLeft(),y=self:GetTop()-UIParent:GetBottom()}
    end)
    local pos=U.db.positions[kind]
    if pos then f:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',pos.x,pos.y)
    else f:SetPoint('CENTER',UIParent,'CENTER',x,40) end
    return f
end
local function makeRow(parent, i)
    local row=CreateFrame('StatusBar',nil,parent)
    row:SetSize(222,22); row:SetStatusBarTexture(texture)
    row:SetPoint('TOPLEFT',26,-20-(i-1)*24)
    row.bg=row:CreateTexture(nil,'BACKGROUND'); row.bg:SetAllPoints(); row.bg:SetColorTexture(.09,.09,.10,.9)
    row.icon=row:CreateTexture(nil,'ARTWORK'); row.icon:SetSize(22,22); row.icon:SetPoint('RIGHT',row,'LEFT',-2,0)
    row.icon:SetTexCoord(.08,.92,.08,.92)
    row.name=row:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); row.name:SetPoint('LEFT',5,0)
    row.name:SetWidth(162); row.name:SetJustifyH('LEFT')
    row.time=row:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall'); row.time:SetPoint('RIGHT',-4,0)
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
        f:EnableMouse(not U.db.locked)
        f:SetHeight(math.max(44,20+#list*24))
        f.label:SetText((kind=='kick' and 'Kicks' or 'Stops') .. (U.db.locked and '' or ' — drag to move'))
        f:SetShown(#list>0 or not U.db.locked)
        for i,e in ipairs(list) do
            local row=f.rows[i] or makeRow(f,i); f.rows[i]=row; row.entry=e
            row.icon:SetTexture(e.ability.icon); row.name:SetText(e.player:match('^[^-]+'))
            local c=color(e); row:SetStatusBarColor(c.r,c.g,c.b,.95)
            row:Show(); paint(row,now)
            if e.expires>now then active=true end
        end
        for i=#list+1,#f.rows do f.rows[i]:Hide() end
    end
    driver:SetScript('OnUpdate',active and tick or nil)
end
