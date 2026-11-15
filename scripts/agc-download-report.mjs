#!/usr/bin/env node
// AGC Reports API：应用下载安装报表（近 N 天 / 任意区间 / 按版本·国家·日期分组）
//
// 用法：
//   node scripts/agc-download-report.mjs                       # 近 30 天，按日期
//   node scripts/agc-download-report.mjs --days 7              # 近 7 天
//   node scripts/agc-download-report.mjs --start 20261001 --end 20261031 --group-by appVersion
//   node scripts/agc-download-report.mjs --group-by countryId --json
//
// 认证：优先用 AGC_TOKEN 环境变量；否则复用 connect-api-cli 的 token 缓存
// （~/.connect-api-cli-token.json），缓存过期时自动调 CLI 重新登录。
// 凭证配置见项目 .env（AGC_AUTH_MODE / AGC_SA_CREDENTIALS 或 AGC_CLIENT_ID / AGC_CLIENT_SECRET）。

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const API_HOST = 'https://connect-api.cloud.huawei.com';
const REPORT_PATH = '/api/report/distribution-operation-quality/v1/appDownloadExport';
const GROUP_BY = new Set(['date', 'countryId', 'businessType', 'appVersion']);
const CACHE_FILE = path.join(os.homedir(), '.connect-api-cli-token.json');
const DEFAULT_CLI = 'C:/Users/Administrator/.claude/skills/hmos-connect-api-cli-skill/scripts/connect-api-cli.js';
const DAY_MS = 86400000;

function fail(msg) {
  console.error(`错误：${msg}`);
  process.exit(1);
}

function ymd(date) {
  const y = date.getUTCFullYear();
  const m = String(date.getUTCMonth() + 1).padStart(2, '0');
  const d = String(date.getUTCDate()).padStart(2, '0');
  return `${y}${m}${d}`;
}

function parseArgs(argv) {
  const opts = { days: 30, groupBy: 'date', json: false, out: null, filters: [] };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      i += 1;
      if (i >= argv.length) fail(`${arg} 缺少取值`);
      return argv[i];
    };
    switch (arg) {
      case '--days': opts.days = Number(next()); break;
      case '--start': opts.start = next(); break;
      case '--end': opts.end = next(); break;
      case '--group-by': opts.groupBy = next(); break;
      case '--filter': opts.filters.push(next()); break;
      case '--out': opts.out = next(); break;
      case '--json': opts.json = true; break;
      case '--brief': opts.brief = true; break;
      case '--app-id': opts.appId = next(); break;
      case '-h':
      case '--help':
        opts.help = true;
        break;
      default:
        fail(`未知参数 ${arg}（--help 查看用法）`);
    }
  }
  return opts;
}

function resolveRange(opts) {
  if (opts.start && opts.end) return { start: opts.start, end: opts.end };
  if (!Number.isFinite(opts.days) || opts.days <= 0) fail('--days 必须是正整数');
  const end = new Date();
  const start = new Date(end.getTime() - (opts.days - 1) * DAY_MS);
  return { start: ymd(start), end: ymd(end) };
}

function isFresh(cache) {
  return cache && cache.accessToken && cache.expiresAt > Date.now() + 60000;
}

function readCache() {
  if (!fs.existsSync(CACHE_FILE)) return null;
  try {
    return JSON.parse(fs.readFileSync(CACHE_FILE, 'utf8'));
  } catch {
    return null;
  }
}

function loginViaCli() {
  const cli = process.env.CONNECT_API_CLI || DEFAULT_CLI;
  if (!fs.existsSync(cli)) {
    fail(`token 已过期且找不到 connect-api-cli（${cli}）。设置 CONNECT_API_CLI 指向它，或手动跑 auth login。`);
  }
  console.error('token 失效，正在用 connect-api-cli 重新获取…');
  execFileSync(process.execPath, [cli, 'auth', 'login'], { stdio: ['ignore', 'inherit', 'inherit'], cwd: process.cwd() });
}

function resolveAuth() {
  const envToken = process.env.AGC_TOKEN;
  if (envToken) {
    const clientId = process.env.AGC_CLIENT_ID || readCache()?.clientId;
    if (!clientId) fail('用 AGC_TOKEN 时还需要 AGC_CLIENT_ID（AGC 要求 client_id 请求头）');
    return { token: envToken, clientId };
  }
  let cache = readCache();
  if (!isFresh(cache)) {
    loginViaCli();
    cache = readCache();
  }
  if (!isFresh(cache)) fail('拿不到有效 token。确认当前目录 .env 的 AGC 凭证，然后跑 connect-api-cli auth login');
  return { token: cache.accessToken, clientId: cache.clientId, domain: cache.domain || 'connect-api.cloud.huawei.com' };
}

function parseCsv(text) {
  const rows = [];
  let field = '';
  let row = [];
  let quoted = false;
  const clean = text.replace(/^\uFEFF/, '');
  for (let i = 0; i < clean.length; i += 1) {
    const ch = clean[i];
    if (quoted) {
      if (ch === '"' && clean[i + 1] === '"') {
        field += '"';
        i += 1;
      } else if (ch === '"') {
        quoted = false;
      } else {
        field += ch;
      }
    } else if (ch === '"') {
      quoted = true;
    } else if (ch === ',') {
      row.push(field);
      field = '';
    } else if (ch === '\n') {
      row.push(field.replace(/\r$/, ''));
      rows.push(row);
      row = [];
      field = '';
    } else {
      field += ch;
    }
  }
  if (field !== '' || row.length > 0) {
    row.push(field.replace(/\r$/, ''));
    rows.push(row);
  }
  return rows.filter((r) => r.some((c) => c.trim() !== ''));
}

const TOTAL_COLUMNS = /成功次数|下载次数|安装次数|曝光次数|访问次数|卸载次数|分享次数|ICON点击次数/;

function summarize(header, rows) {
  const totals = {};
  header.forEach((name, idx) => {
    if (!TOTAL_COLUMNS.test(name)) return;
    const values = rows.map((r) => Number((r[idx] ?? '').replace('%', '')));
    if (values.some((v) => !Number.isFinite(v))) return;
    totals[name] = values.reduce((a, b) => a + b, 0);
  });
  return totals;
}

function printTable(header, rows) {
  const widths = header.map((name, idx) =>
    Math.max(width(name), ...rows.map((r) => width(r[idx] ?? ''))));
  const line = (cells) => cells.map((c, i) => pad(c, widths[i])).join('  ');
  console.log(line(header));
  console.log(widths.map((w) => '-'.repeat(w)).join('  '));
  rows.forEach((r) => console.log(line(header.map((_, i) => r[i] ?? ''))));
}

const BRIEF_COLUMNS = ['总下载成功次数', '更新下载成功次数', '新下载成功次数', '安装成功次数'];

function briefView(header, rows) {
  const indexes = BRIEF_COLUMNS.map((name) => header.indexOf(name));
  return {
    header: ['分组', ...BRIEF_COLUMNS],
    rows: rows.map((r) => [r[0], ...indexes.map((i) => (i >= 0 ? r[i] : '-'))]),
  };
}

function width(text) {  return [...String(text)].reduce((sum, ch) => sum + (/[\u4e00-\u9fa5]/.test(ch) ? 2 : 1), 0);
}

function pad(text, target) {
  return String(text) + ' '.repeat(Math.max(0, target - width(text)));
}

function buildUrl(appId, range, opts) {
  const url = new URL(`${API_HOST}${REPORT_PATH}/${appId}`);
  url.searchParams.set('language', 'zh-CN');
  url.searchParams.set('startTime', range.start);
  url.searchParams.set('endTime', range.end);
  url.searchParams.set('groupBy', opts.groupBy);
  url.searchParams.set('exportType', 'CSV');
  for (const filter of opts.filters) {
    const [key, value] = filter.split('=');
    if (!key || value === undefined) fail(`--filter 需要 key=value 形式，收到 ${filter}`);
    url.searchParams.append('filterCondition', key);
    url.searchParams.append('filterConditionValue', value);
  }
  return url;
}

async function fetchReport(url, auth) {
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${auth.token}`, client_id: auth.clientId },
  });
  const body = await res.text();
  if (!res.ok) fail(`报表接口 ${res.status}：${body.slice(0, 300)}`);
  let payload;
  try {
    payload = JSON.parse(body);
  } catch {
    fail(`报表接口返回非 JSON：${body.slice(0, 300)}`);
  }
  if (payload.ret && payload.ret.code !== 0) fail(`报表接口 code=${payload.ret.code} ${payload.ret.msg}`);
  const link = payload.fileURL || payload.fileUrl;
  if (!link) fail(`报表接口没给下载地址：${body.slice(0, 300)}`);
  const csvRes = await fetch(link);
  if (!csvRes.ok) fail(`下载报表失败 ${csvRes.status}`);
  return csvRes.text();
}

function saveCsv(opts, range, csv) {
  const outPath = opts.out
    ? path.resolve(opts.out)
    : path.join(process.cwd(), `agc-download-${opts.groupBy}-${range.start}-${range.end}.csv`);
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, csv, 'utf8');
  return outPath;
}

function printHelp() {
  console.log(`AGC 下载安装报表
  --days <n>        近 n 天（默认 30）
  --start/--end     YYYYMMDD，指定区间（优先于 --days）
  --group-by <g>    date | countryId | businessType | appVersion（默认 date）
  --filter k=v      报表过滤，可重复，如 --filter countryId=CN
  --app-id <id>     覆盖默认 App ID
  --out <file>      CSV 保存路径
  --json            输出 JSON（便于脚本消费）
  --brief           只打印下载/安装几列
  -h, --help        显示帮助`);
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  if (opts.help) return printHelp();
  if (!GROUP_BY.has(opts.groupBy)) fail(`--group-by 只支持 ${[...GROUP_BY].join(' / ')}`);

  const appId = opts.appId || process.env.AGC_APP_ID || '6917620381536923302';
  const range = resolveRange(opts);
  const auth = resolveAuth();

  const csv = await fetchReport(buildUrl(appId, range, opts), auth);
  const rows = parseCsv(csv);
  if (rows.length < 2) {
    console.log(`${range.start} ~ ${range.end}：没有数据（该区间无下载/安装记录）`);
    return;
  }

  const header = rows[0];
  const dataRows = rows.slice(1);
  const totals = summarize(header, dataRows);
  const outPath = saveCsv(opts, range, csv);

  if (opts.json) {
    console.log(JSON.stringify({ appId, range, groupBy: opts.groupBy, header, rows: dataRows, totals, csv: outPath }, null, 2));
    return;
  }

  console.log(`App ${appId}｜${range.start} ~ ${range.end}｜按 ${opts.groupBy} 分组｜${dataRows.length} 行`);
  console.log(`CSV：${outPath}\n`);
  if (opts.brief) {
    const view = briefView(header, dataRows);
    printTable(view.header, view.rows);
  } else {
    printTable(header, dataRows);
  }
  console.log('\n合计：');
  for (const [name, value] of Object.entries(totals)) console.log(`  ${name}：${value}`);
}

main().catch((err) => fail(err instanceof Error ? err.message : String(err)));
