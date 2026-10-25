local _, U = ...
local CVAR='chatBubblesParty'
local status='Off.'
local shuttingDown=false
function U.InitOptions()
    shuttingDown=false
    local saved=type(UnhingedCCOptions)=='table' and UnhingedCCOptions or {}
    U.options={hidePartyBubbles=saved.hidePartyBubbles==true}
    if saved.bubbleRestoreValue=='0' or saved.bubbleRestoreValue=='1' then U.options.bubbleRestoreValue=saved.bubbleRestoreValue end
    UnhingedCCOptions=U.options
end
function U.PartySetupMatchesGroup()
    local category=IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and LE_PARTY_CATEGORY_INSTANCE or LE_PARTY_CATEGORY_HOME
    if not IsInGroup(category) or IsInRaid(category) then return false end
    local count=GetNumGroupMembers(category)
    local roster=U.roster or {}
    if count<2 or count>5 or #roster~=count then return false end
    local found,names={},0
    for _,player in ipairs(U.db.players) do
        if player.name~='' then
            local full=U.ResolveName(player.name,roster)
            if not full or found[full] then return false end
            found[full]=true; names=names+1
        end
    end
    return names==count
end
local function getValue()
    if not C_CVar or not C_CVar.GetCVar then return nil end
    local ok,value=pcall(C_CVar.GetCVar,CVAR)
    if ok and (value=='0' or value=='1') then return value end
end
local function setValue(value)
    if not C_CVar or not C_CVar.SetCVar then return false end
    local ok=pcall(C_CVar.SetCVar,CVAR,value)
    return ok and getValue()==value
end
local function report(text)
    status=text
    if U.RefreshBubbleStatus then U.RefreshBubbleStatus() end
end
function U.BubbleStatus() return status end
function U.UpdatePartyBubbles(shutdown)
    if not U.options or not U.db then return end
    if shutdown then shuttingDown=true end
    local previous=U.options.bubbleRestoreValue
    if not U.options.hidePartyBubbles and previous==nil then report('Off.'); return end
    local inInstance=IsInInstance()
    local matches=U.PartySetupMatchesGroup()
    local hide=not shuttingDown and U.options.hidePartyBubbles and inInstance and matches
    -- Re-evaluate after combat instead of retaining an outdated roster decision.
    if InCombatLockdown() and (hide or previous~=nil) then report('Waiting until combat ends.'); return end
    if hide then
        local current=getValue()
        if not current then report('Could not read the party bubble setting.'); return end
        if previous==nil then U.options.bubbleRestoreValue=current end
        if current~='0' and not setValue('0') then report('Could not hide party bubbles. Another addon may control this setting.'); return end
        report('Party chat bubbles are hidden.')
    else
        if previous~=nil then
            local current=getValue()
            if current~=previous and not setValue(previous) then report('Could not restore the party bubble setting.'); return end
            U.options.bubbleRestoreValue=nil
        end
        if not U.options.hidePartyBubbles then report('Off.')
        elseif not inInstance then report('Waiting until you enter an instance.')
        elseif not matches then report('The group does not match Party Setup.') end
    end
end
function U.SetHidePartyBubbles(enabled)
    U.options.hidePartyBubbles=enabled==true
    U.UpdatePartyBubbles()
end
