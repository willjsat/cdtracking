unpack=unpack or table.unpack
local methods={}
frames={}; clock=100; DEFAULT_CHAT_FRAME={AddMessage=function() end}
function methods:SetScript(k,v) self.scripts[k]=v end
function methods:GetScript(k) return self.scripts[k] end
function methods:HasScript() return true end
function methods:RegisterEvent(e) self.events[e]=true end
function methods:UnregisterEvent(e) self.events[e]=nil end
function methods:SetText(s) self.text=tostring(s); if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
function methods:GetText() return self.text or '' end
function methods:SetParent(p) self.parent=p end
function methods:SetSize(w,h) self.width=w;self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:SetPoint(...) self.point={...} end
function methods:ClearAllPoints() self.point=nil end
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
function GetMacroInfo() return nil end
function GetNumMacros() return 0,0 end
MAX_CHARACTER_MACROS=30
function CreateMacro(name,icon,text) lastMacro=text; return 1 end
secret={}; function issecretvalue(v) return rawequal(v,secret) end
