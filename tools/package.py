"""Produce an installable archive with a stable AddOns folder layout."""
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path(__file__).resolve().parents[1]
output = root / 'dist/UnhingedCC-0.1.0.zip'
output.parent.mkdir(exist_ok=True)
with ZipFile(output, 'w', ZIP_DEFLATED) as archive:
    for file in sorted((root / 'UnhingedCC').glob('*')):
        if file.is_file():
            archive.write(file, file.relative_to(root))
print(output)
