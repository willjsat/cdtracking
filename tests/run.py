"""Run with Python and lupa (Lua 5.1); no WoW client required."""
from pathlib import Path
from lupa.lua51 import LuaRuntime
root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / 'tests/wow_mock.lua').read_text())
namespace = lua.table()
toc = (root / 'UnhingedCC/UnhingedCC.toc').read_text()
for file in [line.strip() for line in toc.splitlines() if line.strip().endswith('.lua')]:
    lua.execute('return assert(loadstring(...))', (root / 'UnhingedCC' / file).read_text())('UnhingedCC', namespace)
lua.globals().U = namespace
lua.execute((root / 'tests/spec.lua').read_text())

# Check encoding against the standard library, independently of our Lua decoder.
import base64
import zlib
for length in range(1, 81):
    config = namespace.NewConfig()
    config.players[1].name = 'N' * length
    encoded = namespace.Export(config)
    prefix, payload, digest = encoded[1:].split('!')
    assert prefix == 'UCC4'
    decoded = base64.b64decode(payload, validate=True)
    assert decoded.startswith(b'UCC3\nP\t')
    assert f'{zlib.adler32(decoded):08x}' == digest
print('PASS: Base64 and checksum match Python standard library for 80 configs')
