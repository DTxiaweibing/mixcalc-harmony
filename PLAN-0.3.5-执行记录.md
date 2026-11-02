# 0.3.5 执行记录（对齐安卓 P0 快捷设置 / P1 表头弹窗）

> 计划来源：[PLAN.md](PLAN.md)「下一步工作计划」P0、P1。
> 对标对象：安卓 `D:\mixcalc-lab` 的 0.3.5（`PLAN-0.3.5-执行记录.md`）。
> 本文件只记“做了什么、怎么验证的、还差什么”，不改计划本身。

_开始：2026-11-01_

## 范围决定

- 本轮只做安卓 0.3.5 的等价内容：P0 快捷设置窗口自适应 + 铺满 11 列时隐藏、P1 表头弹窗右边缘对齐、折叠屏按**当前窗口宽度**切布局。
- **P1.5 键盘三档、P2 棚号智能输入不动**，仍按 PLAN.md 的排期单独出版本。
- **版本号暂不调**：先真机/云调试过验收矩阵，再改 `0.3.5 / versionCode 1000305` 并打 release 包（与安卓“先验收再定版”一致）。

---

## 改了什么

| 文件 | 改动 |
|---|---|
| `entry/src/main/ets/common/LayoutRules.ets`（新增） | 纯计算：`isTabletWidth()`、`fillsAllColumns()`、`rightAlignedX()`，以及共享的 `LAYOUT_COLUMN_IDS` / `LAYOUT_WIDTHS`；无 UI / 无 deviceInfo 依赖 |
| `entry/src/main/ets/table/MixCalcTable.ets` | ① 平板/手机布局改为**只看当前窗口宽度**（`viewW >= 600`），不再用 `deviceInfo.deviceType`；② 列宽/列 id 改用 `LayoutRules` 的共享常量；③ 水比 / 发酵料 / 列操作三个弹窗改为右边缘对齐单元格再夹进窗口；④ 列菜单宽度与 picker 统一为 `min(200, viewW)`；⑤ 表体宽度变化时关闭贴表头弹窗 |
| `entry/src/main/ets/pages/Index.ets` | ① 监听 `window.windowSizeChange`，窗口宽变时重算 `screenW` / `menuWidth`；② 宽度变化时关闭主菜单、批次子菜单、快捷设置、语言弹窗；③ 快捷设置面板宽度改 `100%`（去掉 360 上限）；④ 「快捷设置」入口改由 `fillsAllColumns()` 决定，不再用 `deviceInfo` 猜设备类型；⑤ 列 id 改用共享常量 |

### 判据（与安卓一致）

```text
isTabletWidth(w)   = w >= 600vp
fillsAllColumns(v) = 11 列全可见 && 600vp <= 表格实际宽度（LAYOUT_WIDTHS 合计）
menuShowQuick      = !fillsAllColumns(可见掩码, 表格实际宽度)
popupX             = clamp(columnLeft(col) + cw(col) - popupW, 0, w - popupW)
```

- 600vp 只是**平板布局分界**；平板布局会把可见列整体缩放到窗宽，全可见时必然铺满，所以 `fillsAllColumns` 等价于「全可见 + 窗口 ≥600vp」。
- 宽度用 `MixCalcTable.onViewWidth` 回报的**表体实际宽度**，不用窗口宽度另算一份，避免 600vp 边界上两处各判一次。
- 还有列被隐藏时 `fillsAllColumns` 必须返回 false，否则用户没有入口把列恢复回来。

---

## 关键判断

- **布局判据从“设备类型”改成“当前窗口宽度”**：安卓 0.3.5 修的是折叠屏外屏被当成平板，把 11 列硬压进 370dp。鸿蒙侧原来的 `deviceInfo.deviceType` 有对称问题（折叠屏展开后仍按手机固定列宽 + 横向滚动），因此一并对齐成窗口宽度判断。
- **共享常量放进 `LayoutRules.ets`，不在两个文件里各写一份**：`Index` 判断“要不要显示快捷设置”和 `MixCalcTable` 算列宽必须用同一份宽度/列 id，否则以后改列宽又会出现“已经铺满但按钮还在”。
- **窗口宽度变化时关闭弹窗**：列宽重算后弹窗的 `x` 会过期；安卓 0.3.5 也是直接 dismiss 让用户重开，不尝试原地重排。
- **不关闭正在编辑的单元格**：键盘 `RESIZE` 只改高度，宽度变化才关弹窗；编辑值已经在 `onChange` 里落过，保持焦点比强行收键盘体验更好。

---

## 验证

```powershell
$root='D:\command-line-tools\command-line-tools'
$env:PATH="$root\bin;$root\tool\node;$env:PATH"; $env:DEVECO_SDK_HOME="$root\sdk"
cd D:\mixcalc-harmony
hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

| 步骤 | 结果 |
|---|---|
| 改动前基线编译 | BUILD SUCCESSFUL in 1 min 48 s |
| P0 + P1 + 折叠屏判据改完 | BUILD SUCCESSFUL in 1 min 39 s |
| 补“宽度变化关弹窗”后再编译 | BUILD SUCCESSFUL in 1 min 37 s |
| 代码评审后的 7 项修复 | BUILD SUCCESSFUL in 1 min 38 s |

- **没有单测**：`entry/src` 下没有 `test` / `ohosTest` 工程，本机也没有连接设备（`hdc list targets` 为空），所以只能做编译验证 + 人工矩阵；判据是纯函数，后续可先补 ohosTest 再回归。
- 编译告警只涉及既有 deprecated API（`router.pushUrl`、`promptAction.showToast`、`getContext`），本轮未新增。
- 同步文档：`PLAN.md`（已完成 / 进行中 / P0 / P1 / 已知差异 / 当前状态）、`docs/harmony-tablet-adaptation-notes.md` 第六节、新建 `CHANGELOG.md`（0.3.5 段，2026-11-02 定稿）。

---

## 代码评审后补的修复（2026-11-01）

| 问题 | 处理 |
|---|---|
| `Index` 只用窗口宽度判 11 列，和表格 `viewW` 是两个来源，600vp 边界可能判不一致 | 新增 `MixCalcTable.onViewWidth` 回调，把表体实际宽度回报给 `Index`，判 11 列只用这一个值 |
| 拿不到 `window` 对象时 `screenW` 永远停在 360，平板会一直显示「快捷设置」 | `initWindowMetrics().catch` 里退回 `display.getDefaultDisplaySync()` 宽度，失败也打日志 |
| 折叠/展开后 `offsetX` 可能超过新的 `maxOffsetX`，表格右侧留一条空白 | `applyViewSize()` 里补 `clampOffsets()` |
| 窗口变化强制关闭快捷设置时，列改动已写进 batch 但表格没重建 | 关闭前 `saveAll()` + `rebuildTable()`，让改动立即生效 |
| 菜单项用中文标签 `'批次切换'` 判断是否收起菜单，英文下批次子菜单打不开（原有 bug） | `MenuItem` 增加 `keepOpen` 字段，批次项显式置 true |
| 列宽缓存 key 用 `Math.round(viewW)`，599.6 / 600.4 同 key | 改成 `Math.round(viewW * 10)` |
| `fillsAllColumns` 里有一个永远走不到的分支 | 删掉分支，改成「全可见 + 600vp 固定列宽 ≤ 表宽」，注释写清等价关系 |

已知未处理（与安卓 0.3.5 同等限制，留给 P1.5）：

- 窗口高 < 约 490vp 时，快捷设置面板底部按钮可能超出屏幕（面板还没有滚动容器）；
- 换料比例弹窗只跟随宽度变化关闭，不跟随高度（键盘 RESIZE）重排；
- 页面不注销 `windowSizeChange` 监听（入口页常驻，退出即进程结束）。

---

## 验收记录（2026-11-02）

### 一、云调试（全矩阵通过）

由用户在 AGC 云调试按下面清单逐项验证，**结论：全部通过**（明细未逐条留档到本仓库；如需回溯补截图）。

### 二、真机（nova 15，补充抽查）

设备：`夏卫兵的 nova 15`（PSN-AL00，API 26），无线调试 `hdc tconn 192.168.10.103:42085`，
屏幕 1084×2412 px / 3.0 密度 ≈ **361vp 宽**（手机布局，远低于 600vp 分界）。

安装：`hdc install -r entry-default-signed.hap` 覆盖已装的 0.3.4，**签名一致、安装成功、本地数据保留**；
桌面显示的版本号仍是 v0.3.4（版本号按计划留到全矩阵过完再调）。

| 项 | 结果 |
|---|---|
| 启动 / 表格渲染 | 正常，pid 稳定；后台->前台未重启，hilog 无 JsError / 无崩溃，只有既有的 `Text: generatePaintRegion`、`AceTheme: dialog_padding_*` 告警 |
| 手机竖屏菜单 | 有「快捷设置」；菜单宽度 = max(140, 窗宽/3) ≈ 140vp，符合预期 |
| 快捷设置面板宽度 | 左右铺满整屏（0 → 1084px），不再有 360vp 上限留下的右边空白 |
| 面板内容 | 表头 5 列（列名/固列/解固/隐列/显列）+ 9 行 + 底部 4 按钮全部完整显示，未被裁；末行「称料」不在面板内是设计（与安卓一致，只列 9 列） |
| 表格横向滚动 | 可滚到最右（0.3料 / 0.5料 / 1.0料 / 水15% / 称料），冻结的序号列不跟随，符合手机布局预期 |
| 最右列·水列表头弹窗 | 点「水15%」弹出「选择水百分比」，**右边缘贴住该单元格右边缘**（≈890px），未溢出屏幕，7 个选项完整可见，当前值 15% 带勾 |
| 点「称料」表头 | 不弹列菜单（该列不参与列设置），不报错 |

真机只做了补充抽查，其余机型项以云调试结论为准。

未在真机覆盖：折叠屏外屏与内屏、平板横竖屏、反复折叠、分屏拖拽、
隐藏列后入口是否保留（真机上误触面板导致藏列未提交，未验到）、最左列与中间列表头弹窗的左边界夹取。

---

## 验收清单（云调试，2026-11-02 全部通过）

- [x] 手机竖屏：菜单有「快捷设置」，面板左右满宽；9 列 / 四个开关 / 底部四按钮不被裁（nova 15 真机 + 云调试）；
- [x] 手机隐藏任意一列：菜单仍保留「快捷设置」，能再恢复；
- [x] 折叠屏外屏（约 370vp）：手机布局、横向滚动、菜单有「快捷设置」；
- [x] 折叠屏内屏（≥600vp）：11 列铺满、菜单无「快捷设置」；
- [x] 三折叠 单屏 / 双屏 / 三屏态：单屏回手机布局、双屏与三屏铺满 11 列；
- [x] 反复折叠/展开 5 次：布局切换正常，不出现“列已铺满但快捷设置还在”，不残留旧列宽；
- [x] 平板横/竖屏：11 列铺满、菜单无「快捷设置」、面板满宽；
- [x] 平板先手动藏列 → 重开应用：列保持隐藏，快捷设置能再次出现；
- [x] 最左列表头：水比/发酵料/列操作弹窗贴左不裁切；
- [x] 最右列表头：弹窗右边缘贴单元格右边缘、完整可见；
- [x] 中间列：右边缘对齐，点完能直接选；
- [x] 分屏 / 自由窗口拖拽宽度变化时：菜单和贴表头弹窗自动关闭，不出现错位。

---

## 启动期与英文页面修复（2026-11-02 追加）

### 现象

1. 冷启动会先闪应用图标（白底）再进表格；
2. 手机横着拿再启动，出来后抽屉菜单特别宽（截图实测 **269vp**），
3. 切到英文后，「帮助 / 隐私政策 / 用户协议」仍然是中文页。

### 根因（有设备证据）

- **菜单宽度**：截图里菜单右边缘 ≈ 809px ≈ 269vp，而 `269 × 3 ≈ 806vp`，
  正好是这块屏 `2412px ÷ 3` 的**横屏**宽度；同一张图里表格却是手机布局
  （40/60vp 固定列宽 + 横向滚动），说明表格拿到的 361vp 是对的。
  → 坏的只有 `Index` 这一路宽度：它来自 `window.getWindowProperties()` 一次性采样
  + `windowSizeChange` 事件；启动时窗口先按横屏创建，转屏后事件没有派发，
  宽度就永久停在 806vp。菜单宽度又是从这个坏值缓存到 `@State` 的，所以一直错。
- **启动闪图标**：`module.json5` 的 `startWindowIcon` 指向应用图标，启动页背景是纯白，
  与首帧 `page_bg` 不一致；且 `Index` 用 `if (this.ready)` 门控整个表格，
  要等 preferences 读完才渲染，启动页停留时间被拉长。
- **英文页面**：`rawfile/en/` 下三个英文页本来就有（与安卓 `assets/en/` 一一对应），
  但 `openPage()` 永远只传中文路径，`WebPage` 也没有语言判断。

### 改法

- 宽度唯一来源改为**根布局 `onAreaChange`**（和表格同一条路），`windowSizeChange` 仅作兜底；
  两个源头都只写 `screenW`，幂等。菜单宽度不再缓存，改为 `menuWidth()` 实时算
  `Math.max(140, screenW / 3)`。删除 `display.getDefaultDisplaySync()` 兜底。
- `EntryAbility`：`setPreferredOrientation` / `setWindowSystemBarProperties` 提到
  `loadContent` **之前**（`loadContent` 回调里再调一次，幂等），手机锁竖屏、
  平板/折叠屏内屏跟随系统自动旋转。
- 启动页：新增 8×8 全透明 `start_transparent.png`，`startWindowIcon` 指向它；
  `start_window_background` 白 → `#F5F5F5`（照抄安卓 `AppTheme.NoWindowBackground`）。
- `Index.aboutToAppear()` 先塞两个空 `Batch` 再读 preferences，删掉 `if (this.ready)`，
  首帧即出标题栏 + 表格骨架，数据到位后 `rebuildTable()`。
- `Index.openPage()` 增加 `lang` 参数；`WebPage.resolveRoute()` 用
  `resourceManager.getRawFileContentSync('en/' + route)` 探测存在性，存在即用英文页，
  否则回退中文（与安卓 `resolveAssetPath()` 等价）。

### nova 15 真机验证（1084×2412 px，3.0 密度 ≈ 361vp）

| 项 | 结果 |
|---|---|
| 冷启动 | 直接出 UI（标题栏 + 表格），菜单默认关闭；连拍 5 帧未见图标 / 白屏 |
| 抽屉菜单宽度 | 菜单项 bounds 全为 `[0,×][420,×]` → 420px = **140vp** = `max(140, 361/3)`；旧版是 269vp |
| 菜单第一项 | 「快捷设置」在（宽度与表格同源，不再误判成「已铺满 11 列」） |
| 版本文案 | `版本:v0.3.5` |
| 英文界面 | 切 English 后菜单为 `Quick settings / Switch batch / Privacy policy / Help / Language`；打开 Privacy policy 显示英文 "Privacy Policy"，Help 显示英文 "Help" 且图片正常 |
| hilog | 无 mixcalc / shrimpfarm 相关 Error |
| 横握冷启动 | 用户真机确认「nova 15 一切正常」 |

用户明确：**版本号不再升级**，就用 0.3.5 出 release 包上传应用市场（当前市场是 0.3.4）。

---

## 收尾（2026-11-02）

- `AppScope/app.json5` 定版 `versionName 0.3.5 / versionCode 1000305`；
- 打 release 包：`scripts/build-release-app.ps1` → `dist/mixcalc-0.3.5-release-signed.app` + `.hap`（2026-11-02 19:50 已按最终英文版重打）；
- 提交并推送到两个远端：`origin`（GitHub `DTxiaweibing/mixcalc-harmony`）、`gitee`（`xia-guard/mixcalc-harmony`）。

---

## 英文文案对齐安卓（2026-11-02 追加）

### 范围

以安卓 `app/src/main/res/values-en/strings.xml` 为准，逐项核对鸿蒙 `Strings.ets` 与硬编码文案；只改英文显示，不改业务逻辑、不改中文文案含义。

### 改了什么

| 文件 | 改动 |
|---|---|
| `common/Strings.ets` | `title` / `menu.quick` / `menu.privacy` / `menu.terms` / `menu.version` / 列名 / 列操作 / 快捷设置 / 批次 / 键盘 / 水比 / 发酵料 / 重置提示等英文改为安卓原文；补 `water.header`、`pad.clear`、`pad.next`、`pad.nextRow`、`btn.gotIt`、`privacy.loadFail` |
| `pages/Index.ets` | 删除 `TITLE_BASE` / `COLUMN_HEADS` 硬编码；列显示/隐藏提示、批次标题改走 `t()`；隐私加载失败改走 `privacy.loadFail` |
| `table/MixCalcTable.ets` | 单元格编辑按钮「取消 / 确定」、提示「知道了」、水比表头、列操作标题、自定义面板「清空 / 下一步」、编辑态「下一行 ▾」全部走 `t()`；`CellEditorDialog` 增加 `lang` |

### 英文页面核对

- `rawfile/en/help/index.html`、`rawfile/en/privacy.html`、`rawfile/en/user.html` 与安卓 `assets/en/` 同名文件 **SHA-256 完全一致**；
- `rawfile/en/privacy_consent.txt` 与安卓 `assets/en/privacy_consent.txt` **SHA-256 完全一致**；
- 应用内英文文案不再从 `Strings.ets` 之外硬编码中文。

### 验证

```powershell
$root='D:\command-line-tools\command-line-tools'
$env:PATH="$root\bin;$root\tool\node;$env:PATH"; $env:DEVECO_SDK_HOME="$root\sdk"
cd D:\mixcalc-harmony
hvigorw.bat assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
```

- 编译：**BUILD SUCCESSFUL**（仅既有 deprecated API 告警）；
- 真机：`hdc tconn 192.168.10.103:42085` → `hdc install -r entry-default-signed.hap` 安装成功，启动正常，PID 已确认；
- 版本：`0.3.5 / versionCode 1000305`。

### 英文应用名（2026-11-02 追加）

- 新增 `AppScope/resources/en/element/string.json`：`app_name = ShrimpCalc`；
- 新增 `entry/src/main/resources/en/element/string.json`：`module_desc` / `EntryAbility_desc` / `EntryAbility_label = ShrimpCalc`，`title_main = Mix Calculator`；
- 资源限定符用 `en`（语言级），英文系统 / 英文区域都会命中；中文系统仍回退 `base` 的「秒算虾料」；
- 重新编译 `BUILD SUCCESSFUL`，已安装到 nova 15 并启动。

### 未改

- 桌面应用名只在英文系统下变 `ShrimpCalc`；中文系统仍为「秒算虾料」品牌名。

### 最终打包（2026-11-02 19:50）

**调试包**

- 文件：`dist/mixcalc-0.3.5-debug-signed.hap`
- 签名：DevEco 自动调试证书（debug）
- 用途：手机 / 平板 / 云调试安装
- 已安装到 nova 15，`versionName 0.3.5 / versionCode 1000305`，启动正常

**发布包**

- APP：`dist/mixcalc-0.3.5-release-signed.app`（AppGallery 上传用这个）
- HAP：`dist/mixcalc-0.3.5-release-signed.hap`（云调试 / 企业分发测试用）
- 签名：`D:\mixcalc-sign\mixcalc-release.p12` + release profile
- `build-profile.json5` 的 `signingConfig` 已恢复为 `default`，不会留下 unsigned 构建状态

**签名选择**

- 调试安装 → debug 签名 HAP；
- 应用市场 → release 签名 APP；
- 普通手机直接点 release HAP 仍会报 `9568322 not trusted app source`，这是手机不信任本机 release 证书，不是包坏了；云调试/上架走对应渠道即可。

