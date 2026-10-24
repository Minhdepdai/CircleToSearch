import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { HistoryService, HistoryItem } from '../services/HistoryService';
import { ImageService } from '../services/ImageService';

/**
 * Trang Lịch sử: danh sách 20 vùng khoanh gần nhất.
 * Chạm 1 mục để mở lại vùng đó ở trang khoanh tròn.
 */
@Entry
@Component
struct HistoryPage {
  @State private items: HistoryItem[] = [];
  @State private isLoading: boolean = true;

  private async reload(): Promise<void> {
    this.isLoading = true;
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    this.items = await HistoryService.getItems(context);
    this.isLoading = false;
  }

  aboutToAppear(): void {
    this.reload();
  }

  /**
   * Mở lại mục lịch sử: nạp ảnh crop vào AppStorage rồi về trang khoanh tròn
   */
  private async openItem(item: HistoryItem): Promise<void> {
    try {
      const pixelMap = await ImageService.loadPixelMapFromUri(item.filePath);
      AppStorage.setOrCreate<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP, pixelMap);
      AppStorage.setOrCreate<string>(Constants.KEY_IMAGE_SOURCE, Constants.SOURCE_GALLERY);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/CircleCropPage' });
    } catch (err) {
      Logger.error('Mở mục lịch sử thất bại: %{public}s', JSON.stringify(err));
      this.getUIContext().getPromptAction().showToast({ message: 'Không mở được ảnh này' });
      await this.reload();
    }
  }

  private async clearHistory(): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    await HistoryService.clearAll(context);
    this.getUIContext().getPromptAction().showToast({ message: 'Đã xóa toàn bộ lịch sử' });
    this.reload();
  }

  private modeLabel(mode: string): string {
    if (mode === Constants.MODE_OCR) {
      return 'Trích text';
    }
    if (mode === Constants.MODE_TRANSLATE) {
      return 'Dịch thuật';
    }
    return 'Tìm kiếm';
  }

  private modeColor(mode: string): string {
    if (mode === Constants.MODE_OCR) {
      return '#34A853';
    }
    if (mode === Constants.MODE_TRANSLATE) {
      return '#EA4335';
    }
    return '#4285F4';
  }

  private formatTime(createdAt: number): string {
    const d = new Date(createdAt);
    const hh = `0${d.getHours()}`.slice(-2);
    const mm = `0${d.getMinutes()}`.slice(-2);
    const dd = `0${d.getDate()}`.slice(-2);
    const mo = `0${d.getMonth() + 1}`.slice(-2);
    return `${dd}/${mo} ${hh}:${mm}`;
  }

  build() {
    Column() {
      // Header
      Row() {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Image($r('sys.media.ohos_ic_public_arrow_left'))
            .width(20)
            .height(20)
            .fillColor('#202124')
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })

        Text('Lịch sử khoanh vùng')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#202124')
          .margin({ left: 8 })

        Blank()

        Button('Xóa hết')
          .fontSize(13)
          .fontColor('#EA4335')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            this.clearHistory();
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 8, right: 16 })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#1A73E8')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.items.length === 0) {
        Column({ space: 10 }) {
          Image($r('sys.media.ohos_ic_public_albums'))
            .width(48)
            .height(48)
            .fillColor('#9AA0A6')
          Text('Chưa có lịch sử nào')
            .fontSize(14)
            .fontColor('#5F6368')
          Text('Các vùng bạn khoanh sẽ được lưu lại ở đây (tối đa 20)')
            .fontSize(12)
            .fontColor('#9AA0A6')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.items, (item: HistoryItem, index: number) => {
            ListItem() {
              Row({ space: 14 }) {
                Image(item.filePath)
                  .width(56)
                  .height(56)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
                  .alt($r('sys.media.ohos_ic_public_albums'))

                Column({ space: 4 }) {
                  Text(this.modeLabel(item.mode))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#202124')
                  Text(this.formatTime(item.createdAt))
                    .fontSize(12)
                    .fontColor('#9AA0A6')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Circle({ width: 8, height: 8 }).fill(this.modeColor(item.mode))
              }
              .width('100%')
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .shadow({ radius: 6, color: '#12000000', offsetY: 2 })
              .onClick(() => {
                this.openItem(item);
              })
            }
          }, (item: HistoryItem, index: number) => `${item.createdAt}_${item.mode}`)
        }
        .width('92%')
        .layoutWeight(1)
        .padding({ top: 8, bottom: 12 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
  }
}
