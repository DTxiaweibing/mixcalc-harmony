/**
 * 连号压缩：把一串棚号压成「升序、去重、连号 ≥3 写 a-b、空格分隔」的文本。
 *
 * 单独成叶子模块：ShedText.normalize 与 ShedCoverage.renormalize 都要用同一套压缩，
 * 而安卓版 ShedCoverage 与 ShedText 互相 import，ArkTS 循环依赖有风险，故把压缩算法
 * 放到这个谁都不依赖的叶子模块里。
 */

/** 拼接用的分隔符：用户习惯用空格分开，不写「、」。 */
const JOINER: string = ' ';
/** 连号收成区间的阈值：连着 3 个及以上才写成 a-b。 */
const RANGE_MIN_SPAN: number = 3;

/**
 * 把号码数组压成文本：先升序去重，连续 ≥3 个写 a-b，否则逐个列出，片段间用半角空格连接。
 * 不修改传入数组；空数组返回空串。
 */
export function compressNumbers(numbers: number[]): string {
  const copy: number[] = numbers.slice();
  copy.sort((a: number, b: number) => a - b);
  const sorted: number[] = [];
  for (let k: number = 0; k < copy.length; k++) {
    if (sorted.length === 0 || sorted[sorted.length - 1] !== copy[k]) {
      sorted.push(copy[k]);
    }
  }

  const parts: string[] = [];
  let i: number = 0;
  while (i < sorted.length) {
    const start: number = sorted[i];
    let end: number = start;
    while (i + 1 < sorted.length && sorted[i + 1] === end + 1) {
      i++;
      end = sorted[i];
    }
    if (end - start + 1 >= RANGE_MIN_SPAN) {
      parts.push(start.toString() + '-' + end.toString());
    } else {
      for (let n: number = start; n <= end; n++) {
        parts.push(n.toString());
      }
    }
    i++;
  }
  return parts.join(JOINER);
}
