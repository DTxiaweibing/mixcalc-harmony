/**
 * LayoutRules 布局判据回归：列宽、平板阈值、fillsAllColumns 边界。
 *
 * 重点覆盖 0.3.6 的边界缺陷：固定列宽总和曾一度超过平板阈值 600vp，
 * 600vp ~ 总宽之间的窗口（含横屏平板 / 分屏）已经把可见列缩放到窗宽、
 * 11 列其实全显示，判据不能再拿固定总宽去卡。现在总宽 604vp（棚号 64vp，
 * 其余列 40/60vp），仍超过阈值，靠 isTabletWidth 提前判定保证 600vp 即铺满。
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

  // 列宽：只有棚号列 64vp，其余列一律 40vp 或 60vp（用户约束，勿改其它列）
  t.equal(R.LAYOUT_WIDTHS.length, 11, '列数 11');
  t.equal(R.LAYOUT_WIDTHS[1], 64, '棚号列 64vp');
  const others = R.LAYOUT_WIDTHS.filter((_, i) => i !== 1);
  t.equal(others.every((w) => w === 40 || w === 60), true, '其余列只能是 40vp 或 60vp');
  t.equal(others.filter((w) => w === 40).length, 3, '3 列 40vp');
  t.equal(others.filter((w) => w === 60).length, 7, '7 列 60vp');
  const total = R.LAYOUT_WIDTHS.reduce((a, b) => a + b, 0);
  t.equal(total, 604, '固定列宽总和 604vp');
  t.equal(R.TABLET_MIN_WIDTH, 600, '平板阈值 600vp');

  const all = new Array(11).fill(true);
  const hidden = all.slice();
  hidden[5] = false;

  // 平板阈值边界
  t.equal(R.isTabletWidth(599), false, '599vp 不是平板');
  t.equal(R.isTabletWidth(600), true, '600vp 进入平板');

  // 手机模式：固定 604vp 放不下，还要横向滚动，快捷设置入口必须留着
  t.equal(R.fillsAllColumns(all, 360), false, '手机 360vp 未铺满');
  t.equal(R.fillsAllColumns(all, 599), false, '599vp 未铺满');

  // 平板 / 横屏：窗口宽度打到 600vp 就全部显示所有列，与固定总宽无关
  t.equal(R.fillsAllColumns(all, 600), true, '600vp 阈值处已铺满，全列显示');
  t.equal(R.fillsAllColumns(all, 601), true, '601vp 刚过阈值已铺满');
  t.equal(R.fillsAllColumns(all, 611), true, '611vp 平板已铺满');
  t.equal(R.fillsAllColumns(all, 800), true, '横屏平板 800vp 已铺满');

  // 有列被隐藏时入口必须保留，无论窗口多宽
  t.equal(R.fillsAllColumns(hidden, 360), false, '有隐藏列 360vp 保留入口');
  t.equal(R.fillsAllColumns(hidden, 800), false, '有隐藏列 800vp 仍保留入口');

  // 空可见表 / 非法宽度
  t.equal(R.fillsAllColumns([], 800), false, '空可见表 false');
  t.equal(R.fillsAllColumns(all, 0), false, '宽度 0 false');
}
