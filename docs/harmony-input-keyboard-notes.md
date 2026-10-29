# 鸿蒙 ArkUI 输入框 / 键盘 / 焦点经验总结

> 来源：`mixcalc-harmony`（秒算虾料 鸿蒙版）开发过程中踩过的坑与最终方案。
> 环境：HarmonyOS SDK 6.0.1（API 21），DevEco **命令行**工具链，真机 nova 15（HarmonyOS 7.0.0）。
> 适用场景：表格类 / 多单元格录入界面（WPS、Excel、自绘表格那种"点一格输一格、按下一步往右走"）。

**下次做鸿蒙应用、尤其要自己做"单元格内编辑"的，先看这一篇，能省掉两三天。**

---

## 一、最核心的结论（先记住这三条）

1. **全表只放一个 `TextInput`，并且要放在不会被重建的位置**（最外层 `Stack`，不要放在 `ForEach`/`List`/`if` 里）。
2. **`onSubmit` 必须调 `event.keepEditableState()`**，否则按输入法的「下一步/回车」时，ArkUI 会让输入框**退出编辑态** → 焦点释放 → 输入法收键盘 → 你再抢焦点 → 键盘又弹上来，就是"退下去再弹上来"。
3. **`onBlur` 里绝对不要收键盘/结束编辑**，换格瞬间的旧 blur 会晚一步到达，会把刚打开的新格连键盘一起关掉。

---

## 二、典型症状与真正原因

| 症状 | 真正原因 |
|---|---|
| 换格时键盘"退下去又弹上来"（闪一下） | 编辑会话断了：`TextInput` 被销毁重建，或 `onSubmit` 退出编辑态，或 `onBlur` 主动收键盘 |
| 换格后键盘不弹、光标不在新格 | 新节点还没挂载就 `requestFocus`（时间差），或焦点被 `Grid/List/Scroll` 这类可获焦容器抢走 |
| 点一下格子只出现"编辑框"却没有键盘 | 只是切换了"编辑态样式"，没有真正 `requestFocus` 到输入框 |
| 输入框浮在所有格子上面、拖动表格时不跟手 | 输入框用了 `position` 但坐标没跟滚动量/冻结列一起算，或者放在浮层（Overlay/Dialog）里 |
| 表尾被键盘挡住 | 没有设置键盘避让模式（默认 `OFFSET` 会把整页顶上去） |

---

## 三、最终方案（本项目用的，已验证）

### 3.1 结构：一个常驻编辑器 + 一个"画出来的表格"

```ts
Stack() {                       // 最外层
  Column() {                    // 表头 / 表体 / 表尾（自绘，全部是 Text）
    // ...
  }

  // 全表唯一的输入框，和表体平级，表体重排不会碰它
  if (this.editingRow >= 0 && this.editingCol >= 0) {
    TextInput({ text: this.editorText, controller: this.editorCtrl })
      .id('cellEditor')
      .type(this.editingCol === 1 ? InputType.Normal : InputType.NUMBER_DECIMAL)
      .inputFilter(this.editingCol === 1 ? '[0-9\\-到至~—、，, 号]' : '[0-9.]')
      .position({ x: this.columnLeft(this.editingCol),
                  y: HEAD_H + this.editingRow * ROW_H - this.offsetY })
      .defaultFocus(true)
      .enableKeyboardOnFocus(true)
      .enterKeyType(EnterKeyType.Next)
      .onChange((text: string) => { /* 见 3.4 */ })
      .onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
        event.keepEditableState();   // ★ 关键
        this.moveToNextCell();
      })
      .onBlur(() => {
        if (Date.now() - this.editorOpenedAt < 400) { return; }  // ★ 挡住换格瞬间的旧 blur
        this.finishEdit();
      })
  }
}
```

要点：

- **不要**用「每个格子一个 `TextInput`，`if (editing === i) TextInput else Text`」这种写法，切格必然销毁重建 → 闪。
- **不要**把编辑器放进 `ForEach`/`LazyForEach`/`List` 的 item 里，列表复用会重建它。
- 编辑器用 `position()` 绝对定位到目标格子上，视觉上"长"在格子里；坐标要和格子同一套（含表头高度、滚动偏移、冻结列宽度）。
- 自绘表格的 `Text` 想刷新内容，`ForEach` 的 key **必须带上一个 version**（`row + '_' + col + '_' + version`），否则数据变了界面不刷新；但注意每次 version 变化会重建所有格子——所以**编辑器绝不能放在这棵子树里**。

### 3.2 `keepEditableState()` 是解决"键盘闪"的关键

```ts
.onSubmit((enterKey: EnterKeyType, event: SubmitEvent) => {
  event.keepEditableState();
  this.moveToNextCell();
})
```

API 11+ 的 `SubmitEvent.keepEditableState()` = "提交后保持编辑态"。
不调它，输入法的「下一步/回车」会让输入框退出编辑态，键盘就收；本机（搜狗、小艺）都复现。

> 排查手法：把 `onSubmit` 临时改成**什么都不做**（只提交文本、不改任何状态），如果键盘**照样收**，就说明是"输入法动作键 → 输入框退出编辑态"这个默认行为，只能靠 `keepEditableState()`，不是你的状态管理问题。本项目就是这么定位的。

### 3.3 焦点：怎么保证新格拿到焦点又不抖

```ts
// 打开/换格后
setTimeout(() => focusControl.requestFocus('cellEditor'), 60);
setTimeout(() => focusControl.requestFocus('cellEditor'), 180);  // 兜一次
```

- 换格时**不要**先 `editingRow = -1` 再设新值，中间那一帧输入框会被销毁；直接从旧格改到新格。
- 输入框节点**保持同一个**（不要用 `ForEach` 的 key 强制重建，那会闪）。
- `defaultFocus(true)` 只在首次挂载有效，不能依赖它做换格聚焦。

### 3.4 程序化改文本要压住 `onChange`

换格时要把新格的原值塞进输入框，这会触发 `onChange`，如果不挡住，会被当成"用户输入"提交一次。

```ts
this.editorText = seed;        // 绑定值
this.suppressChange = true;    // 压住一次
setTimeout(() => { this.suppressChange = false; }, 400);

.onChange((text: string) => {
  this.editingText = text;
  if (this.suppressChange) { this.suppressChange = false; return; }
  this.applyLive(text);        // 边输边算
})
```

> 别用 `$$this.editorText` 双向绑定：本项目实测那一版会"输入不显示/光标乱跳"，改回显式 `text + onChange` 才稳。

### 3.5 键盘避让：让表尾贴在键盘上方

```ts
// Entry 页 aboutToAppear
import { KeyboardAvoidMode } from '@kit.ArkUI';
this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
```

- 默认 `OFFSET`：整页被顶上去，表尾可能被键盘挡住。
- `RESIZE`：窗口变矮，表尾自然落在键盘上沿。
- 自绘键盘（见第四节）是"布局的一部分"，不需要这个。

### 3.6 输入内容限制

```ts
.inputFilter(this.editingCol === 1 ? '[0-9\\-到至~—、，, 号]' : '[0-9.]')
```

- `inputFilter` 是**按单字符匹配**的正则，允许的字符留在里面，其余直接打不进去。
- 设置后 `InputType` 自带的过滤会失效（API 11+ 行为），所以白名单要自己写全。
- 需要"任意字符"就写 `'[\\s\\S]'`。
- 中文输入法（拼音上屏）也会走这个过滤，比如白名单里没有汉字，用户就没法用拼音输入汉字。

### 3.7 滚动与编辑的关系

- 表格自己实现滚动（`offsetX/offsetY` + `PanGesture`）时，编辑器 `position` 里要减掉 `offsetY`，这样拖动表格它跟着格子走。
- 格子被滚出可视区（钻到表头下面/滑出左右）就**主动收编辑**，否则输入框会画在表头或别的格子上。
- 冻结列：编辑器 `x` 不能小于冻结宽度，否则会盖在"序号"列上。

---

## 四、备选方案：自绘键盘（customKeyboard）

```ts
TextInput().customKeyboard(this.numKeypad())   // numKeypad 是自己画的 4×4 数字键盘
```

**优点**

- 键盘是界面的一部分，**换格绝对不会收键盘、不会闪**；
- 键位随便排（可以加「下一行」「清空」「00」这种业务键）；
- 不依赖用户装了哪个输入法。

**缺点（本项目最后放弃它的原因）**

- 得自己画所有键，**平板/大屏要另做一套尺寸**；
- 用户习惯的系统输入法（搜狗/小艺）里的联想、语音、剪贴板全没了；
- 需要字母时（比如棚号可能带文字）还得再画一个字母键盘。

**结论**：如果「换格不掉键盘」用 `keepEditableState()` 能解决，**优先用系统输入法 + 常驻编辑器**；自绘键盘只在"必须自定义键位"或"输入法行为完全不可控"时用。

---

## 五、其他容易踩的 ArkUI 坑（同项目记录）

| 坑 | 现象 | 解法 |
|---|---|---|
| `Span` 没有 `onClick` | 一段文字里做"可点链接"（如隐私弹窗里的《用户协议》） | 把正文按字符/词切成多个 `Text` 放 `Flex({wrap:Wrap})` 里，链接那段单独加 `onClick` |
| 自定义 `@CustomDialog` 里 `Button` 文字不居中 | 弹窗按钮文字偏上 | 用 `Text` + `Row().justifyContent(FlexAlign.Center)`，别用 `Button` 的默认排版 |
| `setInterval` 做惯性滚动 | 掉帧时 `dt` 被截断，滑不远 | 用解析积分：`Δx = (v0/k)(1-e^(-k·dt))`，见 `MixCalcTable.startFling()` |
| 屏幕旋转 / 平板 | 布局写死 dp 在平板上一半空白 | 按**可用宽度**做断点：手机固定列宽 + 横滑；平板按可见列均分屏宽再整体贴合（参考安卓 `TabletLayout.computeWidths`） |
| 手动 `layout()` 的 `TextView`（安卓侧经验） | 文字永远不居中 | 先 `measure()` 再 `layout()`，或干脆自绘（`PillButtonView`，用 `fontMetrics` 算基线） |

---

## 六、排查清单（照着做，5 分钟定位）

1. **键盘是不是"收一下再弹"** → 在 `onFocus/onBlur` 打日志，看有没有 `blur → (无 focus) → focus` 的空档。
2. **`onSubmit` 里有没有 `keepEditableState()`** → 没有就先加。
3. **输入框是不是被 `if`/`ForEach`/`List` 包着** → 是就搬到最外层。
4. **`onBlur` 里是不是在收键盘/结束编辑** → 去掉，改成时间闸（400ms 内忽略）。
5. **换格时是不是先关再开** → 改成直接改坐标和文本，不经过"关闭"状态。
6. **格子滚出可视区后输入框还在** → 在滚动回调里做边界判断，出去就收编辑。
7. **系统键盘挡住表尾** → `KeyboardAvoidMode.RESIZE`。

---

## 七、相关代码位置（本仓库）

- `entry/src/main/ets/table/MixCalcTable.ets`
  - 编辑器与 `onSubmit/onBlur/onChange`：搜 `cellEditor`
  - 换格：`moveEditor()` / `nextCell()` / `nextRowDown()`
  - 滚出可视区收编辑：`clampOffsets()`
  - 屏宽自适应列宽：`ensureWidths()` / `cw()`
  - 惯性滚动：`startFling()` / `flingRunnable`
- `entry/src/main/ets/pages/Index.ets`
  - 键盘避让：`setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE)`
  - 隐私弹窗（含"正文内可点链接"的切段实现）：`privacyTokens()`
- `PLAN.md`：项目进度与待办
