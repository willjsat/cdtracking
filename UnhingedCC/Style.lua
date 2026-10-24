local _, U = ...
local S = {}; U.Style = S
S.texture = 'Interface\\Buttons\\WHITE8X8'
S.bg = {.055,.062,.075,1}
S.panel = {.085,.095,.112,1}
S.border = {.18,.20,.24,1}
S.accent = {.18,.84,.70,1}
function S.Panel(f, color, border)
    f:SetBackdrop({bgFile=S.texture,edgeFile=S.texture,edgeSize=1/UIParent:GetEffectiveScale()})
    f:SetBackdropColor(unpack(color or S.panel)); f:SetBackdropBorderColor(unpack(border or S.border))
end
function S.Button(f)
    S.Panel(f)
    if not f.caption then
        f.caption=f:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
        f.caption:SetPoint('CENTER'); f:SetFontString(f.caption)
    end
    f.caption:SetTextColor(.83,.85,.89)
    f:SetScript('OnEnter',function(self) self:SetBackdropColor(.14,.17,.20,1); self:SetBackdropBorderColor(unpack(S.accent)) end)
    f:SetScript('OnLeave',function(self) S.Panel(self,self.selected and {.12,.22,.22,1} or nil,self.selected and S.accent or nil) end)
end
function S.Input(f)
    S.Panel(f,{.045,.05,.06,1})
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
