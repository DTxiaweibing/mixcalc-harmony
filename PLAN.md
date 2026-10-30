# 秒算虾料 · 鸿蒙版开发计划

> 铁律：每个功能动手前先读安卓对应实现（Java / XML / assets），照抄结构与数值；
> 做完后在手机上逐项对照安卓版核对，记录差异。
>
> 维护规则：**每完成一部分就回到这个文件更新一次**（已完成 / 待办 / 待验证三块）。

_最近更新：2026-10-30_

> 经验沉淀：**鸿蒙输入框 / 键盘 / 焦点**的坑与最终方案见 [docs/harmony-input-keyboard-notes.md](docs/harmony-input-keyboard-notes.md)；**平板适配 / 全屏 / 键盘 / 上架包**见 [docs/harmony-tablet-adaptation-notes.md](docs/harmony-tablet-adaptation-notes.md)（新项目或换人接手先读一遍）。

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
- [x] 列宽自适应：隐藏列后可见列按比例铺满屏宽（手机 / 平板都生效），不再出现右侧留白
- [x] 「下一行 ▾」只在键盘弹起时显示，键盘收起即隐藏（`window.on('keyboardHeightChange')`）
- [x] 第一行「棚号」第一次点开弹格式提示（最小-最大，如 1-40），带「查看帮助」，只提示一次
- [x] 第一行「棚数」在棚号为空时拦截，提示「请先填写第 1 行的棚号」（只此一行是特例，其余行规则不变）
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
- [x] 手机锁竖屏；平板自动旋转（`module.json5` → `auto_rotation` + `EntryAbility` 按 `deviceInfo` 运行时设置）
      · 平板横屏/竖屏都按当前窗口宽度均分 11 列，不再出现“横屏窗口套竖屏 UI”
- [x] 启动即全屏：`module.json5` → `supportWindowMode: ["fullscreen"]`
      · 不再依赖用户在智慧多窗里手动最大化；待重打云调试复验
- [x] 手机/平板横竖屏统一用 `KeyboardAvoidMode.RESIZE`：键盘把页面压矮，表尾始终露在键盘上方
      · 平板横屏也是全宽平铺键盘，不采用 NONE 覆盖；横竖屏只影响 11 列宽度计算

### 平板
- [x] 平板竖屏列宽自适应（照搬安卓 `TabletLayout.computeWidths`：按可见列均分 → 语义微调 ×1.2/×0.8 → 夹 50–120 → 整体贴合屏宽）
      · 2026-10-30 AGC 云调试 **MatePad Air** 第一轮：11 列一次全显，右侧无截断，表头 / 行号 / 表尾正常
      · 2026-10-30 12:10 MatePad Air 窗口最大化后：全屏 11 列、键盘/输入正常
- [x] 平板隐藏「快捷设置」菜单项（`Index.menuItems()` 按 `deviceInfo.deviceType` 判断，`tablet` / `2in1` 不显示）
      · 代码已改，待云调试复验
- [x] 2026-10-30 12:01 CLI 打包成功：`dist/mixcalc-0.3.4-release-signed.app` + `.hap`
      · 待云调试复验：平板横/竖屏 11 列、键盘 RESIZE、无「快捷设置」；手机仍锁竖屏

## 进行中
- [ ] 平板剩余抽查（云调试）：菜单无「快捷设置」、批次 01/02 切换、长按表头列菜单
      · 全屏 11 列 + 键盘 RESIZE + 输入已确认正常（窗口最大化后）

## 待办（按依赖顺序）
1. [x] 平板云真机验证（2026-10-30 MatePad Air，AGC 云调试）—— 11 列一次全显，右侧无截断
2. [ ] 平板剩余抽查：菜单无「快捷设置」、批次切换、长按表头
3. [ ] 逐项复核对齐清单（见下节「已知差异」）
4. [ ] 上架准备：versionCode/versionName 定版、应用图标、隐私政策与用户协议**外链托管**（商店要求可访问链接）、软著信息、签名、应用市场素材
      · APP 打包脚本：`scripts/build-release-app.ps1`（CLI，打 unsigned APP + hap-sign-tool 手签，产出 `dist/*.app`）
      · 2026-10-30 已跑通：`dist/mixcalc-0.3.4-release-signed.app`（待 AGC 上传验证内层 HAP 签名）
      · 注意：hvigor 直接签名要 DevEco 加密密码，明文会报 `00303116`；所以走 unsigned APP + `hap-sign-tool`

## 平板验证的两条路（按性价比排序）

### A. 华为 AGC 云调试 / 云测试（优先，无需真机）
**完整步骤（账号 → 发布证书 / Profile → release 签名 → 云调试 MatePad → 云测试 → 验收清单）见 [docs/huawei-cloud-test-guide.md](docs/huawei-cloud-test-guide.md)。**

关键前提：现有 `entry-default-signed.hap` 是 **debug 自动签名**（`debugKey`），云调试/云测试只认 **发布证书 + release 构建**；必须先按指南申请 `.cer` / `.p7b`，把 `signingConfig` 切到 `release` 再打包。
验收点：11 列是否一次全显示（不横滑）、行高 40、字号 14、键盘弹出时表尾是否贴键盘。

### B. 本地 SDK Previewer（继续啃，可离线）
- `hvigorw ... PreviewBuild` 生成 `.preview` 产物 → 用 `sdk\default\openharmony\previewer\common\bin\Previewer.exe` 按 800×1280 渲染
- 卡点：`Previewer.exe` 需要 `-lws <端口>` 与 IDE 侧通信，命令行参数要靠试

## 平板云调试记录（2026-10-30）

- **设备**：华为 MatePad Air（AGC 云调试）
- **安装包**：`dist/mixcalc-0.3.4-release-signed.hap`（发布证书 + 发布 Profile，release 构建）
- **结果**：11 列一次全显（序号 → 称料），右侧无截断；表头、行号 1~25、表尾 `0/30 帮助 ... 重置` 正常
- **待补**：键盘弹起时表尾位置、键盘「下一步」换格、批次 01/02 切换、长按表头列菜单
- **备注**：
  - 云调试画面缩放会让 `0.5vp` 行线看起来发虚/断，不是绘制问题；以设备截图/真机为准
  - Pad 横屏时竖屏应用居中留边，可用宽度可能 `<600`，此时会走手机固定列宽；要横屏铺满需另做适配
  - `verify-app` 对 AGC 发布证书会报 `11011005 Param is not trusted`，以云调试安装结果为准

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

**当前状态**：功能对齐已完成（编辑、顺序录入、隐私弹窗、表尾、颜色、字号、惯性）；平板 11 列已验证；已改为“手机锁竖屏 + 平板自动旋转 + 横竖屏统一 RESIZE（表尾始终在键盘上方）”，待重打云调试复验横竖屏/键盘；快捷设置入口已按设备类型隐藏；剩上架准备。


## 已知差异 / 待复核
- [x] ~~首行平均值取值~~ → 与安卓一致（已核对）
- [x] ~~快捷菜单「全解固 / 列全显」行为~~ → 与安卓一致（已核对）
- [x] 重置确认框文案 → 已对齐：`确定要重置所有数据吗？\n\n当前已有 %d 行数据，重置后将全部清空。` / `… \n\n当前没有数据需要重置。`；按钮 取消(#666666) / 确定重置(#D32F2F)，70% 宽
- [x] 平板上隐藏「快捷设置」入口 → 已改 `Index.menuItems()`：`deviceInfo.deviceType` 为 `tablet` / `2in1` 时不显示；待重打云测包复验
- [ ] 棚号列用系统键盘：换格时输入法自身会收键盘一次（安卓同样，暂不处理）

## 核对清单（每个功能做完都跑一遍）
- 行高 / 字号 / 颜色 / 边框
- 点击、长按、滑动手感
- 边界：空行、0 棚数、负数、超长棚号
- 杀进程重开数据是否一致
- 批次切换后数据互不干扰、标题正确
- 中英文切换后文案与网页语言一致
- 编辑中：键盘是否抖动、光标是否在末尾、换格/换行是否守顺序规则
