import { ownedSets, renormalize } from './ShedCoverage';

/** 一次推导的结果：每行应显示的文本 + 每行实际棚数（下标与快照一一对应）。 */
export class ShedDraftResult {
  texts: string[] = [];
  counts: number[] = [];

  constructor(texts: string[], counts: number[]) {
    this.texts = texts;
    this.counts = counts;
  }
}

/**
 * 边打字边全表重算：每敲一个字符都拿「快照 + 当前输入」重新推一遍，
 * 而不是在上一次结果上继续改，半成品区间（如 16-4）只影响当前这一帧。
 */
export function recompute(snapshot: string[], editingRow: number,
                          typedText: string): ShedDraftResult {
  // 必须深拷贝字符串数组，不能直接持有 snapshot 引用（编辑中会原地改写）
  const base: string[] = snapshot.slice();
  const editing: boolean = editingRow >= 0 && editingRow < base.length;
  if (editing) {
    base[editingRow] = typedText;
  }

  const sets: number[][] = ownedSets(base);
  const texts: string[] = renormalize(base);
  // 编辑中的那行始终显示用户原样输入，不在敲字时改他正在敲的字
  if (editing) {
    texts[editingRow] = typedText;
  }

  const counts: number[] = [];
  for (let i = 0; i < sets.length; i++) {
    counts.push(sets[i].length);
  }
  return new ShedDraftResult(texts, counts);
}
