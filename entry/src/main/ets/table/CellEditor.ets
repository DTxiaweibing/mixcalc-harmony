/**
 * 单元格内编辑器：与安卓 CellEditorOverlay 对应。
 * 覆盖在单元格位置，自动获焦弹出键盘，输入实时回调。
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

  build() {
    TextInput({ text: this.value })
      .id('cellEditor')
      .type(this.isNumber ? InputType.NUMBER_DECIMAL : InputType.Normal)
      .width(this.widthVp)
      .height(this.heightVp)
      .fontSize(12)
      .textAlign(TextAlign.Center)
      .padding({ left: 0, right: 0, top: 0, bottom: 0 })
      .backgroundColor('#FFFFFF')
      .border({ width: 1.5, color: '#2D8C42' })
      .position({ x: this.xVp, y: this.yVp })
      .zIndex(5)
      .defaultFocus(true)
      .enterKeyType(EnterKeyType.Done)
      .onChange((text: string) => {
        this.onValueChange(text);
      })
      .onSubmit(() => {
        this.onDone();
      })
      .onBlur(() => {
        this.onDone();
      })
  }
}