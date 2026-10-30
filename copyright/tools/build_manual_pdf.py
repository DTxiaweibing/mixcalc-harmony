# -*- coding: utf-8 -*-
"""把 05_软件说明书.md 生成软著登记用的软件说明书 PDF（A4，含封面/目录/页眉）。"""

from __future__ import annotations

import json
import re
from pathlib import Path

from fpdf import FPDF
from fontTools.ttLib import TTFont
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
DOC_PATH = ROOT / "copyright" / "docs" / "05_软件说明书.md"
OUT_DIR = ROOT / "copyright" / "output"
BUILD_DIR = ROOT / "copyright" / "build"
OUT_PDF = OUT_DIR / "02_软件说明书_秒算虾料软件（鸿蒙版）V0.1.pdf"
REPORT_JSON = BUILD_DIR / "manual_report.json"
ICON_PATH = ROOT / "entry" / "src" / "main" / "resources" / "base" / "media" / "icon.png"

SOFTWARE = "秒算虾料软件（鸿蒙版）V0.1"
SOFTWARE_BASE = "秒算虾料软件（鸿蒙版）"
VERSION = "V0.1"
DOC_TITLE = "软件说明书"
DOC_VERSION = "V0.1"
AUTHOR = "夏卫兵"
DOC_DATE = "2026 年 10 月"
DEV_DATE = "2026 年 10 月 30 日"

FONT_DIR = Path(r"C:\Windows\Fonts")
FONT_FANGSONG = FONT_DIR / "simfang.ttf"
FONT_SIMHEI = FONT_DIR / "simhei.ttf"
FONT_CONSOLA = FONT_DIR / "consola.ttf"
FONT_SYMBOL = FONT_DIR / "seguisym.ttf"

PAGE_W = 210.0
PAGE_H = 297.0
MARGIN_L = 22.0
MARGIN_R = 22.0
MARGIN_T = 26.0
MARGIN_B = 20.0
CONTENT_W = PAGE_W - MARGIN_L - MARGIN_R
LINE_H = 6.2

GREEN = (45, 140, 66)
DARK_GREEN = (31, 107, 48)
TEXT = (32, 32, 32)
GRAY = (105, 105, 105)
LIGHT_GREEN = (240, 248, 242)
LIGHT_GRAY = (246, 249, 247)
BORDER_GRAY = (190, 205, 195)

ALL_TEXT: list[str] = []


def add_text(text: str) -> str:
    ALL_TEXT.append(text)
    return text


def clean_inline(text: str) -> str:
    return text.replace("**", "").replace("`", "").strip()


def split_cells(line: str) -> list[str]:
    return [clean_inline(c) for c in line.strip().strip("|").split("|")]


def is_separator(cells: list[str]) -> bool:
    return len(cells) > 0 and all(re.fullmatch(r":?-{3,}:?", c.replace(" ", "")) for c in cells)


def parse_blocks(lines: list[str]) -> list[tuple[str, object]]:
    blocks: list[tuple[str, object]] = []
    i = 0
    while i < len(lines):
        raw = lines[i]
        s = raw.strip()
        if not s or s == "---":
            i += 1
            continue
        if s.startswith("```"):
            i += 1
            code: list[str] = []
            while i < len(lines) and not lines[i].strip().startswith("```"):
                code.append(lines[i].rstrip("\n"))
                i += 1
            i += 1
            blocks.append(("code", code))
            continue
        if s.startswith("|"):
            rows: list[list[str]] = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                cells = split_cells(lines[i])
                if not is_separator(cells):
                    rows.append(cells)
                i += 1
            if rows:
                blocks.append(("table", rows))
            continue
        img = re.match(r"^!\[(.*?)\]\((.*?)\)\s*$", s)
        if img:
            blocks.append(("image", (clean_inline(img.group(1)), img.group(2).strip())))
            i += 1
            continue
        if s.startswith("## "):
            blocks.append(("h1", clean_inline(s[3:])))
            i += 1
            continue
        if s.startswith("### "):
            blocks.append(("h2", clean_inline(s[4:])))
            i += 1
            continue
        if s.startswith("#### "):
            blocks.append(("h3", clean_inline(s[5:])))
            i += 1
            continue
        m = re.match(r"^(\d+)\.\s+(.*)$", s)
        if m:
            blocks.append(("num", (m.group(1) + ".", clean_inline(m.group(2)))))
            i += 1
            continue
        if s.startswith("- "):
            blocks.append(("bullet", clean_inline(s[2:])))
            i += 1
            continue
        if s.startswith("> "):
            quote: list[str] = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote.append(clean_inline(lines[i].strip()[1:].strip()))
                i += 1
            blocks.append(("quote", " ".join(quote)))
            continue
        para: list[str] = [clean_inline(s)]
        i += 1
        while i < len(lines):
            nxt = lines[i].strip()
            if (not nxt or nxt == "---" or nxt.startswith(("#", "|", "```", "- ", "> "))
                    or re.match(r"^\d+\.\s+", nxt)):
                break
            para.append(clean_inline(nxt))
            i += 1
        blocks.append(("p", " ".join(para)))
    return blocks


class ManualPDF(FPDF):
    def __init__(self, total_pages: int = 0) -> None:
        super().__init__(orientation="P", unit="mm", format="A4")
        self.total_pages = total_pages
        self.section_pages: dict[str, int] = {}
        self.set_margins(MARGIN_L, MARGIN_T, MARGIN_R)
        self.set_auto_page_break(True, MARGIN_B)
        self.set_title(f"{SOFTWARE} {DOC_TITLE}")
        self.set_author(AUTHOR)
        self.set_creator("秒算虾料")
        self.set_subject(f"{SOFTWARE} 软件著作权登记文档")
        self.add_font("FangSong", "", str(FONT_FANGSONG))
        self.add_font("FangSong", "B", str(FONT_SIMHEI))
        self.add_font("SimHei", "", str(FONT_SIMHEI))
        self.add_font("Consola", "", str(FONT_CONSOLA))
        self.add_font("SegoeUISymbol", "", str(FONT_SYMBOL))
        self.set_fallback_fonts(["FangSong", "SimHei", "SegoeUISymbol"], exact_match=False)

    def header(self) -> None:
        if self.page_no() == 1:
            return
        self.set_y(10)
        self.set_font("SimHei", "", 9)
        self.set_text_color(95, 95, 95)
        self.cell(125, 6, f"{SOFTWARE}  {DOC_TITLE}", align="L")
        if self.total_pages > 0:
            self.cell(0, 6, f"第 {self.page_no()} 页 / 共 {self.total_pages} 页", align="R")
        else:
            self.cell(0, 6, f"第 {self.page_no()} 页", align="R")
        self.set_draw_color(*GREEN)
        self.set_line_width(0.45)
        self.line(MARGIN_L, 18, PAGE_W - MARGIN_R, 18)
        self.set_y(MARGIN_T)

    # ---------- 结构 ----------
    def h1(self, text: str) -> None:
        if self.get_y() > 90:
            self.add_page()
        self.section_pages[text] = self.page_no()
        self.set_font("SimHei", "", 17)
        self.set_text_color(*DARK_GREEN)
        self.cell(0, 10, add_text(text), new_x="LMARGIN", new_y="NEXT")
        y = self.get_y() + 1
        self.set_draw_color(*GREEN)
        self.set_line_width(0.5)
        self.line(MARGIN_L, y, PAGE_W - MARGIN_R, y)
        self.ln(5)

    def h2(self, text: str) -> None:
        if self.get_y() + 25 > self.page_break_trigger:
            self.add_page()
        self.ln(1.5)
        self.set_font("SimHei", "", 12.5)
        self.set_text_color(40, 40, 40)
        self.cell(0, 8, add_text(text), new_x="LMARGIN", new_y="NEXT")
        self.ln(1)

    def h3(self, text: str) -> None:
        if self.get_y() + 20 > self.page_break_trigger:
            self.add_page()
        self.set_font("SimHei", "", 11)
        self.set_text_color(55, 55, 55)
        self.cell(0, 7, add_text(text), new_x="LMARGIN", new_y="NEXT")
        self.ln(0.5)

    def p(self, text: str, indent: bool = True, size: float = 10.5) -> None:
        self.set_font("FangSong", "", size)
        self.set_text_color(*TEXT)
        content = ("　　" if indent else "") + text
        ALL_TEXT.append(content)
        self.multi_cell(0, LINE_H, content, new_x="LMARGIN", new_y="NEXT", wrapmode="CHAR")
        self.ln(1.2)

    def bullet(self, text: str, label: str = "•") -> None:
        if self.get_y() + 10 > self.page_break_trigger:
            self.add_page()
        self.set_font("FangSong", "", 10.5)
        self.set_text_color(*TEXT)
        y = self.get_y()
        self.set_xy(MARGIN_L + 1, y)
        self.cell(5.5, LINE_H, label, align="L")
        self.set_xy(MARGIN_L + 6.5, y)
        ALL_TEXT.append(text)
        self.multi_cell(CONTENT_W - 6.5, LINE_H, text, new_x="LMARGIN", new_y="NEXT", wrapmode="CHAR")
        self.ln(0.6)

    def numbered(self, num: str, text: str) -> None:
        if self.get_y() + 10 > self.page_break_trigger:
            self.add_page()
        self.set_font("FangSong", "", 10.5)
        self.set_text_color(*TEXT)
        y = self.get_y()
        self.set_xy(MARGIN_L + 1, y)
        self.cell(9, LINE_H, num, align="L")
        self.set_xy(MARGIN_L + 10, y)
        ALL_TEXT.append(text)
        self.multi_cell(CONTENT_W - 10, LINE_H, text, new_x="LMARGIN", new_y="NEXT", wrapmode="CHAR")
        self.ln(0.6)

    def quote(self, text: str) -> None:
        self.set_font("FangSong", "", 9.8)
        lines = self._split_text(text, CONTENT_W - 10, 9.8)
        height = 8 + len(lines) * 5.4
        if self.get_y() + height > self.page_break_trigger:
            self.add_page()
        x = MARGIN_L
        y = self.get_y()
        self.set_fill_color(*LIGHT_GREEN)
        self.rect(x, y, CONTENT_W, height, "F")
        self.set_fill_color(*GREEN)
        self.rect(x, y, 1.6, height, "F")
        self.set_xy(x + 5, y + 3)
        self.set_text_color(55, 70, 58)
        for line in lines:
            ALL_TEXT.append(line)
            self.cell(CONTENT_W - 10, 5.4, line, new_x="LMARGIN", new_y="NEXT")
        self.set_y(y + height + 3)

    def code_block(self, lines: list[str]) -> None:
        self.set_font("Consola", "", 8.4)
        line_h = 4.6
        text_lines: list[str] = []
        for raw in lines:
            text_lines.extend(self._split_text(raw, CONTENT_W - 8, 8.4, mono=True) or [""])
        height = 5 + len(text_lines) * line_h
        if self.get_y() + height > self.page_break_trigger:
            self.add_page()
        x = MARGIN_L
        y = self.get_y()
        self.set_fill_color(*LIGHT_GRAY)
        self.rect(x, y, CONTENT_W, height, "F")
        self.set_text_color(25, 60, 35)
        yy = y + 2.5
        for line in text_lines:
            ALL_TEXT.append(line)
            self.set_xy(x + 4, yy)
            self.cell(0, line_h, line, new_x="LMARGIN", new_y="TOP")
            yy += line_h
        self.set_y(y + height + 2.5)

    def _split_text(self, text: str, width: float, size: float, mono: bool = False) -> list[str]:
        self.set_font("Consola" if mono else "FangSong", "", size)
        if not text:
            return [""]
        out: list[str] = []
        rest = text
        while rest:
            lo, hi = 1, len(rest)
            best = 1
            while lo <= hi:
                mid = (lo + hi) // 2
                if self.get_string_width(rest[:mid]) <= width:
                    best = mid
                    lo = mid + 1
                else:
                    hi = mid - 1
            out.append(rest[:best])
            rest = rest[best:]
        return out

    def figure(self, rel_path: str, caption: str) -> None:
        path = ROOT / rel_path
        if not path.is_file():
            return
        with Image.open(path) as im:
            iw, ih = im.size
        width = 92.0
        height = width * ih / iw
        if height > 112.0:
            height = 112.0
            width = height * iw / ih
        if width > 110.0:
            width = 110.0
            height = width * ih / iw
        if self.get_y() + height + 14 > self.page_break_trigger:
            self.add_page()
        x = (PAGE_W - width) / 2
        y = self.get_y()
        self.image(str(path), x=x, y=y, w=width, h=height)
        self.set_draw_color(205, 215, 208)
        self.set_line_width(0.2)
        self.rect(x, y, width, height)
        self.set_y(y + height + 1.5)
        self.set_font("FangSong", "", 9)
        self.set_text_color(*GRAY)
        ALL_TEXT.append(caption)
        self.cell(0, 5, caption, align="C", new_x="LMARGIN", new_y="NEXT")
        self.ln(3)

    def table(self, rows: list[list[str]]) -> None:
        if not rows:
            return
        ncols = max(len(r) for r in rows)
        rows = [r + [""] * (ncols - len(r)) for r in rows]
        self.set_font("FangSong", "", 8.8)
        weights = []
        for c in range(ncols):
            w = max(self.get_string_width(r[c]) for r in rows)
            weights.append(max(12.0, min(70.0, w + 5.0)))
        total = sum(weights)
        widths = [w * CONTENT_W / total for w in weights]
        line_h = 4.8
        pad = 1.6

        def draw_row(cells: list[str], header: bool = False, fill: tuple | None = None) -> None:
            self.set_font("SimHei" if header else "FangSong", "", 8.8)
            cell_lines = [self._split_text(c, widths[i] - pad * 2, 8.8) for i, c in enumerate(cells)]
            h = max(len(x) for x in cell_lines) * line_h + pad * 2
            if self.get_y() + h > self.page_break_trigger:
                self.add_page()
                draw_row(rows[0], header=True, fill=GREEN)
            x = MARGIN_L
            y = self.get_y()
            for i, c in enumerate(cells):
                if fill:
                    self.set_fill_color(*fill)
                    self.rect(x, y, widths[i], h, "F")
                self.set_draw_color(*BORDER_GRAY)
                self.set_line_width(0.2)
                self.rect(x, y, widths[i], h)
                self.set_xy(x + pad, y + pad)
                if header:
                    self.set_text_color(255, 255, 255)
                else:
                    self.set_text_color(*TEXT)
                for ln in cell_lines[i]:
                    ALL_TEXT.append(ln)
                    self.cell(widths[i] - pad * 2, line_h, ln)
                    self.set_xy(x + pad, self.get_y() + line_h)
                x += widths[i]
            self.set_y(y + h)

        draw_row(rows[0], header=True, fill=GREEN)
        for idx, row in enumerate(rows[1:]):
            draw_row(row, fill=LIGHT_GRAY if idx % 2 == 1 else None)
        self.ln(3)

    def cover(self) -> None:
        self.add_page()
        self.set_y(30)
        self.set_font("SimHei", "", 14)
        self.set_text_color(*GREEN)
        self.cell(0, 8, SOFTWARE_BASE, align="C", new_x="LMARGIN", new_y="NEXT")
        self.set_font("SimHei", "", 10)
        self.set_text_color(*GRAY)
        self.cell(0, 6, VERSION, align="C", new_x="LMARGIN", new_y="NEXT")
        if ICON_PATH.exists():
            self.image(str(ICON_PATH), x=(PAGE_W - 32) / 2, y=55, w=32)
        self.set_y(105)
        self.set_font("SimHei", "", 26)
        self.set_text_color(*DARK_GREEN)
        self.cell(0, 14, DOC_TITLE, align="C", new_x="LMARGIN", new_y="NEXT")
        self.set_font("FangSong", "", 11)
        self.set_text_color(*GRAY)
        self.cell(0, 8, f"文档版本 {DOC_VERSION}", align="C", new_x="LMARGIN", new_y="NEXT")

        self.set_y(150)
        fields = [
            ("文档名称", DOC_TITLE),
            ("软件名称", SOFTWARE_BASE),
            ("版本号", VERSION),
            ("文档版本", DOC_VERSION),
            ("著作权人", AUTHOR),
            ("编制日期", DOC_DATE),
        ]
        for label, value in fields:
            self.set_x(55)
            self.set_font("SimHei", "", 10)
            self.set_text_color(*GRAY)
            self.cell(30, 9, label, align="R")
            self.set_x(88)
            self.set_font("FangSong", "", 11)
            self.set_text_color(*TEXT)
            self.cell(0, 9, value, align="L")
            self.ln(10)
        self.set_y(266)
        self.set_font("FangSong", "", 9)
        self.set_text_color(125, 125, 125)
        self.cell(0, 6, f"本说明书用于{SOFTWARE} 的软件著作权登记", align="C")

    def toc_page(self, entries: list[str], page_map: dict[str, int]) -> None:
        self.add_page()
        self.set_y(28)
        self.set_font("SimHei", "", 20)
        self.set_text_color(*DARK_GREEN)
        self.cell(0, 12, "目  录", align="C", new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(*GREEN)
        self.set_line_width(0.5)
        self.line(80, 43, 130, 43)
        y = 58
        lh = 8.4
        for name in entries:
            num = str(page_map[name])
            self.set_xy(MARGIN_L + 4, y)
            self.set_font("FangSong", "", 11.5)
            self.set_text_color(*TEXT)
            self.cell(0, lh, name, align="L")
            name_w = self.get_string_width(name)
            num_w = self.get_string_width(num)
            dot_start = MARGIN_L + 4 + name_w + 2.5
            dot_end = PAGE_W - MARGIN_R - num_w - 2.5
            if dot_end > dot_start:
                self.set_font("FangSong", "", 9)
                self.set_text_color(155, 165, 158)
                dot_w = max(self.get_string_width("."), 0.8)
                count = int((dot_end - dot_start) / dot_w)
                self.set_xy(dot_start, y)
                self.cell(dot_end - dot_start, lh, "." * count, align="L")
            self.set_xy(PAGE_W - MARGIN_R - num_w, y)
            self.set_font("FangSong", "", 10.5)
            self.set_text_color(*TEXT)
            self.cell(num_w, lh, num, align="R")
            y += lh
        self.set_y(190)
        self.set_font("FangSong", "", 10)
        self.set_text_color(*GRAY)
        self.multi_cell(0, 6, "本说明书共 13 章：第 1～9 章介绍用途、环境、安装、界面、操作、参数、视图、数据和语言；第 10 章给出计算公式；第 11～13 章介绍程序结构、异常提示和版本信息。", wrapmode="CHAR")


def load_blocks() -> list[tuple[str, object]]:
    text = DOC_PATH.read_text(encoding="utf-8")
    start = text.find("## 1 软件概述")
    if start < 0:
        raise SystemExit("找不到正文起点：## 1 软件概述")
    return parse_blocks(text[start:].splitlines())


def build_body(pdf: ManualPDF, blocks: list[tuple[str, object]]) -> None:
    started = False
    for kind, value in blocks:
        if kind == "h1":
            if not started:
                pdf.add_page()
                started = True
            pdf.h1(str(value))
        elif kind == "h2":
            pdf.h2(str(value))
        elif kind == "h3":
            pdf.h3(str(value))
        elif kind == "p":
            pdf.p(str(value))
        elif kind == "bullet":
            pdf.bullet(str(value))
        elif kind == "num":
            num, text = value  # type: ignore[misc]
            pdf.numbered(str(num), str(text))
        elif kind == "quote":
            pdf.quote(str(value))
        elif kind == "code":
            pdf.code_block(list(value))  # type: ignore[arg-type]
        elif kind == "image":
            caption, rel_path = value  # type: ignore[misc]
            pdf.figure(str(rel_path), str(caption))
        elif kind == "table":
            pdf.table(list(value))  # type: ignore[arg-type]


def check_font_coverage(texts: list[str]) -> dict:
    cmaps = []
    for path in [FONT_FANGSONG, FONT_SIMHEI, FONT_CONSOLA, FONT_SYMBOL]:
        try:
            font = TTFont(str(path), fontNumber=0, lazy=True)
            cmap = set()
            for table in font["cmap"].tables:
                cmap.update(table.cmap.keys())
            cmaps.append(cmap)
            font.close()
        except Exception:
            continue
    covered = set().union(*cmaps) if cmaps else set()
    missing: dict[str, int] = {}
    for text in texts:
        for ch in text:
            if ch in "\r\n\t":
                continue
            if ord(ch) not in covered:
                missing[ch] = missing.get(ch, 0) + 1
    return missing


def build() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    blocks = load_blocks()
    entries = [str(v) for k, v in blocks if k == "h1"]
    if len(entries) != 13:
        raise SystemExit(f"章节数不是 13：{len(entries)}")

    probe = ManualPDF(total_pages=0)
    probe.cover()
    build_body(probe, blocks)
    probe_pages = probe.page_no()
    section_pages = dict(probe.section_pages)
    for name in entries:
        if name not in section_pages:
            raise SystemExit(f"缺少章节页码：{name}")

    total_pages = probe_pages + 1
    page_map = {name: section_pages[name] + 1 for name in entries}

    pdf = ManualPDF(total_pages=total_pages)
    pdf.cover()
    pdf.toc_page(entries, page_map)
    build_body(pdf, blocks)
    if pdf.page_no() != total_pages:
        raise SystemExit(f"页数不一致：预计 {total_pages}，实际 {pdf.page_no()}")

    pdf.output(str(OUT_PDF))
    missing = check_font_coverage(ALL_TEXT)
    report = {
        "software": SOFTWARE,
        "document": DOC_TITLE,
        "document_version": DOC_VERSION,
        "pages": total_pages,
        "toc_pages": 1,
        "sections": page_map,
        "missing_glyphs": missing,
        "text_chars": sum(len(x) for x in ALL_TEXT),
        "output": str(OUT_PDF),
    }
    REPORT_JSON.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    build()
