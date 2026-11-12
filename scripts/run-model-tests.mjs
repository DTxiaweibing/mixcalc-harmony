#!/usr/bin/env node
/**
 * 模型层回归跑车（无需设备、无需 npm 依赖）。
 *
 * 思路：entry/src/main/ets/model/*.ets 里的模型文件本身就是 TypeScript 子集，
 * 原样复制成 .ts，用 DevEco SDK 自带的 tsc 编译成 commonjs，再由
 * scripts/model-tests/*.test.mjs 通过 createRequire 加载编译产物做断言。
 *
 * 用法：node scripts/run-model-tests.mjs
 *   MODEL_TEST_KEEP=1  保留 scripts/.model-test-build/ 便于排查
 *   MODEL_TEST_TSC     覆盖 tsc 路径（默认用 DevEco SDK 里的那份）
 */
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { isDeepStrictEqual, inspect } from 'node:util';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const MODEL_DIR = path.join(ROOT, 'entry', 'src', 'main', 'ets', 'model');
const COMMON_DIR = path.join(ROOT, 'entry', 'src', 'main', 'ets', 'common');
const TEST_DIR = path.join(ROOT, 'scripts', 'model-tests');
const BUILD_DIR = path.join(ROOT, 'scripts', '.model-test-build');
const GEN_DIR = path.join(BUILD_DIR, 'gen');
const OUT_DIR = path.join(BUILD_DIR, 'out');
const DEFAULT_TSC = path.join('D:', 'command-line-tools', 'command-line-tools', 'sdk',
  'default', 'openharmony', 'ets', 'build-tools', 'ets-loader', 'node_modules',
  'typescript', 'bin', 'tsc');

// 只编译这几个模型文件：后面任务新增的文件现在还不存在，跳过即可
const MODEL_FILES = [
  'ShedRange', 'ShedText', 'ShedCoverage', 'ShedDisplay',
  'ShedDraft', 'ShedDeletePlan', 'FeedData', 'RowSettlement'
];

// common/ 下同样是纯计算（不 import ArkUI），一并纳入回归：
// LayoutRules 的列宽 / 铺满判据此前没有单测，600vp 阈值边界因此漏掉过。
const COMMON_FILES = ['LayoutRules'];

const keepBuild = process.env.MODEL_TEST_KEEP === '1';

/** 断言上下文：累计通过数与失败明细。 */
function createContext() {
  const failures = [];
  let count = 0;
  return {
    failures,
    get count() {
      return count;
    },
    equal(actual, expected, label) {
      count++;
      if (!isDeepStrictEqual(actual, expected)) {
        failures.push(`${label}: expected ${inspect(expected)} actual ${inspect(actual)}`);
      }
    }
  };
}

function cleanBuildDir() {
  rmSync(BUILD_DIR, { recursive: true, force: true });
}

/** 复制存在的模型文件（.ets -> .ts，内容原样），返回复制/跳过名单。 */
function copyModelSources() {
  const copied = [];
  const skipped = [];
  for (const name of MODEL_FILES) {
    const source = path.join(MODEL_DIR, `${name}.ets`);
    if (!existsSync(source)) {
      skipped.push(name);
      continue;
    }
    writeFileSync(path.join(GEN_DIR, `${name}.ts`), readFileSync(source, 'utf8'));
    copied.push(name);
  }
  for (const name of COMMON_FILES) {
    const source = path.join(COMMON_DIR, `${name}.ets`);
    if (!existsSync(source)) {
      skipped.push(name);
      continue;
    }
    writeFileSync(path.join(GEN_DIR, `${name}.ts`), readFileSync(source, 'utf8'));
    copied.push(name);
  }
  return { copied, skipped };
}

function compileModelSources(copied) {
  if (copied.length === 0) {
    return;
  }
  const tsc = process.env.MODEL_TEST_TSC || DEFAULT_TSC;
  const args = [
    tsc, '--target', 'es2020', '--module', 'commonjs',
    '--skipLibCheck', '--strict', 'false', '--outDir', OUT_DIR,
    ...copied.map((name) => path.join(GEN_DIR, `${name}.ts`))
  ];
  execFileSync(process.execPath, args, { cwd: ROOT, stdio: 'inherit' });
}

function listTestFiles() {
  if (!existsSync(TEST_DIR)) {
    return [];
  }
  return readdirSync(TEST_DIR)
    .filter((name) => name.endsWith('.test.mjs'))
    .sort();
}

async function runTestFiles(t) {
  process.env.MODEL_TEST_OUT_DIR = OUT_DIR;
  for (const name of listTestFiles()) {
    const uri = pathToFileURL(path.join(TEST_DIR, name)).href;
    try {
      const mod = await import(uri);
      if (typeof mod.default !== 'function') {
        t.failures.push(`${name}: 缺少默认导出的 run(t) 函数`);
        continue;
      }
      await mod.default(t);
    } catch (error) {
      t.failures.push(`${name}: 抛出异常 ${error && error.stack ? error.stack : error}`);
    }
  }
}

function finish(failed) {
  if (keepBuild) {
    console.log(`构建目录已保留：${BUILD_DIR}`);
  } else {
    cleanBuildDir();
  }
  process.exit(failed ? 1 : 0);
}

async function main() {
  cleanBuildDir();
  mkdirSync(GEN_DIR, { recursive: true });
  mkdirSync(OUT_DIR, { recursive: true });

  const { copied, skipped } = copyModelSources();
  console.log(`模型文件：编译 ${copied.length} 个` +
    (skipped.length > 0 ? `，暂缺跳过 ${skipped.join('/')}` : ''));

  try {
    compileModelSources(copied);
  } catch (error) {
    console.error('✗ 模型文件编译失败');
    return finish(true);
  }

  const testFiles = listTestFiles();
  if (testFiles.length === 0) {
    console.error('✗ 没有找到 scripts/model-tests/*.test.mjs');
    return finish(true);
  }

  const t = createContext();
  await runTestFiles(t);

  if (t.failures.length > 0) {
    for (const failure of t.failures) {
      console.error(`✗ ${failure}`);
    }
    console.error(`✗ ${t.failures.length} 处断言失败（共 ${t.count} 条）`);
    return finish(true);
  }
  console.log(`✓ ${t.count} assertions`);
  return finish(false);
}

await main();
