"""Run with Python and lupa (Lua 5.1); no WoW client required."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / 'tests/wow_mock.lua').read_text())
namespace = lua.table()
for file in ['Abilities.lua', 'Model.lua', 'Display.lua', 'Config.lua', 'Core.lua']:
    lua.execute('return assert(loadstring(...))', (root / 'UnhingedCC' / file).read_text())('UnhingedCC', namespace)
lua.globals().U = namespace
lua.execute((root / 'tests/spec.lua').read_text())
