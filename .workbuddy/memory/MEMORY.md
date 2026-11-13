# mixcalc-harmony 项目长期约定

## 列宽（用户 2026-11-12 明确裁决，勿改）
- `LAYOUT_WIDTHS[1]`（棚号列）= **64vp**。
- **其余 10 列只能是 40vp 或 60vp**，不许出现其它数值（当前 3 列 40vp + 7 列 60vp）。
- 固定列宽合计 **604vp**；`TABLET_MIN_WIDTH` 仍 **600vp**，窗口 ≥600vp 即全部显示所有列（由 `isTabletWidth` 提前判定，与总宽无关）。
- 原因：60vp 时真机把 `…21-30…` 这类双省略号行裁到只剩 `…`，可用宽 59vp 不够；64vp 可用 63vp，余量约 5.5vp。
- 回归守护：`scripts/model-tests/layout-rules.test.mjs` 有"其余列只能是 40 或 60"的断言。

## 棚号展示分档（用户 2026-11-12 定档，勿改）
- 列全部显示（≥600vp 铺满）→ **15vp / 每行 9 字符**。
- 列滚动显示（手机固定列宽）→ **14vp / 每行 7 字符**。
- 字号与字符预算必须同源，取同一个 `shedAllColumnsVisible()` 判据；整列统一、不按行浮动。
- 棚号上限 **99**，提示文案示例 `1-99`；toast 贴在表格最上面一行（`Alignment.Top` + `offset: { dx: 0, dy: 72 }`，SDK 的 `Offset` 字段是 `dx/dy` 不是 `x/y`）。
- 正文 16vp、表头 14vp。
- 版本固定 **v0.3.6 / 1000306**，不升 0.3.7。

## 编辑态结算（勿改回去）与启动方向（11-12 22:35 实测改回 auto_rotation）
- **只有用户主动离开单元格才结算**：安卓 `CellEditorOverlay` 没有焦点监听，`end()` 只由 `MixCalcTableView.handleTap()` 触发；鸿蒙 `TextInput.onBlur` 必须区分窗口级失焦（截屏/通知栏/切后台）与用户点别处，靠 `windowEvent(WINDOW_ACTIVE/INACTIVE)` + 根布局 `onTouch` 时间戳双判据。系统级失焦要**保留编辑态和实时计算结果**，否则一截屏就结算、屏也截不到。实时计算 `onChange → editLive → applyEdit(text,false)` 与失焦定稿 `finishEdit → applyEdit(text,true) + settleRowsAndPad` 两条链路不许合并。
- **静态方向必须是 `module.json5` 的 `auto_rotation`（11-12 晚云调试实测推翻了白天定的 portrait）**：启动窗口方向只由静态配置决定（早于 `onWindowStageCreate`），平板横屏由系统按「支持横屏」创建窗口才不会被压成竖屏窄条居中。`portrait` + 运行时补 `AUTO_ROTATION` 这条路**两次都失败**：`b8f714e`(11-11) 的提交注释原话「转屏时系统按静态 portrait 把窗口压成竖屏窄条居中」，`696b074`(11-12) 改回 portrait 并加 `onConfigurationUpdate` 兜底，云调试平板仍窄条 —— **运行时 API 补不回来，兜底无效**。用户口径「0.3.5 一切正常」对应的正是 11-11 之后那版 `auto_rotation`。代价：手机横着拿冷启动会「先横屏闪一下再转竖」（`applyWindowSetup` 仍锁 `PORTRAIT`），按 0.3.5 口径接受。`onConfigurationUpdate` 保留为防御性兜底，但别指望它。`EntryAbility` 手机 `PORTRAIT` / 平板 `AUTO_ROTATION` 分流 + 平板 `maximize()` 不变。

## 棚号两行排版顺序（用户 2026-11-12 按 12 组验收清单裁决，勿改回去）
- 真机用的是 `entry/src/main/ets/model/ShedDisplay.ets` 的 `renderForMode()` → `renderWithBudget()`；**项目里没有 `NumberRangeFormatter.ets`**（那是桌面 `未命名.txt` 的参考实现，从未集成，`utils/` 目录都不存在）。
- A-2 两行切分：在**所有可行切分**里取首行长度最接近 `total/2` 的，**平手保留更靠前的 k**（首行更短）。旧的「第一个可行 k 即返回」会产出 `1-3` / `5 7-15`，必须避免；但也不能单纯取首行最长，否则 `1-3 5` / `7 9 11` 会被挤成 `1-3 5 7` / `9 11`。
- B-2 双区间：首行在首个区间之后继续贪心补中间词（`candidate.length <= MAX`，不越过尾部区间）；若中间词**全部**露出，第二行不加前导省略号（`1-3 5` / `7-15…`），否则保留（`…21-30…`）。
- B-1 散点：省略号紧贴数字**不留空格**（`…13 15`，不是 `… 13 15`），预算相应从 `MAX-2` 改 `MAX-1`。
- 回归守护：`scripts/model-tests/shed-column-fit.test.mjs` 末尾有完整 12 组清单断言（24 条）；`shed-display.test.mjs` 的旧期望已同步到新口径。全量 **521 assertions**。

## 用户偏好
- 「没让你调整不要调整其他东西」：只改指定的数值，不要顺手动已测试通过的项；注释与测试断言同步属于必要配套。
- 每推进一步要跑全量回归、打调试包推手机、记录。
- hdc 目标地址目前是 `192.168.1.7:42085`（更早用过 `192.168.10.103:42085`）。WiFi 掉线时用 `hdc kill` + `hdc start -r` 重启服务；`hdc install` 的路径必须用 PowerShell 的 `D:\...` 反斜杠写法，Git Bash 的 `D:/...` 会被当相对路径。
- 抓 ArkTS `console.info` 日志：`hilog -r` 清 → 重启应用 → `hilog -x`；中文/省略号要按 UTF-8 解码，PowerShell 控制台按 GBK 会显示成 `鈥?`。

## 权威文档与两点省略号（2026-11-12 定）
- **`docs/安卓端同步清单-鸿蒙改动全记录.md`** 是「从安卓移植后鸿蒙改了什么 + 安卓以后要同步什么」的唯一汇总，含全部计算规则与安卓待办 Checklist。旧文档（`CHANGELOG.md` / `PLAN-0.3.6-执行记录.md` 等）停在 11-10/11-11 且含过期值，改安卓前以该清单为准。安卓仓库在 `D:\mixcalc-lab`。
- **两点省略号方案已放弃，勿再提**：`‥` U+2025 在 HarmonyOS Sans 里与 `…` 同为 14.00vp 一点不省；`..` 能省宽但会破「`…` 按 1 字符计入 7/9 预算」的口径，牵动 12 组清单、79 组预览、521 断言与 64vp 定档。维持 `…` / 64vp / 现有预算口径。
- 换格规则（用户点名要回流安卓）：「下一行」跳下一行第一个可编辑格而非死守同列；换格即走完整结算删死行；删行后光标跟着上移。安卓待改点只有 `MixCalcActivity.moveFocusToNextRow():884-905` 的 `:897-900`；安卓已有 `onRowsRecycled`/`shiftRowsAfterRemoval` 做光标平移，别照搬鸿蒙的 `targetRef/indexOf`。
