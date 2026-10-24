local _, U = ...
function U.PresetName(name)
    if type(name)~='string' then return nil,'Enter a preset name.' end
    name=name:match('^%s*(.-)%s*$')
    if not U.CleanText(name,40,false) then return nil,'Use a name between 1 and 40 characters.' end
    return name
end
function U.InitPresets()
    U.presets=type(UnhingedCCPresets)=='table' and UnhingedCCPresets or {}
    UnhingedCCPresets=U.presets
end
function U.PresetNames()
    local names={}
    for name,config in pairs(U.presets) do
        if U.PresetName(name) and U.Validate(config) then names[#names+1]=name end
    end
    table.sort(names,function(a,b) return a:lower()<b:lower() end)
    return names
end
function U.SavePreset(name,replace)
    local clean,err=U.PresetName(name); if not clean then return nil,err end
    for existing in pairs(U.presets) do
        if type(existing)=='string' and existing:lower()==clean:lower() then
            if not replace then return nil,'A preset with that name already exists.',existing end
            clean=existing; break
        end
    end
    local config; config,err=U.Validate(U.db); if not config then return nil,err end
    U.presets[clean]=config
    return true,clean
end
function U.ApplyConfig(config)
    local valid,err=U.Validate(config); if not valid then return nil,err end
    U.entries={}
    U.Commit(valid); U.RestoreDisplayPositions()
    return true
end
function U.LoadPreset(name)
    local config=U.presets[name]
    if not config then return nil,'Preset not found.' end
    return U.ApplyConfig(config)
end
function U.ResetConfig()
    local config=U.NewConfig()
    config.positions=U.db.positions
    config.locked=U.db.locked
    U.entries={}
    return U.Commit(config)
end
