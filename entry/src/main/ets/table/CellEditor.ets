/**
 * 单元格内编辑器：对应安卓 CellEditorOverlay。
 * 覆盖在单元格位置，挂载后主动抢焦点弹出键盘，输入实时回调。
 */
@Component
export struct CellEditor {
  value: string = '';
  widthVp: number = 60;
  heightVp: number = 40;
  xVp: number = 0;
  yVp: number = 0;
  isNumber: boolean = true;
  onValueChange: (text: string) => void = () => {};
  onDone: () => void = () => {};
  onNext: () => void = () => {};
  private finished: boolean = false;

  aboutToAppear(): void {
    // 挂载后连续尝试抢焦点，避免第一次点击只显示输入框不弹键盘
    setTimeout(() => {
      focusControl.requestFocus('cellEditor');
    }, 30);
    setTimeout(() => {
      focusControl.requestFocus('cellEditor');
    }, 150);
  }

  /** 回车与失焦都会触发，只允许提交一次，避免第二次用空串清空格子 */
  private finish(): void {
    if (this.finished) {
      return;
    }
    this.finished = true;
    this.onDone();
  }

  build() {
    TextInput({ text: this.value })
      .id('cellEditor')
      .type(this.isNumber ? InputType.NUMBER_DECIMAL : InputType.Normal)
      .width(this.widthVp)
      .height(this.heightVp)
      .fontSize(12)
      .textAlign(TextAlign.Center)
      .padding({ left: 0, right: 0, top: 0, bottom: 0 })
      .borderRadius(0)
      .backgroundColor('#FFFFFF')
      .border({ width: 1.5, color: '#2D8C42' })
      .caretColor('#2D8C42')
      .position({ x: this.xVp, y: this.yVp })
      .zIndex(5)
      .defaultFocus(true)
      .enterKeyType(EnterKeyType.Next)
      .onChange((text: string) => {
        this.onValueChange(text);
      })
      .onSubmit(() => {
        if (this.finished) {
          return;
        }
        this.finished = true;
        this.onNext();
      })
      .onBlur(() => {
        this.finish();
      })
  }
}