/**
 * 棚号文本的增删与重排（转出 / 转入 / 删除用）——按 Java 版 ShedText 1:1 直译。
 *
 * 分隔符认 , ， 、 ; ； / 和空白；区间认 - — － ~ ～ 至 到。
 *
 * 转移（transfer）：按号码集合换主人，两边文本都按转移后的实际号码重排重写——
 *   没有任何「落在范围内就跳过」的暗规则，号码换没换主人由打点覆盖说了算；
 * 拿走号码（remove，删除/卖出用）：单号直接删；号写在连续段里就把这段拆开
 *   （1-40 去掉 5 → 1-4 6-40），否则原行还在算着这个棚，等于没删。
 */
import { parseShedNumbers } from './ShedCoverage';
import { compressNumbers } from './ShedRange';

/** 拼接用的分隔符：用户习惯用空格分开，不写「、」。 */
const JOINER: string = ' ';
/** 区间符号：出现任何一个就说明这一段是连续段。 */
const RANGE_CHARS: string = '-—－~～至到';

/** 按实际号码重排文本：升序、连着 3 个及以上收成 a-b、空格分隔；没有号码返回空串。 */
export function normalize(numbers: number[]): string {
  if (numbers.length === 0) {
    return '';
  }
  return compressNumbers(numbers);
}

/**
 * 转移一批号码：返回 [新来源文本, 新目标文本]。
 * 两边都按「转移后的实际号码」重排，不做「目标行范围内就跳过」之类的暗规则。
 */
export function transfer(sourceText: string, targetText: string, numbers: number[]): string[] {
  let source: number[] = parseShedNumbers(sourceText);
  const target: number[] = parseShedNumbers(targetText);
  for (let i: number = 0; i < numbers.length; i++) {
    const n: number = numbers[i];
    if (n <= 0) {
      continue;
    }
    source = withoutValue(source, n);
    target.push(n);
  }
  const result: string[] = [];
  result.push(compressNumbers(source));
  result.push(compressNumbers(target));
  return result;
}

/**
 * 整行的号全部转给一个空行：等于只是把整行往下挪一格，屏幕闪一下却什么都没变，
 * 这种转移直接不让做。目标行不是空的（真合并）才放行。
 */
export function pointlessWholeRowMove(targetText: string, sourceOwned: number[],
                                      numbers: number[]): boolean {
  const targetBlank: boolean = targetText.trim().length === 0;
  if (!targetBlank || sourceOwned.length === 0 || numbers.length === 0) {
    return false;
  }
  for (let i: number = 0; i < sourceOwned.length; i++) {
    if (numbers.indexOf(sourceOwned[i]) < 0) {
      return false;
    }
  }
  return true;
}

/**
 * 拿走选中的棚号：单号删掉，连续段拆开只留剩下的部分。
 * 一个都没删到时原样返回 base（连分隔符都不动）。
 */
export function remove(text: string, numbers: number[]): string {
  const base: string = text.trim();
  if (base.length === 0 || numbers.length === 0) {
    return base;
  }
  const parts: string[] = base.split(/[,，、;；\/\s]+/);
  const out: string[] = [];
  let removed: boolean = false;
  for (let i: number = 0; i < parts.length; i++) {
    const part: string = parts[i];
    if (part.length === 0) {
      continue;
    }
    const single: number = standaloneNumber(part);
    if (single !== 0) {
      // 单号：在待删集合里就跳过，否则原样搬过去
      if (numbers.indexOf(single) >= 0) {
        removed = true;
        continue;
      }
      appendPart(out, part);
      continue;
    }
    // 连续段：看这段里有没有要被拿走的号
    const own: number[] = parseShedNumbers(part);
    let touched: boolean = false;
    for (let j: number = 0; j < own.length; j++) {
      if (numbers.indexOf(own[j]) >= 0) {
        touched = true;
        break;
      }
    }
    if (!touched) {
      appendPart(out, part);
      continue;
    }
    removed = true;
    const remain: number[] = [];
    for (let j: number = 0; j < own.length; j++) {
      if (numbers.indexOf(own[j]) < 0) {
        remain.push(own[j]);
      }
    }
    if (remain.length > 0) {
      appendPart(out, compressNumbers(remain));
    }
  }
  return removed ? out.join(JOINER) : base;
}

/** 这一段是不是单号；是就返回号码（>0），连续段或空段返回 0（ArkTS 不用 null）。 */
function standaloneNumber(part: string): number {
  for (let i: number = 0; i < part.length; i++) {
    if (RANGE_CHARS.indexOf(part.charAt(i)) >= 0) {
      return 0;
    }
  }
  const nums: number[] = parseShedNumbers(part);
  return nums.length === 1 ? nums[0] : 0;
}

/** 返回去掉所有等于 value 的元素后的新数组（对应 TreeSet.remove(n)）。 */
function withoutValue(list: number[], value: number): number[] {
  const out: number[] = [];
  for (let i: number = 0; i < list.length; i++) {
    if (list[i] !== value) {
      out.push(list[i]);
    }
  }
  return out;
}

/** 往片段列表里追加一段（跳过空段），片段之间最终用空格连接。 */
function appendPart(parts: string[], part: string): void {
  if (part.length === 0) {
    return;
  }
  parts.push(part);
}
