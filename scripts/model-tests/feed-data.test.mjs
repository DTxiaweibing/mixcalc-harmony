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

  // 6) averageValue：与安卓 getAverage(boolean) 对齐——手改过平均用手改值，
  //    否则按当前料量/棚数现算（选换料比例时要用它把当前平均钉住）
  const computed = new FeedData();
  computed.setShedNumber('1-10');
  computed.powder = 500;
  t.equal(computed.averageValue(false), 50, 'averageValue: 500/10 → 50');
  computed.fermented = 100;
  t.equal(computed.averageValue(false), 50, 'averageValue: 发酵料不参与算料 → 仍 50');
  t.equal(computed.averageValue(true), 60, 'averageValue: 发酵料参与算料 → 600/10 → 60');
  const manualAvg = new FeedData();
  manualAvg.setShedNumber('1-10');
  manualAvg.powder = 500;
  manualAvg.average = 12.5;
  manualAvg.isAverageManuallyModified = true;
  t.equal(manualAvg.averageValue(false), 12.5, 'averageValue: 手改过 → 直接用 average');
  const zeroShed = new FeedData();
  zeroShed.powder = 500;
  t.equal(zeroShed.averageValue(false), 0, 'averageValue: 棚数 0 → 0');

  // 7) 选完换料比例立即按比例拆两格（安卓 applySwitchRatioNow 的模型侧等价）
  const oneFeed = new FeedData();
  oneFeed.setShedNumber('1-10');
  oneFeed.powder = 500;
  oneFeed.switchRatio = 0.3;
  oneFeed.average = oneFeed.averageValue(false);
  oneFeed.isAverageManuallyModified = true;
  oneFeed.recalculateDerivedOnly(20, false, false);
  t.equal(oneFeed.powder, 350, '换料比例 30%: 粉料 = 500 × 0.7');
  t.equal(oneFeed.feed03, 150, '换料比例 30%: 0.3料 = 500 × 0.3');
  t.equal(oneFeed.average, 50, '换料比例: 每棚平均不变');

  const twoFeed = new FeedData();
  twoFeed.setShedNumber('1-10');
  twoFeed.powder = 400;
  twoFeed.feed03 = 100;
  twoFeed.switchRatio = 0.5;
  twoFeed.average = twoFeed.averageValue(false);
  twoFeed.isAverageManuallyModified = true;
  twoFeed.recalculateDerivedOnly(20, false, false);
  t.equal(twoFeed.powder, 250, '换料比例 50%: 粉料 = 500 × 0.5');
  t.equal(twoFeed.feed03, 250, '换料比例 50%: 0.3料 = 500 × 0.5');

  // 8) mergeSmallerWhenCleared：把「最细的一档」清零时并进唯一的粗料，量用调用方传的编辑前原值
  const merged = new FeedData();
  merged.setShedNumber('1-10');
  merged.powder = 350;
  merged.feed03 = 150;
  merged.switchRatio = 0.3;
  t.equal(merged.mergeSmallerWhenCleared(0, 350), 350, 'merge: 清零粉料 → 返回并入量 350');
  t.equal(merged.feed03, 500, 'merge: 0.3料 = 150 + 350');
  t.equal(merged.powder, 0, 'merge: 粉料 清 0');
  t.equal(merged.switchRatio, 0, 'merge: 换料比例作废');
  t.equal(merged.mergeSmallerWhenCleared(0, 0), 0, 'merge: 调用方已作废原值（0）→ 不再并第二笔');

  const midFeed = new FeedData();
  midFeed.setShedNumber('1-10');
  midFeed.feed05 = 150;
  midFeed.feed10 = 100;
  t.equal(midFeed.mergeSmallerWhenCleared(2, 150), 150, 'merge: 清零 0.5料 → 并进 1.0料');
  t.equal(midFeed.feed10, 250, 'merge: 1.0料 = 100 + 150');

  const notAFinerExit = new FeedData();
  notAFinerExit.setShedNumber('1-10');
  notAFinerExit.powder = 100;
  notAFinerExit.feed05 = 150;
  t.equal(notAFinerExit.mergeSmallerWhenCleared(2, 150), 0, 'merge: 前面还有更细的一档有料 → 不合并');

  const twoCoarser = new FeedData();
  twoCoarser.setShedNumber('1-10');
  twoCoarser.feed03 = 100;
  twoCoarser.feed05 = 100;
  t.equal(twoCoarser.mergeSmallerWhenCleared(0, 80), 0, 'merge: 粗料不止一档 → 不合并');

  const zeroAmount = new FeedData();
  zeroAmount.setShedNumber('1-10');
  zeroAmount.powder = 100;
  t.equal(zeroAmount.mergeSmallerWhenCleared(1, 0), 0, 'merge: 原值为 0 → 不合并');
}
