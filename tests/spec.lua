local count=0
local function check(v,why) count=count+1; assert(v,why) end
local function eq(a,b,why) check(a==b,(why or '')..' expected '..tostring(b)..', got '..tostring(a)) end
local function clone(c) return assert(U.Import(U.Export(c))) end
local c=U.NewConfig(); c.players[1].name='Brick'; c.players[2].name='Mage-Realm'
c.players[1].slots[1].spell=183752; c.players[1].slots[2].spell=179057
c.players[2].slots[1].spell=2139
local valid,err=U.Validate(c); check(valid,err)
eq(#c.players,5); eq(#c.players[1].slots,5)
c.players[1].slots[2].trigger='CustomStop'; c.players[1].slots[2].override=33
local imported=assert(U.Import(U.Export(c)))
eq(imported.players[1].slots[2].override,33)
eq(imported.players[1].slots[2].trigger,'CustomStop')
check(not U.Import('return os.execute("bad")'))
check(not U.Import(string.rep('X',32769)))
check(not U.Import(U.Export(c):gsub('Brick','%%ZZ',1)))
local bad=clone(c); bad.players[1].slots[2].spell=183752; check(not U.Validate(bad),'reject kick in stop slot')
bad=clone(c); bad.players[2].name='brick'; check(not U.Validate(bad),'duplicate name')
bad=clone(c); bad.players[1].slots[1].priority=0; check(not U.Validate(bad))
bad=clone(c); bad.players[1].slots[1].override=0/0; check(not U.Validate(bad))
bad=clone(c); bad.players[1].slots[2].trigger='BrickKick'; check(not U.Validate(bad),'duplicate trigger')
bad=clone(c); bad.players[1].name='Brick\n/cast'; check(not U.Validate(bad))
local utf=clone(c); utf.players[1].name='Brïck-Realm'; utf.players[1].slots[2].trigger='hello % tab'; eq(assert(U.Import(U.Export(utf))).players[1].name,'Brïck-Realm')
U.db=c; U.Rebuild(); U.roster={'Brick-Realm','Mage-Realm'}
check(not U.HandleChat('BrickKick','Mage-Realm',100),'sender spoof')
check(not U.HandleChat('BrickKick','Stranger-Realm',100),'not in party')
check(not U.HandleChat('prefix BrickKick','Brick-Realm',100),'exact match')
check(U.HandleChat('BrickKick','Brick-Realm',100),'valid sender')
eq(U.entries['1:1'].expires,115)
check(not U.HandleChat('BrickKick','Brick-Realm',101),'duplicate active timer')
eq(U.entries['1:1'].expires,115)
check(U.HandleChat('CustomStop','Brick-Realm',100)); eq(U.entries['1:2'].expires,133)
check(not U.HandleChat(secret,'Brick-Realm',100)); check(not U.HandleChat('BrickKick',secret,100)); eq(U.blocked,2)
eq(U.Order('kick',101)[1].player,'Mage-Realm','ready first')
eq(U.Order('kick',116)[1].player,'Brick','priority restored')
U.db.players[1].slots[1].priority=99; U.Rebuild(); eq(U.entries['1:1'].expires,115,'preserve cooldown on priority edit')
U.db.players[1].slots[1].spell=1766; U.Rebuild(); eq(U.entries['1:1'].expires,0,'changed spell resets timer')
eq(U.ResolveName('Brick',{'Brick-A','Brick-B'}),nil,'ambiguous name rejected')
eq(U.ResolveName('Brick-A',{'Brick-A','Brick-B'}),'brick-a')
-- Load the real event controller, configuration and display against a mock API.
for _,f in ipairs(frames) do if f.events.ADDON_LOADED then f.scripts.OnEvent(f,'ADDON_LOADED','UnhingedCC'); break end end
check(UnhingedCCDB~=nil,'saved variables initialized')
check(U.Commit(c))
local macro=assert(U.Macro(1,2)); check(macro:find('/cast Chaos Nova',1,true)); check(macro:find('/party CustomStop',1,true))
U.CreateAbilityMacro(1,2); eq(lastMacro,macro,'macro creation')
U.OpenConfig()
local function click(text)
 for i=#frames,1,-1 do local f=frames[i]; if f.text==text and f.scripts.OnClick then f.scripts.OnClick(f); return f end end
 error('No button '..text)
end
local function clickSlot(p,s)
 for i=#frames,1,-1 do local f=frames[i]; if f.playerIndex==p and f.slotIndex==s and f.scripts.OnClick then f.scripts.OnClick(f); return f end end
 error('No ability slot')
end
click('Prioritisation'); click('Party Setup'); click('Prioritisation')
local before=#frames
for i=1,10 do U.OpenConfig(); click('Party Setup'); click('Prioritisation') end
eq(#frames,before,'configuration frames pooled')
click('Copy'); click('Close'); click('Export'); click('Close'); click('Import'); click('Close')
click('Unlock Bars'); eq(U.db.locked,false); click('Lock Bars'); eq(U.db.locked,true)
U.roster={'Brick-Realm','Mage-Realm'}; check(U.HandleChat('BrickKick','Brick-Realm',100))
local driver
for _,f in ipairs(frames) do if f.scripts.OnUpdate then driver=f end end
check(driver,'timer driver active')
clock=200; driver.scripts.OnUpdate(driver,.1); eq(driver.scripts.OnUpdate,nil,'driver sleeps when all ready')
-- UI ability selection and pool reuse across changing slot kinds.
local setup=clone(U.db); setup.players[1].slots[1].spell=183752; setup.players[1].slots[1].priority=1; U.Commit(setup)
click('Party Setup'); clickSlot(1,1); click('Counterspell')
eq(U.db.players[1].slots[1].spell,2139,'picker changes intended slot')
clickSlot(1,2); click('Storm Bolt')
eq(U.db.players[1].slots[2].spell,107570,'stop picker changes intended slot')
local poolCount=#frames
for i=1,3 do
 clickSlot(1,1); click('Counterspell')
 clickSlot(1,2); click('Storm Bolt')
end
eq(#frames,poolCount,'ability picker pools widgets')
click('Prioritisation')
local input
for i=#frames,1,-1 do
 local f=frames[i]
 if f.kind=='EditBox' and f.text=='1' and f.scripts.OnTextChanged then input=f; break end
end
check(input,'priority input exists')
input.text='50'; input.scripts.OnTextChanged(input,true)
eq(U.db.players[1].slots[1].priority,50,'typing changes priority immediately')
-- Earliest active timer precedes a higher-priority timer that expires later.
U.entries['1:1'].expires=250; U.entries['2:1'].expires=240
U.entries['1:1'].priority=1; U.entries['2:1'].priority=99
eq(U.Order('kick',200)[1].key,'2:1')
-- Macro creation never overwrites or runs during combat.
local oldCreate=CreateMacro; local created=0
CreateMacro=function(...) created=created+1; return oldCreate(...) end
InCombatLockdown=function() return true end
U.CreateAbilityMacro(1,1); eq(created,0)
InCombatLockdown=function() return false end
GetMacroInfo=function() return 'Existing macro' end
U.CreateAbilityMacro(1,1); eq(created,0)
local fresh=U.NewConfig(); fresh.players[1].name='Angeels-Realm'
fresh.players[1].slots[1].spell=183752; fresh.players[1].slots[2].spell=179057
fresh.players[1].slots[3].spell=1234195
local v2=assert(U.Validate(fresh)); eq(v2.version,2)
eq(U.Trigger(v2.players[1],1),'AngeelsKick')
eq(U.Trigger(v2.players[1],2),'AngeelsChaosNova')
eq(U.Trigger(v2.players[1],3),'AngeelsVoidNova')
eq(U.Abilities[1234195].cooldown,45,'Devourer verified baseline')
eq(U.Abilities[1234195].note,'Devourer')
v2.players[1].slots[4]=v2.players[1].slots[2]; v2.players[1].slots[2]={spell=0,priority=2,trigger=''}
eq(U.Trigger(v2.players[1],4),'AngeelsChaosNova','independent of slot')
local legacy=U.NewConfig(); legacy.version=1; legacy.players[1].name='Angeels-Realm'
legacy.players[1].slots[1].spell=183752; legacy.players[1].slots[1].trigger='Angeels-Realm:1'
legacy.players[1].slots[2].spell=179057; legacy.players[1].slots[2].trigger='Angeels-Realm:4'
legacy.players[1].slots[3].spell=1234195; legacy.players[1].slots[3].trigger='MyCustomVoid'
legacy.players[1].slots[2].override=33; legacy.positions.kick={x=300,y=500}; legacy.locked=false
local migrated=assert(U.Validate(legacy))
eq(migrated.players[1].slots[1].trigger,''); eq(U.Trigger(migrated.players[1],1),'AngeelsKick')
eq(migrated.players[1].slots[2].trigger,''); eq(U.Trigger(migrated.players[1],2),'AngeelsChaosNova')
eq(migrated.players[1].slots[3].trigger,'MyCustomVoid','preserve custom messages')
eq(migrated.players[1].slots[2].override,33); eq(migrated.positions.kick.x,300); eq(migrated.locked,false)
local legacyText=U.Export(legacy):gsub('UCC2','UCC1',1)
eq(U.Trigger(assert(U.Import(legacyText)).players[1],2),'AngeelsChaosNova','v1 import migration')
check(U.Commit(migrated)); U.roster={'Angeels-Realm'}
check(not U.HandleChat('Angeels-Realm:1','Angeels-Realm',200),'numeric IDs removed')
check(not U.HandleChat('AngeelsKick','Other-Realm',200),'new IDs retain sender validation')
check(U.HandleChat('AngeelsKick','Angeels-Realm',200))
check(U.HandleChat('AngeelsChaosNova','Angeels-Realm',200))
check(U.HandleChat('MyCustomVoid','Angeels-Realm',200))
check(U.Macro(1,2):find('/party AngeelsChaosNova',1,true))
-- Exact compact layout: total width 20% narrower, no top padding, one physical pixel gap.
local rows={}
for _,f in ipairs(frames) do if f.kind=='StatusBar' and f.entry and f:IsShown() then rows[#rows+1]=f end end
check(#rows>0)
for _,r in ipairs(rows) do
 eq(r.parent.width,248*.8)
 eq(r.width,248*.8-24)
 check(r.point[3]==0 or r.point[3]==-23,'headerless 22px rows with 1px gap')
end
-- Catalog integrity: every added spell has valid timer metadata and source text.
local catalogCount=0
for id,a in pairs(U.Abilities) do
 catalogCount=catalogCount+1
 check(type(id)=='number' and a.cooldown>0 and type(a.icon)=='string' and (a.kind=='kick' or a.kind=='stop'))
end
check(catalogCount>=79,'expanded spell catalog')
-- Search the expanded picker by spec, select Devourer, then clear the slot.
click('Party Setup'); clickSlot(1,3)
local search
for i=#frames,1,-1 do
 local f=frames[i]
 if f.kind=='EditBox' and f.parent and f.parent.search==f then search=f; break end
end
check(search,'search box exists')
search.text='Devourer'; search.scripts.OnTextChanged(search,true)
local available=0
for _,f in ipairs(frames) do if f.abilityID and f:IsShown() and f.parent==search.parent.content then available=available+1; eq(f.abilityID,1234195) end end
eq(available,1,'spec search finds Void Nova')
click('Void Nova'); eq(U.db.players[1].slots[3].spell,1234195)
clickSlot(1,3); click('Clear slot'); eq(U.db.players[1].slots[3].spell,0)
-- Saving a displayed generated trigger keeps the slot dynamic.
local dynamic=U.NewConfig(); dynamic.players[1].name='Angeels'; dynamic.players[1].slots[2].spell=179057
dynamic.players[1].slots[2].trigger='AngeelsChaosNova'
local normalized=assert(U.Validate(dynamic)); eq(normalized.players[1].slots[2].trigger,'')
normalized.players[1].slots[2].spell=1234195; eq(U.Trigger(normalized.players[1],2),'AngeelsVoidNova')
-- Exercise v1 SavedVariables migration through the real login event handler.
UnhingedCCDB=legacy
for _,f in ipairs(frames) do
 if f.scripts.OnEvent then f.scripts.OnEvent(f,'ADDON_LOADED','UnhingedCC'); break end
end
eq(UnhingedCCDB.version,2); eq(UnhingedCCDB.positions.kick.x,300)
eq(U.Trigger(UnhingedCCDB.players[1],2),'AngeelsChaosNova')
-- UI scale changes retain a one-physical-pixel gap and mover lock state.
UIParent.GetEffectiveScale=function() return 1.25 end
U.RefreshDisplay()
local seenGap=false
for _,f in ipairs(frames) do
 if f.kind=='StatusBar' and f.entry and f:IsShown() and f.entry.ability.kind=='stop' then
  if f.point[3]~=0 then eq(f.point[3],-22.8); seenGap=true end
 end
end
check(seenGap,'scaled row spacing verified')
print('PASS: '..count..' assertions; Lua 5.1 model, event, macro, UI and timer tests')
