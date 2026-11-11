#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
棚号列「7 字符规则 + 列宽/字号」像素可行性测算（只读，纯计算，不改应用代码）。

数据来源（均为真机截图像素扫描，见 PLAN-0.3.6-执行记录 任务 27/28）：
  - 1008x2232 截图 @15vp：'7-15' 四字符 = 33vp  -> 8.25vp/字符（A 方案现行口径）
  - 1084x2412 截图 @14vp：'1-3'   = 17.33vp
                          '21-30' = 31.33vp
                          '…' 单侧 = 11.33vp
                          '…21-30…' 整行 = 57.33vp
  由 '1-3'(2d+h=17.33) 与 '21-30'(4d+h=31.33) 解得：数字 d=7.0、连字符 h=3.33。
  空格按半角估 3.5vp；省略号与相邻文本之间各有 1.67vp 间隙
  （由 57.33 - (11.33+31.33+11.33) = 3.33 反推，两处各 1.67vp）。
  字号按线性缩放（字体渲染基本性质）：宽度 * fs/14。

用法：python scripts/check-shed-font-fit.py [列宽1 列宽2 ...]
例：  python scripts/check-shed-font-fit.py 56 58 60 62 63 64 68 72
"""

import sys

DIGIT14 = 7.0        # 数字
DASH14 = 3.33        # 连字符 '-'
SPACE14 = 3.5        # 半角空格
ELLIPSIS14 = 11.33   # 省略号 '…'（U+2026，横排三点）
GAP14 = 1.67         # 省略号与相邻文本之间的间隙（每处）
BORDER_VP = 1.0      # 单元格左右边框各 0.5vp，Text 无 padding
BASE_FS = 14.0       # 字形表实测时的字号

# A 方案现行口径：15vp 粗体半角字符平均 8.25vp（ShedDisplay.ets 里的常量）
A_SCHEME_CHAR_VP_AT_15 = 8.25
A_SCHEME_RULE_MAX = 9

# 用户贴的 Java 工具类 ShedNumberFormatter 的真实输出（javac 21 实跑，探针结果）。
# 注意：sample 的实际第二行是 …32 34…，并非其注释里写的 …21-30…。
JAVA_LINES = [
    ("sample 第1行",        "1-3 5"),
    ("sample 第2行",        "\u202632 34\u2026"),
    ("single-range",       "21-35"),
    ("exact7",             "1 3 5 7"),
    ("two-lines-full 2",   "\u202611 13\u2026"),
    ("16-scattered 2",     "\u202629 31\u2026"),
    ("3-ranges 2",         "\u202641-55\u2026"),
    ("many-ranges 2",      "\u202661-63\u2026"),
    ("91-99",              "91-99"),
    ("项目算法最坏行",       "\u202621-30\u2026"),
]


def line_width_vp(s: str, fs: float) -> float:
    """按实测字形表算一行文本在指定字号下的像素宽度（vp）。"""
    total = 0.0
    prev = ""
    for ch in s:
        if ch == "\u2026":
            total += ELLIPSIS14
            if prev and prev not in (" ", "\u2026"):
                total += GAP14
        elif ch == "-":
            total += DASH14
        elif ch == " ":
            total += SPACE14
        elif ch.isdigit():
            total += DIGIT14
            if prev == "\u2026":
                total += GAP14
        else:
            total += DIGIT14
        prev = ch
    return total * fs / BASE_FS


def a_scheme_font(column_width_vp: float) -> int:
    """现行 A 方案 shedFontSizeVp()：15vp 能否装下标称 9 字符。"""
    avail = max(1.0, column_width_vp - BORDER_VP)
    return 15 if int(avail // A_SCHEME_CHAR_VP_AT_15) >= A_SCHEME_RULE_MAX else 14


def a_scheme_budget(column_width_vp: float) -> int:
    fs = a_scheme_font(column_width_vp)
    avail = max(1.0, column_width_vp - BORDER_VP)
    per = A_SCHEME_CHAR_VP_AT_15 * fs / 15.0
    return min(A_SCHEME_RULE_MAX, max(1, int(avail // per)))


WIDTHS = "14vp(现行) 15vp(想用)".split()


def main() -> None:
    cols = [int(x) for x in sys.argv[1:]] or [56, 58, 60, 62, 63, 64, 68, 72]

    print("=" * 84)
    print("字形表校准（@14vp 真机实测）")
    for s, expect in [("1-3", 17.33), ("21-30", 31.33), ("\u202621-30\u2026", 57.33)]:
        got = line_width_vp(s, 14)
        print(f"  {s!r:20s} 模型 {got:6.2f}vp   实测 {expect:6.2f}vp   差 {got-expect:+.2f}vp")

    print()
    print("=" * 84)
    print("Java 7 字符规则各输出行的实际像素宽度")
    print(f"  {'行':<22s} {'字符数':>6s} {'@14vp':>9s} {'@15vp':>9s}  60vp可用59vp时")
    worst15 = 0.0
    worst15_name = ""
    for name, s in JAVA_LINES:
        w14 = line_width_vp(s, 14)
        w15 = line_width_vp(s, 15)
        if w15 > worst15:
            worst15, worst15_name = w15, name
        flag = "放不下 ✗" if w15 > 59 else "放得下 ✓"
        print(f"  {name:<22s} {len(s):>6d} {w14:>8.2f}vp {w15:>8.2f}vp  {flag}")
    print(f"\n  最宽行：{worst15_name!r} = {worst15:.2f}vp @15vp")
    print(f"  纯 7 个普通字符行 '1 3 5 7' = {line_width_vp('1 3 5 7', 15):.2f}vp @15vp")
    print("  -> 溢出只发生在含省略号的行：'…' 实测 11.33vp ≈ 1.6 个数字，字符口径却只算 1。")

    print()
    print("=" * 84)
    print("各列宽档能否容纳最坏行（可用宽 = 列宽 - 1vp 边框）")
    print(f"  {'列宽':>5s} {'可用':>6s} {'14vp余量':>10s} {'15vp余量':>10s} "
          f"{'15vp结论':>12s} {'A方案自动字号':>13s} {'A方案预算':>9s}")
    for c in cols:
        avail = c - BORDER_VP
        r14 = avail - line_width_vp("\u202621-30\u2026", 14)
        r15 = avail - worst15
        verdict = "裁字 ✗" if r15 < 0 else ("临界 ⚠" if r15 < 2 else "可放下 ✓")
        print(f"  {c:>4d}vp {avail:>5.0f}vp {r14:>+9.2f}vp {r15:>+9.2f}vp "
              f"{verdict:>12s} {a_scheme_font(c):>11d}vp {a_scheme_budget(c):>8d}字符")

    print()
    print("=" * 84)
    print("结论")
    need = worst15 + BORDER_VP
    print(f"  · 最坏行 @15vp = {worst15:.2f}vp，加 1vp 边框 -> 至少需列宽 {need:.2f}vp")
    print(f"  · 60vp 列可用 59vp，超出 {worst15-59:.2f}vp：15vp 放不下，会被 Clip 裁字。")
    print(f"  · 60vp 以下（56/58vp）差得更多；15vp 想有余量需 64vp 以上。")
    print(f"  · 14vp 在 60vp 下余 {59-line_width_vp(chr(0x2026)+'21-30'+chr(0x2026), 14):.2f}vp（偏薄），64vp 余 5.67vp 最稳。")
    print(f"  · 现行 A 方案 shedFontSizeVp() 在 <76vp 时一律降到 14vp，")
    print(f"    想强制 15vp 必须同时改判据；但改了也仍需把列宽放到 >= {need:.0f}vp。")


if __name__ == "__main__":
    main()
