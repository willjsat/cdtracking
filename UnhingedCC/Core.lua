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
    if U.db then U.RefreshDisplay(); U.UpdatePartyBubbles() end
end
local events=CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:SetScript('OnEvent',function(self,event,...)
    if event=='ADDON_LOADED' then
        if (...)~=addon then return end
        local db,err
        local migrated = UnhingedCCDB and UnhingedCCDB.version ~= U.VERSION
        if UnhingedCCDB then db,err=U.Validate(UnhingedCCDB) else db=U.NewConfig() end
        if not db then
            U.Print('Saved config could not be loaded: '..err..' It has been preserved; import a valid config to replace it.')
            db=U.NewConfig(); U.invalidSaved=true
        else UnhingedCCDB=db end
        U.InitPresets(); U.InitOptions(); U.db=db; U.Rebuild(); U.Roster()
        if migrated and not U.invalidSaved then U.Print('Tracking IDs are now generated automatically as PlayerKick / PlayerAbility. Recreate or edit macros that used custom or numeric IDs.') end
        self:UnregisterEvent('ADDON_LOADED')
        for _,ev in ipairs({'PLAYER_REGEN_ENABLED','PLAYER_LOGOUT','ZONE_CHANGED_NEW_AREA','DISPLAY_SIZE_CHANGED','UI_SCALE_CHANGED','GROUP_ROSTER_UPDATE','PLAYER_ENTERING_WORLD','CHAT_MSG_PARTY','CHAT_MSG_PARTY_LEADER','CHAT_MSG_INSTANCE_CHAT','CHAT_MSG_INSTANCE_CHAT_LEADER'}) do self:RegisterEvent(ev) end
        SLASH_UNHINGEDCC1='/ucc'; SLASH_UNHINGEDCC2='/unhingedcc'
        SlashCmdList.UNHINGEDCC=function(cmd)
            if cmd=='lock' or cmd=='unlock' then U.db.locked=cmd=='lock'; U.RefreshDisplay()
            elseif cmd=='status' then U.Print('Unreadable chat events skipped: '..(U.blocked or 0)..'. Timers are estimates; /ucc opens setup.')
            elseif cmd=='reset' then for _,e in pairs(U.entries) do e.expires=0 end; U.RefreshDisplay()
            else U.OpenConfig() end
        end
    elseif event=='PLAYER_LOGOUT' then U.UpdatePartyBubbles(true)
    elseif event=='PLAYER_REGEN_ENABLED' then
        if U.options.hidePartyBubbles or U.options.bubbleRestoreValue then U.Roster() end
    elseif event=='UI_SCALE_CHANGED' or event=='DISPLAY_SIZE_CHANGED' then U.RefreshDisplay(); U.RestoreDisplayPositions(); U.Style.RefreshBorders(); if U.RefreshConfigLines then U.RefreshConfigLines() end
    elseif event=='GROUP_ROSTER_UPDATE' or event=='PLAYER_ENTERING_WORLD' or event=='ZONE_CHANGED_NEW_AREA' then U.Roster(); if event=='PLAYER_ENTERING_WORLD' then U.Style.RefreshFonts() end
    else
        local message,sender=...
        U.HandleChat(message,sender,GetTime())
    end
end)
function U.Commit(c)
    local valid,err=U.Validate(c)
    if not valid then return nil,err end
    U.db=valid; UnhingedCCDB=valid; U.invalidSaved=nil; U.Rebuild(); U.UpdatePartyBubbles()
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
    local function fail(message) U.Print(message); return nil,message end
    if InCombatLockdown() then return fail('Create macros outside combat.') end
    local text,err=U.Macro(p,s)
    if not text then return fail(err) end
    local player=U.db.players[p]
    local name,realm=UnitFullName('player')
    local full=name..'-'..((realm and realm~='') and realm or GetNormalizedRealmName())
    -- Refresh the roster before matching a character entered after login/group changes.
    U.Roster()
    if U.ResolveName(player.name,U.roster)~=U.Name(full) then return fail('Create is only available for your character. Use Copy for another player.') end
    if #text>255 then return fail('Macro exceeds 255 bytes. Use Copy and shorten the showtooltip line.') end
    local macroName
    for i=1,99 do local candidate='UCC'..s..'_'..i; if not GetMacroInfo(candidate) then macroName=candidate; break end end
    if not macroName then return fail('No unused macro name. Use Copy.') end
    local limits=Constants and Constants.MacroConsts
    local maxCharacter=(limits and limits.MAX_CHARACTER_MACROS) or MAX_CHARACTER_MACROS or 30
    local _,character=GetNumMacros()
    if type(character)~='number' then return fail('Could not read the character macro slots. Use Copy.') end
    if character>=maxCharacter then return fail('Character macro slots are full. Use Copy.') end
    local icon=C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(player.slots[s].spell) or U.Abilities[player.slots[s].spell].icon
    local ok,index=pcall(CreateMacro,macroName,icon,text,true)
    if not ok then return fail('Macro creation failed: '..tostring(index)) end
    if type(index)~='number' or index<=0 then return fail('WoW did not create the macro. Use Copy in the macro editor.') end
    local savedName,_,savedText=GetMacroInfo(index)
    if savedName~=macroName or savedText~=text then return fail('Could not verify the new macro. Check the character tab in /macro.') end
    U.Print('Created '..macroName..' in the character tab of /macro.')
    return index,macroName
end
