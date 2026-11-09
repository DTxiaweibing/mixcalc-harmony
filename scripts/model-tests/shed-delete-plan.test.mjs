/**
 * ShedDeletePlan 模型测试：直译 ShedDeletePlanTest.java 全量 6 组，
 * 并覆盖计划里 6 条期望（含去重升序、跳过 <=0、只看上方行）。
 */
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);

/** 加载编译后的模型产物（由 run-model-tests.mjs 设置 MODEL_TEST_OUT_DIR）。 */
function loadModel(name) {
  const outDir = process.env.MODEL_TEST_OUT_DIR;
  if (!outDir) {
    throw new Error('MODEL_TEST_OUT_DIR 未设置，请用 node scripts/run-model-tests.mjs 运行');
  }
  return require(path.join(outDir, `${name}.js`));
}

export default function run(t) {
  const { ShedDeletePlan } = loadModel('ShedDeletePlan');

  // 组1：第 1 行申明 "1-15"，上方 "1-40" 全部有来路 → 全退回，permanent 空
  {
    const plan = ShedDeletePlan.of(['1-40', '1-15'], 1, [1, 2, 3, 15]);
    t.equal(plan.fallback, [1, 2, 3, 15], '组1: fallback 全中 [1,2,3,15]');
    t.equal(plan.permanent, [], '组1: permanent 空');
    t.equal(plan.hasFallback(), true, '组1: hasFallback() === true');
    t.equal(plan.hasPermanent(), false, '组1: hasPermanent() === false');
  }

  // 组2：顶行 row=0 没有上方行 → 全部 permanent
  {
    const plan = ShedDeletePlan.of(['1-40', '1-15'], 0, [5, 6]);
    t.equal(plan.fallback, [], '组2: fallback 空');
    t.equal(plan.permanent, [5, 6], '组2: permanent [5,6]');
    t.equal(plan.hasFallback(), false, '组2: hasFallback() === false');
    t.equal(plan.hasPermanent(), true, '组2: hasPermanent() === true');
  }

  // 组3：5 在上方 "1-20" 里（有来路），30 上方没人填过（真删）
  {
    const plan = ShedDeletePlan.of(['1-20', '1-9 30'], 1, [30, 5]);
    t.equal(plan.fallback, [5], '组3: fallback [5]');
    t.equal(plan.permanent, [30], '组3: permanent [30]');
    t.equal(plan.hasFallback(), true, '组3: hasFallback() === true');
    t.equal(plan.hasPermanent(), true, '组3: hasPermanent() === true');
  }

  // 组4：来路判定看区间展开，不是字符串包含（25 落在 "20-30" 内）
  {
    const plan = ShedDeletePlan.of(['1-40', '20-30'], 1, [25]);
    t.equal(plan.fallback, [25], '组4: fallback [25]（区间展开）');
    t.equal(plan.permanent, [], '组4: permanent 空');
  }

  // 组5：只在下方行（第 3 行 "5"）出现的号不算来路，只看上方
  {
    const plan = ShedDeletePlan.of(['', '', '5'], 1, [5]);
    t.equal(plan.fallback, [], '组5: fallback 空（绝不看下方行）');
    t.equal(plan.permanent, [5], '组5: permanent [5]');
    t.equal(plan.hasPermanent(), true, '组5: hasPermanent() === true');
  }

  // 组6：空输入安全 + 去重升序 + 跳过 <=0
  {
    const emptyTargets = ShedDeletePlan.of(['', ''], 1, []);
    t.equal(emptyTargets.fallback, [], '组6: 空 targets → fallback 空');
    t.equal(emptyTargets.permanent, [], '组6: 空 targets → permanent 空');

    const emptyDeclared = ShedDeletePlan.of([], 0, []);
    t.equal(emptyDeclared.fallback, [], '组6: 空 declared → fallback 空');
    t.equal(emptyDeclared.permanent, [], '组6: 空 declared → permanent 空');

    const dedup = ShedDeletePlan.of(['1-40'], 1, [3, 3, -1, 0, 5]);
    t.equal(dedup.fallback, [3, 5], '组6: 去重升序、跳过 <=0 → fallback [3,5]');
    t.equal(dedup.permanent, [], '组6: 去重后 permanent 空');
  }
}
