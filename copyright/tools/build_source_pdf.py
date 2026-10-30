# -*- coding: utf-8 -*-
"""生成鸿蒙版软件著作权登记用的源程序鉴别材料（V0.1，60 页，每页 50 行）。"""

from __future__ import annotations

import json
import math
import re
import sys
import unicodedata
from pathlib import Path

from fpdf import FPDF

ROOT = Path(__file__).resolve().parents[2]
APP = ROOT
OUT_DIR = ROOT / "copyright" / "output"
BUILD_DIR = ROOT / "copyright" / "build"
OUT_DIR.mkdir(parents=True, exist_ok=True)
BUILD_DIR.mkdir(parents=True, exist_ok=True)

SOFTWARE = "秒算虾料软件（鸿蒙版）V0.1"
AUTHOR = "夏卫兵"
FONT_CONSOLAS = Path(r"C:\Windows\Fonts\consola.ttf")
FONT_SIMHEI = Path(r"C:\Windows\Fonts\simhei.ttf")
FONT_FANGSONG = Path(r"C:\Windows\Fonts\simfang.ttf")
FONT_SYMBOL = Path(r"C:\Windows\Fonts\seguisym.ttf")

PAGE_W, PAGE_H = 210.0, 297.0
MARGIN_L = 15.0
MARGIN_R = 15.0
CONTENT_TOP = 24.0
LINE_COUNT = 50
LINE_H = 14.0 * 25.4 / 72  # 14pt，fpdf 的 cell 高度单位是 mm
FONT_SIZE = 7.6
MAX_COLS = 116
WIDTH_MM = PAGE_W - MARGIN_L - MARGIN_R
WIDTH_PT = WIDTH_MM * 72 / 25.4

# 前 30 页优先放核心算法、自绘表格和主界面；后 30 页以模型、入口、文案和配置收尾。
SOURCE_ORDER = [
    "entry/src/main/ets/model/FeedData.ets",
    "entry/src/main/ets/table/MixCalcTable.ets",
    "entry/src/main/ets/table/CellEditor.ets",
    "entry/src/main/ets/pages/Index.ets",
    "entry/src/main/ets/pages/WebPage.ets",
    "entry/src/main/ets/entryability/EntryAbility.ets",
    "entry/src/main/ets/model/Batch.ets",
    "entry/src/main/ets/model/BatchStore.ets",
    "entry/src/main/ets/common/Strings.ets",
]

CONFIG_FILES = [
    "AppScope/app.json5",
    "AppScope/resources/base/element/string.json",
    "build-profile.json5",
    "oh-package.json5",
    "entry/build-profile.json5",
    "entry/oh-package.json5",
    "entry/src/main/module.json5",
    "entry/src/main/resources/base/profile/main_pages.json",
    "entry/src/main/resources/base/element/string.json",
    "entry/src/main/resources/base/element/color.json",
]


def east_asian(ch: str) -> bool:
    return unicodedata.east_asian_width(ch) in ("W", "F")


def display_cols(text: str) -> int:
    return sum(2 if east_asian(ch) else 1 for ch in text)


def split_runs(text: str):
    runs = []
    buf = []
    current = None
    for ch in text:
        is_cjk = east_asian(ch)
        if current is None:
            current = is_cjk
        if is_cjk != current:
            runs.append(("".join(buf), current))
            buf = []
            current = is_cjk
        buf.append(ch)
    if buf:
        runs.append(("".join(buf), current))
    return runs


def break_candidates(line: str) -> list[int]:
    """返回可以断行的位置（断在该字符之后），字符串/字符字面量内部不算。"""
    points: set[int] = set()
    in_string = in_char = escaped = False
    for i, ch in enumerate(line):
        if in_string or in_char:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif in_string and ch == '"':
                in_string = False
            elif in_char and ch == "'":
                in_char = False
            continue
        if ch == '"':
            in_string = True
        elif ch == "'":
            in_char = True
        elif ch in " ,;(":
            points.add(i + 1)
        elif ch in "+-*/%=<>?!:&|":
            points.add(i + 1)
    return sorted(points)


def wrap_line(line: str) -> list[str]:
    if display_cols(line) <= MAX_COLS:
        return [line]
    indent = len(line) - len(line.lstrip(" "))
    continuation = " " * (indent + 8)
    pieces: list[str] = []
    rest = line
    while display_cols(rest) > MAX_COLS:
        candidates = [p for p in break_candidates(rest) if display_cols(rest[:p]) <= MAX_COLS]
        if not candidates:
            # 单个超长字符串/标识符，保持完整，绘制时自动缩小字号
            break
        cut = max(candidates)
        piece = rest[:cut].rstrip()
        if not piece:
            break
        pieces.append(piece)
        tail = rest[cut:].lstrip(" ")
        if not tail:
            rest = ""
            break
        rest = continuation + tail
    if rest.strip():
        pieces.append(rest.rstrip())
    return pieces


def strip_java_comments(text: str) -> str:
    """去掉 Java 的 // 与 /* */ 注释，字符串和字符字面量内部不动。"""
    out: list[str] = []
    i = 0
    n = len(text)
    state = "code"
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
        elif state == "string":
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
            elif ch == '"':
                state = "code"
                i += 1
            else:
                i += 1
        elif state == "char":
            out.append(ch)
            if ch == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
            elif ch == "'":
                state = "code"
                i += 1
            else:
                i += 1
        elif state == "line":
            if ch in "\r\n":
                out.append(ch)
                state = "code"
            i += 1
        else:  # block
            if ch == "*" and nxt == "/":
                state = "code"
                i += 2
            elif ch in "\r\n":
                out.append(ch)
                i += 1
            else:
                i += 1
    return "".join(out)


def strip_xml_comments(text: str) -> str:
    return re.sub(r"<!--.*?-->", "", text, flags=re.S)


def load_lines(files: list[Path]):
    lines: list[str] = []
    stats = []
    for path in files:
        raw_original = path.read_text(encoding="utf-8-sig")
        raw_original = raw_original.replace("\r\n", "\n").replace("\r", "\n")
        raw_lines = raw_original.splitlines()
        raw_nonblank = sum(1 for item in raw_lines if item.strip())

        if path.suffix.lower() in (".ets", ".json5"):
            # ArkTS 和 JSON5 都支持 // 与 /* */ 注释
            raw = strip_java_comments(raw_original)
        else:
            raw = raw_original

        source_lines = raw.splitlines()
        nonblank = sum(1 for item in source_lines if item.strip())
        printed = []
        for item in source_lines:
            item = item.replace("\t", "    ").replace("\x0c", "").rstrip()
            if not item.strip():
                continue
            printed.extend(wrap_line(item))
        lines.extend(printed)
        stats.append(
            {
                "file": path.relative_to(APP).as_posix(),
                "raw_lines": len(raw_lines),
                "raw_nonblank": raw_nonblank,
                "code_lines": len(source_lines),
                "code_nonblank": nonblank,
                "print_lines": len(printed),
            }
        )
    return lines, stats


def measure_line(pdf: FPDF, text: str, size: float) -> float:
    width = 0.0
    for run, is_cjk in split_runs(text):
        pdf.set_font("SimHei" if is_cjk else "Consolas", "", size)
        width += pdf.get_string_width(run)
    return width


def draw_line(pdf: FPDF, text: str, y: float) -> tuple[float, bool]:
    size = FONT_SIZE
    width = measure_line(pdf, text, size)
    for _ in range(6):
        if width <= WIDTH_PT:
            break
        size = max(5.5, size * (WIDTH_PT / width) * 0.98)
        width = measure_line(pdf, text, size)
    x = MARGIN_L
    pdf.set_xy(x, y)
    for run, is_cjk in split_runs(text):
        pdf.set_font("SimHei" if is_cjk else "Consolas", "", size)
        run_width = pdf.get_string_width(run)
        pdf.cell(run_width, LINE_H, run)
    return width, width <= WIDTH_PT + 0.5


class SourcePDF(FPDF):
    def __init__(self, total_pages: int):
        super().__init__(orientation="P", unit="mm", format="A4")
        self.total_pages = total_pages
        self.set_auto_page_break(False)
        self.set_margins(MARGIN_L, CONTENT_TOP, MARGIN_R)
        self.add_font("Consolas", "", str(FONT_CONSOLAS))
        self.add_font("SimHei", "", str(FONT_SIMHEI))
        self.add_font("FangSong", "", str(FONT_FANGSONG))
        self.add_font("SegoeUISymbol", "", str(FONT_SYMBOL))
        self.set_fallback_fonts(["SimHei", "FangSong", "SegoeUISymbol"], exact_match=False)
        self.set_title(f"{SOFTWARE} 源程序")
        self.set_author(AUTHOR)
        self.set_subject("计算机软件著作权登记源程序鉴别材料")
        self.set_creator("build_source_pdf.py")

    def header(self):
        self.set_font("FangSong", "", 8.5)
        self.set_text_color(70, 70, 70)
        self.set_xy(MARGIN_L, 11)
        self.cell(0, 5, SOFTWARE)
        self.set_xy(PAGE_W - MARGIN_R - 60, 11)
        self.cell(60, 5, f"第 {self.page_no()} 页 / 共 {self.total_pages} 页", align="R")
        self.set_draw_color(120, 120, 120)
        self.set_line_width(0.2)
        self.line(MARGIN_L, 17.5, PAGE_W - MARGIN_R, 17.5)
        self.set_text_color(0, 0, 0)


def collect_files() -> list[Path]:
    files: list[Path] = []
    seen: set[Path] = set()
    for rel in SOURCE_ORDER:
        path = ROOT / rel
        if not path.is_file():
            print(f"[warn] 跳过不存在的文件: {rel}", file=sys.stderr)
            continue
        files.append(path)
        seen.add(path.resolve())
    for path in sorted((ROOT / "entry/src/main/ets").rglob("*.ets"), key=lambda p: p.as_posix().lower()):
        if path.resolve() not in seen:
            print(f"[warn] 追加未列出的 ArkTS 文件: {path.relative_to(ROOT)}", file=sys.stderr)
            files.append(path)
            seen.add(path.resolve())
    for rel in CONFIG_FILES:
        path = ROOT / rel
        if not path.is_file():
            print(f"[warn] 跳过不存在的配置: {rel}", file=sys.stderr)
            continue
        files.append(path)
    return files


def main() -> int:
    files = collect_files()
    lines, stats = load_lines(files)
    total = len(lines)
    full_pages = math.ceil(total / LINE_COUNT)
    if full_pages <= 60:
        selected = lines
        out_pages = full_pages
        mode = "全部提交（不足 60 页）"
    else:
        # 取前 30 页 + 最后 30 页（1500 行），保证末页也是完整 50 行，
        # 不因源码总行数的零头只剩一行。
        selected = lines[: 30 * LINE_COUNT] + lines[-(30 * LINE_COUNT):]
        out_pages = 60
        mode = "前 30 页 + 后 30 页"

    pdf = SourcePDF(out_pages)
    overflow = []
    for page_index in range(out_pages):
        pdf.add_page()
        chunk = selected[page_index * LINE_COUNT : (page_index + 1) * LINE_COUNT]
        for line_index, text in enumerate(chunk):
            y = CONTENT_TOP + line_index * LINE_H
            width, ok = draw_line(pdf, text, y)
            if not ok:
                overflow.append({"page": page_index + 1, "line": line_index + 1, "text": text[:80]})

    out_pdf = OUT_DIR / f"01_源程序_{SOFTWARE}.pdf"
    out_pdf.write_bytes(bytes(pdf.output()))

    (BUILD_DIR / "source_print.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")

    missing_glyphs = {}
    for key, font in pdf.fonts.items():
        if getattr(font, "missing_glyphs", None):
            missing_glyphs[key] = [hex(code) for code in font.missing_glyphs]

    report = {
        "software": SOFTWARE,
        "mode": mode,
        "source_total_lines": sum(item["raw_lines"] for item in stats),
        "source_nonblank_lines": sum(item["raw_nonblank"] for item in stats),
        "code_total_lines": sum(item["code_lines"] for item in stats),
        "code_nonblank_lines": sum(item["code_nonblank"] for item in stats),
        "comment_removed_lines": sum(item["raw_nonblank"] - item["code_nonblank"] for item in stats),
        "comments_stripped": True,
        "print_lines": total,
        "full_pages": full_pages,
        "submitted_pages": out_pages,
        "first_chunk_lines": min(30 * LINE_COUNT, total),
        "last_chunk_start_line": total - 30 * LINE_COUNT + 1 if full_pages > 60 else 1,
        "overflow_lines": overflow,
        "missing_glyphs": missing_glyphs,
        "files": stats,
        "output": str(out_pdf),
    }
    (BUILD_DIR / "source_report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
