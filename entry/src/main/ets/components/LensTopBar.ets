/**
 * Thanh điều khiển phía trên cửa sổ kết quả (Lens / OCR / Dịch thuật)
 */
@Component
export struct LensTopBar {
  public title: string = 'Google Lens';
  public onClose: () => void = () => {};
  public onRefresh: () => void = () => {};

  build() {
    Row() {
      // Icon thương hiệu Lens thu nhỏ
      Row({ space: 8 }) {
        Circle({ width: 10, height: 10 }).fill('#4285F4')
        Circle({ width: 10, height: 10 }).fill('#EA4335')
        Circle({ width: 10, height: 10 }).fill('#FBBC05')
        Circle({ width: 10, height: 10 }).fill('#34A853')

        Text(this.title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#202124')
          .margin({ left: 4 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(VerticalAlign.Center)
      .layoutWeight(1)

      // Nút làm lại
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Image($r('sys.media.ohos_ic_public_restore'))
          .width(18)
          .height(18)
          .fillColor('#5F6368')
      }
      .width(36)
      .height(36)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        this.onRefresh();
      })

      // Nút đóng
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Image($r('sys.media.ohos_ic_public_cancel'))
          .width(20)
          .height(20)
          .fillColor('#5F6368')
      }
      .width(36)
      .height(36)
      .backgroundColor(Color.Transparent)
      .margin({ left: 8 })
      .onClick(() => {
        this.onClose();
      })
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#E8EAED' })
  }
}
