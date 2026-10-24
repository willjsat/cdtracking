local _, U = ...
local groups = {}
local WIDTH, HEIGHT, ICON_GAP = 248 * .8, 22, 2
local function round(v) return math.floor(v+.5) end
local function metrics(f)
    local pixel=U.Style.Pixel(f)
    local height=math.max(1,round(HEIGHT/pixel))
    local width=math.max(height+2,round(WIDTH/pixel))
    local iconGap=math.max(1,round(ICON_GAP/pixel))
    return {pixel=pixel,height=height*pixel,width=width*pixel,gap=pixel,step=(height+1)*pixel,inset=(height+iconGap)*pixel,iconGap=iconGap*pixel}
end
local function positionGroup(f,kind)
    local pos=U.db.positions[kind]
    local x=pos and pos.x or UIParent:GetWidth()/2+(kind=='kick' and -160 or 160)-WIDTH/2
    local y=pos and pos.y or UIParent:GetHeight()/2+40+HEIGHT/2
    local pixel=U.Style.Pixel(UIParent)
    f:ClearAllPoints()
    f:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',round(x/pixel)*pixel,round(y/pixel)*pixel)
end
local function snapTexture(t)
    t:SetSnapToPixelGrid(true); t:SetTexelSnappingBias(0)
end
local texture = 'Interface\\Buttons\\WHITE8X8'
local function color(e)
    local class = U.classes and U.classes[U.Name(e.player)] or e.ability.class
    local c = RAID_CLASS_COLORS[class]
    return c or {r=.65,g=.65,b=.65}
end
local function makeGroup(kind, label)
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
        local pixel=U.Style.Pixel(UIParent)
        U.db.positions[kind]={x=round((f:GetLeft()-UIParent:GetLeft())/pixel)*pixel,y=round((f:GetTop()-UIParent:GetBottom())/pixel)*pixel}
        positionGroup(f,kind)
    end)
    positionGroup(f,kind)
    return f
end
local function makeRow(parent)
    local row=CreateFrame('StatusBar',nil,parent)
    row:SetStatusBarTexture(texture)
    local fill=row:GetStatusBarTexture(); if fill then snapTexture(fill) end
    row.bg=row:CreateTexture(nil,'BACKGROUND'); row.bg:SetAllPoints(); row.bg:SetColorTexture(.09,.09,.10,.9); snapTexture(row.bg)
    row.icon=row:CreateTexture(nil,'ARTWORK'); snapTexture(row.icon)
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
        groups.kick=makeGroup('kick','Kicks')
        groups.stop=makeGroup('stop','Stops')
    end
    local now,active=GetTime(),false
    for kind,f in pairs(groups) do
        local list=U.Order(kind,now)
        f.mover:SetShown(not U.db.locked)
        local m=metrics(f)
        f:SetSize(m.width,math.max(m.height,#list*m.height+math.max(0,#list-1)*m.gap))
        if f.layoutPixel~=m.pixel then positionGroup(f,kind); f.layoutPixel=m.pixel end
        f:SetShown(#list>0 or not U.db.locked)
        for i,e in ipairs(list) do
            local row=f.rows[i] or makeRow(f); f.rows[i]=row; row.entry=e
            row:SetSize(m.width-m.inset,m.height)
            row:ClearAllPoints(); row:SetPoint('TOPLEFT',m.inset,-(i-1)*m.step)
            row.icon:SetSize(m.height,m.height); row.icon:ClearAllPoints(); row.icon:SetPoint('RIGHT',row,'LEFT',-m.iconGap,0)
            row.name:SetWidth(math.max(1,m.width-m.inset-48))
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
    for kind,f in pairs(groups) do positionGroup(f,kind) end
end
