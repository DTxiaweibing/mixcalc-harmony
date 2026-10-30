# -*- coding: utf-8 -*-
"""统计鸿蒙版源码行数，供软著申请表填写。"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(r"D:\mixcalc-harmony")
FILES: list[str] = []
FILES += sorted(
    p.relative_to(ROOT).as_posix()
    for p in (ROOT / "entry/src/main/ets").rglob("*.ets")
)


def strip_comments(text: str) -> str:
    out: list[str] = []
    i = 0
    state = "code"
    n = len(text)
    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if state == "code":
            if ch == '"':
                state = "string"
                out.append(ch)
                i += 1
            elif ch == "'":
                state = "char"
                out.append(ch)
                i += 1
            elif ch == "/" and nxt == "/":
                state = "line"
                i += 2
            elif ch == "/" and nxt == "*":
                state = "block"
                i += 2
            else:
                out.append(ch)
                i += 1
        elif state in ("string", "char"):
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
            elif (state == "string" and ch == '"') or (state == "char" and ch == "'"):
                state = "code"
                i += 1
            else:
                i += 1
        elif state == "line":
            if ch in "\r\n":
                out.append(ch)
                state = "code"
            i += 1
        else:
            if ch == "*" and nxt == "/":
                state = "code"
                i += 2
            elif ch in "\r\n":
                out.append(ch)
                i += 1
            else:
                i += 1
    return "".join(out)


rows = []
for rel in FILES:
    path = ROOT / rel
    if not path.is_file():
        continue
    raw = path.read_text(encoding="utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
    raw_lines = raw.splitlines()
    code = strip_comments(raw).splitlines()
    rows.append(
        {
            "file": rel,
            "raw_lines": len(raw_lines),
            "raw_nonblank": sum(1 for x in raw_lines if x.strip()),
            "code_lines": len(code),
            "code_nonblank": sum(1 for x in code if x.strip()),
        }
    )

summary = {
    "files": rows,
    "raw_lines": sum(r["raw_lines"] for r in rows),
    "raw_nonblank": sum(r["raw_nonblank"] for r in rows),
    "code_lines": sum(r["code_lines"] for r in rows),
    "code_nonblank": sum(r["code_nonblank"] for r in rows),
}
print(json.dumps(summary, ensure_ascii=False, indent=2))
