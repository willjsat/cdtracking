local _, U = ...
local floor, sort = math.floor, table.sort
U.VERSION = 2
function U.IsSecret(v) return issecretvalue and issecretvalue(v) end
function U.CleanText(v, max, empty)
    return type(v) == 'string' and #v <= max and (empty or #v > 0)
        and not v:find('[%c|]')
end
function U.Name(v)
    return v:lower():gsub('%s+', '')
end
function U.NewConfig()
    local c = {version = 2, locked = true, players = {}, positions = {}}
    for p = 1, 5 do
        c.players[p] = {name = '', slots = {}}
        for s = 1, 5 do
            c.players[p].slots[s] = {spell = 0, priority = (p-1)*5+s, trigger = ''}
        end
    end
    return c
end
-- Stable English tokens make macros readable across client locales and slot moves.
function U.DefaultTrigger(player, spell)
    local ability = U.Abilities[spell]
    local name = player.name:match('^[^-]+') or ''
    if not ability then return '' end
    return name .. (ability.kind == 'kick' and 'Kick' or (ability.token or ability.name:gsub('[^%w]', '')))
end
function U.Trigger(player, s)
    local a = player.slots[s]
    return a.trigger ~= '' and a.trigger or U.DefaultTrigger(player, a.spell)
end
function U.Validate(c)
    if type(c) ~= 'table' or (c.version ~= 1 and c.version ~= 2) or type(c.players) ~= 'table' then return nil, 'Unsupported config.' end
    local out, names, triggers = U.NewConfig(), {}, {}
    out.locked = c.locked ~= false
    for p = 1, 5 do
        local player = c.players[p]
        if type(player) ~= 'table' or not U.CleanText(player.name, 80, true) or player.name:find('[%s:]') then return nil, 'Invalid player name.' end
        local key = U.Name(player.name)
        if key ~= '' and names[key] then return nil, 'Duplicate player name.' end
        names[key] = true
        out.players[p].name = player.name
        if type(player.slots) ~= 'table' then return nil, 'Missing ability slots.' end
        triggers[p] = {}
        for s = 1, 5 do
            local a = player.slots[s]
            if type(a) ~= 'table' then return nil, 'Missing ability slot.' end
            local spell = a.spell
            local ability = U.Abilities[spell]
            if spell ~= 0 and (not ability or ability.kind ~= (s == 1 and 'kick' or 'stop')) then return nil, 'Invalid ability for slot.' end
            if type(a.priority) ~= 'number' or a.priority ~= floor(a.priority) or a.priority < 1 or a.priority > 999 then return nil, 'Priority must be 1–999.' end
            if not U.CleanText(a.trigger, 100, true) then return nil, 'Invalid chat value.' end
            if a.override ~= nil and (type(a.override) ~= 'number' or a.override ~= a.override or a.override < 0.1 or a.override > 3600) then return nil, 'Cooldown must be 0.1–3600 seconds.' end
            local custom = a.trigger
            -- v1 UI sometimes saved a displayed default as an explicit override.
            -- Migrate numeric player IDs while retaining genuinely custom messages.
            if c.version == 1 then
                local prefix, index = custom:match('^(.*):(%d+)$')
                if prefix == player.name and tonumber(index) >= 1 and tonumber(index) <= 5 then custom = '' end
            end
            if custom == U.DefaultTrigger(player, spell) then custom = '' end
            local trigger = custom ~= '' and custom or U.DefaultTrigger(player, spell)
            if spell ~= 0 and triggers[p][trigger] then return nil, 'Duplicate chat value for this player.' end
            if spell ~= 0 then triggers[p][trigger] = true end
            out.players[p].slots[s] = {spell = spell, priority = a.priority, trigger = custom, override = a.override}
        end
    end
    if type(c.positions) == 'table' then
        for _, kind in ipairs({'kick','stop'}) do
            local pos = c.positions[kind]
            if type(pos) == 'table' and type(pos.x) == 'number' and type(pos.y) == 'number'
                and pos.x == pos.x and pos.y == pos.y and math.abs(pos.x) < 20000 and math.abs(pos.y) < 20000 then
                out.positions[kind] = {x=pos.x, y=pos.y}
            end
        end
    end
    return out
end
-- A versioned, bounded data-only format. Never execute imported Lua.
local function enc(s) return (s:gsub('([^%w%-%._])', function(c) return string.format('%%%02X', c:byte()) end)) end
local function dec(s)
    if s:gsub('%%%x%x',''):find('%%') then error('Malformed escape') end
    return (s:gsub('%%(%x%x)',function(h) return string.char(tonumber(h,16)) end))
end
function U.Export(c)
    local lines = {'UCC2'}
    for p = 1, 5 do
        local player = c.players[p]
        lines[#lines+1] = 'P\t' .. enc(player.name)
        for s = 1, 5 do
            local a = player.slots[s]
            lines[#lines+1] = table.concat({'A',a.spell,a.priority,a.override or '',enc(a.trigger)},'\t')
        end
    end
    return table.concat(lines,'\n')
end
function U.Import(text)
    if type(text) ~= 'string' or #text > 32768 then return nil, 'Config exceeds 32 KB.' end
    local ok, result, reason = pcall(function()
        text = text:gsub('\r',''):gsub('\n+$','')
        local lines = {}; for l in (text .. '\n'):gmatch('(.-)\n') do lines[#lines+1] = l end
        if #lines ~= 31 or (lines[1] ~= 'UCC1' and lines[1] ~= 'UCC2') then return nil, 'Invalid UnhingedCC config.' end
        local c, n = U.NewConfig(), 2
        c.version = lines[1] == 'UCC1' and 1 or 2
        for p=1,5 do
            local name = lines[n]:match('^P\t(.*)$'); if not name then return nil,'Invalid player record.' end
            c.players[p].name = dec(name); n=n+1
            for s=1,5 do
                local id,priority,override,trigger = lines[n]:match('^A\t(%d+)\t(%d+)\t([%d%.]*)\t(.*)$')
                if not id then return nil,'Invalid ability record.' end
                c.players[p].slots[s] = {spell=tonumber(id),priority=tonumber(priority),override=override ~= '' and tonumber(override) or nil,trigger=dec(trigger)}
                if override ~= '' and not tonumber(override) then return nil,'Invalid cooldown.' end
                n=n+1
            end
        end
        return U.Validate(c)
    end)
    if not ok then return nil,'Malformed config.' end
    return result, reason
end
function U.Rebuild()
    local old = U.entries or {}
    U.entries, U.lookup = {}, {}
    for p, player in ipairs(U.db.players) do
        if player.name ~= '' then
            for s,a in ipairs(player.slots) do
                local ability = U.Abilities[a.spell]
                if ability then
                    local key = p .. ':' .. s
                    local prior = old[key]
                    local e = {key=key, player=player.name, spell=a.spell, ability=ability,
                        priority=a.priority, trigger=U.Trigger(player,s), duration=a.override or ability.cooldown,
                        expires=prior and prior.player==player.name and prior.spell==a.spell and prior.expires or 0}
                    U.entries[key] = e
                    local list = U.lookup[e.trigger] or {}; U.lookup[e.trigger] = list; list[#list+1] = e
                end
            end
        end
    end
    if U.RefreshDisplay then U.RefreshDisplay() end
end
function U.Order(kind, now)
    local list = {}
    for _,e in pairs(U.entries) do if e.ability.kind == kind then list[#list+1] = e end end
    sort(list,function(a,b)
        local ar,br = a.expires <= now, b.expires <= now
        if ar ~= br then return ar end
        if not ar and a.expires ~= b.expires then return a.expires < b.expires end
        if a.priority ~= b.priority then return a.priority < b.priority end
        return a.key < b.key
    end)
    return list
end
-- Resolve through the actual party roster, rejecting ambiguous short names.
function U.ResolveName(configured, roster)
    local wanted, found = U.Name(configured), nil
    for _,full in ipairs(roster) do
        local n = U.Name(full)
        if n == wanted or (not wanted:find('-',1,true) and n:match('^[^-]+') == wanted) then
            if found and found ~= n then return nil end
            found = n
        end
    end
    return found
end
function U.HandleChat(message, sender, now)
    if U.IsSecret(message) or U.IsSecret(sender) then
        U.blocked = (U.blocked or 0)+1
        if U.blocked == 1 and U.Print then U.Print('Chat is restricted: unreadable announcements are being skipped. Timers may be incomplete. /ucc status for details.') end
        return false
    end
    if type(message) ~= 'string' or type(sender) ~= 'string' then return false end
    local candidates = U.lookup[message]
    if not candidates then return false end
    local source = U.ResolveName(sender, U.roster or {})
    if not source then return false end
    for _,e in ipairs(candidates) do
        if U.ResolveName(e.player,U.roster or {}) == source then
            -- Ignore repeated macro presses while the estimated cooldown is active.
            if e.expires > now then return false end
            e.expires = now + e.duration
            if U.RefreshDisplay then U.RefreshDisplay() end
            return true
        end
    end
    return false
end
