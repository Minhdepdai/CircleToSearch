/**
 * Hiệu ứng Loading Shimmer / Pulse mô phỏng animation quét của Google Lens
 */
@Component
export struct LensLoadingView {
  @Prop loadingText: string = 'Đang phân tích hình ảnh...';
  @State private rotateAngle: number = 0;
  private timerId: number = -1;

  aboutToAppear(): void {
    // Chu kỳ animation quay các vòng hào quang
    this.stopAnimation();
    this.timerId = setInterval(() => {
      this.rotateAngle = (this.rotateAngle + 10) % 360;
    }, 30);
  }

  aboutToDisappear(): void {
    this.stopAnimation();
  }

  private stopAnimation(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  build() {
    Column() {
      // Vòng tròn hào quang đa sắc phong cách Google Lens
      Stack({ alignContent: Alignment.Center }) {
        Circle({ width: 70, height: 70 })
          .fill(Color.Transparent)
          .stroke('#4285F4')
          .strokeWidth(3)
          .strokeDashArray([15, 10])
          .rotate({ angle: this.rotateAngle })

        Circle({ width: 50, height: 50 })
          .fill(Color.Transparent)
          .stroke('#EA4335')
          .strokeWidth(2.5)
          .strokeDashArray([10, 8])
          .rotate({ angle: -this.rotateAngle })

        Image($r('sys.media.ohos_ic_public_search_filled'))
          .width(26)
          .height(26)
          .fillColor('#1A73E8')
      }
      .margin({ bottom: 16 })

      Text(this.loadingText)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#3C4043')

      Text('Circle Lens')
        .fontSize(12)
        .fontColor('#70757A')
        .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor('#F8F9FA')
  }
}
