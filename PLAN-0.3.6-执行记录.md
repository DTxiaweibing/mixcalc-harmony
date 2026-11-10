# 鸿蒙版对齐安卓 0.3.5 → 0.3.20 执行记录

> 目标：读取 `D:\mixcalc-lab`（安卓）从 0.3.5 到当前（0.3.20 / versionCode 23）的全部进化，
> 应用到 `D:\mixcalc-harmony`（鸿蒙）。按小任务逐步改代码、逐步跑测试、逐步记录，
> 最后用 `D:\command-line-tools` 工具链打调试包，经 `hdc` 推送到手机 `192.168.10.103:42085`。
>
> 业务准绳：`D:\mixcalc-lab\docs\棚号与表格逻辑-0.3.6至0.3.19完整改动与移植说明.md`
> 执行计划：`docs/superpowers/plans/2026-11-09-harmony-shed-ledger-0.3.6.md`
> 签名材料：`D:\mixcalc-sign`（发布证书 / p7b / p12，release 包用）

## 起点核对（2026-11-10）

| 项 | 状态 |
|---|---|
| 安卓当前版本 | 0.3.20 / versionCode 23，release 包 `dist/mixcalc-0.3.6-shed-ledger.apk` |
| 鸿蒙当前版本 | 0.3.6 / versionCode 1000306（`AppScope/app.json5`），功能水平≈安卓 0.3.7 |
| 鸿蒙缺口 | renormalize、ShedDisplay 两行折叠、ShedDraft 快照、ShedText 转移/删除、ShedDeletePlan、行回收、气泡选中/菜单/转出转入/删除、编辑快照生命周期、棚号列 72vp |
| 版本规则 | 0.3.9 / 0.3.12 / 0.3.14 的旧规则已被 0.3.20 取代，按移植说明第 3、4 章实现 |
| 任务 0（测试跑车） | 已完成：`scripts/run-model-tests.mjs` + `scripts/model-tests/feed-data.test.mjs`，`node scripts/run-model-tests.mjs` → `✓ 1 assertions` |
| 工具链 | `D:\command-line-tools\command-line-tools`（hvigorw / hdc / SDK tsc） |
| 手机 | `hdc tconn 192.168.10.103:42085` → `Connect OK` |

## 逐步记录

### 任务 0 · 环境与测试跑车（已完成，上一轮遗留）
- `node -v` → v22.22.2；`node scripts/run-model-tests.mjs` → 编译 3 个模型文件，`✓ 1 assertions`，退出码 0。
- 工作区未提交：`scripts/run-model-tests.mjs`、`scripts/model-tests/feed-data.test.mjs`、`.gitignore`（追加 `scripts/.model-test-build/`）。
- 决定：继承已有 15 步计划，从任务 1 开始；每步「改码 → 跑测试 → 编译 → 提交 → 记录」。

### 任务 1 · ShedRange + ShedText（纯函数）
- 新增 `model/ShedRange.ets`：`compressNumbers(number[])`，升序去重、连续≥3 才写区间、空格分隔。
- 新增 `model/ShedText.ets`：`normalize` / `transfer` / `pointlessWholeRowMove` / `remove`；`remove` 能拆区间（`1-40` 去 5 → `1-4 6-40`），一个都没删到时原样返回。
- 新增 `scripts/model-tests/shed-text.test.mjs`：66 个断言点，含 ShedTextTest 全量 + ShedTransferTest 端到端流程。
- 提交 `251a01e`。

### 任务 2 · ShedCoverage.renormalize
- `ShedCoverage.ets` 追加 `renormalize(texts)`：只重写「被占走部分号码」的行，`owned` 为空时原样保留（0 棚行交给行回收）。
- 新增 `shed-coverage.test.mjs`（10 个断言点，含幂等与空串）。
- 提交 `9c29a9a`。

### 任务 3 · ShedDisplay 两行极简折叠
- 新增 `model/ShedDisplay.ets`：`render(rawText)`，逐行直译 Java；A-1/A-2/B-1/B-2 四分支、9 字符/行、区间不切断、唯一区间只露一次。
- 新增 `shed-display.test.mjs`（8 个断言点，覆盖 12 组期望 + 行长/行数约束）。
- 提交 `bf47682`。

### 任务 4 · ShedDraft 快照重推
- 新增 `model/ShedDraft.ets`：`recompute(snapshot, editingRow, typedText)`；快照深拷贝、每字符从快照重推、编辑行保留原文。
- 新增 `shed-draft.test.mjs`（20 个断言点，逐字符前缀断言 + 半成品回滚）。
- 提交 `a3be105`。

### 任务 5 · ShedDeletePlan
- 新增 `model/ShedDeletePlan.ets`：`of(declaredTexts, row, targets)` 只看上方行，分 `fallback` / `permanent` 两桶。
- 新增 `shed-delete-plan.test.mjs`（23 个断言点，含区间展开、下方行不算来路）。
- 提交 `c2ac7f0`。

### 任务 6 · FeedData 派生显示与棚数直写
- `FeedData.ets`：新增 `shedDisplay`（不落盘）、`getShedDisplay` / `setShedDisplay` / `setShedCountDirectly` / `clearDerived` / `hasRowData`；`setShedNumber` 清显示；`fromJson` 清显示（R4）。
- `feed-data.test.mjs` 替换为 30 个断言点，保留冒烟断言与 `loadModel` helper。
- 提交 `9f00d09`。

### 任务 7 · RowSettlement 行回收与结算
- `RowSettlement.ets`：新增 `recycleDeadRows`（按申明文本 `ownedCounts` 重算、一次删完、纯空行不删）、`settleRows`（先回收再兜底清、底部补空行）、`RowSettleResult`；保留 `settleZeroRowData`。
- 新增 `row-settlement.test.mjs`（73 个断言点，含「三行被同一行覆盖且缓存滞后一次删完」）。
- 提交 `2e1d438`。

### 模型层阶段验收（任务 1-7）
- `node scripts/run-model-tests.mjs` → 编译 8 个模型文件，**✓ 328 assertions**，退出码 0。
- `hvigorw assembleHap -p product=default -p buildMode=debug --no-daemon` → **BUILD SUCCESSFUL in 2 min 46 s**（ArkTS 严格模式通过，仅既有 deprecated 警告）。
- 提交序列：`ca09556` → `251a01e` → `9c29a9a` → `bf47682` → `a3be105` → `c2ac7f0` → `9f00d09` → `2e1d438`。

### 任务 8 · 棚号操作中英文案
- `Strings.ets` ZH/EN 各加 12 个 key：`shed.more` / `shed.selectAll` / `shed.invert` / `shed.delete` / `shed.transferOut` / `shed.transferIn` / `shed.transferWholeToBlank` / `shed.deleteTitle` / `shed.deleteMsg` / `shed.deleteMsgFallback` / `shed.deleteMsgPermanent` / `shed.deleteMsgMixed`。
- 提交 `0cbb134`。

### 任务 9 · 表格打点覆盖两层 + 棚号编辑快照
- `MixCalcTable.ets`：
  - 新增 `snapshotShedTexts()`（取 `shedNumber` 声明文本）、`beginShedEdit()` / `endShedEdit()`，维护 `shedEditSnapshot` / `shedEditRow` / `shedEditActive`。
  - `applyShedCoverage()` 改为两层：**声明永不改写**，只写 `setShedDisplay()` 与 `setShedCountDirectly()`；`oldCount` 在写显示之前取出，棚数变了才按「平均 × 新棚数」重算料量。
  - 编辑中走 `recompute(快照, 编辑行, 当前输入)` 逐帧重推；非编辑态走 `renormalize + ownedSets`。
  - `settleZeroRows()` → `settleRowsAndPad()`，接 `settleRows`（回收 + 兜底清 + 补空行）。
- 提交 `4673e4e`。

### 任务 10 · 棚号列两行折叠 + 固定字号 + 72vp
- `LayoutRules.ets`：`LAYOUT_WIDTHS[1]` 60 → **72**。
- `MixCalcTable.ets`：`cellText()` 棚号列走 `renderShedDisplay()`（`\n` 分行），`cellView()` 棚号列 15vp 字号 + `lineHeight(18)` + `maxLines(2)` + Clip。
- 提交 `4673e4e`（与任务 9 同提交）。

### 编译验收（任务 8-10）
- 首次编译失败：`Module '"../model/ShedDraft"' has no exported member 'ShedDraft'` —— 按函数式导出误写成类调用，已改为 `import { recompute, ShedDraftResult }` + `recompute(...)`。
- 修正后 `hvigorw assembleHap -p product=default -p buildMode=debug --no-daemon` → **BUILD SUCCESSFUL in 1 min 57 s**。

### 任务 11 · 棚号气泡选中 / ⋮ 菜单 / 转出转入
- 气泡打开条件对齐安卓：`numbers` 非空 **或** 本行有棚号文本 **或** 有待转池可转入（空行也能当转入目标）。
- 号码块点选：绿底黑字（`#A8DDB5`/`#000000`）↔ 蓝底白字（`#2F6FED`/`#FFFFFF`）；ForEach key 带上选中位，保证换色即时生效。
- 表头新增 `⋮`（48×40 点击区）：全选 / 反选 / 删除 / 转出 / 转入；菜单右边缘对齐气泡右边缘，下方放不下就翻到气泡上方。
- 待转池：转出只记号码 + 来源行，**来源行数据一个字不改**；气泡自行关掉（不走遮罩点击，故无需 keepPending 标记）。
  作废时机＝遮罩点击关窗、点到别的格子、删除、行结算、视口尺寸变化。
- 转入：`transfer(来源原文, 目标原文, 号码)` 重写两边文本 → `rewriteToOwned` 按实际归属重排 → `forceRecomputeRows` 覆盖并重算派生值 → 两行一起交 `settleRowsAndPad` 回收。
  防呆 `pointlessWholeRowMove`：整行转给空行等于只挪一格，直接拦下并提示 `shed.transferWholeToBlank`。
- 新增 `commitShedText(row, text)`（对齐安卓 `commitCell(row,"shed_number",…)`）：改棚号 → 保持平均 → 重算料量 → 覆盖 → 落盘。
- 提交 `ab25dc2`。

### 任务 12 · 删除确认 / 只动本行 / 行回收
- `confirmDeleteShedNumbers`：`ShedDeletePlan.of(声明文本, 行, 目标)` 分 fallback / permanent 两桶，生成三类正文（全退回 / 全真删 / 混合），真删的号码用 `normalize()` 压成区间点名，超 80 字符只列前 12 个。
- `applyDeleteShedNumbers`：只把目标号码从**本行**申明里 `remove`（区间该拆就拆），绝不从全表每行删。
- 号删光且棚数 ≤ 0 → 行号进 `emptiedByUser` → `settleRowsAndPad` 一次删完、下面行上顶、底部补空行。
- 与任务 11 同提交 `ab25dc2`。
- 回归：`node scripts/run-model-tests.mjs` → **✓ 328 assertions**；`assembleHap` → **BUILD SUCCESSFUL in 2 min 1 s**。

### 修补 · 转入后的「来路」不能丢（用户提出）
- 用户质疑：来源行被转入/转出改过以后，后来的行想退回还有没有可能？会不会因为没快照就直接被删？
- 用模型代码跑探针验证（`1-40` 上、`1-15` 下，把 `20-24` 往下转）：
  - **安卓做法**（转完 `rewriteToOwned` 把两行声明裁成「只留实际占有的号」）：来源行从 `1-40` 变成 `16-19 25-40`，
    `1-15` 的申明记忆被抹掉；此后目标行清空，`1-15` **不会退回，直接被判成真删**。用户的怀疑成立。
  - **不裁剪**：来源行仍是 `1-40`，目标行清空后 `1-15` 与 `20-24` 原样退回。
- 结论：退回从来不靠快照——`ownedSets` 每帧按「还有哪一行在申明这个号」现算，**声明文本本身就是来路账本**。
  要保来路，只要不主动把声明裁掉。
- 改法：
  - 新增 `ShedText.giveDown(sourceText, targetText, numbers)`：**往下转**时来源行原文一字不动，只把号码并入目标行
    （后行优先，号本来就归下行，来源行不用让）。
  - **往上转**仍用 `transfer`：来源行在下面，不真松手号根本没走。
  - 删除 `MixCalcTable.rewriteToOwned()` 及其两处调用，并在代码里写明为什么不能裁。
- 新增 `scripts/model-tests/shed-transfer-provenance.test.mjs`（16 个断言点）：锁住「往下转后清空目标行，号退回来源行」
  「删掉来源行申明过的号 → 判退回；删掉没人申明过的号 → 判真删」「往上转来源行必须让出」，并把
  「重写成 owned 会丢来路」作为反面断言写进测试，防止以后有人"优化"回去。
- 回归：**✓ 344 assertions**；`assembleHap` → **BUILD SUCCESSFUL in 2 min 13 s**。
- 版本号维持 `0.3.6 / 1000306` 不动（市场当前是 0.3.5，0.3.6 尚未发布，发布时就用 0.3.6）。

### 任务 15 · 打包并推送到手机
- `hvigorw assembleHap -p product=default -p buildMode=debug` → `entry-default-signed.hap`（debug 自动签名），
  复制为 `dist/mixcalc-0.3.6-debug-signed.hap`（2.68 MB）。
- `hdc tconn 192.168.10.103:42085` → Connect OK；`hdc install -r -d` → `install bundle successfully`
  （中间装过一次 0.3.7 试验包，故带 `-d` 允许降级回 0.3.6）。
- `bm dump` 核对：`versionCode 1000306 / versionName 0.3.6`；`aa force-stop` + `aa start` 后正常出界面。
- 真机截图核对：棚号两行折叠正常（`10-20 / 22 24 26`、`28…36-46 / …50-60`），棚数 9/14/27 与号码对得上；
  点「棚数」弹出气泡「第 1 行棚号 / 共 9 个 / ⋮」，号码块点选绿底→蓝底生效。
- 待用户真机复核：⋮ 菜单项（选中后应出现「删除」「转出」）、转出→转入、清空下行看号码是否退回上行。
- 调试产物：`dist/mixcalc-0.3.6-debug-signed.hap`；截图 `dist/shot-0.3.6.jpeg`、`shot-bubble.jpeg`、`shot-select4.jpeg`。

### 任务 16 · 打正式发布包（上架用）
- 用 `scripts/build-release-app.ps1`，密码走 `MIXCALC_P12_PWD` 环境变量（不落盘、不写进 build-profile.json5）。
- 第一次带 clean 失败：`hvigor clean` 删 `entry\build` 被拦（`Unable to delete ... may be opened by another program` +
  批量删除保护），**不是代码问题**；工程配置在 finally 里已自动恢复（`signingConfig: 'default'` 仍在，无 `.bak` 残留）。
- 第二次 `-SkipClean` 成功：`assembleApp -p buildMode=release --no-codesign` → **BUILD SUCCESSFUL in 6 min 59 s**
  → `hap-sign-tool sign-app` 用 `D:\mixcalc-sign\mixcalc-release.p12`（别名 `mixcalc`）签出 `.app` 与 `.hap`。
- 签名校验 `verify-app` → **Verify success**；证书链 `Huawei CBG Root CA G2` → `Developer Relations CA G2` →
  `CN="夏卫兵(2069877646933652481), Release"`，**不是 debugKey**，符合 AGC 上架要求。
- 版本 `0.3.6 / 1000306`，bundleName `com.shrimpfarm.mixcalc`，设备类型 phone + tablet。
- 产物：`dist/mixcalc-0.3.6-release-signed.app`（1.82 MB，**上架只传这个**）、
  `dist/mixcalc-0.3.6-release-signed.hap`（2.16 MB，装机测试用）、`*.sha256`。
- 注意：发布签名与手机上的调试签名不同，**不能覆盖安装**，要装 release hap 必须先卸载旧包（会清本地数据）。

### 任务 17 · 真机反馈修复：两行显示被裁 / 棚号清不掉 / 列宽回归
用户真机测出三个问题，逐条定位并修复：

1. **棚号两行显示被裁成只剩一个「…」**：鸿蒙字体比安卓宽，72vp 配正文 15vp 字号放不下 9 字符行。
   修法：`fsShed()` 给棚号列单独固定 13vp 字号、`lineHeight` 15，正文列仍 15vp/18。
2. **所有行的棚号「删除 / 重置」清不掉，杀进程重启才空**：`clearRowData` 直接写 `row.shedNumber = ''`，
   绕过了 `setShedNumber()`，派生显示串 `shedDisplay` 没被清掉，格子继续显示老棚号；
   载入 JSON 不含显示串，所以只有重启才正常。
   修法：`clearRowData` 改走 `row.setShedNumber('')`；`finishEdit` 里棚号格无条件重算一次显示；
   `resetAll` 收尾清快照 + 重跑打点覆盖 + 全行重算 + 行结算，显示串、棚数、派生值一起归零。
3. **底部「重置」被横向滚动推到屏幕外**：表尾把重置格从滚动行里拿出来，钉在屏幕右边缘（`position x = viewW - cw(10)`）。
4. **棚号列宽不对（用户最终裁决）**：中途为塞下两行把 `LAYOUT_WIDTHS[1]` 一路加到 104vp，用户明确要求「改回来」。
   **恢复 0.3.5 基线 60vp**（`[40, 60, 40, 40, 60, …]`，合计 600），靠 13vp 小字号容纳两行，不靠加宽列。
   真机 `dumpLayout` 实测：棚号列 180px = 60vp，与 0.5料 / 水20% / 称料 完全一致；序号 / 棚数 / 平均 为 120px = 40vp。

验收：`node scripts/run-model-tests.mjs` → **✓ 344 assertions**；
`hvigorw assembleHap -p buildMode=debug --no-daemon` → **BUILD SUCCESSFUL in 1 min 52 s**；
`hdc install -r -d` 覆盖安装到 `192.168.10.103:42085` → `install bundle successfully`，
`aa force-stop` + `aa start` 后界面正常、无弹窗、重置按钮完整可点（截图 `dist/width-60-final.jpeg`）。
清理了临时探针 `scripts/model-tests/zz-probe.test.mjs`。

> 提醒：这轮改动发生在正式发布包之后，`dist/mixcalc-0.3.6-release-signed.app` 已过期，
> 用户测试通过后需要**重打一次发布包**再上架。

