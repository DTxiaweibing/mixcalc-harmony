# 秒算虾料 · 鸿蒙版开发计划

> 铁律：每个功能动手前先读安卓对应实现（Java / XML / assets），照抄结构与数值；
> 做完后在手机上逐项对照安卓版核对，记录差异。
>
> 维护规则：**每完成一部分就回到这个文件更新一次**（已完成 / 待办 / 待验证三块）。

_最近更新：2026-10-29_

> 经验沉淀：**鸿蒙输入框 / 键盘 / 焦点**的坑与最终方案见 [docs/harmony-input-keyboard-notes.md](docs/harmony-input-keyboard-notes.md)（新项目或换人接手先读一遍）。

## 已完成

### 基础与内核
- [x] 工程骨架、包名、图标、桌面名「秒算虾料」
- [x] 表格渲染 / 滚动（惯性、冻结列、吸顶吸底、边界）
- [x] 计算内核（FeedData 逐行移植）、首行锚点、行清空规则
- [x] 持久化（preferences，saved_data → batches_v2 迁移）
- [x] 表头/表体/表尾拆分，帮助/重置按钮、冻结格不透明
- [x] 批次 01/02（标题批次号、子菜单带 ✓、按批持久化）

### 交互
- [x] 单元格编辑：全表唯一编辑器，放在最外层 Stack（表体重排不重建它）
- [x] 系统输入法（搜狗/小艺都行），数字列 `NUMBER_DECIMAL` + `inputFilter` 只收数字/小数点
- [x] `onSubmit` 用 `SubmitEvent.keepEditableState()`：按「下一步」换格**不收键盘**
- [x] 光标：系统原生光标，点开时在数据末尾
- [x] 键盘「下一步」= 同向右移（行末换行）；右下角「下一行 ▾」= 同列向下
- [x] 顺序录入规则：点格子 / 键盘下一步（跨行）/ 下一行按钮，前面有空行时拦截并弹窗提示
- [x] 「只拦空行」：中间行被清空后，后面已有数据的行照样能改
- [x] 棚号↔棚数联动：改棚号时清掉「棚数手改」标记，以最后一次修改为准
- [x] 棚号输入白名单：只放行 0-9 / - / 到 至 ~ — 、 ， , 空格 号（字母/汉字/表情打不进去），解析归一化同安卓（1到40、1号至40号、1、2、3）
- [x] 长按料格换料比例（10%~90%、当前值 ✓、浅绿高亮；改过数值即失效）
- [x] 列操作（长按表头：固定/隐藏/显示全部/取消固定，按批持久化）
- [x] 快捷设置（9 列、灰/绿切换块、全取消/全解固/列全显/全确认，样式对齐安卓）
- [x] 水比 / 发酵料：点表头弹列表（安卓 showWaterPercentageDialog / showFermentedCalculationDialog）
- [x] 误差显示：标题栏右侧（安卓 updateErrorDisplay）
- [x] 表尾统计：料/水列没数据时显示 `0`（不留空）
- [x] 所有弹窗压在单元格编辑框之上（开弹窗前先收编辑 + 编辑器降层级）

### 视觉
- [x] 表格字号 14（对齐安卓观感）
- [x] 表头乳白底；发酵料表头：参与算水浅绿、参与算料加粗棕边
- [x] 禁输格浅灰 `#F0F0F0`；换料目标格浅绿 `#F0F8F0`
- [x] 菜单项文字居中、版本行黑色

### 系统与合规
- [x] 菜单 / 帮助网页 / 隐私 / 协议 / 网页系统栏
- [x] 重置弹窗、列表弹窗、确认弹窗（安卓规格复用）
- [x] 语言切换（跟随系统/中文/English，app_language，@Prop lang 不闪屏）
- [x] 首次启动隐私同意弹窗（85% 宽、标题 18、正文 13、正文内协议名可点、拒绝退出、按 `privacy_version` 记忆）
- [x] 应用锁定竖屏（手机与平板一致，`module.json5` → `orientation: portrait`）
- [x] 系统键盘弹出用 `KeyboardAvoidMode.RESIZE`（表尾露在键盘上方）

## 进行中
- [ ] 平板竖屏列宽自适应（照搬安卓 `TabletLayout.computeWidths`：按可见列均分 → 语义微调 ×1.2/×0.8 → 夹 50–120 → 整体贴合屏宽）
      · 代码已完成，**手机分支未改动**（`viewW < 600` 走原固定列宽）
      · 缺真机验证

## 待办（按依赖顺序）
1. [ ] 平板真机验证（800×1280 / 1000×1600）
2. [ ] 逐项复核对齐清单（见下节「已知差异」）
3. [ ] 上架准备：versionCode/versionName 定版、应用图标、隐私政策与用户协议**外链托管**（商店要求可访问链接）、软著信息、签名、应用市场素材

## 平板验证的两条路（按性价比排序）

### A. 华为 AGC 云调试（优先，无需真机）
1. 华为开发者账号（需实名）→ AGC 创建项目 / 应用（包名 `com.shrimpfarm.mixcalc`）
2. **发布证书**：AGC「证书、APP ID 和 Profile」→ 生成 `.cer` / `.p7b`（需要先做 CSR；签名指纹要和 HAP 一致）
3. 用发布证书重签 HAP（`hap-sign-tool`），否则云机装不上
4. AGC「云调试」→ 选平板（MatePad 竖屏）→ 上传 HAP → 远程操作 + 截图
5. 验收点：11 列是否一次全显示（不横滑）、行高 40、字号 14、键盘弹出时表尾是否贴键盘

### B. 本地 SDK Previewer（继续啃，可离线）
- `hvigorw ... PreviewBuild` 生成 `.preview` 产物 → 用 `sdk\default\openharmony\previewer\common\bin\Previewer.exe` 按 800×1280 渲染
- 卡点：`Previewer.exe` 需要 `-lws <端口>` 与 IDE 侧通信，命令行参数要靠试

## 会话交接（新开对话时先读这里）

**项目位置**
- 鸿蒙：`D:\mixcalc-harmony`（包名 `com.shrimpfarm.mixcalc`，版本 0.3.4 / versionCode 1000304）
- 安卓：`D:\mixcalc-lab`（0.3.4 / versionCode 7）
- 远端：Gitee `xia-guard/mixcalc-harmony`、`xia-guard/mixcalc-lab`；GitHub `DTxiaweibing/mixcalc-harmony`、`DTxiaweibing/mixcalc-lab`（**必须走 SSH**，443 常被网络重置）

**构建 / 安装**（鸿蒙）
```powershell
$root='D:\command-line-tools\command-line-tools'
$env:PATH="$root\bin;$root\tool\node;$env:PATH"; $env:DEVECO_SDK_HOME="$root\sdk"
cd D:\mixcalc-harmony
hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
hdc tconn 192.168.10.104:42085
hdc -t <dev> install -r entry\build\default\outputs\default\entry-default-signed.hap
hdc -t <dev> shell aa force-stop -b com.shrimpfarm.mixcalc
hdc -t <dev> shell aa start -a EntryAbility -b com.shrimpfarm.mixcalc
```
（装完必须 force-stop + start，否则跑的还是旧进程）

**必读技能**：`harmony-arkui-input-focus`（输入框/键盘/焦点全是坑）、`android-custom-table`（对照安卓做法）

**当前状态**：功能对齐已完成（编辑、顺序录入、隐私弹窗、表尾、颜色、字号、竖屏、惯性）；只剩平板验证 + 上架准备。


## 已知差异 / 待复核
- [x] ~~首行平均值取值~~ → 与安卓一致（已核对）
- [x] ~~快捷菜单「全解固 / 列全显」行为~~ → 与安卓一致（已核对）
- [x] 重置确认框文案 → 已对齐：`确定要重置所有数据吗？\n\n当前已有 %d 行数据，重置后将全部清空。` / `… \n\n当前没有数据需要重置。`；按钮 取消(#666666) / 确定重置(#D32F2F)，70% 宽
- [ ] 平板上是否隐藏「快捷设置」入口（安卓平板模式行为）—— 无平板，暂无法确认
- [ ] 棚号列用系统键盘：换格时输入法自身会收键盘一次（安卓同样，暂不处理）

## 核对清单（每个功能做完都跑一遍）
- 行高 / 字号 / 颜色 / 边框
- 点击、长按、滑动手感
- 边界：空行、0 棚数、负数、超长棚号
- 杀进程重开数据是否一致
- 批次切换后数据互不干扰、标题正确
- 中英文切换后文案与网页语言一致
- 编辑中：键盘是否抖动、光标是否在末尾、换格/换行是否守顺序规则
