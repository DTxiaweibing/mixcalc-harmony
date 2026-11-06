/**
 * 棚号解析 + 打点覆盖。
 *
 * 规则（与安卓版一致，后面的行优先）：
 * 1. 每行的「棚号」先展开成一个个具体的棚号，同一行里重复写的棚号只算一次；
 * 2. 把所有行按顺序铺到同一张“地皮”上，后写的行覆盖先写的行；
 * 3. 每行最终占有的棚数 = 铺完之后还写着这行的棚号个数。
 *
 * 例：第 2 行填 1-40，第 3 行填 20-30，则第 3 行占 20-30 共 11 个，
 *     第 2 行只剩 1-19、31-40 共 29 个，不会把 20-30 重复算两遍。
 */

// 棚号上限：超过就提示“输入超上限值”，超出的那段不计入棚数
export const MAX_SHED_NUMBER: number = 1000;
// 一个区间最多展开多少个棚号，上限 1000 之后其实到不了，留作最后一道防呆
const MAX_RANGE_SPAN: number = 10000;

/** 统一连接符、按分隔符切成一段一段（"1 - 40,45" -> ["1-40","45"]）。 */
function splitParts(raw: string): string[] {
  const result: string[] = [];
  if (raw === undefined || raw === null) {
    return result;
  }
  let text: string = raw.trim();
  if (text.length === 0) {
    return result;
  }
  // 中文连接符统一成横杠，横杠两边的空格先吃掉，免得 "1 - 40" 被空格拆成三段
  text = text.replace(/[到至~～—－]/g, '-');
  text = text.replace(/\s*-\s*/g, '-');
  const parts: string[] = text.split(/[,，、;；\/\s]+/);
  for (let i = 0; i < parts.length; i++) {
    const part: string = parts[i].trim();
    if (part.length > 0) {
      result.push(part);
    }
  }
  return result;
}

/** 一段里最多取两个数字：区间取首尾，单个数字就一个。 */
function numbersInPart(part: string): number[] {
  const nums: number[] = [];
  if (part.indexOf('-') >= 0) {
    const segs: string[] = part.split('-');
    for (let j = 0; j < segs.length && nums.length < 2; j++) {
      const digits: string = segs[j].replace(/[^0-9]/g, '');
      if (digits.length > 0) {
        nums.push(parseInt(digits, 10));
      }
    }
    return nums;
  }
  const digits: string = part.replace(/[^0-9]/g, '');
  if (digits.length > 0) {
    nums.push(parseInt(digits, 10));
  }
  return nums;
}

/**
 * 把一行棚号文本展开成去重、升序的棚号数组。
 * 支持："1-40"、"1到40"、"1至40"、"1~40"、"40-1"（反向自动纠正）、
 *       "1-10,15,20-30"（逗号/顿号/空格/分号分隔）、"1 - 40"（横杠两边带空格）。
 * 超过 MAX_SHED_NUMBER 的段整段忽略（由 findOverLimit 负责给提示）。
 */
export function parseShedNumbers(raw: string): number[] {
  const result: number[] = [];
  const parts: string[] = splitParts(raw);
  const seen: Set<number> = new Set<number>();

  for (let i = 0; i < parts.length; i++) {
    const nums: number[] = numbersInPart(parts[i]);
    if (nums.length === 0) {
      continue;
    }
    if (nums.length === 1) {
      const n: number = nums[0];
      if (n > 0 && n <= MAX_SHED_NUMBER) {
        seen.add(n);
      }
      continue;
    }
    let start: number = nums[0];
    let end: number = nums[1];
    if (start > end) {
      const temp: number = start;
      start = end;
      end = temp;
    }
    if (start <= 0) {
      start = 1;
    }
    if (start > MAX_SHED_NUMBER || end > MAX_SHED_NUMBER) {
      continue;
    }
    if (end - start > MAX_RANGE_SPAN) {
      continue;
    }
    for (let n = start; n <= end; n++) {
      seen.add(n);
    }
  }

  seen.forEach((n: number) => {
    result.push(n);
  });
  result.sort((a: number, b: number) => a - b);
  return result;
}

/**
 * 找出输入里第一个超过上限的棚号，没有就返回 0。
 * 只负责“报不报超限”，计数交给 parseShedNumbers（超限段不计入）。
 */
export function findOverLimit(raw: string): number {
  const parts: string[] = splitParts(raw);
  for (let i = 0; i < parts.length; i++) {
    const nums: number[] = numbersInPart(parts[i]);
    for (let j = 0; j < nums.length; j++) {
      if (nums[j] > MAX_SHED_NUMBER) {
        return nums[j];
      }
    }
  }
  return 0;
}

/**
 * 打点覆盖：按行序把棚号铺开，后面的行覆盖前面的行，返回每行实际占有的棚数。
 * 传空字符串的行不参与占位。
 */
export function ownedCounts(texts: string[]): number[] {
  const counts: number[] = [];
  for (let i = 0; i < texts.length; i++) {
    counts.push(0);
  }
  const owner: Map<number, number> = new Map<number, number>();
  for (let i = 0; i < texts.length; i++) {
    const nums: number[] = parseShedNumbers(texts[i]);
    for (let j = 0; j < nums.length; j++) {
      owner.set(nums[j], i);
    }
  }
  owner.forEach((rowIndex: number) => {
    counts[rowIndex] = counts[rowIndex] + 1;
  });
  return counts;
}

/** 所有行棚号的并集大小（去重后的总棚数），给需要“总棚数”的地方用。 */
export function unionCount(texts: string[]): number {
  const owner: Map<number, number> = new Map<number, number>();
  for (let i = 0; i < texts.length; i++) {
    const nums: number[] = parseShedNumbers(texts[i]);
    for (let j = 0; j < nums.length; j++) {
      owner.set(nums[j], i);
    }
  }
  return owner.size;
}
