local _, U = ...
local floor, sort = math.floor, table.sort
U.VERSION = 3
function U.IsSecret(v) return issecretvalue and issecretvalue(v) end
function U.CleanText(v, max, empty)
    return type(v) == 'string' and #v <= max and (empty or #v > 0)
        and not v:find('[%c|]')
end
function U.Name(v)
    return v:lower():gsub('%s+', '')
end
function U.NewConfig()
    local c = {version = 3, locked = true, players = {}, positions = {}}
    for p = 1, 5 do
        c.players[p] = {name = '', slots = {}}
        for s = 1, 5 do
            c.players[p].slots[s] = {spell = 0, priority = (p-1)*5+s}
        end
    end
    return c
end
-- Stable English tokens make macros readable across client locales and slot moves.
function U.DefaultTrigger(player, spell)
    local ability = U.Abilities[spell]
    local name = player.name:match('^[^-]+') or ''
    if not ability then return '' end
    return name .. (ability.kind == 'kick' and 'Kick' or ability.name:gsub('[^%w]', ''))
end
function U.Trigger(player, s)
    return U.DefaultTrigger(player, player.slots[s].spell)
end
function U.Validate(c)
    if type(c) ~= 'table' or (c.version ~= 1 and c.version ~= 2 and c.version ~= 3) or type(c.players) ~= 'table' then return nil, 'Unsupported config.' end
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
            if a.override ~= nil and (type(a.override) ~= 'number' or a.override ~= a.override or a.override < 0.1 or a.override > 3600) then return nil, 'Cooldown must be 0.1–3600 seconds.' end
            local trigger = U.DefaultTrigger(player, spell)
            if spell ~= 0 and triggers[p][trigger] then return nil, 'Duplicate chat value for this player.' end
            if spell ~= 0 then triggers[p][trigger] = true end
            out.players[p].slots[s] = {spell = spell, priority = a.priority, override = a.override}
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
local function serialize(c)
    local lines = {'UCC3'}
    for p = 1, 5 do
        local player = c.players[p]
        lines[#lines+1] = 'P\t' .. enc(player.name)
        for s = 1, 5 do
            local a = player.slots[s]
            lines[#lines+1] = table.concat({'A',a.spell,a.priority,a.override or ''},'\t')
        end
    end
    return table.concat(lines,'\n')
end
local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function base64(text)
    local out = {}
    for i=1,#text,3 do
        local a,b,c = text:byte(i,i+2)
        local n = a*65536+(b or 0)*256+(c or 0)
        out[#out+1] = alphabet:sub(floor(n/262144)%64+1,floor(n/262144)%64+1)
            ..alphabet:sub(floor(n/4096)%64+1,floor(n/4096)%64+1)
            ..(b and alphabet:sub(floor(n/64)%64+1,floor(n/64)%64+1) or '=')
            ..(c and alphabet:sub(n%64+1,n%64+1) or '=')
    end
    return table.concat(out)
end
local function unbase64(text)
    if #text%4~=0 or text:find('[^%w+/=]') then error('Invalid encoding') end
    local out={}
    for i=1,#text,4 do
        local block=text:sub(i,i+3)
        if block:find('=') and (i+3~=#text or not block:match('^[%w+/][%w+/][%w+/=]=$')) then error('Invalid padding') end
        local values={}
        for j=1,4 do
            local ch=block:sub(j,j)
            values[j]=ch=='=' and 0 or assert(alphabet:find(ch,1,true))-1
        end
        local n=values[1]*262144+values[2]*4096+values[3]*64+values[4]
        out[#out+1]=string.char(floor(n/65536)%256)
            ..(block:sub(3,3)~='=' and string.char(floor(n/256)%256) or '')
            ..(block:sub(4,4)~='=' and string.char(n%256) or '')
    end
    return table.concat(out)
end
local function checksum(text)
    local a,b=1,0
    for i=1,#text do a=(a+text:byte(i))%65521; b=(b+a)%65521 end
    return string.format('%08x',b*65536+a)
end
function U.Export(c)
    local payload=serialize(c)
    return '!UCC4!'..base64(payload)..'!'..checksum(payload)
end
function U.Import(text)
    if type(text) ~= 'string' or #text > 32768 then return nil, 'Config exceeds 32 KB.' end
    local ok, result, reason = pcall(function()
        text=text:match('^%s*(.-)%s*$')
        if text:sub(1,1)=='"' and text:sub(-1)=='"' then text=text:sub(2,-2) end
        if text:sub(1,6)=='!UCC4!' then
            local encoded,hash=text:gsub('%s',''):match('^!UCC4!([%w+/=]+)!(%x%x%x%x%x%x%x%x)$')
            if not encoded then return nil,'Invalid export string.' end
            text=unbase64(encoded)
            if checksum(text)~=hash:lower() then return nil,'Export string is damaged. Copy it again.' end
        end
        text = text:gsub('\r',''):gsub('\n+$','')
        local lines = {}; for l in (text .. '\n'):gmatch('(.-)\n') do lines[#lines+1] = l end
        if #lines ~= 31 or (lines[1] ~= 'UCC1' and lines[1] ~= 'UCC2' and lines[1] ~= 'UCC3') then return nil, 'Invalid UnhingedCC config.' end
        local c, n = U.NewConfig(), 2
        -- Older formats carried a custom trigger field; accept but discard it.
        local legacy = lines[1] ~= 'UCC3'
        for p=1,5 do
            local name = lines[n]=='P' and '' or lines[n]:match('^P\t(.*)$'); if not name then return nil,'Invalid player record.' end
            c.players[p].name = dec(name); n=n+1
            for s=1,5 do
                local id,priority,override
                if legacy then
                    local trigger
                    for padding=0,2 do
                        id,priority,override,trigger = (lines[n]..string.rep('\t',padding)):match('^A\t(%d+)\t(%d+)\t([%d%.]*)\t(.*)$')
                        if id then break end
                    end
                    if trigger then dec(trigger) end -- Validate escapes without retaining custom IDs.
                else
                    id,priority,override = lines[n]:match('^A\t(%d+)\t(%d+)\t([%d%.]*)$')
                    if not id then id,priority=lines[n]:match('^A\t(%d+)\t(%d+)$'); override='' end
                end
                if not id then return nil,'Invalid ability record.' end
                c.players[p].slots[s] = {spell=tonumber(id),priority=tonumber(priority),override=override ~= '' and tonumber(override) or nil}
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
