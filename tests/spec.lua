local count=0
local function check(v,why) count=count+1; assert(v,why) end
local function eq(a,b,why) check(a==b,(why or '')..' expected '..tostring(b)..', got '..tostring(a)) end
local function clone(c) return assert(U.Import(U.Export(c))) end
local c=U.NewConfig(); c.players[1].name='Brick'; c.players[2].name='Mage-Realm'
c.players[1].slots[1].spell=183752; c.players[1].slots[2].spell=179057
c.players[2].slots[1].spell=2139
local valid,err=U.Validate(c); check(valid,err)
eq(#c.players,5); eq(#c.players[1].slots,5)
c.players[1].slots[2].trigger='Brick:4'; c.players[1].slots[2].override=33
local imported=assert(U.Import(U.Export(c)))
eq(imported.players[1].slots[2].override,33)
eq(imported.players[1].slots[2].trigger,'Brick:4')
check(not U.Import('return os.execute("bad")'))
check(not U.Import(string.rep('X',32769)))
check(not U.Import(U.Export(c):gsub('Brick','%%ZZ',1)))
local bad=clone(c); bad.players[1].slots[2].spell=183752; check(not U.Validate(bad),'reject kick in stop slot')
bad=clone(c); bad.players[2].name='brick'; check(not U.Validate(bad),'duplicate name')
bad=clone(c); bad.players[1].slots[1].priority=0; check(not U.Validate(bad))
bad=clone(c); bad.players[1].slots[1].override=0/0; check(not U.Validate(bad))
bad=clone(c); bad.players[1].slots[2].trigger='Brick:1'; check(not U.Validate(bad),'duplicate trigger')
bad=clone(c); bad.players[1].name='Brick\n/cast'; check(not U.Validate(bad))
local utf=clone(c); utf.players[1].name='Brïck-Realm'; utf.players[1].slots[2].trigger='hello % tab'; eq(assert(U.Import(U.Export(utf))).players[1].name,'Brïck-Realm')
U.db=c; U.Rebuild(); U.roster={'Brick-Realm','Mage-Realm'}
check(not U.HandleChat('Brick:1','Mage-Realm',100),'sender spoof')
check(not U.HandleChat('Brick:1','Stranger-Realm',100),'not in party')
check(not U.HandleChat('prefix Brick:1','Brick-Realm',100),'exact match')
check(U.HandleChat('Brick:1','Brick-Realm',100),'valid sender')
eq(U.entries['1:1'].expires,115)
check(not U.HandleChat('Brick:1','Brick-Realm',101),'duplicate active timer')
eq(U.entries['1:1'].expires,115)
check(U.HandleChat('Brick:4','Brick-Realm',100)); eq(U.entries['1:2'].expires,133)
check(not U.HandleChat(secret,'Brick-Realm',100)); check(not U.HandleChat('Brick:1',secret,100)); eq(U.blocked,2)
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
local macro=assert(U.Macro(1,2)); check(macro:find('/cast Chaos Nova',1,true)); check(macro:find('/party Brick:4',1,true))
U.CreateAbilityMacro(1,2); eq(lastMacro,macro,'macro creation')
U.OpenConfig()
local function click(text)
 for i=#frames,1,-1 do local f=frames[i]; if f.text==text and f.scripts.OnClick then f.scripts.OnClick(f); return f end end
 error('No button '..text)
end
click('Prioritisation'); click('Party Setup'); click('Prioritisation')
local before=#frames
for i=1,10 do U.OpenConfig(); click('Party Setup'); click('Prioritisation') end
eq(#frames,before,'configuration frames pooled')
click('Copy'); click('Close'); click('Export'); click('Close'); click('Import'); click('Close')
click('Unlock Bars'); eq(U.db.locked,false); click('Lock Bars'); eq(U.db.locked,true)
U.roster={'Brick-Realm','Mage-Realm'}; check(U.HandleChat('Brick:1','Brick-Realm',100))
local driver
for _,f in ipairs(frames) do if f.scripts.OnUpdate then driver=f end end
check(driver,'timer driver active')
clock=200; driver.scripts.OnUpdate(driver,.1); eq(driver.scripts.OnUpdate,nil,'driver sleeps when all ready')
-- UI ability selection and pool reuse across changing slot kinds.
local setup=clone(U.db); setup.players[1].slots[1].spell=183752; setup.players[1].slots[1].priority=1; U.Commit(setup)
click('Party Setup'); click('Disrupt'); click('MAGE — Counterspell')
eq(U.db.players[1].slots[1].spell,2139,'picker changes intended slot')
click('Chaos Nova'); click('WARRIOR — Storm Bolt')
eq(U.db.players[1].slots[2].spell,107570,'stop picker changes intended slot')
local poolCount=#frames
for i=1,3 do
 click('Counterspell'); click('MAGE — Counterspell')
 click('Storm Bolt'); click('WARRIOR — Storm Bolt')
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
print('PASS: '..count..' assertions; Lua 5.1 model, event, macro, UI and timer tests')
