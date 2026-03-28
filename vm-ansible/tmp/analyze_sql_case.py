from pathlib import Path
import re

path = Path('C:/Workspace/k8s-lab-dabin/backup/db/all.sql')
text = path.read_text(encoding='utf-8', errors='ignore').replace(chr(96), '')

names = [
    m.group(1)
    for m in re.finditer(r"CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?([A-Za-z0-9_]+)", text, flags=re.IGNORECASE)
    if m.group(1)
]
upper = [n for n in names if any(ch.isupper() for ch in n)]

print(f"CREATE_TABLE_COUNT {len(names)}")
print(f"UPPERCASE_TABLE_DEFS {len(upper)}")
print("SAMPLE", ",".join(sorted(set(upper))[:30]))
