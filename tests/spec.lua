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
eq(imported.players[1].slots[2].trigger,nil,'custom IDs discarded')
check(not U.Import('return os.execute("bad")'))
check(not U.Import(string.rep('X',32769)))
check(not U.Import(U.Export(c):sub(1,-2)..'z'),'damaged export rejected')
local bad=clone(c); bad.players[1].slots[2].spell=183752; check(not U.Validate(bad),'reject kick in stop slot')
bad=clone(c); bad.players[2].name='brick'; check(not U.Validate(bad),'duplicate name')
bad=clone(c); bad.players[1].slots[1].priority=0; check(not U.Validate(bad))
bad=clone(c); bad.players[1].slots[1].override=0/0; check(not U.Validate(bad))
bad=clone(c); bad.players[1].slots[3].spell=179057; check(not U.Validate(bad),'duplicate generated trigger')
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
check(U.HandleChat('BrickChaosNova','Brick-Realm',100)); eq(U.entries['1:2'].expires,133)
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
local macro=assert(U.Macro(1,2)); check(macro:find('/cast Chaos Nova',1,true)); check(macro:find('/party BrickChaosNova',1,true))
U.CreateAbilityMacro(1,2); eq(lastMacro,macro,'macro creation')
U.OpenConfig()
local function visible(f)
 while f do if not f:IsShown() then return false end; f=f.parent end
 return true
end
local function click(text)
 for i=#frames,1,-1 do local f=frames[i]; if f.text==text and f.scripts.OnClick and visible(f) then f.scripts.OnClick(f); return f end end
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
 if f.kind=='EditBox' and f.playerIndex==1 and f.slotIndex==1 and f.scripts.OnTextChanged then input=f; break end
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
local v2=assert(U.Validate(fresh)); eq(v2.version,3)
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
eq(migrated.players[1].slots[1].trigger,nil); eq(U.Trigger(migrated.players[1],1),'AngeelsKick')
eq(migrated.players[1].slots[2].trigger,nil); eq(U.Trigger(migrated.players[1],2),'AngeelsChaosNova')
eq(migrated.players[1].slots[3].trigger,nil,'remove legacy custom messages')
eq(migrated.players[1].slots[2].override,33); eq(migrated.positions.kick.x,300); eq(migrated.locked,false)
local function legacyExport(config,header)
 local lines={header}
 for _,p in ipairs(config.players) do
  lines[#lines+1]='P\t'..p.name
  for _,a in ipairs(p.slots) do lines[#lines+1]=table.concat({'A',a.spell,a.priority,a.override or '',a.trigger or ''},'\t') end
 end
 return table.concat(lines,'\n')
end
local legacyText=legacyExport(legacy,'UCC1')
eq(U.Trigger(assert(U.Import(legacyText)).players[1],2),'AngeelsChaosNova','v1 import migration')
check(U.Commit(migrated)); U.roster={'Angeels-Realm'}
check(not U.HandleChat('Angeels-Realm:1','Angeels-Realm',200),'numeric IDs removed')
check(not U.HandleChat('AngeelsKick','Other-Realm',200),'new IDs retain sender validation')
check(U.HandleChat('AngeelsKick','Angeels-Realm',200))
check(U.HandleChat('AngeelsChaosNova','Angeels-Realm',200))
check(not U.HandleChat('MyCustomVoid','Angeels-Realm',200),'legacy custom IDs no longer accepted')
check(U.HandleChat('AngeelsVoidNova','Angeels-Realm',200))
check(U.Macro(1,2):find('/party AngeelsChaosNova',1,true))
-- Exact compact layout: total width 20% narrower, no top padding, one physical pixel gap.
local rows={}
for _,f in ipairs(frames) do if f.kind=='StatusBar' and f.entry and f:IsShown() then rows[#rows+1]=f end end
check(#rows>0)
for _,r in ipairs(rows) do
 eq(r.parent.width,198)
 eq(r.width,174)
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
local normalized=assert(U.Validate(dynamic)); eq(normalized.players[1].slots[2].trigger,nil)
normalized.players[1].slots[2].spell=1234195; eq(U.Trigger(normalized.players[1],2),'AngeelsVoidNova')
-- Exercise v1 SavedVariables migration through the real login event handler.
UnhingedCCDB=legacy
for _,f in ipairs(frames) do
 if f.scripts.OnEvent then f.scripts.OnEvent(f,'ADDON_LOADED','UnhingedCC'); break end
end
eq(UnhingedCCDB.version,3); eq(UnhingedCCDB.positions.kick.x,300)
eq(U.Trigger(UnhingedCCDB.players[1],2),'AngeelsChaosNova')
-- UI scale changes retain a one-physical-pixel gap and mover lock state.
UIParent.GetEffectiveScale=function() return 1.25 end
U.RefreshDisplay()
local seenGap=false
for _,f in ipairs(frames) do
 if f.kind=='StatusBar' and f.entry and f:IsShown() and f.entry.ability.kind=='stop' then
  if f.point[3]~=0 then check(math.abs(f.point[3]+23.2)<.000001); seenGap=true end
 end
end
check(seenGap,'scaled row spacing verified')
-- Old v2 imports cannot reactivate custom IDs; v3 exports contain no override field.
local fromV2=assert(U.Import(legacyExport(legacy,'UCC2')))
eq(fromV2.players[1].slots[3].trigger,nil)
eq(U.Trigger(fromV2.players[1],3),'AngeelsVoidNova')
local serialized=U.Export(legacy)
check(serialized:match('^!UCC4!'))
check(not serialized:find('MyCustomVoid',1,true),'export drops custom IDs even from unnormalized input')
local roundtrip=assert(U.Import(serialized)); eq(roundtrip.players[1].slots[2].override,33)
roundtrip.players[1].slots[2].trigger='SneakyOverride'
eq(U.Trigger(roundtrip.players[1],2),'AngeelsChaosNova','runtime always uses generated IDs')
roundtrip.players[1].name='Brick-Realm'
eq(U.Trigger(roundtrip.players[1],2),'BrickChaosNova','IDs follow name changes')
check(U.Commit(roundtrip)); U.roster={'Brick-Realm'}
check(not U.HandleChat('SneakyOverride','Brick-Realm',300))
check(U.HandleChat('BrickChaosNova','Brick-Realm',300))
check(U.Macro(1,2):find('/party BrickChaosNova',1,true))
click('Prioritisation')
local readonly=0
for _,f in ipairs(frames) do
 if f.text=='BrickChaosNova' then
  check(f.kind~='EditBox','generated tracking IDs are not editable')
  if f.kind=='FontString' and f:IsShown() then readonly=readonly+1 end
 end
end
check(readonly>0,'generated ID shown as read-only text')
-- Clipboard-safe exports: quoted/wrapped input, Unicode and missing legacy trailing tabs.
local exported=U.Export(U.db)
check(not exported:find('%s'),'export is a single unbroken string')
local quoted=assert(U.Import('"'..exported..'"')); eq(quoted.players[1].name,U.db.players[1].name)
local wrapped=exported:gsub('(.)(.)(.)(.)(.)(.)','%1%2%3%4%5%6\n')
check(U.Import(wrapped),'line-wrapped encoded export imports')
local broken=exported:sub(1,10)..(exported:sub(11,11)=='A' and 'B' or 'A')..exported:sub(12)
check(not U.Import(broken),'checksum rejects a changed payload')
local old=U.NewConfig(); old.players[1].name='Angeels'; old.players[2].name='Iamthelight'
old.players[1].slots[1].spell=183752; old.players[1].slots[2].spell=217832
old.players[2].slots[1].spell=96231; old.players[2].slots[2].spell=115750
local oldRows={'UCC3'}
for _,p in ipairs(old.players) do
 oldRows[#oldRows+1]='P\t'..p.name
 for _,a in ipairs(p.slots) do oldRows[#oldRows+1]=table.concat({'A',a.spell,a.priority,''},'\t') end
end
local pasted=table.concat(oldRows,'\n')
local fixed=assert(U.Import('"'..pasted..'"')); eq(fixed.players[2].slots[2].spell,115750)
local trimmed=pasted:gsub('[\t ]+\n','\n'):gsub('[\t ]+$','')
check(U.Import(trimmed),'older exports survive clipboard whitespace trimming')
local unicode=U.NewConfig(); unicode.players[1].name='Brïck-Realm'
eq(assert(U.Import(U.Export(unicode))).players[1].name,'Brïck-Realm')
-- Explicit class filter composes with search and uses compact entries.
click('Party Setup'); clickSlot(1,2)
click('All classes'); click('Demon Hunter')
local pickerFrame
for _,f in ipairs(frames) do if f.classMenu and f.classFilter=='DEMONHUNTER' then pickerFrame=f end end
check(pickerFrame,'class filter selected')
local matches=0
for _,f in ipairs(frames) do
 if f.parent==pickerFrame.content and f.abilityID and f:IsShown() then
  matches=matches+1; eq(U.Abilities[f.abilityID].class,'DEMONHUNTER'); eq(f.height,34)
 end
end
check(matches>0)
pickerFrame.search.text='Void'; pickerFrame.search.scripts.OnTextChanged(pickerFrame.search,true)
local filtered=0
for _,f in ipairs(frames) do if f.parent==pickerFrame.content and f.abilityID and f:IsShown() then filtered=filtered+1; eq(f.abilityID,1234195) end end
eq(filtered,1,'class plus text search')
-- All three windows drag only from their title bars.
click('Export')
local windows=0
for _,f in ipairs(frames) do
 if f.titleBar then
  windows=windows+1; eq(f.scripts.OnDragStart,nil,'content cannot start dragging')
  check(f.titleBar.scripts.OnDragStart); f.titleBar.scripts.OnDragStart(f.titleBar); eq(f.moving,true)
  f.titleBar.scripts.OnDragStop(f.titleBar); eq(f.moving,false)
  check(f.titleBar.close.backdropColor[1]>.5,'red close button')
 end
end
eq(windows,3)
-- Export output stays read-only and matches the actual config.
local output
for _,f in ipairs(frames) do if f.box and f.output==U.Export(U.db) then output=f end end
check(output); eq(assert(U.Import(output.box:GetText())).players[1].name,U.db.players[1].name)
output.box.text='accidental edit'; output.box.scripts.OnTextChanged(output.box,true)
eq(output.box:GetText(),output.output,'export text cannot be overwritten')
-- Scaled borders remain one physical pixel, including a downscaled window.
U.Style.RefreshBorders()
local borders=0
for f in pairs(U.Style.borders) do
 borders=borders+1; check(not f.backdrop.edgeFile,'backdrop borders removed'); check(math.abs(f.borderLines[1].height*f:GetEffectiveScale()-1)<.000001); check(math.abs(f.borderLines[3].width*f:GetEffectiveScale()-1)<.000001)
end
check(borders>0)
-- Exact realm-qualified example remains canonical.
local realmConfig=U.NewConfig(); realmConfig.players[1].name='Angeels-TarrenMill'; realmConfig.players[1].slots[2].spell=1234195
eq(U.Trigger(realmConfig.players[1],2),'AngeelsVoidNova')
-- Preset save/cancel/load/replace/reset all use the same confirmation popup.
local snapshot=U.NewConfig(); snapshot.players[1].name='Brick-Realm'; snapshot.players[1].slots[1].spell=183752
snapshot.players[1].slots[2].spell=1234195; snapshot.players[1].slots[2].override=33
snapshot.positions.kick={x=321,y=432}; snapshot.positions.stop={x=567,y=678}; snapshot.locked=false
check(U.Commit(snapshot)); U.RestoreDisplayPositions(); U.OpenConfig(); click('Party Setup')
local beforeSave=U.Export(U.db)
click('Save Preset')
local popup
for _,f in ipairs(frames) do if f.shield and f.action then popup=f end end
check(popup); popup.input:SetText('Dungeon'); click('Cancel'); eq(U.presets.Dungeon,nil)
click('Save Preset'); popup.input:SetText('  '); click('Save'); eq(U.presets['  '],nil); check(popup.error:GetText()~='')
popup.input:SetText('Dungeon'); click('Save'); check(U.presets.Dungeon); eq(U.presets.Dungeon.positions.kick.x,321)
eq(U.presets.Dungeon.players[1].slots[2].override,33); eq(UnhingedCCPresets,U.presets)
local changed=assert(U.Validate(U.db)); changed.players[1].name='Other'; changed.positions.kick.x=99; U.Commit(changed)
eq(U.presets.Dungeon.players[1].name,'Brick-Realm','snapshot is independent')
click('Dungeon'); click('No'); eq(U.db.players[1].name,'Other','load cancel preserves setup')
click('Dungeon'); click('Yes'); eq(U.db.players[1].name,'Brick-Realm'); eq(U.db.positions.kick.x,321)
eq(U.Export(U.db),beforeSave); eq(U.entries['1:2'].expires,0,'preset load clears active timers')
-- Duplicate names prompt; cancellation does not overwrite the saved snapshot.
local changedAgain=assert(U.Validate(U.db)); changedAgain.players[1].slots[2].override=40; U.Commit(changedAgain)
click('Save Preset'); popup.input:SetText('dungeon'); click('Save'); click('No'); eq(U.presets.Dungeon.players[1].slots[2].override,33)
click('Save Preset'); popup.input:SetText('Dungeon'); click('Save'); click('Yes'); eq(U.presets.Dungeon.players[1].slots[2].override,40)
click('Reset All'); click('Cancel'); eq(U.db.players[1].name,'Brick-Realm')
local anchors={}
for _,f in ipairs(frames) do if f.kind=='kick' or f.kind=='stop' then anchors[f]=f.point end end
click('Reset All'); click('Reset'); eq(U.db.players[1].name,''); eq(U.db.locked,false)
eq(U.db.positions.kick.x,321); eq(U.db.positions.kick.y,432)
eq(U.db.positions.stop.x,567); eq(U.db.positions.stop.y,678)
for f,point in pairs(anchors) do eq(f.point,point,'reset does not reanchor bars') end
for p,player in ipairs(U.db.players) do
 eq(player.name,'')
 for slot,a in ipairs(player.slots) do
  eq(a.spell,0); eq(a.priority,slot==1 and p or (p-1)*4+slot-1); eq(a.override,nil)
 end
end
check(next(U.entries)==nil,'reset clears removed assignments and active timers')
check(U.presets.Dungeon,'reset retains saved presets')
click('Dungeon'); click('Yes'); eq(U.db.players[1].name,'Brick-Realm'); eq(U.db.players[1].slots[2].override,40)
U.InitPresets(); check(U.presets.Dungeon,'presets survive SavedVariables initialization')
click('Prioritisation')
local saveButton
for _,f in ipairs(frames) do if f.text=='Save Preset' and f.scripts.OnClick then saveButton=f end end
check(saveButton and saveButton:IsShown(),'save available on priorities page')
-- Header/sidebar have only fills, while controls use a single pixel strip per edge.
local options
for _,f in ipairs(frames) do if f.name=='UnhingedCCOptions' then options=f end end
check(not U.Style.borders[options.titleBar]); check(not U.Style.borders[options.side]); check(options.divider)
eq(options.side.backdrop.edgeFile,nil); eq(options.titleBar.backdrop.edgeFile,nil)
-- Fonts: EUI selection, game selection, and inherited fallback on errors/bad paths.
local sample=CreateFrame('FontString')
EllesmereUI={GetFontPath=function() return 'eui-font' end}
U.Style.Font(sample); eq(sample:GetFont(),'eui-font')
EllesmereUI.GetFontPath=function() error('not initialized') end
U.Style.Font(sample); eq(sample:GetFont(),'game-font')
EllesmereUI.GetFontPath=function() return 'missing-font' end
U.Style.Font(sample); eq(sample:GetFont(),'game-font','bad font falls back to original font object')
EllesmereUI=nil; U.Style.Font(sample); eq(sample:GetFont(),'game-font')
-- Macro API: Retail constants only; verify the stored body and surface failures.
GetMacroInfo=function(key) local m=macroStore[key]; if m then return m.name,m.icon,m.body end end
CreateMacro=oldCreate; MAX_CHARACTER_MACROS=nil
GetNumMacros=function() return 0,0 end
U.roster={'Brick-Realm'}
local id,macroName=U.CreateAbilityMacro(1,2)
eq(id,121); local storedName,_,storedBody=GetMacroInfo(id); eq(storedName,macroName)
check(storedBody:find('/party BrickVoidNova',1,true))
GetNumMacros=function() return 0,Constants.MacroConsts.MAX_CHARACTER_MACROS end
local failure,reason=U.CreateAbilityMacro(1,2); eq(failure,nil); check(reason:find('full',1,true))
GetNumMacros=function() return 0,0 end
CreateMacro=function() error('API failure') end
failure,reason=U.CreateAbilityMacro(1,2); eq(failure,nil); check(reason:find('API failure',1,true))
CreateMacro=function() return nil end
failure,reason=U.CreateAbilityMacro(1,2); eq(failure,nil); check(reason:find('did not create',1,true))
CreateMacro=function() return 999 end
failure,reason=U.CreateAbilityMacro(1,2); eq(failure,nil); check(reason:find('verify',1,true))
-- UI create button reports failures in the settings window as well as chat.
click('Create')
local reported=false
for _,f in ipairs(frames) do if f.kind=='FontString' and f.text and f.text:find('verify',1,true) then reported=true end end
check(reported,'macro failure is visible in settings')
-- New assignments use independent queues even with sparse players and slots.
local queues=U.NewConfig()
check(U.AssignAbility(queues,1,1,183752)); eq(queues.players[1].slots[1].priority,1)
check(U.AssignAbility(queues,1,2,179057)); eq(queues.players[1].slots[2].priority,1)
check(U.AssignAbility(queues,3,1,2139)); eq(queues.players[3].slots[1].priority,2)
check(U.AssignAbility(queues,1,4,217832)); eq(queues.players[1].slots[4].priority,2)
check(U.AssignAbility(queues,4,3,115750)); eq(queues.players[4].slots[3].priority,3)
check(U.AssignAbility(queues,5,1,96231)); eq(queues.players[5].slots[1].priority,3)
-- Replacement keeps its order; removal compacts only that category.
check(U.AssignAbility(queues,3,1,1766)); eq(queues.players[3].slots[1].priority,2)
check(U.AssignAbility(queues,1,1,0)); eq(queues.players[3].slots[1].priority,1); eq(queues.players[5].slots[1].priority,2)
eq(queues.players[4].slots[3].priority,3,'kick removal leaves stop priorities alone')
check(U.AssignAbility(queues,1,2,0)); eq(queues.players[1].slots[4].priority,1); eq(queues.players[4].slots[3].priority,2)
eq(queues.players[5].slots[1].priority,2,'stop removal leaves kick priorities alone')
check(U.AssignAbility(queues,2,1,6552)); eq(queues.players[2].slots[1].priority,3,'new kick appends')
check(not U.AssignAbility(queues,2,1,179057),'cannot put a stop in the kick slot')
-- Explicit ordering survives assignment changes; labels are compacted in that order.
queues.players[3].slots[1].priority=99
check(U.AssignAbility(queues,1,1,183752))
eq(queues.players[5].slots[1].priority,1); eq(queues.players[2].slots[1].priority,2)
eq(queues.players[3].slots[1].priority,3); eq(queues.players[1].slots[1].priority,4)
-- The actual picker uses the assignment function, rather than slot-based defaults.
U.Commit(U.NewConfig()); U.OpenConfig(); click('Party Setup')
clickSlot(1,1); click('Demon Hunter'); click('Demon Hunter'); click('Disrupt')
eq(U.db.players[1].slots[1].priority,1)
clickSlot(1,2); click('Void Nova'); eq(U.db.players[1].slots[2].priority,1)
clickSlot(3,1); click('Disrupt'); eq(U.db.players[3].slots[1].priority,2)
clickSlot(4,5); click('Imprison'); eq(U.db.players[4].slots[5].priority,2)
clickSlot(1,2); click('Clear slot'); eq(U.db.players[4].slots[5].priority,1)
eq(U.db.players[3].slots[1].priority,2)
-- Screenshot-inspired palette and panel structure, with existing controls retained.
check(U.Style.bg[1]>U.Style.bg[3],'warm dark background')
eq(U.Style.gold[1],1); eq(U.Style.gold[2],.82); eq(U.Style.gold[3],0)
eq(options.titleBar.title:GetText(),'UnhingedCC')
check(options.side and options.presetContent and options.reset)
click('Prioritisation'); check(saveButton:IsShown())
-- Settings has no outer outline; popup outlines match their title bars.
check(not U.Style.borders[options],'configuration window has no outline')
for _,popupWindow in ipairs({popup,output,pickerFrame}) do
 eq(popupWindow.lineColor,U.Style.header,'popup border uses header colour')
end
-- Body text gains two points once; titles retain their inherited size.
local bodyFont=CreateFrame('FontString'); local titleFont=CreateFrame('FontString')
U.Style.Font(bodyFont); local _,bodySize=bodyFont:GetFont(); eq(bodySize,14)
U.Style.Font(titleFont,nil,true); local _,titleSize=titleFont:GetFont(); eq(titleSize,12)
U.Style.RefreshFonts(); local _,refreshedSize=bodyFont:GetFont(); eq(refreshedSize,14,'font refresh does not compound the increase')
local _,refreshedTitle=titleFont:GetFont(); eq(refreshedTitle,12)
-- Hovering assigned party icons uses the actual spell tooltip, not summary text.
local tooltipConfig=U.NewConfig(); tooltipConfig.players[1].name='Brick'
U.AssignAbility(tooltipConfig,1,1,183752); U.AssignAbility(tooltipConfig,1,2,1234195)
U.Commit(tooltipConfig); click('Party Setup')
local partyIcon
for _,f in ipairs(frames) do
 if f.kind=='Button' and f.playerIndex==1 and f.slotIndex==2 and visible(f) then partyIcon=f end
end
check(partyIcon)
partyIcon.scripts.OnEnter(partyIcon); eq(GameTooltip.tooltipSpell,1234195); check(GameTooltip:IsShown())
partyIcon.scripts.OnLeave(partyIcon); check(not GameTooltip:IsShown())
click('Prioritisation')
local spellIcon
for _,f in ipairs(frames) do if f.kind=='Button' and f.spellID==1234195 and visible(f) then spellIcon=f end end
check(spellIcon)
local calls=GameTooltip.tooltipCalls
spellIcon.scripts.OnEnter(spellIcon); eq(GameTooltip.tooltipSpell,1234195); eq(GameTooltip.tooltipCalls,calls+1)
spellIcon.scripts.OnLeave(spellIcon); check(not GameTooltip:IsShown())
-- Reused icons get one hover callback, without accumulating old tooltip handlers.
for i=1,4 do U.RenderConfig() end
calls=GameTooltip.tooltipCalls
spellIcon.scripts.OnEnter(spellIcon); eq(GameTooltip.tooltipCalls,calls+1)
local headerFound=false
for _,f in ipairs(frames) do
 if f.kind=='FontString' and f.text=='Chat ID' and visible(f) then
  eq(f.parent.backdropColor[1],U.Style.tableHeader[1]); local _,size=f:GetFont(); eq(size,14); headerFound=true
 end
end
check(headerFound,'readable column header band exists')
-- Regression: SetFontObject retains local overrides, as it can in the client.
local retained=CreateFrame('FontString'); retained:SetFont('game-font',30,'')
retained:SetFontObject(GameFontNormal); local _,retainedSize=retained:GetFont(); eq(retainedSize,30)
U.Style.Font(retained); local _,repairedSize=retained:GetFont(); eq(repairedSize,14,'ignore a pre-existing enlarged local override')
U.Style.Font(retained,nil,true); local _,repairedTitle=retained:GetFont(); eq(repairedTitle,12)
click('Party Setup')
-- Warm both picker states, then repeatedly add/remove an ability via real callbacks.
clickSlot(1,3); click('Imprison'); clickSlot(1,3); click('Clear slot')
local sizes={}
for f in pairs(U.Style.fonts) do local _,size=f:GetFont(); sizes[f]=size end
for cycle=1,20 do
 clickSlot(1,3); click('Imprison'); clickSlot(1,3); click('Clear slot')
 local stable=true
 for f,size in pairs(sizes) do local _,actual=f:GetFont(); if actual~=size then stable=false; break end end
 check(stable,'font sizes drift after ability add/remove cycle '..cycle)
end
for cycle=1,5 do U.OpenConfig(); U.Style.RefreshFonts() end
local stable=true
for f,size in pairs(sizes) do local _,actual=f:GetFont(); if actual~=size then stable=false; break end end
check(stable,'opening settings and refreshing fonts also remain stable')
-- Follow intentional changes to the source FontObject without accumulating offsets.
local gameGetter=GameFontNormal.GetFont
GameFontNormal.GetFont=function() return 'game-font',13,'' end
U.Style.Font(retained); local _,newBodySize=retained:GetFont(); eq(newBodySize,15)
U.Style.Font(retained,nil,true); local _,newTitleSize=retained:GetFont(); eq(newTitleSize,13)
GameFontNormal.GetFont=gameGetter; U.Style.RefreshFonts()
-- Regression: fractional physical heights make snapped textures show uneven gaps.
local pixelsConfig=U.NewConfig()
for p=1,5 do
 pixelsConfig.players[p].name='Pixels'..p
 pixelsConfig.players[p].slots[1].spell=183752
 for slot,id in ipairs({179057,1234195,217832,211881}) do pixelsConfig.players[p].slots[slot+1].spell=id end
end
pixelsConfig.positions.kick={x=100.33,y=555.17}
pixelsConfig.positions.stop={x=300.47,y=555.17}
local function roundPixel(v) return math.floor(v+.5) end
for _,screenHeight in ipairs({720,768,1080,1440,2160}) do
 physicalHeight=screenHeight
 for _,scale in ipairs({.53,.64,.711111,.8,.9,1,1.25}) do
 UIParent.GetEffectiveScale=function() return scale end
 U.Commit(pixelsConfig); U.RestoreDisplayPositions()
 for _,f in ipairs(frames) do
  if f.kind=='kick' or f.kind=='stop' then
   local top=f.point[5]
   local physicalScale=scale*screenHeight/768
   local stable=true
   if math.abs(top*physicalScale-roundPixel(top*physicalScale))>.000001 then stable=false end
   for i=1,#f.rows-1 do
    local a,b=f.rows[i],f.rows[i+1]
    if a:IsShown() and b:IsShown() then
     local bottom=roundPixel((top+a.point[3])*physicalScale)-roundPixel(a.height*physicalScale)
     local nextTop=roundPixel((top+b.point[3])*physicalScale)
     if bottom-nextTop~=1 or math.abs(a.height*physicalScale-roundPixel(a.height*physicalScale))>.000001 then stable=false end
     if a.icon.height~=a.height then stable=false end
    end
   end
   check(stable,'every row/icon gap is one physical pixel at '..screenHeight..'p / scale '..scale)
  end
 end
end
end
-- Preserve a valid pixel conversion during a transient display-size transition.
local beforeTransition=U.Style.Pixel(UIParent)
physicalHeight=0; eq(U.Style.Pixel(UIParent),beforeTransition)
physicalHeight=1080; UIParent.GetEffectiveScale=function() return .64 end
-- Exercise the actual display-change event path: layout and positions both re-snap.
for _,f in ipairs(frames) do if f.events.DISPLAY_SIZE_CHANGED then f.scripts.OnEvent(f,'DISPLAY_SIZE_CHANGED'); break end end
local px=U.Style.Pixel(UIParent)
check(math.abs(px-(768/1080)/.64)<.000001)
for _,f in ipairs(frames) do
 if f.kind=='kick' or f.kind=='stop' then
  check(math.abs(f.point[5]/px-roundPixel(f.point[5]/px))<.000001)
  f.mover.scripts.OnDragStop(f.mover)
  check(math.abs(U.db.positions[f.kind].x/px-roundPixel(U.db.positions[f.kind].x/px))<.000001)
  check(math.abs(U.db.positions[f.kind].y/px-roundPixel(U.db.positions[f.kind].y/px))<.000001)
 end
end
-- Quality-of-life option: exact roster match, event-driven CVar ownership/restoration.
local members={'Brick-Realm','Mage-Realm'}
local instance,raid,combat=false,false,false
local bubbleValue='1'; local writes={}; local refuse=false
C_CVar={
 GetCVar=function(name) eq(name,'chatBubblesParty'); return bubbleValue end,
 SetCVar=function(name,value)
  check(not combat,'no CVar writes in combat'); eq(name,'chatBubblesParty')
  writes[#writes+1]=value; if not refuse then bubbleValue=value end
 end,
}
IsInGroup=function() return #members>1 end
IsInRaid=function() return raid end
IsInInstance=function() return instance,instance and 'party' or 'none' end
InCombatLockdown=function() return combat end
GetNumGroupMembers=function() return #members end
UnitExists=function(unit)
 if unit=='player' then return true end
 local n=tonumber(unit:match('^party(%d+)$')); return n and n<#members or false
end
UnitFullName=function(unit)
 local n=unit=='player' and 1 or tonumber(unit:match('^party(%d+)$'))+1
 return members[n]:match('^([^-]+)%-(.+)$')
end
local function event(name)
 for _,f in ipairs(frames) do if f.events[name] then f.scripts.OnEvent(f,name); return end end
 error('Event not registered: '..name)
end
local function matching()
 local c=U.NewConfig(); c.players[1].name='Brick'; c.players[2].name='Mage-Realm'; return c
end
UnhingedCCOptions=nil; U.InitOptions(); U.Commit(matching()); U.Roster()
eq(U.options.hidePartyBubbles,false); eq(#writes,0)
check(U.PartySetupMatchesGroup())
U.SetHidePartyBubbles(true); eq(bubbleValue,'1'); eq(#writes,0,'outside instance does not change bubbles')
instance=true; event('PLAYER_ENTERING_WORLD'); eq(bubbleValue,'0'); eq(U.options.bubbleRestoreValue,'1')
local nWrites=#writes; event('GROUP_ROSTER_UPDATE'); eq(#writes,nWrites,'matching events do not repeat writes')
members={'Mage-Realm','Brick-Realm'}; event('GROUP_ROSTER_UPDATE'); eq(bubbleValue,'0','roster order does not matter')
members={'Brick-Realm','Mage-Realm','Extra-Realm'}; event('GROUP_ROSTER_UPDATE'); eq(bubbleValue,'1'); eq(U.options.bubbleRestoreValue,nil)
members={'Brick-Realm','Mage-Realm'}; event('GROUP_ROSTER_UPDATE'); eq(bubbleValue,'0')
instance=false; event('ZONE_CHANGED_NEW_AREA'); eq(bubbleValue,'1')
-- A player who already had bubbles off keeps that preference on exit.
bubbleValue='0'; instance=true; event('PLAYER_ENTERING_WORLD'); eq(U.options.bubbleRestoreValue,'0')
instance=false; event('PLAYER_ENTERING_WORLD'); eq(bubbleValue,'0'); eq(U.options.bubbleRestoreValue,nil)
-- Missing names, extra names, ambiguous names, raids and solo groups cannot match.
instance=true; bubbleValue='1'
local extra=matching(); extra.players[3].name='Extra-Realm'; U.Commit(extra); eq(bubbleValue,'1')
local alias=matching(); alias.players[2].name='Brick-Realm'; U.Commit(alias); check(not U.PartySetupMatchesGroup())
members={'Brick-A','Brick-B'}; local ambiguous=matching(); ambiguous.players[2].name='Brick-B'; U.Commit(ambiguous); U.Roster(); check(not U.PartySetupMatchesGroup())
ambiguous.players[1].name='Brick-A'; U.Commit(ambiguous); check(U.PartySetupMatchesGroup()); eq(bubbleValue,'0')
raid=true; event('GROUP_ROSTER_UPDATE'); eq(bubbleValue,'1'); check(not U.PartySetupMatchesGroup()); raid=false
members={'Brick-Realm'}; event('GROUP_ROSTER_UPDATE'); check(not U.PartySetupMatchesGroup())
members={'Brick-Realm','Mage-Realm'}; U.Commit(matching()); U.Roster(); eq(bubbleValue,'0')
U.roster={'Brick-Realm'}; U.UpdatePartyBubbles(); eq(bubbleValue,'1','incomplete roster restores bubbles')
-- Combat waits; when combat ends the current conditions win, not an old queued value.
U.Roster(); eq(bubbleValue,'0'); combat=true
members={'Brick-Realm','Other-Realm'}; event('GROUP_ROSTER_UPDATE'); eq(bubbleValue,'0'); eq(U.BubbleStatus(),'Status: Active - Waiting for combat to end')
members={'Brick-Realm','Mage-Realm'}; event('GROUP_ROSTER_UPDATE'); combat=false; event('PLAYER_REGEN_ENABLED'); eq(bubbleValue,'0')
combat=true; U.SetHidePartyBubbles(false); eq(bubbleValue,'0'); combat=false; event('PLAYER_REGEN_ENABLED'); eq(bubbleValue,'1'); eq(U.options.bubbleRestoreValue,nil)
combat=true; U.SetHidePartyBubbles(true); eq(bubbleValue,'1'); eq(U.options.bubbleRestoreValue,nil)
U.SetHidePartyBubbles(false); combat=false; event('PLAYER_REGEN_ENABLED'); eq(bubbleValue,'1')
-- Logout and saved recovery markers restore the actual previous value.
U.SetHidePartyBubbles(true); eq(bubbleValue,'0'); event('PLAYER_LOGOUT'); eq(bubbleValue,'1'); eq(U.options.bubbleRestoreValue,nil)
UnhingedCCOptions={hidePartyBubbles=false,bubbleRestoreValue='1'}; bubbleValue='0'; U.InitOptions(); U.UpdatePartyBubbles(); eq(bubbleValue,'1')
refuse=true; U.SetHidePartyBubbles(true); eq(bubbleValue,'1'); check(U.BubbleStatus():find('Could not hide',1,true))
refuse=false; U.SetHidePartyBubbles(false); U.SetHidePartyBubbles(true); eq(bubbleValue,'0')
refuse=true; U.SetHidePartyBubbles(false); eq(U.options.bubbleRestoreValue,'1'); check(U.BubbleStatus():find('Could not restore',1,true))
refuse=false; event('PLAYER_REGEN_ENABLED'); eq(bubbleValue,'1'); eq(U.options.bubbleRestoreValue,nil)
-- Configuration page, checkbox behaviour and independent local preference storage.
U.OpenConfig(); click('Configuration')
eq(options.heading:GetText(),'Configuration'); check(not saveButton:IsShown()); check(not options.reset:IsShown())
local checkbox
for _,f in ipairs(frames) do if f.kind=='CheckButton' and visible(f) then checkbox=f end end
check(checkbox); checkbox:SetChecked(true); checkbox.scripts.OnClick(checkbox)
eq(U.options.hidePartyBubbles,true); eq(bubbleValue,'0')
check(U.SavePreset('QoL separation'))
U.SetHidePartyBubbles(false); U.LoadPreset('QoL separation'); eq(U.options.hidePartyBubbles,false,'presets do not enable local bubble setting')
U.SetHidePartyBubbles(true)
local shared=assert(U.Import(U.Export(U.db))); U.Commit(shared); eq(U.options.hidePartyBubbles,true,'import retains local option')
U.ResetConfig(); eq(U.options.hidePartyBubbles,true,'party reset preserves QoL option'); eq(bubbleValue,'1','empty party setup restores bubbles')
click('Party Setup'); eq(options.tabs[1].point[3]-options.tabs[2].point[3]-options.tabs[1].height,4,'4px sidebar button gap')
click('Configuration')
local beforePages=#frames
for cycle=1,5 do click('Party Setup'); click('Prioritisation'); click('Configuration') end
check(#frames<=beforePages+12,'configuration widgets are pooled')
-- Group-category selection supports both queued instance parties and home parties.
U.SetHidePartyBubbles(false); U.Commit(matching()); U.Roster()
IsInGroup=function(category) return category==LE_PARTY_CATEGORY_INSTANCE end
GetNumGroupMembers=function(category) eq(category,LE_PARTY_CATEGORY_INSTANCE); return 2 end
check(U.PartySetupMatchesGroup())
IsInGroup=function(category) return category==LE_PARTY_CATEGORY_HOME end
GetNumGroupMembers=function(category) eq(category,LE_PARTY_CATEGORY_HOME); return 2 end
check(U.PartySetupMatchesGroup())
-- Shutdown cannot be undone by a later roster event in the same session.
U.SetHidePartyBubbles(true); eq(bubbleValue,'0'); event('PLAYER_LOGOUT'); eq(bubbleValue,'1')
event('GROUP_ROSTER_UPDATE'); eq(bubbleValue,'1')
-- Bubble chat notifications only follow confirmed setting changes.
local originalPrint=U.Print; local notifications={}
U.Print=function(text) notifications[#notifications+1]=text end
U.InitOptions(); U.SetHidePartyBubbles(false)
bubbleValue='1'; instance=false; refuse=false; combat=false
U.SetHidePartyBubbles(true)
eq(U.BubbleStatus(),'Status: Not Active - Not in instance'); eq(#notifications,0)
instance=true; event('PLAYER_ENTERING_WORLD')
eq(U.BubbleStatus(),'Status: Active'); eq(notifications[1],'Party chat bubbles disabled.')
local notices=#notifications; event('GROUP_ROSTER_UPDATE'); event('PLAYER_REGEN_ENABLED'); eq(#notifications,notices,'no repeated notifications for unchanged values')
instance=false; event('ZONE_CHANGED_NEW_AREA')
eq(notifications[#notifications],'Party chat bubbles enabled.'); eq(#notifications,notices+1)
instance=true; members={'Brick-Realm','Other-Realm'}; event('GROUP_ROSTER_UPDATE')
eq(U.BubbleStatus(),'Status: Not Active - Not in eligible party')
members={'Brick-Realm','Mage-Realm'}; U.SetHidePartyBubbles(false); U.Roster()
notices=#notifications; bubbleValue='0'; U.SetHidePartyBubbles(true); eq(U.BubbleStatus(),'Status: Active')
instance=false; event('PLAYER_ENTERING_WORLD'); eq(#notifications,notices,'already-disabled bubbles do not generate a false enabled notification')
U.SetHidePartyBubbles(false); eq(U.BubbleStatus(),'Status: Not Active - Disabled')
bubbleValue='1'; instance=true; refuse=true; U.SetHidePartyBubbles(true)
eq(#notifications,notices,'failed changes do not announce success')
refuse=false; U.SetHidePartyBubbles(false); combat=true; U.SetHidePartyBubbles(true)
eq(U.BubbleStatus(),'Status: Not Active - Waiting for combat to end'); eq(#notifications,notices)
combat=false; event('PLAYER_REGEN_ENABLED'); eq(#notifications,notices+1)
U.SetHidePartyBubbles(false); eq(notifications[#notifications],'Party chat bubbles enabled.')
U.Print=originalPrint
-- Status sits next to the setting; the description is one concise paragraph.
click('Configuration')
local inlineStatus,description
for _,f in ipairs(frames) do
 if f.kind=='FontString' and f.text and visible(f) then
  if f.text:find('Status: ',1,true)==1 then inlineStatus=f end
  if f.text:find('Hides party chat bubbles in instances',1,true)==1 then description=f end
 end
end
check(inlineStatus); eq(inlineStatus.point[3],-61); check(inlineStatus.point[2]>400)
check(description); check(not description.text:find('\n',1,true)); check(#description.text<220)
check(not description.text:find('normal party conversation',1,true))
check(not description.text:find('Everyone in the group',1,true))
check(not description.text:find('Messages still appear',1,true))
check(not description.text:find('combat',1,true))
print('PASS: '..count..' assertions; Lua 5.1 model, event, macro, UI and timer tests')
