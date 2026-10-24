local addon, U = ...
function U.Print(text) DEFAULT_CHAT_FRAME:AddMessage('|cffbb77ffUnhingedCC:|r '..text) end
function U.Roster()
    U.roster,U.classes={},{}
    for i=0,4 do
        local unit=i==0 and 'player' or 'party'..i
        if UnitExists(unit) then
            local name,realm=UnitFullName(unit)
            if not U.IsSecret(name) and not U.IsSecret(realm) and name then
                if not realm or realm=='' then realm=GetNormalizedRealmName() end
                local full=name..'-'..realm
                U.roster[#U.roster+1]=full
                local _,class=UnitClass(unit)
                if not U.IsSecret(class) then U.classes[U.Name(full)]=class; U.classes[U.Name(name)]=class end
            end
        end
    end
    if U.db then U.RefreshDisplay() end
end
local events=CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:SetScript('OnEvent',function(self,event,...)
    if event=='ADDON_LOADED' then
        if (...)~=addon then return end
        local db,err
        local migrated = UnhingedCCDB and UnhingedCCDB.version == 1
        if UnhingedCCDB then db,err=U.Validate(UnhingedCCDB) else db=U.NewConfig() end
        if not db then
            U.Print('Saved config could not be loaded: '..err..' It has been preserved; import a valid config to replace it.')
            db=U.NewConfig(); U.invalidSaved=true
        else UnhingedCCDB=db end
        U.db=db; U.Rebuild(); U.Roster()
        if migrated and not U.invalidSaved then U.Print('Updated chat IDs to PlayerKick / PlayerAbility. Recreate or edit your macros; old numeric IDs are no longer tracked.') end
        self:UnregisterEvent('ADDON_LOADED')
        for _,ev in ipairs({'UI_SCALE_CHANGED','GROUP_ROSTER_UPDATE','PLAYER_ENTERING_WORLD','CHAT_MSG_PARTY','CHAT_MSG_PARTY_LEADER','CHAT_MSG_INSTANCE_CHAT','CHAT_MSG_INSTANCE_CHAT_LEADER'}) do self:RegisterEvent(ev) end
        SLASH_UNHINGEDCC1='/ucc'; SLASH_UNHINGEDCC2='/unhingedcc'
        SlashCmdList.UNHINGEDCC=function(cmd)
            if cmd=='lock' or cmd=='unlock' then U.db.locked=cmd=='lock'; U.RefreshDisplay()
            elseif cmd=='status' then U.Print('Unreadable chat events skipped: '..(U.blocked or 0)..'. Timers are estimates; /ucc opens setup.')
            elseif cmd=='reset' then for _,e in pairs(U.entries) do e.expires=0 end; U.RefreshDisplay()
            else U.OpenConfig() end
        end
    elseif event=='UI_SCALE_CHANGED' then U.RefreshDisplay()
    elseif event=='GROUP_ROSTER_UPDATE' or event=='PLAYER_ENTERING_WORLD' then U.Roster()
    else
        local message,sender=...
        U.HandleChat(message,sender,GetTime())
    end
end)
function U.Commit(c)
    local valid,err=U.Validate(c)
    if not valid then return nil,err end
    U.db=valid; UnhingedCCDB=valid; U.invalidSaved=nil; U.Rebuild()
    return true
end
function U.Macro(p,s)
    local player=U.db.players[p]; local a=U.Abilities[player.slots[s].spell]
    if not a then return nil,'Assign an ability first.' end
    if player.name=='' then return nil,'Set a player name first.' end
    local name=C_Spell.GetSpellName(a.spellID or player.slots[s].spell) or a.name
    local channel=IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and '/instance ' or '/party '
    return '#showtooltip '..name..'\n/cast '..name..'\n'..channel..U.Trigger(player,s)
end
function U.CreateAbilityMacro(p,s)
    if InCombatLockdown() then U.Print('Create macros outside combat.'); return end
    local text,err=U.Macro(p,s)
    if not text then U.Print(err); return end
    local player=U.db.players[p]
    local name,realm=UnitFullName('player')
    local full=name..'-'..((realm and realm~='') and realm or GetNormalizedRealmName())
    if U.ResolveName(player.name,U.roster)~=U.Name(full) then U.Print('Only create macros for your own configured character. Use Copy Macro for another player.'); return end
    if #text>255 then U.Print('Macro exceeds the 255-byte limit. Shorten the chat value.'); return end
    -- Never overwrite an existing macro, including one from an earlier config.
    local macroName
    for i=1,99 do local candidate='UCC'..s..'_'..i; if not GetMacroInfo(candidate) then macroName=candidate; break end end
    if not macroName then U.Print('No free UnhingedCC macro name.'); return end
    local _,character=GetNumMacros()
    if character>=MAX_CHARACTER_MACROS then U.Print('Character macro slots are full. Use Copy Macro.'); return end
    local ok,result=pcall(CreateMacro,macroName,U.Abilities[player.slots[s].spell].icon,text,true)
    U.Print(ok and result and ('Created character macro '..macroName..'. Drag it from /macro to your action bar.') or 'Macro creation failed. Use Copy Macro.')
end
