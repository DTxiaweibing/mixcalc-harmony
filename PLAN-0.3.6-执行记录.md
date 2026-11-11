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
- 调试产物：`dist/mixcalc-0.3.6-debug-signed.hap`（真机验证截图已按用户要求清理，不再保留图片文件）。

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
`aa force-stop` + `aa start` 后界面正常、无弹窗、重置按钮完整可点。
清理了临时探针 `scripts/model-tests/zz-probe.test.mjs`。

> 提醒：这轮改动发生在正式发布包之后，`dist/mixcalc-0.3.6-release-signed.app` 已过期，
> 用户测试通过后需要**重打一次发布包**再上架。

### 任务 18 · 棚号列字号回调 14vp 并重新打调试包
- 用户裁决：只需把棚号列字号 `fsShed()` 从 **13vp → 14vp**，其它一律不动
  （列宽 60vp、`lineHeight 15`、`maxLines 2`、折叠算法、编辑/重置逻辑全部保持原样，均已真机测试通过）。
- 查证：`fs()` 正文 15vp、`fsHeader()` 表头 14vp、`fsShed()` 是上一轮新加的 13vp；
  安卓侧 `CellStyle` 正文 16sp、棚号列 `SHED_TEXT_SIZE_DP = 16`，并非「安卓要调小一号」，
  鸿蒙不需要跟着缩小。
- 本次 `git diff` 只有 1 行（`return '13vp'` → `return '14vp'`）。
- 用户清空了 `dist/`，故从空目录重新生成：先删掉 `entry/build/.../entry-default-signed.hap`
  与 unsigned hap 强制重打，再全量编译。
- 验收：模型测试 **✓ 344 assertions**；`assembleHap -p buildMode=debug --no-daemon`
  → **BUILD SUCCESSFUL in 2 min 23 s**；`dist/mixcalc-0.3.6-debug-signed.hap`
  （2.56 MB，18:32，SHA256 `713FE73BB879A99389D3BC9E2AFB2B44F84165A1A770E97B5F04C744F9D95DAE`）。
- `hdc tconn 192.168.10.103:42085` → `Connect OK`；`install -r -d` → `install bundle successfully`；
  `aa force-stop` + `aa start` → `start ability successfully`；`bm dump` 核对 `1000306 / 0.3.6`。
- 本轮未生成任何截图或界面树文件（用户已清理过一次）。

### 任务 19 · 棚号列宽 60vp → 72vp（14vp 字号显示不下）
- 用户真机反馈：字号回到 14vp 后棚号「还是没办法显示 / 显示不正常」，要求把棚号列加宽到 **72vp** 再试。
- 改动只有一处数值：`LAYOUT_WIDTHS[1]` 60 → 72，列宽合计 600 → 612；另同步两条已过时的注释
  （原注释写「靠 13vp 小字号、不靠加宽列」「合计 600」，与当前 14vp + 72vp 不符）。
- **明确不动**：`fsShed()` 仍 14vp、其余 10 列宽度、两行折叠算法（每行 ≤9 字符）、
  `lineHeight 15` / `maxLines 2`、编辑/清除/重置/转出转入逻辑、版本 `0.3.6 / 1000306`。
- `fillsAllColumns()` 用 `LAYOUT_WIDTHS` 求和动态算总宽，加宽后自动跟随，无需改代码；
  `TABLET_MIN_WIDTH` 仍 600，平板整体缩放逻辑不受影响。
- 验收：`node scripts/run-model-tests.mjs` → **✓ 344 assertions**；
  先删旧 `entry-default-signed.hap` / `entry-default-unsigned.hap` 强制重建，
  `CompileArkTS 54s` + `PackageHap` + `SignHap` 全部重跑 →
  **BUILD SUCCESSFUL in 1 min 58 s**（仅既有 deprecated / 异常告警）。
- 产物：`dist/mixcalc-0.3.6-debug-signed.hap`（2,686,169 B，18:58，
  SHA256 `142194215161F0511F7861F0B3E847DB51D6BDE7CDAF6EC4199D0235A9610175`，与上一版 `713FE73B…` 不同，确认是新包）。
- 推送：`hdc tconn 192.168.10.103:42085` → Connect OK（期间 WiFi 连接掉过两次，重连即可）；
  `install -r -d` → `install bundle successfully`；`aa force-stop` + `aa start` → 成功；
  `bm dump` 核对 `versionCode 1000306 / versionName 0.3.6`。
- 本轮未生成任何截图或界面树文件。
- 待用户真机看显示效果：若 72vp 仍被裁，下一步可选「字号回 13vp」或「继续加宽到 84vp」，
  由用户裁决后再动，不擅自多改。
- 提醒：这轮改动同样发生在正式发布包之后，`dist/mixcalc-0.3.6-release-signed.app` 依旧过期，
  定稿后必须**重打一次发布包**再上架。

### 任务 20 · 棚号字号 15vp + 列宽收到 68vp
- 用户先说「棚号字号也 15 号吧」，推包过程中又追加「把列宽改成 68 试试」。
  **最终交付状态：字号 15vp（与正文一致）+ 棚号列宽 68vp。**
- 中间态 `15vp @ 72vp` 曾打一版并推送（SHA256 `86fde882…e3ba`），用户随即要求收窄到 68vp，
  该中间包已被最终包覆盖，不作交付。
- 有效改动只有 2 个数值：`fsShed()` `14vp → 15vp`；`LAYOUT_WIDTHS[1]` `72 → 68`（合计 612 → 608）。
  其余是注释同步（原注释写「字号必须比正文小一号」「靠 72vp 列宽」，已过时）。
- **不动**：其余 10 列宽度、两行折叠算法（每行 ≤9 字符）、`lineHeight 15` / `maxLines 2`、
  编辑/清除/重置/转出转入逻辑、版本 `0.3.6 / 1000306`。
- 截图自检（中间态 15vp@72vp）：`snapshot_display` 抓图核对，第 1 行两行棚号
  `1-3` / `…21-30…` 显示完整、无裁字、两行不重叠，字号与「27」等正文数字一致。
  截图只放系统临时目录，看完连同设备端 `/data/local/tmp/fs15.jpeg` 一并删除；项目目录无新增图片。
- 验收：`node scripts/run-model-tests.mjs` → **✓ 344 assertions**；删旧 hap 强制重建，
  `CompileArkTS 1m19s` + `PackageHap` + `SignHap` 全部重跑 → **BUILD SUCCESSFUL in 2 min 19 s**。
- 最终产物：`dist/mixcalc-0.3.6-debug-signed.hap`，SHA256
  `f16f6273161291e92302785cd8bf16ecd095a504891e96d1b25eb20af82423e1`。
  `tconn 192.168.10.103:42085` → `install -r -d` 成功 → `aa force-stop` + `aa start` 成功 →
  `bm dump` 核对 `0.3.6`。
- 待真机确认：68vp 比 72vp 少 4vp，15vp 字号下最长 9 字符行可能略紧；
  且棚号 `lineHeight` 仍是 15vp（当初配小字号用的），若看着挤可把它调到 18vp 与正文一致
  —— 需用户裁决后再动，不擅自多改。
- 发布包 `dist/mixcalc-0.3.6-release-signed.app` 依旧过期，定稿后必须重打再上架。
- 推送复核（19:22，用户问「有没有推送到手机」）：设备 `bm dump` 的 `updateTime` =
  `1794309506714` → **2026-11-10 19:18:26 +0800**，与本轮 `install -r -d` 时间一致；
  `list targets` 在线、应用进程在跑（pid 29545）、版本 `0.3.6 / 1000306`。
  再次 `aa force-stop` + `aa start` 后抓临时截图核对：68vp 列宽与 15vp 字号均已生效，
  第 1 行两行棚号 `1-3` / `…21-30…` 完整无裁字；截图看完连同设备端临时文件一并删除。

### 任务 21 · 改以「已发布安卓」为基准对齐，并排查「显示所有列」阈值
**用户改基准**：安卓 0.3.6 已发布、鸿蒙尚未发布，故不再改安卓，改为鸿蒙跟安卓走、都调大。

查证安卓 `D:\mixcalc-lab`（0.3.6）：
| 项 | 值 | 位置 |
|---|---|---|
| 列宽 | `{40, 72, 40, 40, 60×7}`，棚号 **72dp**，合计 **612dp** | `MixCalcActivity.java:148` |
| 棚号展示字号 | `SHED_TEXT_SIZE_DP = 16`（density 换算，不随系统字体） | `MixCalcTableView.java:986` |
| 正文 / 表头 | 16sp / 14sp | `CellStyle.java:75-79` |
| 行高 / 表头 / 平板阈值 | 40dp / 40dp / `TABLET_MIN_WIDTH_DP = 600` | `MixCalcTableView.java:101-102`、`TabletLayout.java:9` |

鸿蒙改动（2 个数值 + 注释）：`LAYOUT_WIDTHS[1]` 68 → **72vp**（合计 608 → 612）、
`fsShed()` 15 → **16vp**。正文 15vp、表头 14vp **未动**（与安卓仍差 1 号，用户未要求，不擅自扩大改动面）。

验收：模型测试 **✓ 344 assertions**（构建期间并行跑被系统 SIGTERM，构建结束后单独补跑通过）；
`assembleHap` → **BUILD SUCCESSFUL in 8 min 21 s**（本轮机器资源紧张，编译 3m57s / 签名 1m12s）；
新包 `dist/mixcalc-0.3.6-debug-signed.hap`，SHA256 `ae343906…61e6`；
`install -r -d` → `aa force-stop` + `aa start` → `bm dump` 核对 `0.3.6 / 1000306`。
截图自检：16vp @ 72vp 下两行棚号 `1-3` / `…21-30…` 完整、无裁字、两行不挤，字号与「27」协调；截图已清理。

#### 「显示所有列」宽度阈值排查（本轮用户提问）
- 项目里有**两套宽度判据**，都在 `common/LayoutRules.ets`：
  1. `TABLET_MIN_WIDTH = 600`（`:16`）——平板布局阈值；`>=600vp` 时 `MixCalcTable.isTabletMode()`
     把可见列**缩放到窗口宽**（`MixCalcTable.ets:516-567`），11 列必然全部铺满；
  2. `fillsAllColumns(visible, widthVp)`（`:25-41`）——控制「快捷设置」入口是否隐藏
     （`Index.ets:90-96`），实现是 `sum(LAYOUT_WIDTHS) <= widthVp`，**只看固定列宽总和**。
- 历史值：0.3.5 基线棚号 60vp → 总和 **600**，与平板阈值 600 恰好重合，无缝隙；
  本轮中间态依次为 72vp→612、68vp→608，最终跟随安卓回到 **612**。
- 结论：**现在确实要求窗口宽 ≥ 612vp 才判定「铺满」**。手机（<600vp）恒定 false，
  本来就要横向滚动，行为与以前一致；真正变化的是 **600 ≤ 窗口宽 < 612vp** 这一段。
- ⚠️ **有问题**：这一段已进入平板模式、列被缩放铺满屏宽、11 列其实全显示，
  但 `fillsAllColumns` 仍拿固定 612 去比 → 返回 false → 「快捷设置」入口在已铺满时多余出现。
  这是多出 12vp 后新暴露的边界缝隙，总和 600 的时代不存在。
- 安卓**没有**这个问题：`TabletLayout.fillsAllColumns(..., tabletMode)` 有平板分支
  （`:89-93` 用 `computeWidths` 缩放后的实际总宽判断），`>=600dp` 恒 true。
- 另注：`fillsAllColumns` / `LAYOUT_WIDTHS` 目前**没有模型层单测覆盖**（`scripts/` 无匹配）。
- 建议修法（**未执行，等用户裁决**）：全可见检查之后补一行
  `if (isTabletWidth(widthVp)) { return true; }`，与安卓 tabletMode 分支对齐；
  改动 1 行 + 注释，需重打包验证。用户未明确要求改，故本轮只排查不动手。
- 发布包 `dist/mixcalc-0.3.6-release-signed.app` 依旧过期，定稿后必须重打再上架。

### 任务 22 · 修复铺满判据 + 正文字号对齐 + 补布局判据回归
用户三条指令：① 修掉 `fillsAllColumns` 要 612 才判铺满的问题；② 把鸿蒙正文 15vp 调到 16vp；
③ 追问「`if (isTabletWidth(widthVp)) return true;` 是什么」，并指出**鸿蒙有横屏平板、安卓平板强制竖屏**，两端形态不同。

**关于第 3 点的裁决（重要）**：那一行不是照搬安卓的竖屏假设，依据的是**鸿蒙自己**的
`MixCalcTable.isTabletMode()`（`MixCalcTable.ets:516-518` 同样调用 `isTabletWidth` / `TABLET_MIN_WIDTH=600`）。
含义是：11 列全可见且窗口已进入平板/宽屏模式时，列已被 `ensureWidths()` 缩放到窗宽、
必然铺满，所以直接返回 true，不再拿固定 612vp 去卡。
- 鸿蒙横屏平板 / 分屏（≥600vp，含 600~611vp）→ 缩放铺满 → true，快捷设置入口正确隐藏；
- 鸿蒙竖屏手机（<600vp）→ 仍是固定 612vp 横向滚动 → false，入口保留；
- 安卓平板强制竖屏只影响安卓自己的窗口宽度分布，不改变鸿蒙这条判据；
  本轮**不动安卓、不改 `TABLET_MIN_WIDTH`**，只让判据与鸿蒙自身缩放逻辑同源。
  将来若横屏平板要换阈值，改 `TABLET_MIN_WIDTH` 一处即可（两处共用）。

**改动清单**：
1. `common/LayoutRules.ets`：`fillsAllColumns` 全可见检查后补 `if (isTabletWidth(widthVp)) return true;`
   + 注释说明依据鸿蒙自身缩放、非照搬安卓竖屏假设。
2. `table/MixCalcTable.ets`：`fs()` 15vp → **16vp**（对齐安卓 `CellStyle` 16sp）；
   表头注释「比正文小 1vp」→「小 2vp」。`fsHeader()` 仍 14vp —— 与安卓 14sp **本来就一致，未改**。
3. `scripts/run-model-tests.mjs`：新增 `COMMON_DIR` / `COMMON_FILES`，让纯计算的
   `common/LayoutRules.ets` 也能被编译进回归（原 `MODEL_FILES` 只扫 `model/` 8 个文件）。
4. 新增 `scripts/model-tests/layout-rules.test.mjs`：**16 条断言**，覆盖列宽 11 列 / 棚号 72vp /
   总和 612 / 阈值 600、手机 360·599 false、平板 600·611·612·横屏 800 true、
   有隐藏列时任意宽度均 false、空表与非法宽度 false。

**两端最终对齐**（数值层面）：
| 项 | 安卓 0.3.6 | 鸿蒙 0.3.6 |
|---|---|---|
| 列宽 / 总宽 | 棚号 72dp / 612dp | 72vp / 612vp |
| 棚号字号 | 16dp | 16vp |
| 正文 / 表头 | 16sp / 14sp | 16vp / 14vp |
| 行高 / 表头高 | 40dp / 40dp | 40vp / 40vp |
| 平板阈值 | 600dp | 600vp |
注：安卓用 `sp`（随系统字体缩放）、鸿蒙用 `vp`（固定不缩放），平台机制无法完全等价，数值已一致。

**验收**：模型测试 **344 → ✓ 360 assertions**（编译 9 个文件）；
`assembleHap` → **BUILD SUCCESSFUL in 2 min 5 s**；
新包 `dist/mixcalc-0.3.6-debug-signed.hap`，SHA256 `6e6dc39b…7797`；
`install -r -d` → `aa force-stop` + `aa start` → `bm dump` 核对 `0.3.6`。
真机截图自检：正文 16vp 后序号 / 棚数 27 / 表尾统计 / 表头均完整无裁切，
棚号两行 `1-3` / `…21-30…` 完整；截图与设备端临时文件已删除，项目无新增图片。
发布包仍需重打。

## 任务 23：重打测试包，供云调试平台测试（21:44-21:50）

用户表示对连续几轮显示/布局改动不放心，要求先出一份测试包上传云调试自行验证，
**本轮不改任何代码、不做功能改动**。

**出包前状态**：`git status` 仅 `.workbuddy/` 未跟踪，HEAD = `5ee48ff`（任务 22 已全部提交）；
模型测试 **✓ 360 assertions**（编译 9 个文件）；关键数值复核：
`LAYOUT_WIDTHS[1]=72`、总宽 612、`TABLET_MIN_WIDTH=600`、`fsShed=16vp`、`fs=16vp`、`fsHeader=14vp`。

**构建**：删除 `entry-default-signed.hap` / `entry-default-unsigned.hap` 后
`assembleHap -p product=default -p buildMode=debug --no-daemon` →
**BUILD SUCCESSFUL in 43 s 883 ms**。`CompileArkTS` 为 UP-TO-DATE（代码与手机上同一份，
编译缓存命中），`PackageHap`(3s725ms) 与 `SignHap`(19s260ms) 均重跑。

**交付包**：`dist/mixcalc-0.3.6-debug-signed.hap`，2,686,123 B，
SHA256 `b76dca4691acb68bd9e723ac3c69b303f101f30f451a8077b122d04ca9980cf1`
（与上一版 `6e6dc39b…7797` 不同，签名块已重生成）。`dist/` 保持只有这一个包，
无截图、无界面树、无校验文件等冗余产物。

**包内静态校验**（`unzip -p`）：`module.json` 中
`versionName=0.3.6`、`versionCode=1000306`、`bundleName=com.shrimpfarm.mixcalc`；
`ets/modules.abc` 可检索到 `16vp` 字符串标记；包内含 `pack.info`、`resources.index`、
中英文 help 资源等完整条目。

**安装自检**（同一台手机 `192.168.10.103:42085`，仅验证包可用，不替用户做功能测试）：
`install -r -d` → `install bundle successfully`；
`aa force-stop` + `aa start` → `start ability successfully`；
`pidof` = 58035；`bm dump` 主段 `versionCode 1000306 / versionName 0.3.6`。

**云调试建议重点验证**（用户自行测试，本轮未执行）：
1. 横屏平板 / 分屏在 **600~611vp** 时：11 列是否缩放铺满，「快捷设置」入口是否按新判据隐藏；
2. 棚号两行折叠在 **16vp / 72vp** 下是否完整、无裁字、无两行挤压；
3. 正文统一 **16vp** 后数字、表尾统计、表头是否裁切或顶出格子；
4. 清空 / 重置棚号（派生显示态清除）与转出转入后清空目标行能否退回原行（来路保存）；
5. 切批次、退后台再回来、行结算补空行。

**后续**：云调试通过后再重打**正式发布包**（`dist/mixcalc-0.3.6-release-signed.app`
仍是过期产物，不可直接上架）。若平台要求 `.app` 包或正式签名而非 debug 签名 HAP，
需按平台要求补打。

## 任务 24：云调试反馈 —— 回退 68vp/15vp + 修复平板转屏（11-11 08:41-08:55）

用户云调试实测反馈两条：
1. 多机型比较下来**棚号列宽 68vp + 字号 15vp 最稳定**；
2. **平板运行中旋转**时界面「竖在屏幕中间像一个手机一样」；冷启动横屏 / 竖屏都正常，
   0.3.5 发布版从未出现。

**诊断（与 0.3.5 基线 `d521e50` 逐行对比）**：
- `Index.ets` 的宽度链路（根布局 `onAreaChange` → `applyWindowWidth` → `tableWidth`）、
  `MixCalcTable` 的 `isTabletMode()` / `ensureWidths()` / `applyViewSize()` 相对 0.3.5
  **完全没有改动**，排除表格布局逻辑。
- `entry/src/main/module.json5` 是唯一方向相关的实质差异：
  0.3.5 首版 `orientation: auto_rotation` / `["fullscreen"]`；
  现版 `orientation: portrait` / `["fullscreen","split"]`。
- 追溯提交：`585b439`（11-02 20:19，在 0.3.5 首次出包 `d521e50` 19:51 之后）
  为消除手机启动「先横后竖闪一下」把静态方向改成 `portrait`，
  平板改由 `EntryAbility.applyWindowSetup()` 运行时补 `AUTO_ROTATION`。
- **根因**：冷启动时运行时那次 `setPreferredOrientation(AUTO_ROTATION)` 生效，
  所以横屏/竖屏冷启动都正常；但**运行中旋转是配置变更**，系统按 Ability 的静态
  `orientation: portrait` 重新约束/重建窗口 → 平板横屏下出现竖屏窄窗口居中。
  运行时补方向覆盖不了静态声明，这就是「只有转屏出问题」。

**改动清单（5 个文件，均最小改动）**：
1. `module.json5`：`orientation` `portrait` → **`auto_rotation`**（恢复 0.3.5 首版）。
   `supportWindowMode: ["fullscreen","split"]` 与平板启动 `maximize()` **未动**，分屏能力保留。
2. `EntryAbility.ets`：只同步注释，说明静态方向为何必须 auto_rotation；
   手机仍在 `loadContent` 前由 `setPreferredOrientation(PORTRAIT)` 锁竖屏，逻辑未改。
3. `LayoutRules.ets`：`LAYOUT_WIDTHS[1]` 72 → **68**，总宽 612 → **608**，注释同步。
4. `MixCalcTable.ets`：`fsShed()` 16vp → **15vp**，两处注释同步。
5. `scripts/model-tests/layout-rules.test.mjs`：列宽 / 总宽断言 72·612 → 68·608，
   平板边界断言 611 → **607**（贴合 608 总宽前的缝隙），保留 600/612/800 与隐藏列断言。

**刻意未动**：正文 `fs()` 仍 **16vp**（用户任务 22 明确要求对齐安卓 16sp）、表头 14vp、
`fillsAllColumns` 的平板分支（任务 22 修复保留）、两行折叠算法、编辑/清空/重置/来路逻辑、
版本 `0.3.6 / 1000306`。若用户希望正文也回 15vp 需另行确认。

**验收**：模型测试 **✓ 360 assertions**；
`assembleHap` → **BUILD SUCCESSFUL in 2 min 17 s**（`CompileArkTS` 实跑 1m10s，
非缓存命中；仅既有 ArkTS 告警）；
新包 `dist/mixcalc-0.3.6-debug-signed.hap` 2,686,124 B，
SHA256 `1ad9a646b8d10d280e48cd97cb8cbd7ff28d67ecde1536e08bcb2b71c998f042`；
包内 `module.json` 校验 `orientation: auto_rotation` / `supportWindowMode: [fullscreen,split]`
/ `0.3.6 / 1000306`，`modules.abc` 可检索 `15vp` 标记；
`install -r -d` → `force-stop` + `start` → `bm dump` 核对 0.3.6，进程 9082。
`dist/` 仍只有这一个包，无截图 / 界面树等冗余产物。

**云调试复测重点**：
1. 平板横屏启动 → 转竖屏 → 再转回横屏，反复几次，界面是否始终铺满、不再出现竖屏窄条居中；
2. 手机冷启动是否仍稳在竖屏（静态方向回退后，重点看会不会重现「先横后竖闪一下」）；
3. 68vp / 15vp 下棚号两行是否完整、正文 16vp 是否裁切；
4. 分屏 / 悬浮窗进出、600~607vp 窗口下「快捷设置」入口。

**遗留**：`docs/harmony-tablet-adaptation-notes.md`、`docs/huawei-cloud-test-guide.md`、
`CHANGELOG` 里仍写着 `orientation: portrait` 的旧方案，等云调试验证通过后再统一更新，
本轮未擅自改历史文档。正式发布包依旧过期，定稿后重打。

## 任务 25：转屏修复验证通过，棚号列宽放宽到 72vp（11-11 10:57-11:05）

用户云调试复测反馈：**旋转没问题了**（任务 24 的 `auto_rotation` 修复有效）；
但 68vp 列宽「有些手机显示有问题」，虽然本机正常 → 要求**棚号列宽放回 72vp**。

**改动（仅列宽一个数值 + 同步注释/断言，共 3 文件）**：
1. `LayoutRules.ets`：`LAYOUT_WIDTHS[1]` 68 → **72**，固定总宽 608 → **612**，
   注释说明放宽原因（多机型兼容，本机 68vp 正常但其它机型两行棚号异常）。
2. `MixCalcTable.ets`：两处提到「68vp 列宽」的注释同步为 72vp，`fsShed()` **仍 15vp**。
3. `layout-rules.test.mjs`：列宽 / 总宽断言 68·608 → 72·612，
   平板边界断言 607 → **611**（贴合 612 总宽前的缝隙），保留 600/612/800 与隐藏列断言。

**刻意未动**：棚号字号 15vp、正文 16vp、表头 14vp、`orientation: auto_rotation`（已验证通过）、
`fillsAllColumns` 平板分支、两行折叠、棚号账本逻辑、版本 `0.3.6 / 1000306`。
最终组合：**棚号列 72vp + 字号 15vp**（列宽与已发布安卓 72dp 一致，字号不照搬 16dp）。

**验收**：模型测试 **✓ 360 assertions**；
`assembleHap` → **BUILD SUCCESSFUL in 2 min 9 s**（`CompileArkTS` 实跑 1m5s，仅既有告警）；
新包 `dist/mixcalc-0.3.6-debug-signed.hap` 2,686,124 B，
SHA256 `84c17e0d12919906a396360c39e1b88285bd85847abc9f887fc011c8972737c2`
（与上一版 `1ad9a646…f042` 不同）；
包内 `module.json` 复核 `orientation: auto_rotation` / `0.3.6 / 1000306`；
`install -r -d` → `force-stop` + `start` → `bm dump` 核对 0.3.6，进程 60358。
`dist/` 只有这一个包，无截图等冗余产物。

**遗留**：三份文档中的旧 `portrait` 方案描述仍待更新 —— 显示参数仍在逐档微调，
等整体定稿后一次性统一改，避免文档反复改。正式发布包依旧过期，定稿后重打。

---

## 任务 26：推送测试包 + 多机列数 / 棚号显示差异排查（11:37-11:45，零代码改动）

**推送**：`dist/mixcalc-0.3.6-debug-signed.hap`（SHA256 `84c17e0d…3c2`）经
`tconn 192.168.10.103:42085` → `install -r -d` → `force-stop` + `start` →
`bm dump` 核对 `1000306 / 0.3.6`，进程 4765。未重编译、未改任何代码。

**用户现象**：云测试各手机显示不一致（旧手机都不正常、本机正常），折叠展开 / 平板都正常；
有的手机一屏列数多、有的少，棚号有时不按两行规则显示。

**实测设备参数**：`hidumper -s DisplayManagerService` → 物理 1084×2412、`Density 3`、
`VirtualWidth 361vp`。用户截图正好是 6 列完整 + 第 7 列「0.3料」露一半，与固定列宽累计
（前 6 列 312vp、第 7 列到 372vp）在 361vp 窗口下的推算完全吻合。

**结论（只排查，未改码）**：
1. 列数差异来自窗口 vp 宽度 = 物理像素 ÷ density。手机模式（<600vp）用固定 612vp 列宽
   + 横向滚动，一屏装几列就显示几列；系统「显示大小」、分屏、折叠外屏还会改变该值。
   键盘只改高度不改宽度，不影响列数。
2. 列显隐 / 冻结按批次落盘（`Batch.columnVisibility` / `columnFixed`），不同设备设置不同
   也会改变可见列数；隐藏列后 `ensureWidths()` 末尾还会把剩余列等比放大铺满。
3. 平板 / 折叠展开（≥600vp）走另一套算法：棚号列宽 = `viewW / 可见列数 × 1.2` 再整体缩放，
   云测平板通常 ≥800vp → 棚号约 87vp 以上，比手机固定 72vp 宽松，故看起来都正常。
4. 根因：`ShedDisplay.render` 按「每行 ≤9 字符」折叠，**不感知列宽与机型字体**；能否显示完整
   由「72vp 列宽 × 15vp 粗体 × 该机型字形宽度」决定。15vp 粗体 9 个半角字符约需 72~81vp，
   72vp 是临界经验值：本机字体较窄刚好放下，旧机型字形稍宽即被 `TextOverflow.Clip` 裁掉，
   看起来「没按规则」。这解释了此前 16/15/14vp 与 60/68/72vp 反复试档。
5. 潜在隐患（未修）：平板模式 600vp 附近 `base=54.5`，seq / avg 被 clamp 到 50 后整体
   `scale < 1`，棚号列约 64~65vp，**比手机固定 72vp 还窄**；600~660vp 区间尚未实测。

**可选修法（等用户裁决，均未执行）**：
- A 治本：把 `cw(1)` 传入 `ShedDisplay.render`，按实际列宽动态算每行字符上限，两端同步 + 补测试；
- B 保守：继续加大余量（列宽 80vp 或字号 14vp），仍是经验值；
- C 补漏：平板模式给棚号列设最小 72vp；
- D 已被用户否决：Text 随内容自动缩字号。

**遗留**：三份文档旧 `portrait` 方案描述待定稿统一更新；正式发布包仍过期，定稿后重打。

---

## 任务 27：像素测量 + A 方案（棚号列按列宽算预算、字号回退）

**用户裁决**：同意 A 方案，要求只针对棚号列；计算不留内边距，单元格 72vp 扣左右各 0.5vp
边框后可用 **71vp**；一旦显示不下就降到 **14vp**；明确「大胆做，失败可回滚」。

**像素测量（截图 `微信图片_20261111115549_84_3.jpg`）**：用 ffmpeg 解成 PPM + 标准库扫描。
- 原图 **1008×2232**（聊天里显示的是缩略图，早期按 466 宽换算的坐标全部作废）。
- 列边界 x = 0 / 114 / 321 / 436 / 551 / 724 / 897 → 列宽 114 / 207 / 115 / 115 / 173 / 173 / 111px，
  与 `[40, 72, 40, 40, 60, 60, 60]vp` 完全成比例（**2.85 px/vp**，窗口 ≈354vp，6 列 + 第 7 列半露）。
- 棚号格 207px 内两行文字占 x=171~265（约 33vp），离边框很远，**没有被裁切**；
  第二行 `7-15` 四字符 = 94px = **33vp → 每字符 8.25vp @15vp 粗体**。
- 结论：71vp ÷ 8.25 = 8.6 → 15vp 下最多 **8 字符**，而规则硬编码 9 字符需 74vp，
  **必然超 3vp 被 Clip**；14vp 下每字符约 7.7vp → 71 ÷ 7.7 = 9.2，刚好放得下 9 字符。
- 纠正上一轮误判：截图里第 2 行起第 5 列往右的浅灰区 **不是渲染 bug**，
  是 `cellFill` 对「棚数为 0 的行」的料列置灰设计（`cellText` 注释已写明）；本机新包截图同样存在。

**实现（只动棚号列）**：
1. `model/ShedDisplay.ets`：`MAX=9` 升为 `RULE_MAX` 标称上限；新增
   `shedAvailableWidth()`（列宽 − 1vp 边框，不留内边距）、`shedMaxCharsAt()`
   （`8.25 × 字号 / 15` 换算，clamp 到 [1,9]，只往下调）、`shedFontSizeVp()`
   （15vp 装不下 9 字符 → 整列降 14vp，避免同列各行字号跳动）、`shedMaxChars()`、
   `renderForColumn()`；原 `render()` 保持标称 9 字符不变，内部抽出 `renderWithBudget()`
   把预算参数化，`ellipsizedTail` 同步接收预算。**两行折叠、Range 不断开、省略号语义全部保留**。
2. `table/MixCalcTable.ets`：只有 3 处接入 —— import、`cellText` 的 `case 1` 改调
   `renderForColumn(..., this.cw(1))`、`fsShed()` 返回 `shedFontSizeVp(cw(1))` 对应的 vp 串。
   正文 16vp、表头 14vp、`lineHeight 15` / `maxLines 2`、列宽 72vp、方向 `auto_rotation` 全部未动。
3. 新增 `scripts/model-tests/shed-column-fit.test.mjs`：常量、可用宽度、预算、
   字号选择、宽列输出与旧 `render()` 一致、窄列每行不超预算、区间不切断等 **75 条断言**。

**验收**：模型测试 **✓ 435 assertions**（360 → 435 全绿）；
`assembleHap` → **BUILD SUCCESSFUL 2m1s**（`CompileArkTS` 实跑 1m6s，仅既有告警）；
包 `dist/mixcalc-0.3.6-debug-signed.hap` 2,695,748 B，SHA256
`94348bf8b450148d71b232641a991d62723a08ea1a7c746f753e04bccb61af98`；
包内 `module.json` 复核 `auto_rotation` / `0.3.6 / 1000306`，`modules.abc` 能检索到新函数；
推 `192.168.10.103:42085` 安装、重启、`bm dump` 核对通过，进程 63551；
临时截图确认 72vp 列下字号已降 **14vp**、两行 `1-3` / `…21-30…` 完整无裁切，
截图与设备端临时文件均已删除，`dist/` 只有这一个包。

**回滚点**：本任务提交的上一个 commit 即改动前基线（`b2f1223`），
`git revert <本任务 commit>` 可一次性退回固定 15vp / 硬编码 9 字符。

**遗留**：安卓端 `ShedDisplay.java` 仍是固定 9 字符，未同步（用户只要求鸿蒙先做）；
三份文档旧 `portrait` 描述待定稿统一更新；正式发布包仍过期，定稿后重打。

---

## 任务 28：14vp 下「两侧留白」测量与列宽反推评估（零代码改动）

**用户观察**：降到 14vp 后，棚号文字到左右边框之间有空档，觉得浪费；
提议按「两边带 `…` + 中间 5 字符」的实际内容宽度反推列宽，留够又不浪费。

**真机像素测量**（`snapshot_display` 1084×2412，density 3 → 1vp = 3px）：
- 列边界 x = 0 / 120 / 336 / 456 / 576 → 棚号格 120..336 = **216px = 72vp**（与配置一致）。
- 第 1 行两行文字（y=370..399 / 415..444）：
  - `1-3`：墨迹 x=204..255 = 52px = **17.33vp**，左右各空 **28.0 / 27.0vp**；
  - `…21-30…`：墨迹 x=142..313 = 172px = **57.33vp**，左右各空 **7.33 / 7.67vp**。
- 字符分段：`…` 的三个点每个 2vp、点间距 3vp，单侧省略号跨度 **11.33vp**；
  `21-30` 五字符墨迹 **31.33vp**。即「两个 `…` + 中间 5 字符」总墨迹约 54vp，
  连字符间隙的实际占宽 **57.33vp**。

**反推结论**：
- 按用户口径（`…21-30…` 7 字符行）留宽度：57.33 + 1vp 边框 ≈ **58.3vp → 取 59~60vp**。
- 但规则允许的最长行是 **9 字符**：14vp 下 9 × 7.7 ≈ **69.3vp**，加边框需 **≈70.3 → 71vp 列宽**；
  含两个省略号的 9 字符行（如 `…101-105…`）按实测字形约需 70~73vp，**72vp 甚至略紧**。
- 所以当前 **72vp 不是浪费，基本是刚好**；用户看到的空档主要来自**内容本身短 + 居中排版**，
  不是列宽留多了。最长行两侧也只各空约 7vp，其中还包含 advance width 的字距。

**为什么不建议缩列宽到 59~60vp（未执行）**：
1. 退回 60vp 档会重现「68vp 在部分机型两行棚号显示异常」的老问题（用户此前要求 72vp 的原因）；
2. `shedMaxCharsAt(59, 14)` = floor(58 / 7.7) = **7**，预算从 9 掉到 7，
   9 字符行被砍成 7 字符，信息丢失比留白更糟；
3. 短行 `1-3` 仍居中，两侧照样空 ~20vp，缩列宽治不了这个观感；
4. 固定总宽 612 → 599vp，横向滚动与其它列对齐都会跟着变。

**可消除留白但需用户裁决的方向（均未执行）**：
- 棚号格 `textAlign` 改左对齐：短行贴左边框，代价是两行右端参差、与其它列居中风格不一致；
- 按行内容长度反向放大字号（短行 16vp / 长行 14vp）：代价是同列字号不齐，且属于此前已否决的「随内容缩放」；
- 只做 1vp 微调（72 → 71vp）收益极小，不值得重编译重推包。

本轮**未改任何代码、未重打包**，手机仍是任务 27 的 `94348bf8…af98`。
测量用的设备端截图与本地 PPM / JPEG 临时文件均已删除。

