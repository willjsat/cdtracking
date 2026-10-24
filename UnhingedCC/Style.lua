local _, U = ...
local S = {}; U.Style = S
S.texture = 'Interface\\Buttons\\WHITE8X8'
S.bg = {.025,.035,.065,1}
S.panel = {.045,.065,.115,1}
S.border = {.16,.22,.38,1}
S.accent = {.46,.36,.94,1}
S.selected = {.10,.13,.25,1}
S.borders={}
function S.Panel(f, color, border)
    S.borders[f]=true
    f:SetBackdrop({bgFile=S.texture,edgeFile=S.texture,edgeSize=1/f:GetEffectiveScale()})
    f:SetBackdropColor(unpack(color or S.panel)); f:SetBackdropBorderColor(unpack(border or S.border))
end
function S.RefreshBorders()
    for f in pairs(S.borders) do
        local backdrop=f:GetBackdrop()
        if backdrop then
            local r,g,b,a=f:GetBackdropColor(); local br,bg,bb,ba=f:GetBackdropBorderColor()
            backdrop.edgeSize=1/f:GetEffectiveScale(); f:SetBackdrop(backdrop)
            f:SetBackdropColor(r,g,b,a); f:SetBackdropBorderColor(br,bg,bb,ba)
        end
    end
end
function S.Button(f)
    S.Panel(f)
    if not f.caption then
        f.caption=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
        f.caption:SetPoint('CENTER'); f:SetFontString(f.caption)
    end
    f.caption:SetTextColor(.83,.85,.89)
    f:SetScript('OnEnter',function(self) self:SetBackdropColor(.10,.15,.27,1); self:SetBackdropBorderColor(unpack(S.accent)) end)
    f:SetScript('OnLeave',function(self) S.Panel(self,self.selected and S.selected or nil,self.selected and S.accent or nil) end)
end
function S.Input(f)
    S.Panel(f,{.025,.035,.06,1})
    f:SetFontObject('GameFontHighlightSmall'); f:SetTextInsets(8,8,0,0)
end
function S.Scroll(parent)
    local f=CreateFrame('ScrollFrame',nil,parent)
    f:EnableMouseWheel(true)
    f:SetScript('OnMouseWheel',function(self,delta)
        self:SetVerticalScroll(math.max(0,math.min(self:GetVerticalScrollRange(),self:GetVerticalScroll()-delta*42)))
    end)
    return f
end

function S.TitleBar(owner, text)
    owner:SetMovable(true)
    local bar=CreateFrame('Frame',nil,owner,'BackdropTemplate')
    bar:SetPoint('TOPLEFT',1,-1); bar:SetSize(owner:GetWidth()-2,30)
    S.Panel(bar,{.075,.09,.18,1})
    bar:EnableMouse(true); bar:RegisterForDrag('LeftButton')
    bar:SetScript('OnDragStart',function() owner:StartMoving() end)
    bar:SetScript('OnDragStop',function() owner:StopMovingOrSizing() end)
    bar.title=bar:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
    bar.title:SetPoint('LEFT',10,0); bar.title:SetText(text)
    local close=CreateFrame('Button',nil,bar,'BackdropTemplate'); close:SetSize(40,28); close:SetPoint('TOPRIGHT',-1,-1)
    S.Button(close); close:SetText('X'); S.Panel(close,{.55,.08,.13,1},{.72,.15,.20,1})
    close:SetScript('OnEnter',function(self) S.Panel(self,{.8,.12,.18,1}) end)
    close:SetScript('OnLeave',function(self) S.Panel(self,{.55,.08,.13,1},{.72,.15,.20,1}) end)
    close:SetScript('OnClick',function() owner:Hide() end)
    bar.close=close; owner.titleBar=bar
    return bar
end
