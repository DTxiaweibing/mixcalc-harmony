// 转出 / 转入之后「来路」还在不在：号码能不能退回原来的行。
//
// 结论：退回不靠任何快照，全靠「还有哪一行在申明这个号」——打点覆盖每次现算。
// 所以只要不把来源行的声明重写成「只留实际占有的号」，来路就一直在账上。
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);
const outDir = process.env.MODEL_TEST_OUT_DIR;
const load = (name) => require(path.join(outDir, `${name}.js`));

const range = (from, to) => {
  const out = [];
  for (let n = from; n <= to; n++) {
    out.push(n);
  }
  return out;
};

export default function run(t) {
  const { ownedSets, parseShedNumbers } = load('ShedCoverage');
  const { transfer, giveDown, remove, normalize } = load('ShedText');
  const { ShedDeletePlan } = load('ShedDeletePlan');

  const owned = (texts) => ownedSets(texts).map((s) => normalize(s));

  // ---------- 往下转：来源行原文原样留着，来路不丢 ----------
  const down = giveDown('1-40', '1-15', range(20, 24));
  t.equal(down, ['1-40', '1-15 20-24'], '往下转：来源行声明一个字不改（1-40 原样留着）');
  t.equal(owned(down), ['16-19 25-40', '1-15 20-24'], '往下转：号归下行，上行显示自动让出');

  // 目标行整格清空 → 号全部退回来源行
  t.equal(owned([down[0], '']), ['1-40', ''], '清空目标行：1-15 与 20-24 全部退回来源行');

  // 目标行只删掉 1-15 → 1-15 退回来源行；20-24 是没来路的真删
  const afterPartial = remove(down[1], range(1, 15));
  t.equal(afterPartial, '20-24', '删除 1-15 后目标行只剩 20-24');
  t.equal(owned([down[0], afterPartial]), ['1-19 25-40', '20-24'],
    '删 1-15：退回来源行继续算料（20-24 仍在目标行）');

  // ---------- 删除确认框也按「来路」判，不按快照 ----------
  const planFallback = ShedDeletePlan.of([down[0], down[1]], 1, range(1, 15));
  t.equal(planFallback.fallback, range(1, 15), '删除 1-15：判定为「会退回上面」，不是真删');
  t.equal(planFallback.permanent, [], '删除 1-15：真删名单为空');

  const planMixed = ShedDeletePlan.of([down[0], down[1]], 1, range(20, 24));
  t.equal(planMixed.fallback, range(20, 24), '删除 20-24：来源行还申明着 1-40，判定为退回来源行');
  t.equal(planMixed.permanent, [], '删除 20-24：真删名单为空——转下来的号依然有来路');

  // 真删只发生在「上面没有任何行申明过」的号上（用户自己新填的号）
  const planNew = ShedDeletePlan.of(['1-40', '1-15 50'], 1, [50]);
  t.equal(planNew.permanent, [50], '删除 50：上面没人申明过，判定为真删');
  t.equal(planNew.fallback, [], '删除 50：退回名单为空');

  // ---------- 往上转：来源行必须真的松手 ----------
  const up = transfer('1-15 20-24', '28-40', range(1, 5));
  t.equal(up, ['6-15 20-24', '1-5 28-40'], '往上转：来源行真的让出 1-5，目标行并入');
  t.equal(owned(up), ['6-15 20-24', '1-5 28-40'], '往上转：号确实归了上方行');

  // ---------- 反面：重写成「只留实际占有的号」就等于销毁来路 ----------
  const rewritten = owned(down);
  t.equal(owned([rewritten[0], '']), ['16-19 25-40', ''],
    '反面：来源行重写成 owned 后，清空目标行时 1-15 彻底消失（这就是不能重写的原因）');

  // ---------- 声明文本里的号就是这行认领的号，不做区间内跳过 ----------
  t.equal(parseShedNumbers('1-40').length, 40, '声明 1-40 解析出 40 个号');
  t.equal(normalize(parseShedNumbers('1-40')), '1-40', '1-40 规范化后仍是 1-40');
}
