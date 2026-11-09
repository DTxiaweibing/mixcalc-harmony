import { parseShedNumbers } from './ShedCoverage';

/**
 * 删除前的「去向判定」：这一批号里，哪些还有来路可退，哪些删了就没了。
 *
 * 删除只动本行申明。本行让出来的号如果在**上面某行**还申明着，会被打点覆盖
 * 退回到那一行继续算料（fallback）；上面没有任何行申明过它，就是彻底从表里
 * 消失，需要点名告知用户（permanent）。
 *
 * 只看本行上方的行：本行显示的号一定是本行申明里、且没被下面行占走的号，
 * 所以它不可能同时被下面的行申明着，绝不向下看。
 */

/** 只扫描本行上方（i < row 且 i < declaredTexts.length）是否申明过 target。 */
function hasSourceAbove(declaredTexts: string[], row: number, target: number): boolean {
  let limit: number = row;
  if (limit > declaredTexts.length) {
    limit = declaredTexts.length;
  }
  for (let i: number = 0; i < limit; i++) {
    const text: string = declaredTexts[i];
    if (parseShedNumbers(text).indexOf(target) >= 0) {
      return true;
    }
  }
  return false;
}

export class ShedDeletePlan {
  /** 会退回上面某行的号码（升序）。 */
  fallback: number[] = [];
  /** 没有来路、删了就真没了的号码（升序）。 */
  permanent: number[] = [];

  static of(declaredTexts: string[], row: number, targets: number[]): ShedDeletePlan {
    const plan: ShedDeletePlan = new ShedDeletePlan();
    const sorted: number[] = targets.slice().sort((a: number, b: number) => a - b);
    let previous: number = -1;
    for (let k: number = 0; k < sorted.length; k++) {
      const n: number = sorted[k];
      if (n <= 0) {
        continue;
      }
      if (n === previous) {
        continue;
      }
      previous = n;
      if (hasSourceAbove(declaredTexts, row, n)) {
        plan.fallback.push(n);
      } else {
        plan.permanent.push(n);
      }
    }
    return plan;
  }

  hasFallback(): boolean {
    return this.fallback.length > 0;
  }

  hasPermanent(): boolean {
    return this.permanent.length > 0;
  }
}
