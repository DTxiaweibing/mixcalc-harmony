// 页内胶囊提示：全项目 toast 的唯一外观来源。
// 系统 promptAction.showToast 不支持 height / borderRadius / fontSize（见 SDK ShowToastOptions），
// 所以提示统一用本组件：40vp 高、#FBE3E3 底、#7A1F1F 15vp 粗体、两端半圆。
// 英文长句靠缩小字号塞进单行，缩到 10vp 仍放不下才省略。

const TOAST_H: number = 40;
const TOAST_RADIUS: number = TOAST_H / 2;
const TOAST_MAX_FONT: string = '15vp';
const TOAST_MIN_FONT: string = '10vp';
const TOAST_PAD_X: number = 20;

@Component
export struct ToastPill {
  @Prop message: string = '';
  // 相对所在 Stack 的 y：表格内传 0（表头行顶部），页面内传「状态栏 + 标题栏」高度
  @Prop top: number = 0;

  build() {
    Row() {
      Text(this.message)
        .height(TOAST_H)
        .maxLines(1)
        // 放得下就是 15vp；放不下自动缩字号，10vp 是下限
        .minFontSize(TOAST_MIN_FONT)
        .maxFontSize(TOAST_MAX_FONT)
        .heightAdaptivePolicy(TextHeightAdaptivePolicy.MAX_LINES_FIRST)
        .fontWeight(FontWeight.Bold)
        .fontColor('#7A1F1F')
        .textAlign(TextAlign.Center)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .padding({ left: TOAST_PAD_X, right: TOAST_PAD_X })
        .backgroundColor('#FBE3E3')
        // 半径 = 高度一半 → 两端全圆角的胶囊
        .borderRadius(TOAST_RADIUS)
        .constraintSize({ maxWidth: '92%' })
    }
    .width('100%')
    .height(TOAST_H)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .position({ x: 0, y: this.top })
    // Transparent：自身和子节点不拦事件，被它盖住的表头照常可点。
    // （HitTestMode.None 只放行自身，子节点仍会挡点击，别用）
    .hitTestBehavior(HitTestMode.Transparent)
    .zIndex(8)
  }
}
