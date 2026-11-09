/**
 * FeedData 模型测试（任务 6：派生显示与直写棚数）。
 *
 * 跑车用法见 scripts/run-model-tests.mjs；本文件默认导出 run(t)，
 * 通过 loadModel('FeedData') 取编译产物里的 FeedData 类做断言。
 */
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);

/** 加载编译后的模型产物（由 run-model-tests.mjs 设置 MODEL_TEST_OUT_DIR）。 */
export function loadModel(name) {
  const outDir = process.env.MODEL_TEST_OUT_DIR;
  if (!outDir) {
    throw new Error('MODEL_TEST_OUT_DIR 未设置，请用 node scripts/run-model-tests.mjs 运行');
  }
  return require(path.join(outDir, `${name}.js`));
}

export default function run(t) {
  const FeedData = loadModel('FeedData').FeedData;

  // 冒烟：确认跑车把编译产物加载进来这条路是通的
  t.equal(1 + 1, 2, 'smoke: 1 + 1 === 2');

  // 1) setShedNumber 既算本行棚数，又清空派生显示、回落到声明原文
  const display = new FeedData();
  display.setShedNumber('1-40');
  t.equal(display.shedCount, 40, 'setShedNumber("1-40") → shedCount 40');
  t.equal(display.getShedDisplay(), '1-40', 'shedDisplay 为空 → getShedDisplay 回落 "1-40"');
  display.setShedDisplay('16-40');
  t.equal(display.getShedDisplay(), '16-40', 'setShedDisplay("16-40") → getShedDisplay "16-40"');
  display.setShedNumber('1-40 50');
  t.equal(display.shedDisplay, '', '再次 setShedNumber → shedDisplay 清空');
  t.equal(display.getShedDisplay(), '1-40 50', '显示态失效 → 回落新声明 "1-40 50"');
  t.equal(display.shedCount, 41, 'calculateShedCount 仍执行 → "1-40 50" 计 41');

  // 2) shedDisplay 不落盘；fromJson 载入后显示态失效（R4）
  display.setShedDisplay('16-40');
  t.equal('shedDisplay' in display.toJson(), false, 'toJson 不含 shedDisplay');
  const restored = new FeedData();
  restored.setShedDisplay('9-9');
  restored.fromJson(display.toJson());
  t.equal(restored.getShedDisplay(), '1-40 50', 'fromJson 后 shedDisplay 失效 → 回落 shedNumber (R4)');
  t.equal(restored.shedNumber, '1-40 50', 'fromJson 恢复 shedNumber');

  // 3) setShedCountDirectly 只写棚数，不重算平均/料量
  const direct = new FeedData();
  direct.setShedNumber('1-40');
  direct.feed05 = 100;
  direct.average = 2.5;
  direct.water = 20;
  direct.weighed = 3;
  direct.setShedCountDirectly(0);
  t.equal(direct.shedCount, 0, 'setShedCountDirectly(0) → shedCount 0');
  t.equal(direct.feed05, 100, 'setShedCountDirectly 不改 feed05');
  t.equal(direct.average, 2.5, 'setShedCountDirectly 不改 average');
  t.equal(direct.water, 20, 'setShedCountDirectly 不改 water');
  t.equal(direct.weighed, 3, 'setShedCountDirectly 不改 weighed');

  // 4) clearDerived 清各派生字段，保留 shedNumber 与 shedDisplay
  const cleared = new FeedData();
  cleared.setShedNumber('1-40');
  cleared.setShedDisplay('16-40');
  cleared.average = 1;
  cleared.fermented = 2;
  cleared.powder = 3;
  cleared.feed03 = 4;
  cleared.feed05 = 5;
  cleared.feed10 = 6;
  cleared.water = 7;
  cleared.weighed = 8;
  cleared.switchRatio = 0.5;
  cleared.isAverageManuallyModified = true;
  cleared.clearDerived();
  t.equal(cleared.average, 0, 'clearDerived: average 清 0');
  t.equal(cleared.fermented, 0, 'clearDerived: fermented 清 0');
  t.equal(cleared.powder, 0, 'clearDerived: powder 清 0');
  t.equal(cleared.feed03, 0, 'clearDerived: feed03 清 0');
  t.equal(cleared.feed05, 0, 'clearDerived: feed05 清 0');
  t.equal(cleared.feed10, 0, 'clearDerived: feed10 清 0');
  t.equal(cleared.water, 0, 'clearDerived: water 清 0');
  t.equal(cleared.weighed, 0, 'clearDerived: weighed 清 0');
  t.equal(cleared.switchRatio, 0, 'clearDerived: switchRatio 清 0');
  t.equal(cleared.isAverageManuallyModified, false, 'clearDerived: isAverageManuallyModified=false');
  t.equal(cleared.shedNumber, '1-40', 'clearDerived: 保留 shedNumber');
  t.equal(cleared.getShedDisplay(), '16-40', 'clearDerived: 保留 shedDisplay');

  // 5) hasRowData：全零行 false；任一派生字段非零或手动标记为 true 则 true
  const empty = new FeedData();
  t.equal(empty.hasRowData(), false, 'hasRowData: 全零行 false');
  const fields = ['average', 'fermented', 'powder', 'feed03', 'feed05', 'feed10', 'water', 'weighed', 'switchRatio'];
  for (const field of fields) {
    const row = new FeedData();
    row[field] = 1;
    t.equal(row.hasRowData(), true, `hasRowData: ${field} 非零 → true`);
  }
  const flagged = new FeedData();
  flagged.isAverageManuallyModified = true;
  t.equal(flagged.hasRowData(), true, 'hasRowData: isAverageManuallyModified=true → true');
}
