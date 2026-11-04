# 鸿蒙平板适配经验总结（秒算虾料）

> 来源：`mixcalc-harmony`（秒算虾料 鸿蒙版）平板适配 + AGC 云调试 + 上架打包过程。
> 环境：HarmonyOS SDK 6.0.1（API 21）、命令行工具链、云真机 MatePad Air。
> 适用场景：表格类应用，手机锁竖屏、平板横竖屏都要铺满，11 列按窗口宽度重算。

---

## 一、先记住这 6 条

1. **手机启动竖屏，平板自动旋转**：`module.json5` 先写 `portrait`，避免手机启动先横屏闪一下；运行时再按 `deviceInfo.deviceType` 给平板切 `AUTO_ROTATION`。
2. **不要试图强制平板竖屏**：第三方应用在 Pad 上强制不了整机方向；`orientation: portrait` 只用于启动首帧，平板运行时必须切回自动旋转。
3. **平板要“启动即全屏”，同时允许用户分屏**：`supportWindowMode: ["fullscreen", "split"]`，并在 `EntryAbility` 启动时对平板调用 `maximize()`；只写 `["fullscreen"]` 会彻底禁用分屏。
4. **11 列按“当前窗口宽度”算，不是物理屏幕宽度**：`viewW` 是窗口内容宽度。自由窗口下它小于屏幕宽度，表格按窗口铺满是对的；最大化/全屏后自然变成整屏宽度。
5. **键盘统一用 `RESIZE`**：平板横屏也是全宽平铺键盘，平台审核要求；`RESIZE` 让页面变矮、表尾留在键盘上方。不要用 `NONE` 覆盖，否则表尾被盖住。
6. **别拿表格的 `viewH` 判断平板**：`viewH` 会随键盘压缩变化，可能把平板误判成手机。用 `deviceInfo` 或窗口/屏幕尺寸判断。

---

## 二、方向：手机锁竖屏，平板自动旋转

### 2.1 配置

`entry/src/main/module.json5`：

```json5
"orientation": "portrait",
"supportWindowMode": ["fullscreen", "split"],
```

### 2.2 运行时按设备类型设置

`EntryAbility.onWindowStageCreate`，`loadContent` 之前：

```ts
import { deviceInfo } from '@kit.BasicServicesKit';

const win = windowStage.getMainWindowSync();
const isPhone = deviceInfo.deviceType === 'phone';
win.setPreferredOrientation(
  isPhone ? window.Orientation.PORTRAIT : window.Orientation.AUTO_ROTATION
).catch(() => {});
if (!isPhone) {
  win.maximize(window.MaximizePresentation.FOLLOW_APP_IMMERSIVE_SETTING).catch(() => {});
}
```

- 手机：`PORTRAIT`，横过来也不跟着转；
- 平板：`AUTO_ROTATION`，横竖屏都跟随系统；启动时 `maximize()` 回到全屏；
- `2in1` / `default`：按自动旋转处理。

### 2.3 为什么不能强制平板竖屏

Pad 的规格是：竖屏应用在横屏时**居中显示/留边**，系统不会为了一个应用把整机转成竖屏。  
所以：

- 不要写“平板也强制竖屏”；
- 也不要把横屏留边当成 bug；
- 要么接受留边，要么让平板自动旋转、横屏也铺满（本项目选后者）。

---

## 三、启动即全屏，但允许分屏：`supportWindowMode` + `maximize()`

### 3.1 问题现象

云调试里 MatePad Air 打开应用，是一个带最小化/最大化/关闭按钮的**自由窗口**，表格只铺满窗口，看起来“没识别屏幕宽度”。

### 3.2 原因

`supportWindowMode` 默认是：

```json5
["fullscreen", "split", "floating"]
```

平板在多窗口/自由窗口形态下，可能按 `split`/`floating` 启动。  
只保留：

```json5
"supportWindowMode": ["fullscreen"]
```

系统会直接全屏启动，但**分屏也被一起禁用了**。

### 3.3 现在的方案

```json5
"supportWindowMode": ["fullscreen", "split"]
```

启动时在 `EntryAbility` 里对平板调用：

```ts
win.maximize(window.MaximizePresentation.FOLLOW_APP_IMMERSIVE_SETTING)
```

效果：

- 默认启动全屏；
- 用户仍可在使用中手动分屏；
- 手机不调用 `maximize()`，避免影响手机的分屏/全屏行为。

### 3.4 注意

- `maximize()` 在部分设备/窗口状态会返回 `801 Capability not supported` 或 `1300002`，必须 `catch`，不能让它影响启动；
- 如果重打包后仍是小窗口：确认 `module.json5` 真的打进 HAP、云调试没有缓存旧包；必要时升 `versionCode` 再传；
- 只写 `["fullscreen"]` 是最稳的“禁止分屏”方案，但产品要允许分屏时不能这么写。

---

## 四、11 列宽度：按当前窗口宽度重算

### 4.1 判定平板

```ts
private isTabletMode(): boolean {
  if (deviceInfo.deviceType === 'tablet' || deviceInfo.deviceType === '2in1') {
    return true;
  }
  if (deviceInfo.deviceType === 'phone') {
    return false;
  }
  return this.viewW >= 600;
}
```

- 平板：无论横屏/竖屏都走 11 列均分；
- 手机：固定列宽、横向滚动；
- `deviceType` 不可靠时，用 `viewW >= 600` 兜底。

> 不建议用 `Math.min(viewW, viewH)` 判断：`viewH` 是表格 body 高度，键盘弹出会变，容易把平板误判成手机。

### 4.2 分列

`ensureWidths()` 用当前 `viewW`：

1. 统计可见列；
2. `base = viewW / 可见列数`；
3. 棚号/称料 ×1.2，序号/平均 ×0.8；
4. 夹 50~120；
5. 整体缩放到正好等于 `viewW`；
6. 取整误差补给最后一列。

横屏 `viewW` 大、竖屏 `viewW` 小，都会重新算；旋转时 `onAreaChange` 更新 `viewW`，自然重排。

### 4.3 “窗口宽度”不是“屏幕宽度”

- 自由窗口：`viewW` 是窗口内容宽度，表格铺满窗口是正确行为；
- 全屏后：`viewW` 才是整屏宽度，11 列才铺满整屏；
- 所以云调试看到“没铺满”时，先看是不是窗口模式，不要先改列宽算法。

---

## 五、键盘：统一 `RESIZE`，表尾必须露在键盘上方

### 5.1 最终选择

```ts
this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
```

手机、平板横屏、平板竖屏都用 `RESIZE`：

- 键盘把页面压矮；
- 表格 body 的 `viewH` 变小；
- 表尾仍然在键盘上方；
- `ensureEditorVisible()` 用缩小后的 `viewH` 把编辑格滚进可视区；
- 「下一行 ▾」按钮定位在 `viewH` 底部，也跟着键盘上移。

### 5.2 为什么不用 `NONE`

`NONE`（API 14+）是键盘直接覆盖页面、不压缩不上推：

- 表尾会被键盘盖住；
- 平板横屏键盘是全宽平铺键盘，平台审核要求表尾可见；
- 所以本项目最终**不用** `NONE`。

如果以后真要做“悬浮键盘 + 不顶表格”，需要：

- `KeyboardAvoidMode.NONE`；
- `window.on('keyboardHeightChange')` 拿高度（单位 px，`px2vp` 转换）；
- 手动扣掉键盘盖住的高度，滚动编辑格；
- 单独处理表尾/「下一行」按钮的位置。

### 5.3 点击格子要主动滚一次

`openEditor()` 末尾加：

```ts
this.startCaret();
this.ensureEditorVisible();
```

否则第一次点靠下的格子，键盘弹起后可能被挡住；`RESIZE` 只改变 `viewH`，不会自动把自绘表格的 `offsetY` 调过去。

---

## 六、平板菜单：隐藏「快捷设置」

> 2026-11-01 起与安卓 0.3.5 对齐：判据改成「当前窗口是否已经铺满 11 列」，
> 不再用 `deviceInfo.deviceType`（折叠屏外屏会被误判成平板）。

```ts
// common/LayoutRules.ets
export function fillsAllColumns(visible: boolean[], widthVp: number): boolean {
  // 还有列被隐藏 → false（必须保留快捷设置，否则没有入口恢复）
  // 全可见 + 平板布局（>=600vp）→ true
  // 全可见 + 手机布局 → 600vp 固定列宽 <= 当前窗口宽 才为 true
}

// pages/Index.ets
private isQuickSettingsVisible(): boolean {
  // 宽度用表格 via onViewWidth 回报的表体实际宽度，拿不到时退回窗口宽度
  const width = this.tableWidth > 0 ? this.tableWidth : this.screenW;
  return !fillsAllColumns(this.visibleMask(), width);
}

private menuItems(): MenuItem[] {
  const items: MenuItem[] = [];
  if (this.isQuickSettingsVisible()) {
    items.push(new MenuItem(t(this.lang, 'menu.quick'), () => this.openSettings()));
  }
  // 批次、隐私、协议、帮助、语言、版本照旧
  return items;
}
```

- 铺满 11 列（平板 / 折叠屏内屏 / 宽窗口）：不显示「快捷设置」；
- 手机、折叠屏外屏、窗口不足 600vp 的分屏、有列被隐藏：仍然显示；
- `screenW` 由 `windowSizeChange` 实时更新，折叠/展开/转屏都会跟着重算；
- 表格布局本身也改成只看窗口宽度（`viewW >= 600` 走平板布局）。
- 2026-11-02 云调试复验：双折叠内屏 / 三折叠双屏三屏 / 平板 → 无「快捷设置」；外屏 / 单屏 / 手机 → 有。

---

## 七、云调试 / 验收时最容易误判的点

| 现象 | 真正原因 | 处理 |
|---|---|---|
| 表格只占中间一块，没铺满 | 应用在自由窗口，`viewW` 是窗口宽度 | 确认 `supportWindowMode: ["fullscreen", "split"]` 且平板启动调用了 `maximize()`；看标题栏是否有最大化按钮 |
| 平板横屏 UI 还是竖屏 | Pad 不允许强制竖屏 | 让平板自动旋转，横屏也做布局 |
| 11 列被裁/要横滑 | 窗口宽度 < 600，走了手机固定列宽 | 全屏/最大化；平板布局按**当前窗口宽度**判定（>=600vp） |
| 键盘把表尾顶没了 | 用了 `NONE` 覆盖 | 改回 `RESIZE` |
| 键盘弹起编辑格被挡 | 自绘表格没滚 `offsetY` | `ensureEditorVisible()` |
| 行线发虚/断 | 浏览器缩放 + 0.5vp 边框 | 用云调试原图/设备截图判断，不要按缩放截图改代码 |
| 云调试还是旧界面 | 同 `versionCode` 缓存 | 升 `versionCode` 重打重传 |

---

## 八、上架包：HAP ≠ APP

| 包型 | 用途 | 上架 |
|---|---|---|
| `.hap` | 云调试/真机安装 | 不能直接上架 |
| `.app` | AppGallery 发布包 | 传这个 |

### 8.1 不要用明文密码让 hvigor 签名

hvigor 要求 `storePassword` / `keyPassword` 是 DevEco 生成的**加密值**（≥32 位 hex）。命令行直接写明文会报：

```text
00303116 The length of the storePassword or keyPassword ... is less than 32
```

### 8.2 可行 CLI 路线

1. `build-profile.json5` 注释掉 `signingConfig`，打 **unsigned**；
2. `hvigorw assembleApp --no-codesign` 出 unsigned `.app`；
3. `hap-sign-tool sign-app` 用 p12/cer/p7b 签 `.app`；
4. 同样方式签 `.hap` 供云调试。

项目脚本：`scripts/build-release-app.ps1`。  
产物：

```text
dist/mixcalc-<version>-release-signed.app
dist/mixcalc-<version>-release-signed.hap
```

> `verify-app` 对 AGC 发布证书可能报 `11011005 Param is not trusted`，是工具信任根问题；以云调试安装/上架结果为准。

---

## 九、代码位置

| 内容 | 文件 |
|---|---|
| 方向 / 全屏 / 窗口模式 | `entry/src/main/module.json5` |
| 手机锁竖屏、平板自动旋转 | `entry/src/main/ets/entryability/EntryAbility.ets` |
| 键盘避让、平板菜单 | `entry/src/main/ets/pages/Index.ets` |
| 边到边 / 系统栏颜色 / 避让高度 | `entry/src/main/ets/common/WindowChrome.ets` |
| 11 列宽度、编辑格滚动 | `entry/src/main/ets/table/MixCalcTable.ets` |
| 云调试 / 签名 / 上架 | `docs/huawei-cloud-test-guide.md` |
| 输入框 / 键盘 / 焦点 | `docs/harmony-input-keyboard-notes.md` |

---

## 十、一句话版本

**手机启动竖屏；平板运行时 `auto_rotation` + 启动 `maximize()`；`supportWindowMode: ["fullscreen", "split"]`；11 列按当前 `viewW` 均分；键盘横竖屏都用 `RESIZE`，表尾永远在键盘上方。**

---

## 十一、边到边（沉浸式）

### 11.1 结论

`setWindowLayoutFullScreen(true)` + **避让高度 padding**，不要指望 `expandSafeArea`。

`expandSafeArea` 只扩展**绘制**区域，不会把布局内容挪开：标题栏是 40vp、表尾是行高，都是固定尺寸，属性挂上去等于没效果，内容照样被状态栏 / 手势条压住。固定尺寸的条要用 padding 把内容让出来、背景自己铺满。

### 11.2 三条硬规则

1. **系统栏颜色一律透明（`#00000000`），颜色由页面自己画在系统栏下面**。别把实色推给系统——平板全屏时看着一样，一旦拖进分屏 / 小窗就会「还晚了」（见 11.4）。
2. **避让高度用 `getWindowAvoidArea` 取，并且必须监听 `avoidAreaChange`**。转屏、折叠展开、分屏、切三键/手势导航都会变；只在启动时取一次，用户一折叠就错位。
3. **底部取 `max(TYPE_SYSTEM.bottomRect, TYPE_NAVIGATION_INDICATOR.bottomRect)`**：三键导航塞在 `TYPE_SYSTEM` 里，手势条才是 `TYPE_NAVIGATION_INDICATOR`，两个都读才不漏。

### 11.3 坑

- `getWindowAvoidArea` 返回的是 **px**，布局是 vp，必须 `px2vp`；忘了换算会多出三四倍空白。
- `height(40 + inset)` + `padding({top: inset})` 才等价于「内容行 40vp + 背景垫到顶」；只加 padding 不补 height，ArkUI 的 padding 在尺寸内，内容会被压扁。
- `avoidAreaChange` 在 `loadContent` 之前拿不到准值，要在 `loadContent` 回调里再 `syncInsets()` 一次兜底。
- 系统栏颜色别在三个页面各写一份（现在是 `WindowChrome.ets` 一份），否则改色必漏。
- **网页页（帮助 / 隐私 / 协议）要单独做避让**：`Web` 组件自己不会让状态栏，根 `Column` 必须加 `padding({ top: 状态栏, bottom: 导航条 })`；实测 `Web` 节点边界 = `[0,108][1084,2322]`（108px 状态栏 / 90px 导航栏）才对。
- **键盘弹起时底部装饰条要收掉**：`RESIZE` 已经把窗口压到键盘上方，导航条这时压在键盘上，如果还按底部避让留一条垫底，表尾和键盘之间就会多出 20 多 vp 空白；用 `kbVisible ? 0 : 避让高度`。
- 沉浸式之后**横屏挖孔**的左右避让要想清楚做不做；当前手机锁竖屏、平板横屏通常无孔，所以没做。

### 11.4 分屏 / 悬浮窗：状态栏必须「当帧」交还系统

**现象**：手机从底部上滑进分屏 / 小窗，整个手势过程中顶部状态栏一直是应用的绿，松手、窗口定稿后才变回壁纸。

**原因有两层**

1. `windowStatusChange` 在**手势结束、窗口形态定稿之后**才派发。指望它来改颜色，就一定比动画晚；
2. 更关键的是：只要 `statusBarColor` 推过实色，系统栏就一直按那个颜色画，跟窗口动画无关。

**结论：不要给系统栏推实色。**

`statusBarColor` / `navigationBarColor` 恒为 `#00000000`，绿 / 白由页面自己画在系统栏位置。窗口一缩小，那块内容跟着窗口走，状态栏**当帧**就透出壁纸——和手势动画同步，不依赖任何回调时机。

**实现要点（`common/WindowChrome.ets`）**

- `applyWindowMode()` 按 `getWindowStatus()` 切换：`SPLIT_SCREEN` / `FLOATING` → `setWindowLayoutFullScreen(false)` + 避让高度写 0；`FULL_SCREEN` → 恢复；
- 进小窗时 `TYPE_SYSTEM.topRect` 报的是系统「三点控制栏」高度，照旧当状态栏加 padding，会在窗口里多画一条色带，所以非全屏时两个避让高度**一律 0**；
- 除 `windowStatusChange` 外再挂 `windowSizeChange` 兜底（个别版本进小窗只发尺寸事件）；
- 启动**不要**预判模式：窗口建好前 `getWindowStatus()` 可能是 `UNDEFINED`，会把全屏误判成分屏；等 `loadContent` 回调 / `maximize()` 之后各读一次；
- 分屏 / 小窗下图标色换回系统默认白色；
- `MAXIMIZE`（PC / 2in1 / 平板自由多窗最大化）暂按全屏处理，待平板复验。

### 11.5 顶部 / 底部配色（与安卓对齐）

- 顶部两条色带：状态栏区域 `#1F6B30` + 标题栏 `#2D8C42`。深绿那条是 `Index` 顶部一个 `Column`（高度 = 状态栏避让高度），**不是**系统栏颜色，所以它天然跟着窗口走；
- 底部：屏幕最底部铺 `#F0F0F0`（与表格灰格同色），不是表尾的 `#EAF3EC`——否则底部会多出一条绿带；
- 网页页（帮助 / 隐私 / 协议）：白底 + 黑图标，靠 `WebPage` 根 `Column` 的白底兜住透明状态栏。
