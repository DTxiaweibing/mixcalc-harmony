/**
 * LayoutRules 布局判据回归：列宽、平板阈值、fillsAllColumns 边界。
 *
 * 重点覆盖 0.3.6 的边界缺陷：棚号列加宽后固定总宽超过平板阈值 600vp，
 * 600vp ~ 总宽之间的窗口（含横屏平板 / 分屏）已经把可见列缩放到窗宽、
 * 11 列其实全显示，判据不能再拿固定总宽去卡。
 */
import { createRequire } from 'node:module';
import path from 'node:path';

const require = createRequire(import.meta.url);

/** 加载编译后的纯计算模块（由 run-model-tests.mjs 设置 MODEL_TEST_OUT_DIR）。 */
function loadModel(name) {
  const outDir = process.env.MODEL_TEST_OUT_DIR;
  if (!outDir) {
    throw new Error('MODEL_TEST_OUT_DIR 未设置，请用 node scripts/run-model-tests.mjs 运行');
  }
  return require(path.join(outDir, `${name}.js`));
}

export default function run(t) {
  const R = loadModel('LayoutRules');

  // 列宽：云调试多机型实测最稳的一档（棚号 15vp 字号 + 68vp 列宽）
  t.equal(R.LAYOUT_WIDTHS.length, 11, '列数 11');
  t.equal(R.LAYOUT_WIDTHS[1], 68, '棚号列 68vp（云调试实测最稳）');
  const total = R.LAYOUT_WIDTHS.reduce((a, b) => a + b, 0);
  t.equal(total, 608, '固定列宽总和 608vp');
  t.equal(R.TABLET_MIN_WIDTH, 600, '平板阈值 600vp');

  const all = new Array(11).fill(true);
  const hidden = all.slice();
  hidden[5] = false;

  // 平板阈值边界
  t.equal(R.isTabletWidth(599), false, '599vp 不是平板');
  t.equal(R.isTabletWidth(600), true, '600vp 进入平板');

  // 手机模式：固定 608vp 放不下，还要横向滚动，快捷设置入口必须留着
  t.equal(R.fillsAllColumns(all, 360), false, '手机 360vp 未铺满');
  t.equal(R.fillsAllColumns(all, 599), false, '599vp 未铺满');

  // 平板 / 横屏：列已缩放到窗宽，全可见即铺满，与固定总宽 608 无关
  t.equal(R.fillsAllColumns(all, 600), true, '600vp 平板已铺满');
  t.equal(R.fillsAllColumns(all, 607), true, '607vp 平板已铺满（608 总宽前的边界）');
  t.equal(R.fillsAllColumns(all, 612), true, '612vp（已超 608 总宽）仍铺满');
  t.equal(R.fillsAllColumns(all, 800), true, '横屏平板 800vp 已铺满');

  // 有列被隐藏时入口必须保留，无论窗口多宽
  t.equal(R.fillsAllColumns(hidden, 360), false, '有隐藏列 360vp 保留入口');
  t.equal(R.fillsAllColumns(hidden, 800), false, '有隐藏列 800vp 仍保留入口');

  // 空可见表 / 非法宽度
  t.equal(R.fillsAllColumns([], 800), false, '空可见表 false');
  t.equal(R.fillsAllColumns(all, 0), false, '宽度 0 false');
}
