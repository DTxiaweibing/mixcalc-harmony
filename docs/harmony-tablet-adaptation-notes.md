# 鸿蒙平板适配经验总结（秒算虾料）

> 来源：`mixcalc-harmony`（秒算虾料 鸿蒙版）平板适配 + AGC 云调试 + 上架打包过程。
> 环境：HarmonyOS SDK 6.0.1（API 21）、命令行工具链、云真机 MatePad Air。
> 适用场景：表格类应用，手机锁竖屏、平板横竖屏都要铺满，11 列按窗口宽度重算。

---

## 一、先记住这 6 条

1. **手机锁竖屏，平板自动旋转**：`module.json5` 用 `auto_rotation`，运行时再按 `deviceInfo.deviceType` 把手机锁成 `PORTRAIT`。
2. **不要试图强制平板竖屏**：第三方应用在 Pad 上强制不了整机方向；`orientation: portrait` 只会让竖屏应用在横屏时居中留边。
3. **平板要“启动即全屏”**：`supportWindowMode: ["fullscreen"]`。默认值包含 `split`/`floating`，平板可能以自由窗口启动。
4. **11 列按“当前窗口宽度”算，不是物理屏幕宽度**：`viewW` 是窗口内容宽度。自由窗口下它小于屏幕宽度，表格按窗口铺满是对的；最大化/全屏后自然变成整屏宽度。
5. **键盘统一用 `RESIZE`**：平板横屏也是全宽平铺键盘，平台审核要求；`RESIZE` 让页面变矮、表尾留在键盘上方。不要用 `NONE` 覆盖，否则表尾被盖住。
6. **别拿表格的 `viewH` 判断平板**：`viewH` 会随键盘压缩变化，可能把平板误判成手机。用 `deviceInfo` 或窗口/屏幕尺寸判断。

---

## 二、方向：手机锁竖屏，平板自动旋转

### 2.1 配置

`entry/src/main/module.json5`：

```json5
"orientation": "auto_rotation",
"supportWindowMode": ["fullscreen"],
```

### 2.2 运行时按设备类型设置

`EntryAbility.onWindowStageCreate`，`loadContent` 成功后：

```ts
import { deviceInfo } from '@kit.BasicServicesKit';

const win = windowStage.getMainWindowSync();
const isPhone = deviceInfo.deviceType === 'phone';
win.setPreferredOrientation(
  isPhone ? window.Orientation.PORTRAIT : window.Orientation.AUTO_ROTATION
).catch(() => {});
```

- 手机：`PORTRAIT`，横过来也不跟着转；
- 平板：`AUTO_ROTATION`，横竖屏都跟随系统；
- `2in1` / `default`：按自动旋转处理。

### 2.3 为什么不能强制平板竖屏

Pad 的规格是：竖屏应用在横屏时**居中显示/留边**，系统不会为了一个应用把整机转成竖屏。  
所以：

- 不要写“平板也强制竖屏”；
- 也不要把横屏留边当成 bug；
- 要么接受留边，要么让平板自动旋转、横屏也铺满（本项目选后者）。

---

## 三、启动即全屏：`supportWindowMode`

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

系统才会直接全屏启动，不需要用户去智慧多窗里点最大化。

### 3.3 注意

- 这个配置会**禁用分屏/悬浮窗**，是产品取舍；表格类应用通常可以接受。
- 如果重打包后仍是小窗口：确认 `module.json5` 真的打进 HAP、云调试没有缓存旧包；必要时升 `versionCode` 再传。
- 不要依赖 `targetAPIVersion >= 15` 的默认行为，显式写 `["fullscreen"]` 最稳。

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

```ts
private isTabletDevice(): boolean {
  return deviceInfo.deviceType === 'tablet'
    || deviceInfo.deviceType === '2in1'
    || this.screenW >= 600;
}

private menuItems(): MenuItem[] {
  const items: MenuItem[] = [];
  if (!this.isTabletDevice()) {
    items.push(new MenuItem(t(this.lang, 'menu.quick'), () => this.openSettings()));
  }
  // 批次、隐私、协议、帮助、语言、版本照旧
  return items;
}
```

- 平板：不显示「快捷设置」；
- 手机：仍然显示；
- `screenW >= 600` 是 `deviceType` 不可靠时的兜底。

---

## 七、云调试 / 验收时最容易误判的点

| 现象 | 真正原因 | 处理 |
|---|---|---|
| 表格只占中间一块，没铺满 | 应用在自由窗口，`viewW` 是窗口宽度 | 看标题栏是否有最大化按钮；配置 `supportWindowMode: ["fullscreen"]` |
| 平板横屏 UI 还是竖屏 | Pad 不允许强制竖屏 | 让平板自动旋转，横屏也做布局 |
| 11 列被裁/要横滑 | 窗口宽度 < 600，走了手机固定列宽 | 全屏/最大化；平板用 `deviceInfo` 判定 |
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
| 11 列宽度、编辑格滚动 | `entry/src/main/ets/table/MixCalcTable.ets` |
| 云调试 / 签名 / 上架 | `docs/huawei-cloud-test-guide.md` |
| 输入框 / 键盘 / 焦点 | `docs/harmony-input-keyboard-notes.md` |

---

## 十、一句话版本

**手机锁竖屏；平板 `auto_rotation` + `supportWindowMode: ["fullscreen"]`；11 列按当前 `viewW` 均分；键盘横竖屏都用 `RESIZE`，表尾永远在键盘上方。**
