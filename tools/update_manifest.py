"""Refresh the installable addon's file manifest after intentional source changes."""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parent.parent/'AzerothStats'
names=[p.relative_to(root).as_posix() for p in root.iterdir() if p.is_file() and p.suffix in {'.lua','.toc','.md'}]
names += [p.relative_to(root).as_posix() for p in (root/'media').iterdir() if p.is_file()]
(root/'SHA256SUMS.txt').write_text(''.join(hashlib.sha256((root/name).read_bytes()).hexdigest()+'  '+name+'\n' for name in sorted(names)),encoding='utf-8')
print('Manifest:',len(names),'files')
