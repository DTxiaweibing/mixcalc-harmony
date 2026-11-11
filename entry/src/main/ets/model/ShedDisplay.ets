/**
 * 棚号输入框「两行极简显示」算法（展示态专用）——逐行直译 ShedDisplay.java。
 *
 * 口径：数字、短横杠、各项之间的半角空格、省略号 … 各算 1 个字符；
 * 省略号可紧贴数字，起「分隔 + 折叠提示」双重作用。
 *
 * 铁律：
 * 1. Range 绝对完整：绝不把任何连续区间（如 3-15）从中间切断；
 * 2. 单行硬上限：每行 ≤ 9 字符，最多 2 行，任何情况不得爆行；
 * 3. 省略号语义：仅当真发生截断时才出现，无信息丢失时绝不出现；
 * 4. 信息密度优先：必须截断时优先让首、尾两个关键 Range 都露出。
 *
 * 执行分支（命中即返回）：A-1 单行全显示 → A-2 两行全显示 →
 * B-1 散点截断（无 Range 时）→ B-2 双 Range 紧凑折叠截断。
 *
 * 编辑态不走这里：点进格子时编辑浮层加载的仍是完整原始字符串。
 */

// 规则标称的单行硬上限（字符）：两端一致，最多 2 行、绝不爆行。
const RULE_MAX: number = 9;

// ===== 棚号列「按列宽算预算」=====
// 只作用于棚号列（col 1），其它列的字号与文本规则完全不受影响。
// 单元格左右边框各 0.5vp，合计 1vp；Text 自身没有 padding，计算时不再额外留内边距。
export const SHED_BORDER_VP: number = 1;
// 15vp 粗体半角字符（数字 / 短横 / 空格 / 省略号按 1 字符口径）的实测平均占宽。
// 来源：1008px 真机截图量得 '7-15' 四字符 = 94px，按 2.85px/vp 换算 = 33vp → 8.25vp/字符。
export const SHED_CHAR_VP_AT_15: number = 8.25;
export const SHED_FONT_PRIMARY: number = 15;
export const SHED_FONT_FALLBACK: number = 14;

/** 单元格实际可用宽度：列宽扣掉左右边框，不留内边距。 */
export function shedAvailableWidth(columnWidthVp: number): number {
  const w: number = columnWidthVp - SHED_BORDER_VP;
  return w > 0 ? w : 1;
}

/** 指定字号下每行能放几个字符；上限 clamp 到规则标称的 9，只往下调不往上调。 */
export function shedMaxCharsAt(columnWidthVp: number, fontSizeVp: number): number {
  const perChar: number = SHED_CHAR_VP_AT_15 * fontSizeVp / SHED_FONT_PRIMARY;
  const n: number = Math.floor(shedAvailableWidth(columnWidthVp) / perChar);
  if (n < 1) {
    return 1;
  }
  return n > RULE_MAX ? RULE_MAX : n;
}

/** 15vp 装得下标称 9 字符就保持 15vp，否则整列降到 14vp（避免同列各行字号跳动）。 */
export function shedFontSizeVp(columnWidthVp: number): number {
  return shedMaxCharsAt(columnWidthVp, SHED_FONT_PRIMARY) >= RULE_MAX
    ? SHED_FONT_PRIMARY : SHED_FONT_FALLBACK;
}

/** 该列宽下最终采用的每行字符预算。 */
export function shedMaxChars(columnWidthVp: number): number {
  return shedMaxCharsAt(columnWidthVp, shedFontSizeVp(columnWidthVp));
}

/** 按实际列宽折叠（棚号列专用入口）。 */
export function renderForColumn(rawText: string, columnWidthVp: number): string[] {
  return renderWithBudget(rawText, shedMaxChars(columnWidthVp));
}

/** 兼容入口：标称 9 字符预算，模型层回归测试与旧调用方都走这里。 */
export function render(rawText: string): string[] {
  return renderWithBudget(rawText, RULE_MAX);
}

function renderWithBudget(rawText: string, charBudget: number): string[] {
  // 函数体内所有 MAX 引用都指向这个按列宽算出的预算，不再硬编码 9；
  // 下限 3 是为了避免极窄列让省略号预留位算出负数。
  const MAX: number = Math.max(3, Math.floor(charBudget));
  const lines: string[] = [];
  // Java 的空引用判断用「非字符串」一并挡掉，此处全程不引入空值字面量
  if (typeof rawText !== 'string' || rawText.trim().length === 0) {
    return lines;
  }
  const items: string[] = preprocess(rawText);
  if (items.length === 0) {
    // 完全解析不出号码（比如只有乱码）：原文单行兜底，别画空白
    lines.push(rawText.trim());
    return lines;
  }

  const n: number = items.length;
  const total: number = disp(items);

  // A-1 单行全显示
  if (total <= MAX) {
    lines.push(join(items));
    return lines;
  }

  // A-2 两行全显示（无省略号）
  for (let k = 1; k < n; k++) {
    if (disp(items.slice(0, k)) <= MAX && disp(items.slice(k, n)) <= MAX) {
      lines.push(join(items.slice(0, k)));
      lines.push(join(items.slice(k, n)));
      return lines;
    }
  }

  // 找出所有 Range 的下标
  const ridx: number[] = [];
  for (let i = 0; i < n; i++) {
    if (items[i].indexOf('-') >= 0) {
      ridx.push(i);
    }
  }

  // B-1 散点截断：第一行从头贪心，第二行从尾部倒推、头部加 "… "
  if (ridx.length === 0) {
    let firstItems: string[] = [];
    for (let i = 0; i < n; i++) {
      const x: string = items[i];
      const next: string[] = firstItems.slice();
      next.push(x);
      if (disp(next) <= MAX) {
        firstItems = next;
      } else {
        break;
      }
    }
    let lastItems: string[] = [];
    for (let i = n - 1; i >= 0; i--) {
      const x: string = items[i];
      const next: string[] = [];
      next.push(x);
      for (let j = 0; j < lastItems.length; j++) {
        next.push(lastItems[j]);
      }
      if (disp(next) <= MAX - 2) { // 预留 "… " 头部 2 字符
        lastItems = next;
      } else {
        break;
      }
    }
    lines.push(join(firstItems));
    lines.push('… ' + join(lastItems));
    return lines;
  }

  // B-2 双 Range 紧凑折叠截断：
  // 第一行 = 首个 Range 前的散号（贪心）+ … + 首个 Range；
  // 第二行 = … + 尾部 Range，尾部 Range 之后还有被折叠项则再补一个 …
  const firstR: number = ridx[0];
  const lastR: number = ridx[ridx.length - 1];

  // 只有一个区间：区间只许露一次（0.3.17 修复）。原来首行放它、尾行又放它，
  // 用户看到 9-15 出现两遍，像是号码重复了。
  if (firstR === lastR) {
    const mid: string = items[firstR];
    if (firstR === 0) {
      // 区间就在最前：行1 让它带头，行2 接后面的散号
      lines.push(n > 1 ? mid + '…' : mid);
      if (n > 1) {
        lines.push(ellipsizedTail(items, 1, n, '', MAX));
      }
      return lines;
    }
    // 行1 = 区间前的散号（贪心）+ …；行2 = … + 区间 + 区间后的散号（贪心）
    let beforeItems: string[] = [];
    for (let i = 0; i < firstR; i++) {
      const x: string = items[i];
      const next: string[] = beforeItems.slice();
      next.push(x);
      if (disp(next) + 1 <= MAX) { // 末尾还要放一个省略号
        beforeItems = next;
      } else {
        break;
      }
    }
    lines.push(join(beforeItems) + '…');
    lines.push(ellipsizedTail(items, firstR + 1, n, mid, MAX));
    return lines;
  }

  const head: string = items[firstR];
  const budget: number = MAX - 1 - head.length; // 预留 1 字符连接省略号
  const front: string[] = [];
  for (let i = 0; i < firstR; i++) {
    const x: string = items[i];
    const need: number = x.length + (front.length === 0 ? 0 : 1);
    if (disp(front) + need <= budget) {
      front.push(x);
    } else {
      break;
    }
  }
  const firstLine: string = front.length === 0 ? head : join(front) + '…' + head;

  const tailRange: string = items[lastR];
  const secondLine: string = '…' + tailRange + (lastR < n - 1 ? '…' : '');
  lines.push(firstLine);
  lines.push(secondLine);
  return lines;
}

/** 解析 → 去重 → 合并相邻/连续区间 → 排序的显示串列表。 */
function preprocess(rawText: string): string[] {
  const intervals: number[][] = [];
  const tokens: string[] = tokenize(rawText);
  for (let i = 0; i < tokens.length; i++) {
    const token: string = tokens[i];
    const dash: number = token.indexOf('-');
    let a: number = 0;
    let b: number = 0;
    if (dash >= 0) {
      a = parseJavaInt(token.substring(0, dash));
      b = parseJavaInt(token.substring(dash + 1));
    } else {
      a = parseJavaInt(token);
      b = a;
    }
    if (isNaN(a) || isNaN(b)) {
      // 解析不了的片段直接跳过（展示态容错，等价于 Java 的 NumberFormatException）
      continue;
    }
    if (a > b) {
      const t: number = a;
      a = b;
      b = t;
    }
    if (a > 0) {
      const pair: number[] = [a, b];
      intervals.push(pair);
    }
  }
  intervals.sort((p: number[], q: number[]): number =>
    (p[0] !== q[0] ? p[0] - q[0] : p[1] - q[1]));

  const merged: number[][] = [];
  for (let i = 0; i < intervals.length; i++) {
    const iv: number[] = intervals[i];
    if (merged.length > 0 && iv[0] <= merged[merged.length - 1][1] + 1) {
      const last: number[] = merged[merged.length - 1];
      last[1] = Math.max(last[1], iv[1]);
    } else {
      const copy: number[] = [iv[0], iv[1]];
      merged.push(copy);
    }
  }

  const items: string[] = [];
  for (let i = 0; i < merged.length; i++) {
    const iv: number[] = merged[i];
    items.push(iv[0] === iv[1] ? String(iv[0]) : iv[0] + '-' + iv[1]);
  }
  return items;
}

/**
 * 桥接 java.lang.Integer.parseInt：整串必须是十进制整数，否则视为解析失败。
 * JS 的 parseInt 会吃掉尾部垃圾且不抛异常，这里用整串正则把 Java 的
 * NumberFormatException 语义补回来；失败返回 NaN。
 */
function parseJavaInt(s: string): number {
  if (!/^[+-]?\d+$/.test(s)) {
    return NaN;
  }
  return parseInt(s, 10);
}

/** 与 ShedCoverage 一致的分隔符口径：空格、顿号、逗号、分号、斜杠，以及 到/至/~ 等区间写法。 */
function tokenize(rawText: string): string[] {
  let text: string = rawText.trim();
  text = text.replace(/[到至~～—－]/g, '-');
  text = text.replace(/\s*-\s*/g, '-');
  const parts: string[] = text.split(/[,，、;；\/\s]+/);
  const tokens: string[] = [];
  for (let i = 0; i < parts.length; i++) {
    const t: string = parts[i].trim();
    if (t.length > 0) {
      tokens.push(t);
    }
  }
  return tokens;
}

/**
 * 折叠行的后半段：可选的「头一个项」（通常是区间），再从 from 到 to-1 贪心塞散号；
 * 没塞完就在末尾补一个 …。整体不超过单行上限。
 */
function ellipsizedTail(items: string[], from: number, to: number, head: string, maxChars: number): string {
  let sb: string = '…';
  if (head.length > 0) {
    sb += head;
  }
  let clipped: boolean = false;
  for (let i = from; i < to; i++) {
    // 省略号紧贴第一个项（没有 head 时不加空格），与 B-2 的 "…25-32" 风格一致
    const sep: string = sb.length > 1 ? ' ' : '';
    const candidate: string = sb + sep + items[i];
    if (candidate.length + 1 <= maxChars) { // 预留末尾省略号的 1 字符
      sb += sep + items[i];
    } else {
      clipped = true;
      break;
    }
  }
  if (clipped) {
    sb += '…';
  }
  return sb;
}

/** 一行（用半角空格拼接）的字符长度。 */
function disp(items: string[]): number {
  if (items.length === 0) {
    return 0;
  }
  let len: number = items.length - 1;
  for (let i = 0; i < items.length; i++) {
    len += items[i].length;
  }
  return len;
}

/** 用半角空格拼接各项。 */
function join(items: string[]): string {
  let sb: string = '';
  for (let i = 0; i < items.length; i++) {
    if (i > 0) {
      sb += ' ';
    }
    sb += items[i];
  }
  return sb;
}
