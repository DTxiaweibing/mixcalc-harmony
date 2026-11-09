# 鸿蒙版棚号账本移植计划（对齐安卓 0.3.6）

> 执行者：假设你没看过本仓库，也没参与过安卓版。本文给出**要改哪些文件、函数名与签名、
> 每个任务用哪条测试证明**。凡是本文没写的设计选择，按现有代码风格自行决定，不要重构架构。
>
> 唯一业务准绳：`D:\mixcalc-lab\docs\棚号与表格逻辑-0.3.6至0.3.19完整改动与移植说明.md`。
> 安卓 0.3.9 / 0.3.12 / 0.3.14 的旧规则已被文档中的新规则取代，**不要按旧实现**。

---

## 0. 背景与现状（先读）

鸿蒙工程 `D:\mixcalc-harmony` 当前已有相当于安卓 **0.3.7** 的水平：

- 所有行平等、`ownedSets/ownedCounts` 打点覆盖（`entry/src/main/ets/model/ShedCoverage.ets`）；
- 棚数为 0 的行「隐藏但保留」（`RowSettlement.settleZeroRowData`）；
- 只读棚号气泡（`table/MixCalcTable.ets` 里的 `showShedList`、`shedListOpen` 等状态）；
- 棚号列 `maxLines(2)` 但**没有两行折叠算法**，系统会按像素裁断区间；
- 没有 `renormalize`、没有快照重推、没有选中/⋮菜单/转出/转入/删除、没有行回收。

本计划补齐以下缺口，全部 1:1 直译安卓模型层，UI 用现有 ArkUI 组件改造：

| 缺口 | 安卓来源 |
|---|---|
| `ShedText`（转移/删除文本） | `model/ShedText.java` |
| `ShedCoverage.renormalize` | `model/ShedCoverage.java` |
| `ShedDisplay`（两行折叠） | `model/ShedDisplay.java` |
| `ShedDraft`（快照重推） | `model/ShedDraft.java` |
| `ShedDeletePlan`（删除去向） | `model/ShedDeletePlan.java` |
| `RowSettlement.recycleDeadRows` / `settleRows` | `model/RowSettlement.java` |
| `FeedData.shedDisplay` / `setShedCountDirectly` | `model/FeedData.java` |
| 表格覆盖两层 + 快照生命周期 | `MixCalcActivity.applyShedCoverage` |
| 气泡选中 / 菜单 / 转出 / 转入 / 删除 | `MixCalcActivity` 958-1562 |
| 行回收收尾 | `MixCalcActivity.finishRowRemoval` |
| 两行显示 + 固定字号 + 72dp | `MixCalcTableView.drawWrappedCellText` |

---

## 1. Global Constraints（违反任何一条都要停下来改）

1. **纯逻辑只放 `entry/src/main/ets/model/`**，不得 import ArkUI / preferences / promptAction。
   模型函数必须是纯函数或只操作传入的 `FeedData[]`，方便 Node 直接跑测试。
2. **ArkTS 严格模式**：
   - 不用 `any`、不用对象字面量当类实例（用 `new Xxx()`）；
   - 不用 `Map` / `Set` 作为模型入参/返回值，统一 `number[]`、`string[]`；
   - 可空一律用空串/空数组代替 `null`，避免 `string | null`；
   - 数组解构、`Number.parseInt` 等写法不要用，按仓库现有写法（`Number(v)`、显式下标）。
3. **棚号列样式**：正文字号固定为 `fs()`（15vp，vp 不随系统字体缩放），
   与其它列**完全一致**；只额外加 `.lineHeight(18)`、`maxLines(2)`、`TextOverflow.Clip`。
   列宽 `LAYOUT_WIDTHS[1]` 从 60 改 72（手机总宽 600 → 612，更新注释）。
4. **两行显示必须走 `ShedDisplay.render()`**，不许依赖 `Text` 的自动折行/省略号；
   单元格文本 = `render(...).join('\n')`。
5. **声明与显示分离**：`FeedData.shedNumber` 永远是用户声明原文，覆盖/重排只写
   `FeedData.shedDisplay`；只有「转移」「删除后的重排」允许改写声明（`commitShedText`）。
6. **行回收只在结算时刻做**（收起编辑、换格、切批次、退出页面、载入、删除/转移收尾），
   编辑途中绝不动行。
7. **文案必须中英双份**：`common/Strings.ets` 的 `ZH` 与 `EN` 同 key 同时加，缺一不可。
8. 版本号保持工作区已改好的 `versionName 0.3.6` / `versionCode 1000306`，不要改成 0.3.7。
9. 每个任务完成即提交（`git add -A && git commit -m "..."`），不要攒到最后。
10. 改动后 `entry/src/main/ets/**` 单文件不得超过 500 行（`MixCalcTable.ets` 已超，
    本计划不强制拆分，但**禁止再净增长超过 120 行**；超出就把纯逻辑挪进 `model/`）。

---

## 2. 验证方式（没有 ohosTest 源集，也没有可连设备）

工程没有 `entry/src/test`，`hdc list targets` 为空。单测方案：

- `scripts/run-model-tests.mjs` 把 `entry/src/main/ets/model/*.ets` 复制成 `.ts`，
  用 SDK 自带 tsc 编译到临时目录，再由 Node 跑 `scripts/model-tests/*.test.mjs`。
- tsc 路径（已验证可编译现有 3 个 model 文件）：
  `D:\command-line-tools\command-line-tools\sdk\default\openharmony\ets\build-tools\ets-loader\node_modules\typescript\bin\tsc`
- 运行：`node scripts/run-model-tests.mjs`，失败必须非 0 退出。

编译验证（每个 UI 任务至少跑一次）：

```powershell
$env:PATH = 'D:\command-line-tools\command-line-tools\bin;D:\command-line-tools\command-line-tools\tool\node;' + $env:PATH
$env:DEVECO_SDK_HOME = 'D:\command-line-tools\command-line-tools\sdk'
Set-Location D:\mixcalc-harmony
& 'D:\command-line-tools\command-line-tools\bin\hvigorw.bat' assembleHap -p product=default -p buildMode=debug --no-daemon
```

产物在 `entry/build/default/outputs/default/entry-default-signed.hap`（调试自动签名）。
发布包走 `scripts/build-release-app.ps1`（需要 `MIXCALC_P12_PWD`，不在本计划自动执行）。

---

## 3. Review Focus（评审时重点看这些）

1. `applyShedCoverage` 是否**先覆盖再重算派生值**，且改文本前先保存 `oldCount`。
2. 打字途中是否每帧都从 `shedEditSnapshot` 重推，而不是在上一次结果上继续改。
3. `renormalize` 是否只改显示、不清空被整行覆盖的行的文本。
4. 删除是否只动本行声明，且被删空的行走 `emptiedByUser` 回收。
5. 转移是否按号码集合换主人，且转完对来源/目标各做一次 `rewriteToOwned`。
6. 行回收是否**先回收再兜底清**、一次删完、底部补空行、`editingRow=-1` 之后才删。
7. 点「棚数」时先提交上一格再结算，**行下标可能平移**，必须按对象引用重新定位。
8. 棚号列 9 字符/行在 72vp 内是否真的放得下（真机/预览器看 3 位数区间 `100-199`）。

---

## 4. 任务

### 任务 0：搭好模型测试跑车（先有回归，再动业务）

**Files**
- 新增 `scripts/run-model-tests.mjs`
- 新增 `scripts/model-tests/feed-data.test.mjs`（先放一条 `1+1===2` 的冒烟断言）
- 修改 `.gitignore`：追加 `scripts/.model-test-build/`

**Interfaces**
- 脚本无参数；环境变量 `MODEL_TEST_KEEP=1` 时保留临时目录便于排查。
- 测试文件用 ESM，`import { createRequire } from 'node:module'` 加载编译产物。

**步骤**
1. 用 `os.tmpdir()`（或 `process.env.TEMP`）建临时目录，逐文件读取：
   `ShedRange`、`ShedText`、`ShedCoverage`、`ShedDisplay`、`ShedDraft`、
   `ShedDeletePlan`、`FeedData`、`RowSettlement`（允许文件暂时不存在，跳过）。
2. 把 `.ets` 原样写成 `.ts`（不要改内容；相对 import `./X` 正好对应）。
3. `execFileSync(process.execPath, [tscPath, '--target','es2020','--module','commonjs',
   '--skipLibCheck','--strict','false','--outDir', outDir, ...tsFiles])`。
4. 动态 `import()` 所有 `scripts/model-tests/*.test.mjs`，每个模块导出一个
   `export default function run(t)`；`t.equal(actual, expected, label)` 累计失败。
5. 任一失败：打印 `✗ label: expected ... actual ...`，`process.exit(1)`；
   全过打印 `✓ N assertions`，`process.exit(0)`。

**验证**
- `node scripts/run-model-tests.mjs` 输出 `✓ 1 assertions`。

**提交** `test: 增加模型层 Node 测试跑车`

---

### 任务 1：`ShedRange` + `ShedText`

**Files**
- 新增 `entry/src/main/ets/model/ShedRange.ets`
- 新增 `entry/src/main/ets/model/ShedText.ets`
- 新增 `scripts/model-tests/shed-text.test.mjs`

**为什么单独拆 `ShedRange`**：`ShedText.normalize` 与 `ShedCoverage.renormalize` 都要
「升序 + 连号 ≥3 收区间 + 空格分隔」。安卓里 `ShedCoverage` import `ShedText`、`ShedText`
又 import `ShedCoverage`，ArkTS 循环 import 有风险，所以把压缩算法放叶子模块。

**Interfaces**

```ts
// ShedRange.ets
export function compressNumbers(numbers: number[]): string;

// ShedText.ets
export function normalize(numbers: number[]): string;
export function transfer(sourceText: string, targetText: string, numbers: number[]): string[];
export function pointlessWholeRowMove(targetText: string, sourceOwned: number[],
                                      numbers: number[]): boolean;
export function remove(text: string, numbers: number[]): string;
```

**实现要点**
- `compressNumbers`：`slice()` → 数字升序排序（`(a,b)=>a-b`）→ 去重 →
  连续 ≥3 写 `a-b`，否则逐个写；片段之间用**半角空格**连接。
- `normalize` = `compressNumbers`。
- `transfer`：`parseShedNumbers(sourceText)` / `(targetText)` 得两个数组；
  对 `numbers` 里每个 `n>0`：从 source 移除所有等于 n 的元素，向 target 追加 n（后面统一压缩去重）；
  返回 `[compressNumbers(source), compressNumbers(target)]`。
- `remove`：
  - 基准 `base = text.trim()`；空或 numbers 空 → 原样返回 base。
  - 按 `[,，、;；/\s]+` split；对每段：
    - 段内不含 `-—－~～至到` 且 `parseShedNumbers(part).length===1` → 单号，
      在 numbers 里就跳过并记 `removed=true`，否则原样 append；
    - 连续段：若段内没有要删的号 → 原样 append；否则记 `removed=true`，
      展开后过滤，剩余非空则 `compressNumbers(remain)` append。
  - 最后：`removed ? joined : base`（一个都没删到，连分隔符都原样保留）。
- `pointlessWholeRowMove`：目标文本空白、`sourceOwned` 非空、`numbers` 非空、
  且 sourceOwned 每个号都在 numbers 里 → true。

**测试（从 Java 用例直译，命名保持一致）**
- `normalizeSortsAndMerges`：`[5,1,3,2] → "1-3 5"`、`[36,37,38,25,20] → "20 25 36-38"`、
  `[40,39] → "39 40"`、空数组 → `""`。
- `wholeRowToBlankTargetIsPointless`：4 组 true/false（见 `ShedTextTest.java` 30-42）。
- `transferMovesNumbersBothSides`：`transfer("1-40","",[5])` → `["1-4 6-40","5"]`。
- `transferIsNeverANoOpWhenTargetSpanCovers`：`transfer("1-40","20-30",[25])` →
  `["1-24 26-40","20-30"]`；覆盖后 `ownedCounts` = 29 / 11。
- `transferUpFromRange`：`transfer("20-30","1-40",[25])` → `["20-24 26-30","1-40"]`。
- `transferNumbersNotInSourceStillLandOnTarget`：`transfer("1-10","",[11,3])` →
  `["1 2 4-10","3 11"]`。
- `removeDeletesStandaloneNumber` / `removeSplitsRangeWhenNumberInside` /
  `removeSplitsRangeAtEdges` / `removeSplitsRangeInMiddle` / `removeWholeRangeLeavesEmptyText` /
  `removeMixedParts` / `removeKeepsTextWhenNothingRemoved` / `removeHandlesMixedSeparators` /
  `removeHandlesChineseRangeChars`：照抄 `ShedTextTest.java` 83-137 的期望值。
- 额外加 `ShedTransferTest` 的 5 条流程用例（`runTransfer` helper 在测试里用
  `transfer → ownedSets → normalize` 模拟）。

**验证** `node scripts/run-model-tests.mjs` 全绿；`hvigor assembleHap` 能过。

**提交** `feat(model): ShedText 转移/删除文本与 ShedRange 压缩`

---

### 任务 2：`ShedCoverage.renormalize`

**Files**
- 修改 `entry/src/main/ets/model/ShedCoverage.ets`（追加函数，不改已有导出）
- 新增 `scripts/model-tests/shed-coverage.test.mjs`

**Interface**
```ts
export function renormalize(texts: string[]): string[];
```

**实现要点**
1. `const owned: number[][] = ownedSets(texts);`
2. 逐行：`original = texts[i].trim()`；
   `mine = owned[i]`；
   若 `mine.length > 0 && mine.length !== parseShedNumbers(original).length`
   → `compressNumbers(mine)`；否则 `original`。
3. 被整行覆盖（`mine` 为空）时**原样返回**，交给行回收清掉，避免表中间留洞。

**测试**（`ShedCoverageRenormalizeTest.java` 全量）
- `["1-40","1-15"] → ["16-40","1-15"]`，覆盖后 count 25/15
- `["20-30","25"] → ["20-24 26-30","25"]`
- `["1-40","1-15 20"] → ["16-19 21-40","1-15 20"]`
- 单行 `"24-40 1-20"` 不被重排；`"1 3 5 7 8-40"` 原样
- `["1-40","1-40"]` 两行都原样（整行覆盖不清理文本）
- 幂等：`renormalize(renormalize(x))` 与一次结果相同
- `["", ""] → ["", ""]`
- `["1-40","1-20","1-5"] → ["21-40","6-20","1-5"]`

**验证** 同任务 1。

**提交** `feat(model): 棚号文本按实际归属 renormalize`

---

### 任务 3：`ShedDisplay`（两行极简折叠）

**Files**
- 新增 `entry/src/main/ets/model/ShedDisplay.ets`
- 新增 `scripts/model-tests/shed-display.test.mjs`

**Interface**
```ts
export function render(rawText: string): string[];
```

**实现要点**
逐条直译 `ShedDisplay.java`，不要"优化"：
- 常量 `MAX = 9`。
- `tokenize`：trim → 中文区间符统一成 `-` → 吃掉横杠两边空白 → 按 `[,，、;；/\s]+` split。
- `preprocess`：每段按 `-` 拆成 `a,b`（无横杠则 `a=b`），`a>b` 交换，`a>0` 收集；
  按 `a` 再按 `b` 升序；合并 `iv[0] <= last[1] + 1`（相邻/重叠）；
  输出 `a===b ? "a" : "a-b"`。
- `render` 分支严格按：A-1 单行全显示 → A-2 两行全显示 → B-1 无区间散点截断 →
  B-2 双区间紧凑折叠（含"只有一个区间时只露一次"的特判）。
- `disp` = 各项长度和 + 项数-1；`join` 用半角空格。
- `ellipsizedTail` 的 `…` 紧贴首项，末尾若被裁再补 `…`。
- 原文空白 → `[]`；完全解析不出号码 → `[原文 trim]`。

**测试**（`ShedDisplayTest.java` 全量，一行一行对）
- `"1 3 5 7 9 11 13" → ["1 3 5","7 9 11 13"]`
- `"1 3-15 17 19-32" → ["1 3-15","17 19-32"]`
- `"101-105 107 109" → ["101-105","107 109"]`
- `"1 3-15 18 20 22 25-32" → ["1…3-15","…25-32"]`
- `"1 3 5 7-15 18 20 22 25-32 37 39 41" → ["1 3…7-15","…25-32…"]`
- `"1 3-15 18 20 22 24 26 28 30 100-199" → ["1…3-15","…100-199"]`
- `"1-40" → ["1-40"]`；`"1 2 3" → ["1-3"]`；`"1-3 4" → ["1-4"]`；`"1、2、3" → ["1-3"]`
- `"2 4 6 8 10 12 14 16 18 20 22" → ["2 4 6 8","… 20 22"]`
- `"1 3 5 7 9-15 17 19 21" → ["1 3 5 7…","…9-15 17…"]`，且 `9-15` 只出现一次
- `"9-15 17 19 21 23 25" → ["9-15…","…17 19…"]`
- 所有输出行长度 ≤ 9。

**提交** `feat(model): 棚号两行极简折叠 ShedDisplay`

---

### 任务 4：`ShedDraft`（快照重推）

**Files**
- 新增 `entry/src/main/ets/model/ShedDraft.ets`
- 新增 `scripts/model-tests/shed-draft.test.mjs`

**Interfaces**
```ts
export class ShedDraftResult {
  texts: string[];
  counts: number[];
  constructor(texts: string[], counts: number[]);
}

export function recompute(snapshot: string[], editingRow: number,
                          typedText: string): ShedDraftResult;
```

**实现要点**
1. `base = snapshot.slice()`；若 `editingRow` 在范围内 → `base[editingRow] = typedText`。
2. `sets = ownedSets(base)`；`texts = renormalize(base)`。
3. 若在编辑：`texts[editingRow] = typedText`（编辑行永远显示用户原样输入）。
4. `counts[i] = sets[i].length`。

**测试**（`ShedDraftTest.java` 全量）
- 逐字符敲 `"1-15"`：末帧 `["16-40","1-15"]`，counts 25/15。
- 敲第一个 `"1"`：`["2-40","1"]`，counts 39/1。
- `"16-4"` 半成品：首行 `"1-3 17-40"`；输完 `"16-40"` 后恢复 `["1-15","16-40"]`，counts 15/25。
- 编辑行 `"24-40 1-20"` 原样保留；首行 `"21-23"`，counts 3/37。
- 清空：首行 `"1-40"`、编辑行 `""`，counts 40/0。

**提交** `feat(model): 棚号输入快照重推 ShedDraft`

---

### 任务 5：`ShedDeletePlan`（删除去向）

**Files**
- 新增 `entry/src/main/ets/model/ShedDeletePlan.ets`
- 新增 `scripts/model-tests/shed-delete-plan.test.mjs`

**Interfaces**
```ts
export class ShedDeletePlan {
  fallback: number[];
  permanent: number[];
  static of(declaredTexts: string[], row: number, targets: number[]): ShedDeletePlan;
  hasFallback(): boolean;
  hasPermanent(): boolean;
}
```

**实现要点**
- targets 去重升序（先 `slice().sort((a,b)=>a-b)`，再跳过 `<=0` 与重复）。
- 对每个号 `n`：扫描 `i in [0, min(row, declaredTexts.length))`，
  任一 `parseShedNumbers(declaredTexts[i]).indexOf(n) >= 0` → fallback，否则 permanent。
- 只看本行**上方**，不看向下。

**测试**（`ShedDeletePlanTest.java` 全量）
- `["1-40","1-15"], row=1, [1,2,3,15]` → fallback 全中，permanent 空。
- `row=0, [5,6]` → permanent `[5,6]`。
- `["1-20","1-9 30"], row=1, [30,5]` → fallback `[5]`、permanent `[30]`。
- `["1-40","20-30"], row=1, [25]` → fallback `[25]`（看区间展开，不看字符串包含）。
- `["","","5"], row=1, [5]` → permanent `[5]`。
- 空 targets / 空 declared → 两桶都空。

**提交** `feat(model): 删除去向判定 ShedDeletePlan`

---

### 任务 6：`FeedData` 增加派生显示与直写棚数

**Files**
- 修改 `entry/src/main/ets/model/FeedData.ets`
- 新增 `scripts/model-tests/feed-data.test.mjs`

**改动**
1. 新字段（**不进 JSON**，载入后由覆盖重算）：
   ```ts
   shedDisplay: string = '';
   ```
2. `setShedNumber(value)`：赋值后 `this.shedDisplay = ''`，再 `calculateShedCount()`。
3. 新增：
   ```ts
   getShedDisplay(): string;                 // 空则回落 shedNumber
   setShedDisplay(value: string): void;
   setShedCountDirectly(count: number): void; // 只写 shedCount，不重算平均
   clearDerived(): void;                      // 清平均/料/水/称料/换料比例/手动标记（不含棚号）
   hasRowData(): boolean;                     // 供 RowSettlement 用
   ```
   `clearDerived` 与 `hasRowData` 是把 `RowSettlement` 里重复的字段清单收敛到一处。
4. `toJson/fromJson` 不动；`BatchStore.load` 后表格首次 `applyShedCoverage()` 会填好显示。

**测试**
- `setShedNumber("1-40")` → count 40；`getShedDisplay()` 回落 `"1-40"`；
  `setShedDisplay("16-40")` → `getShedDisplay()==="16-40"`；
  再 `setShedNumber("1-40 50")` → 显示清空回落 `"1-40 50"`。
- `setShedCountDirectly(0)` 不改平均/料量。
- `clearDerived()` 把 average/fermented/powder/f03/f05/f10/water/weighed/switchRatio
  清 0、`isAverageManuallyModified=false`，`shedNumber` 保留。
- `hasRowData()` 对全零行 false，任一字段非零或手动标记 true。

**提交** `feat(model): FeedData 派生显示与棚数直写`

---

### 任务 7：`RowSettlement` 行回收

**Files**
- 修改 `entry/src/main/ets/model/RowSettlement.ets`
- 新增 `scripts/model-tests/row-settlement.test.mjs`

**Interfaces**
```ts
export class RowSettleResult {
  removed: number[];
  changed: boolean;
  constructor();
}

export function recycleDeadRows(rows: FeedData[], emptiedByUser: number[]): number[];
export function settleRows(rows: FeedData[], emptiedByUser: number[]): RowSettleResult;
```

`settleZeroRowData` 保留（Index 里暂时还有调用；任务 13 再换掉）。

**实现要点**
- `recycleDeadRows`：
  1. `texts` 取每行 `shedNumber`（空串兜底）；
  2. `owned = ownedCounts(texts)` —— **按申明文本重算，不看缓存 shedCount**；
  3. `owned[i]===0` 且（`hasContent` 或 `emptiedByUser` 含 i）→ 记入 dead；
  4. `hasContent = shedNumber.trim() !== '' || row.hasRowData()`；
  5. 从后往前 `rows.splice(idx, 1)`（先记录升序下标，倒序删）。
- `settleRows`：
  1. `total = rows.length`；
  2. `removed = recycleDeadRows(rows, emptiedByUser)`；
  3. `changed = settleZeroRowData(rows) || removed.length > 0`；
  4. 底部补 `removed.length` 个 `new FeedData()`，保持总行数；
  5. 返回结果。**先回收再兜底清**，顺序不能反。

**测试**
- `RowSettlementTest` 4 条：清料保棚号 / 有棚不动 / 忽略空行 / 混合列表只清 0 棚行。
- `RowSettlementRecycleTest` 7 条全部直译：
  `removesDeadRowAndShiftsBelow`、`keepsAliveRowsAndPureEmptyRows`、
  `multipleDeadRowsRemovedTogether`、`threeCoveredRowsRemovedInOnePass`、
  `allEmptyListUntouched`、`rowEmptiedByDeletingAllShedsIsRecycledAndBelowShiftsUp`、
  `pureEmptyRowStaysWhenNothingWasEmptied`、`emptiedSetIgnoredWhenRowStillHasSheds`。
- 额外 `settleRows`：删 1 行后 `rows.length` 回到原值，末尾是新空行。

**提交** `feat(model): 失焦结算行回收与补空行`

---

### 任务 8：中英文案

**Files**
- 修改 `entry/src/main/ets/common/Strings.ets`

**新增 key（ZH / EN 各一份）**

| key | ZH | EN |
|---|---|---|
| `shed.more` | 棚号操作 | Shed actions |
| `shed.selectAll` | 全选 | Select all |
| `shed.invert` | 反选 | Invert |
| `shed.delete` | 删除 | Delete |
| `shed.transferOut` | 转出 | Move out |
| `shed.transferIn` | 转入 | Move in |
| `shed.transferWholeToBlank` | 整行转到空行等于把整行挪下去，请直接在目标行填写棚号 | Moving a whole row into an empty row just shifts the row down. Type the shed numbers in the target row instead. |
| `shed.deleteTitle` | 删除棚号 | Delete shed numbers |
| `shed.deleteMsg` | 删除已选的 %d 个棚号？删除后这些棚不再参与算料。 | Delete the %d selected shed numbers? They will no longer be counted. |
| `shed.deleteMsgFallback` | 这 %d 个棚号上面还有行填着，删掉后会退回那些行继续算料，不会消失。 | The rows above still declare these %d sheds, so they will fall back to those rows and keep being counted. |
| `shed.deleteMsgPermanent` | 这 %d 个棚号没有来路可退，删掉后全表都不再有了：%s | These %d sheds have no row above to fall back to. They will be gone from the whole table: %s |
| `shed.deleteMsgMixed` | 这 %d 个棚号里，%d 个上面还有来路、会退回；另外 %d 个没有来路，将被真正删除：%s | Of these %d sheds, %d fall back to rows above; the other %d will be permanently deleted: %s |

`t()` 不支持位置参数，用链式 `.replace()` 按顺序替换（第一个 `%d` 是总数，接着 fallback、
再 permanent、最后 `%s`）。

**验证** 启动中英各看一次气泡菜单与删除确认框（预览器即可），确认无 `%d` 残留。

**提交** `feat(i18n): 棚号操作中英文案`

---

### 任务 9：表格覆盖两层 + 编辑快照生命周期

**Files**
- 修改 `entry/src/main/ets/table/MixCalcTable.ets`
  - import：`ShedDraft`、`ShedDisplay`、`ShedText`、`ShedCoverage.renormalize/ownedSets`（去掉不再直接用的 `ownedCounts` 可保留）
  - 字段区（`editingRow` 附近）
  - `applyShedCoverage`（约 865）
  - `applyEdit`（约 894）
  - `openEditor`（约 1436）
  - `finishEdit`（约 962）

**新增私有状态**
```ts
private shedEditActive: boolean = false;
private shedEditRow: number = -1;
private shedEditSnapshot: string[] = [];
```

**新增私有方法**
```ts
private snapshotShedTexts(): string[];
private beginShedEdit(row: number): void;   // 拍快照 + active=true
private endShedEdit(): void;                // active=false、row=-1、snapshot=[]
```

**`applyShedCoverage` 改成两层**

```ts
private applyShedCoverage(): void {
  if (this.rows.length < 1) return;
  const texts: string[] = this.snapshotShedTexts();

  const liveTyping: boolean = this.shedEditActive
    && this.shedEditSnapshot.length === texts.length
    && this.shedEditRow >= 0 && this.shedEditRow < texts.length;

  let counts: number[] = [];
  let canonical: string[] = [];
  if (liveTyping) {
    const draft: ShedDraftResult = ShedDraft.recompute(
      this.shedEditSnapshot, this.shedEditRow, texts[this.shedEditRow]);
    counts = draft.counts;
    canonical = draft.texts;
  } else {
    canonical = renormalize(texts);
    const sets: number[][] = ownedSets(texts);
    for (let i = 0; i < sets.length; i++) counts.push(sets[i].length);
  }

  for (let i = 0; i < this.rows.length; i++) {
    const row: FeedData = this.rows[i];
    const oldCount: number = row.shedCount;
    const oldAverage: number = row.average;
    row.setShedDisplay(canonical[i]);      // 只改显示，不回写声明
    const count: number = counts[i];
    if (oldCount !== count) {
      row.setShedCountDirectly(count);
      if (oldAverage > 0) {
        row.setAverageManually(oldAverage, this.fermentedInAverage);
      }
      row.recalculateDerivedOnly(this.waterPercentage, this.fermentedInWater,
        this.fermentedInAverage);
    }
  }
}
```

> 注意：`setAverageManually` 是否真的生效取决于 `canEditAverage()`；与安卓
> `setAverageManually` 一致即可，不要额外加条件。

**`applyEdit`（col===1 分支）**
保持现有 `row.setShedNumber(value)` + 旧平均重算，只把收尾的 `recomputeFirstRow()`
保留（它现在走上面的两层）。**不要**在 `applyEdit` 里清快照。

**`openEditor` 顺序（关键，防行下标平移）**

```
1. row 越界直接 return。
2. column===2（棚数按钮）：见任务 11「点棚数打开气泡」的流程，不放这里。
3. 不可编辑/被禁用/顺序拦截 → return（同现状）。
4. 若已经在编辑同一格 → requestFocus 后 return。
5. const targetRef = this.rows[row];          // 先记住对象
6. if (this.shedEditActive) this.endShedEdit();
7. if (正在编辑且 dirty) this.applyEdit(this.editingText, true);
8. this.editDirty = false;
9. this.settleRowsAndPad([]);                 // 可能删行
10. const idx = this.rows.indexOf(targetRef); if (idx < 0) return; row = idx;
11. 打开编辑器（现有逻辑）
12. if (column === 1) this.beginShedEdit(row);
```

**`finishEdit`**

```
1. 若在编辑：保存 row/text/dirty → editingRow=-1、editingCol=-1、editingSeed=''、
   editDirty=false → stopCaret() → endShedEdit() → 若 dirty 则 applyEdit(text, true)
2. 否则 endShedEdit()。
3. this.settleRowsAndPad([])。
4. 若上面发生删除/清理，可选再 applyShedCoverage() 一次（settleRowsAndPad 内部已做）。
```

**`settleRowsAndPad(emptied)`**
```ts
private settleRowsAndPad(emptied: number[]): void {
  const result: RowSettleResult = settleRows(this.rows, emptied);
  if (result.removed.length === 0 && !result.changed) return;
  this.editingRow = -1;
  this.editingCol = -1;
  this.editRow = -1;
  this.editCol = -1;
  this.endShedEdit();
  this.shedListOpen = false;
  this.clearPendingTransfer();
  this.applyShedCoverage();
  this.version = this.version + 1;
  this.onChanged();
}
```
（`clearPendingTransfer` 在任务 11 才存在；本任务先留 TODO 注释，任务 11 补上。）

**验证**
- `hvigor assembleHap` 通过。
- 手工：第 1 行 `1-40`、第 2 行 `1-15` → 第 1 行格子显示 `16-40`、棚数 25；
  把第 2 行删空 → 第 1 行自动回到 `1-40`。

**提交** `feat(table): 打点覆盖两层与棚号编辑快照`

---

### 任务 10：棚号列两行显示 + 固定字号 + 72vp

**Files**
- 修改 `entry/src/main/ets/common/LayoutRules.ets`
- 修改 `entry/src/main/ets/table/MixCalcTable.ets`（`cellText` 约 682、`cellView` 约 1822）

**改动**
1. `LAYOUT_WIDTHS = [40, 72, 40, 40, 60, ...]`，注释改成「合计 612：窗口宽度不到 612 时横向滚动」。
2. `cellText` 的 `case 1`：
   ```ts
   case 1: return ShedDisplay.render(row.getShedDisplay()).join('\n');
   ```
   其余列不变；棚数为 0 时料列留白的判断不变。
3. `cellView`：
   - `.fontSize(this.fs())`（保持 15vp，vp 不随系统字体缩放）；
   - `.lineHeight(18)`；
   - `.maxLines(col === 1 ? 2 : 1)`；
   - `.textOverflow({ overflow: col === 1 ? TextOverflow.Clip : TextOverflow.Ellipsis })`；
   - 棚号格的字重/颜色/对齐不变。
4. 编辑器（`TextInput`）宽度自动跟 `cw(1)`（现已是 `this.cw(this.editingCol)`），字号不变；
   编辑时看到的仍是 `shedNumber` 原文，不是折叠串。

**验证**
- 预览器/真机输入 `1 3-15 18 20 22 25-32` → 格子两行 `1…3-15` / `…25-32`，
  不出现第三个 `…`、不把 `3-15` 切断。
- 输入 `101-105 107 109` → 两行 `101-105` / `107 109`，不裁字。
- 系统字体调到最大，棚号列字号不变（其余列同样不变）。

**提交** `feat(table): 棚号列固定字号、两行折叠与 72vp 列宽`

---

### 任务 11：气泡选中 / ⋮ 菜单 / 转出 / 转入

**Files**
- 修改 `entry/src/main/ets/table/MixCalcTable.ets`
  - 状态区（约 382-391）
  - `showShedList`（约 1368）
  - 新增 `closeShedList`、`toggleShedSelected`、`selectAllSheds`、`invertSheds`
  - 新增气泡菜单 overlay（复用 `colMenuOpen` 的写法，约 2180 附近）
  - `openEditor` 开头（待转池作废）

**新增状态/字段**
```ts
@State shedSelected: number[] = [];
@State shedMenuOpen: boolean = false;
@State shedMenuX: number = 0;
@State shedMenuY: number = 0;
@State shedMenuItems: string[] = [];
private shedMenuActions: string[] = [];
private shedMenuOpenedAt: number = 0;
private shedListRow: number = -1;
private keepPendingOnDismiss: boolean = false;

private pendingTransferNumbers: number[] = [];
private pendingTransferSourceRow: number = -1;
```

**点棚数打开气泡（防行下标平移）**

`openEditor(row, 2)` 里不要「先 finishEdit 再直接用 row」，改成：

```ts
if (column === 2) {
  const targetRef: FeedData = this.rows[row];   // 先记对象
  this.finishEdit();                            // 可能结算并回收行
  const idx: number = this.rows.indexOf(targetRef);
  if (idx < 0) {
    return;                                     // 这一行自己刚被回收
  }
  this.showShedList(idx);
  return;
}
```

同时把现有 `showShedList` 开头的 `this.finishEdit()` 删掉（不要在气泡里二次结算）。

**行为**
1. `hasPendingTransfer()` / `clearPendingTransfer()` / `startPendingTransfer(row, selected)`。
2. `showShedList(row)`：
   - 删除「`shedCount<=0` 直接 return」；
   - 打开条件改为：`numbers.length > 0 || getShedDisplay().trim() !== '' || canTransferIn`；
   - `canTransferIn = hasPendingTransfer() && row !== pendingTransferSourceRow`；
   - `shedListRow = row`；`shedSelected = []`；`shedListOpen = true`。
3. `closeShedList(keepPending: boolean)`：
   ```
   shedListOpen=false; shedMenuOpen=false; shedSelected=[];
   if (!keepPending) clearPendingTransfer();
   keepPendingOnDismiss=false;
   ```
   气泡遮罩点击 → `closeShedList(false)`。
4. chip 点击 → `toggleShedSelected(n)`（数组增删）；颜色：
   `selected ? '#2F6FED'/'#FFFFFF' : '#A8DDB5'/'#000000'`。
   `ForEach` key 必须带选中态：`'s' + n + (selected ? '_1' : '_0')`，否则不刷新。
5. `showShedMenu()`（点 ⋮）：
   - items：`全选`、`反选`；`shedSelected` 非空时追加 `删除`、`转出`；
     `hasPendingTransfer() && shedListRow !== pendingTransferSourceRow` 时追加 `转入`；
   - 位置：`x = max(6, shedListX + shedListW - listPopupWidth() - 10)`，
     `y = shedListY + 40`，并 clamp 在 `viewH` 内；`shedMenuOpenedAt = Date.now()`。
6. `handleShedMenuChoice(i)`：
   - 全选：`shedSelected = numbers.slice()`；反选：差集；
   - 删除：`confirmDeleteShedNumbers()`（任务 12）；
   - 转出：`startPendingTransfer(shedListRow, shedSelected)`；
     `keepPendingOnDismiss = true`；`closeShedList(true)`；
   - 转入：`applyTransferIn(shedListRow)`；`closeShedList(false)`。
7. `applyTransferIn(targetRow)`（直译安卓 1403-1480）：
   ```
   if (!hasPendingTransfer() || targetRow === pendingTransferSourceRow) { clear; return; }
   numbers/sourceRow 快照；
   oldSource/oldTarget；
   if (pointlessWholeRowMove(oldTarget, shedNumbersOf(sourceRow), numbers)) {
     toast('shed.transferWholeToBlank'); clear; return;
   }
   const moved = ShedText.transfer(oldSource, oldTarget, numbers);
   clearPendingTransfer();
   this.commitShedText(sourceRow, moved[0]);
   this.commitShedText(targetRow, moved[1]);
   this.rewriteToOwned(sourceRow);
   this.rewriteToOwned(targetRow);
   this.forceRecomputeRows([sourceRow, targetRow]);
   // 被转空的行：shedCount<=0 且原来有内容 → 放进 emptied
   this.settleRowsAndPad(emptied);
   ```
8. `rewriteToOwned(row)`：`ownedSets(all texts)[row]` → `ShedText.normalize`；
   与当前 `shedNumber.trim()` 不同才 `commitShedText`。
9. `forceRecomputeRows(rows: number[])`：`applyShedCoverage()` + 对每行
   `updateAllCalculations(...)` + `version++` + `onChanged()`。
10. **任何一次按下作废待转池**：`openEditor` 开头
    ```ts
    if (this.hasPendingTransfer()
        && !(column === 2 && row !== this.pendingTransferSourceRow)) {
      this.clearPendingTransfer();
    }
    ```
    另外 `showColumnMenu`、`resetAll`、`aboutToDisappear` 也调用 `clearPendingTransfer()`。

**验证（手工）**
- 第 1 行 `1-40`，点棚数：点 `5` 变蓝，⋮ → 转出；关掉气泡 → 待转池作废。
- 再转出 `5`，点第 2 行棚数 → ⋮ 有「转入」；转入后第 1 行 `1-4 6-40`、第 2 行 `5`。
- 往上转：第 3 行 `25` 转入第 1 行 `1-40` → 第 1 行仍 `1-40`、第 3 行空并回收上顶。
- 整行 `26-35` 转入空行 → toast 拦截，不闪屏。

**提交** `feat(table): 棚号气泡选中、菜单、转出转入`

---

### 任务 12：删除 + 去向确认 + 行回收

**Files**
- 修改 `entry/src/main/ets/table/MixCalcTable.ets`

**新增**
```ts
private shedDeleteRow: number = -1;
private shedDeleteTargets: number[] = [];
private shedDeleteTitle: string = '';
private shedDeleteMessage: string = '';
private shedDeleteController: CustomDialogController = new CustomDialogController({
  builder: ConfirmDialog({
    title: this.shedDeleteTitle,
    message: this.shedDeleteMessage,
    cancelText: t(this.lang, 'btn.cancel'),
    confirmText: t(this.lang, 'shed.delete'),
    confirmColor: '#D32F2F',
    onConfirm: () => { this.doDeleteShedNumbers(); }
  }),
  autoCancel: true,
  customStyle: true
});
```

**行为**
1. `confirmDeleteShedNumbers()`：
   - `targets = shedSelected.slice().sort((a,b)=>a-b)`；空则 return；
   - `clearPendingTransfer()`；
   - `declared = this.snapshotShedTexts()`；
   - `plan = ShedDeletePlan.of(declared, shedListRow, targets)`；
   - `shedDeleteRow = shedListRow; shedDeleteTargets = targets;`
   - `shedDeleteTitle = t(lang,'shed.deleteTitle')`；
   - `shedDeleteMessage = this.buildShedDeleteMessage(plan)`；
   - `shedDeleteController.open()`。
2. `buildShedDeleteMessage(plan)`：
   - permanent>0 且 fallback>0 → `shed.deleteMsgMixed`，
     依次 replace 总数、fallback 数、permanent 数、`compactNumberList(permanent)`；
   - 只有 permanent → `shed.deleteMsgPermanent`；
   - 否则 → `shed.deleteMsgFallback`。
3. `compactNumberList(numbers)`：`ShedText.normalize`；长度 >80 时取前 12 个 +
   `' …（共 N 个）'`（英文用 `' … (%d total)'` 可简化，保持与安卓近似即可）。
4. `doDeleteShedNumbers()`：
   ```
   const row = this.shedDeleteRow;
   if (row < 0 || row >= this.rows.length) return;
   const data = this.rows[row];
   const oldText = data.shedNumber;
   const newText = ShedText.remove(oldText, this.shedDeleteTargets);
   this.closeShedList(false);              // 先关气泡，避免回调攥着旧行号（但保留 row）
   if (newText !== oldText) {
     this.commitShedText(row, newText);
   }
   const emptied: number[] = [];
   if (data.shedNumber.trim() === '' && data.shedCount <= 0) emptied.push(row);
   this.settleRowsAndPad(emptied);
   ```
   `settleRowsAndPad` 里已经 `editingRow=-1` 再删行，不会出现编辑器错位。
5. `commitShedText(rowIndex, text)`（任务 11 已引入，这里补实现）：
   ```
   const row = this.rows[rowIndex];
   const oldCount = row.shedCount;
   const oldAverage = row.average;
   row.setShedNumber(text);
   if (row.shedCount !== oldCount && oldAverage > 0 && row.canEditAverage()) {
     row.setAverageManually(oldAverage, this.fermentedInAverage);
   }
   this.applyShedCoverage();
   row.updateAllCalculations(...);
   this.version++;
   this.onChanged();
   ```

**删除语义（必须遵守）**
- 只动**本行声明**；上方有来路的号会自动退回，不要从全表每行一起删。
- 删除后本行棚号为空且棚数 0 → 该行属于「用户刚掏空」，必须回收上顶、底部补空行。
- 删除确认正文必须点名「真正永久消失」的号码。

**验证（手工）**
- 第 1 行 `1-40`、第 2 行 `1-15`；第 2 行删 `1-5` → 第 1 行 `6-15`? 
  （实际：第 1 行显示 `16-40`，第 2 行删掉 1-5 后显示 `6-15`）。
- 第 2 行全部删光 → 第 2 行回收，第 3 行上顶，底部补空行，总行数不变。
- 顶行删 `5`：确认框显示「没有来路可退…5」，删除后全表不再有 5。

**提交** `feat(table): 棚号删除确认、按行声明剔除与行回收`

---

### 任务 13：Index 结算接入

**Files**
- 修改 `entry/src/main/ets/pages/Index.ets`

**改动**
1. import：`settleZeroRowData` → `settleRows`、`RowSettleResult`。
2. 新增：
   ```ts
   private settleCurrentBatch(): void {
     if (this.batches.length === 0) return;
     const result: RowSettleResult = settleRows(this.currentBatch().rows, []);
     if (result.removed.length > 0 || result.changed) {
       this.refreshTick = this.refreshTick + 1;
     }
   }
   ```
3. `switchBatch` 第 379 行：`settleZeroRowData(...)` → `this.settleCurrentBatch();`。
4. `onPageHide` 第 599 行：同样替换。
5. （可选）`load` 完成后调用一次 `settleCurrentBatch()`，对齐安卓「载入即结算」。

**验证**
- 切批次/退后台后再回来：0 棚死行已回收、总行数仍是 30、数据已落盘。
- 两个批次互不影响。

**提交** `feat(pages): 切批次与退出时行回收结算`

---

### 任务 14：版本、CHANGELOG、构建与手动验收

**Files**
- 确认 `AppScope/app.json5`：`versionName "0.3.6"` / `versionCode 1000306`（保持现状）。
- 修改 `CHANGELOG.md`：在 `[0.3.6] - 2026-11-08` 下补「新增」「修复」条目：
  - 棚号文本按实际归属显示（`1-40` 被下行 `1-15` 覆盖后显示 `16-40`）；
  - 输入棚号时按快照逐字重推，半成品区间不会永久抢走别人的号；
  - 棚号气泡支持选中、全选/反选、删除、转出/转入；
  - 删除只动本行声明，能退回的号自动退回，并在确认框点名永久删除的号；
  - 棚数为 0 且有内容的死行结算时整行回收，底部补空行；
  - 棚号列固定字号、两行折叠显示，列宽 60→72vp。
- 删除 `docs/` 下与本版本无关的临时计划（若存在），保留本计划。

**构建**
```powershell
node scripts/run-model-tests.mjs
# 全绿后
.\scripts\build-release-app.ps1     # 需要 $env:MIXCALC_P12_PWD
```
（不想出 release 包时，至少跑一次 `assembleHap` debug。）

**手动验收清单（逐条打勾，任一不过不算完成）**
1. 第 1 行 `1-40`、第 2 行 `1-15` → 第 1 行显示 `16-40`、棚数 25、料量按 25 算。
2. 第 2 行改成 `1-5` → 第 1 行退回 `6-40`、棚数 35。
3. 第 2 行删空 → 第 1 行回到 `1-40`；第 2 行回收上顶，底部补空行，总行数不变。
4. 输入 `16-40` 途中 `16-4`：第 1 行短暂变化，输完立刻恢复。
5. 气泡选中绿↔蓝；全选/反选正确；转出后关气泡 = 作废；点另一行棚数可转入。
6. 往下转、往上转各一次，两边文本与棚数都真的换主人；来回转能回到原样。
7. 整行转入空行被拦截（toast），屏幕不闪。
8. 删除确认框：有来路显示「会退回」，无来路点名具体号码。
9. 棚号 `1 3-15 18 20 22 25-32` 两行显示且区间不被切断；系统字体最大时棚号字号不变。
10. 中英文各走一遍菜单与确认框，无 `%d` / `%s` 残留。
11. 切批次/退后台再进入：数据正确、无中间空洞行。

**提交** `chore: 0.3.6 棚号账本移植完成说明与构建`

---

## 5. 执行顺序与依赖

```
任务 0 → 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8
                                    ↓
                        9 → 10 → 11 → 12 → 13 → 14
```

- 任务 1-7 每完成一个就应让 `node scripts/run-model-tests.mjs` 全绿。
- 任务 9 依赖 2/4/6/7；任务 11 依赖 1/5；任务 12 依赖 1/5/11。
- 任务 9 里 `settleRowsAndPad` 的 `clearPendingTransfer()` 若尚未存在，
  先写空实现注释，任务 11 补实际逻辑（避免任务 9 编译不过）。

## 6. 已知坑（实现时对照）

1. **行下标平移**：`finishEdit` 可能回收行，`openEditor(row, …)` 的 `row` 会失效；
   必须像任务 9 那样先记对象引用再 `indexOf`。
2. **`renormalize` 不能清空被整行覆盖的文本**，否则回收后表中间留洞。
3. **`Text.maxLines(2)` 不是折叠**：必须 `ShedDisplay.render` 产生 `\n`，再交给 `Text`。
4. **`ForEach` 的 key 必须包含选中态**，否则 chip 颜色不刷新。
5. **`setShedDisplay` 后不要立刻 `setShedNumber`**，否则声明被改写、退不回。
6. **结算顺序**：先回收（看 `hasContent`），再兜底清；反了会把「只剩数据的脏行」漏成中间空行。
7. **`applyShedCoverage` 比较 `oldCount` 必须在写显示文本之前取**，否则永远相等、料量不重算。
8. **ArkTS 没有 `Array.remove`**：用 `indexOf` + `splice`。
9. 控制台中文常乱码，核对文案用 `read`/`grep` 工具看文件，不要信 `Get-Content` 输出。
