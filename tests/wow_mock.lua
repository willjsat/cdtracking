unpack=unpack or table.unpack
local methods={}
frames={}; clock=100; DEFAULT_CHAT_FRAME={AddMessage=function() end}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:HasScript() return true end
function methods:RegisterEvent(e) self.events[e]=true end
function methods:UnregisterEvent(e) self.events[e]=nil end
function methods:SetText(s) self.text=tostring(s); if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
function methods:SetSpellByID(id) self.tooltipSpell=id; self.tooltipCalls=(self.tooltipCalls or 0)+1 end
function methods:GetText() return self.text or '' end
function methods:SetParent(p) self.parent=p end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() self.point=nil end
-- Changing inheritance need not clear local SetFont overrides.
function methods:SetFontObject(font) self.fontObject=type(font)=='string' and (_G[font] or GameFontNormal) or font end
function methods:GetFont()
 if self.fontPath then return self.fontPath,self.fontSize,self.fontFlags end
 if self.fontObject then return self.fontObject:GetFont() end
 return 'Fonts\\FRIZQT__.TTF',11,''
end
function methods:SetFont(path,size,flags)
 if path=='missing-font' then return false end
 self.fontPath=path; self.fontSize=size; self.fontFlags=flags; return true
end
function methods:GetEffectiveScale() return (self.scale or 1)*(self.parent and self.parent:GetEffectiveScale() or 1) end
function methods:SetScale(s) self.scale=s end
function methods:SetBackdrop(b) self.backdrop=b end
function methods:GetBackdrop() return self.backdrop end
function methods:SetBackdropColor(...) self.backdropColor={...} end
function methods:GetBackdropColor() return unpack(self.backdropColor or {1,1,1,1}) end
function methods:SetBackdropBorderColor(...) self.borderColor={...} end
function methods:GetBackdropBorderColor() return unpack(self.borderColor or {1,1,1,1}) end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:GetFrameLevel() return 1 end
function methods:GetWidth() return self.width or 1920 end
function methods:GetHeight() return self.height or 1080 end
function methods:SetVerticalScroll(n) self.scroll=n end
function methods:GetVerticalScroll() return self.scroll or 0 end
function methods:GetVerticalScrollRange() return 100 end
function methods:GetLeft() return 100 end
function methods:GetTop() return 200 end
function methods:GetBottom() return 0 end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown~=false end
function methods:SetShown(v) self.shown=v end
function methods:CreateFontString() return CreateFrame('FontString',nil,self) end
function methods:CreateTexture() return CreateFrame('Texture',nil,self) end
local mt={__index=function(t,k) return methods[k] or (k:match('^[A-Z]') and function() end or nil) end}
function CreateFrame(kind,name,parent,template)
 local f=setmetatable({kind=kind,parent=parent,template=template,scripts={},events={},name=name},mt)
 frames[#frames+1]=f; return f
end
GameFontNormal={GetFont=function() return 'game-font',12,'' end}
GameFontHighlightSmall=GameFontNormal
UIParent=CreateFrame('Frame'); RAID_CLASS_COLORS=setmetatable({},{__index=function() return {r=.5,g=.6,b=.7} end})
GameTooltip=CreateFrame('Tooltip'); UISpecialFrames={}; SlashCmdList={}; tinsert=table.insert
function GetTime() return clock end
function UnitExists(u) return u=='player' or u=='party1' end
function UnitFullName(u) return u=='player' and 'Brick' or 'Mage','Realm' end
function UnitClass() return 'Demon Hunter','DEMONHUNTER' end
function GetNormalizedRealmName() return 'Realm' end
C_Spell={GetSpellName=function(id) return U.Abilities[id].name end}
function IsInGroup() return false end
function InCombatLockdown() return false end
macroStore={}
function GetMacroInfo(key) local m=macroStore[key]; if m then return m.name,m.icon,m.body end end
function GetNumMacros() return 0,0 end
Constants={MacroConsts={MAX_CHARACTER_MACROS=30,MAX_ACCOUNT_MACROS=120}}
MAX_CHARACTER_MACROS=nil
function CreateMacro(name,icon,text) lastMacro=text; macroStore[121]={name=name,icon=icon,body=text}; macroStore[name]=macroStore[121]; return 121 end
secret={}; function issecretvalue(v) return rawequal(v,secret) end
