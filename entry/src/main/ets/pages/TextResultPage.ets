import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { OcrService } from '../services/OcrService';
import { HistoryService } from '../services/HistoryService';
import { LensLoadingView } from '../components/LensLoadingView';
import { LensTopBar } from '../components/LensTopBar';

/**
 * Trang kết quả Trích xuất văn bản (OCR on-device bằng CoreVisionKit).
 * Nhận PixelMap đã crop từ AppStorage, nhận diện text và cho phép copy.
 */
@Entry
@Component
struct TextResultPage {
  @State private isLoading: boolean = true;
  @State private ocrText: string = '';
  @State private errorMessage: string = '';
  private requestId: number = 0;

  aboutToAppear(): void {
    this.runOcr();
  }

  private async runOcr(): Promise<void> {
    const requestId = ++this.requestId;
    this.isLoading = true;
    this.errorMessage = '';
    this.ocrText = '';

    const pixelMap = AppStorage.get<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP);
    if (!pixelMap) {
      Logger.error('TextResultPage: không tìm thấy PixelMap trong AppStorage');
      if (requestId === this.requestId) {
        this.errorMessage = 'Không có hình ảnh để nhận diện';
        this.isLoading = false;
      }
      return;
    }

    try {
      const text = await OcrService.recognizeText(pixelMap);
      if (requestId !== this.requestId) {
        return;
      }
      this.ocrText = text;
      if (text === '') {
        this.errorMessage = 'Không nhận diện được văn bản trong vùng đã khoanh';
      }
      // Lưu vào lịch sử
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await HistoryService.addItem(context, pixelMap, Constants.MODE_OCR);
    } catch (error) {
      Logger.error('TextResultPage lỗi OCR: %{public}s', String(error));
      if (requestId === this.requestId) {
        this.errorMessage = 'Nhận diện thất bại. Hãy thử lại với hình ảnh rõ hơn.';
      }
    } finally {
      if (requestId === this.requestId) {
        this.isLoading = false;
      }
    }
  }

  /**
   * Copy toàn bộ text nhận diện được vào clipboard
   */
  private async copyToClipboard(): Promise<void> {
    if (this.ocrText === '') {
      return;
    }

    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.ocrText);
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(data);
      const uiContext = this.getUIContext();
      uiContext.getPromptAction().showToast({ message: 'Đã copy toàn bộ văn bản' });
    } catch (error) {
      Logger.error('Copy clipboard thất bại: %{public}s', String(error));
    }
  }

  private closePage(): void {
    const abilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      abilityContext.terminateSelf().catch((error: Error) => {
        Logger.error('Không thể đóng trang OCR: %{public}s', error.message);
      });
    } catch (error) {
      Logger.error('Không thể đóng trang OCR: %{public}s', String(error));
    }
  }

  build() {
    Column() {
      LensTopBar({
        title: 'Trích xuất văn bản',
        onClose: () => {
          this.closePage();
        },
        onRefresh: () => {
          this.runOcr();
        }
      })

      Stack() {
        if (this.isLoading) {
          LensLoadingView({ loadingText: 'Đang nhận diện văn bản...' })
        }

        if (this.errorMessage !== '') {
          Column({ space: 12 }) {
            Image($r('sys.media.ohos_ic_public_fail'))
              .width(48)
              .height(48)
              .fillColor('#EA4335')
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor('#5F6368')
              .textAlign(TextAlign.Center)
              .padding({ left: 24, right: 24 })
            Button('Thử lại')
              .fontSize(14)
              .backgroundColor('#1A73E8')
              .onClick(() => {
                this.runOcr();
              })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#FFFFFF')
        }

        if (!this.isLoading && this.errorMessage === '') {
          Column() {
            Scroll() {
              Text(this.ocrText)
                .fontSize(16)
                .fontColor('#202124')
                .lineHeight(26)
                .padding(16)
                .width('100%')
                .copyOption(CopyOptions.LocalDevice)
            }
            .layoutWeight(1)
            .align(Alignment.Top)
            .width('100%')

            Button('Copy toàn bộ')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .width('90%')
              .height(48)
              .backgroundColor('#1A73E8')
              .borderRadius(24)
              .margin({ bottom: 20 })
              .onClick(() => {
                this.copyToClipboard();
              })
          }
          .width('100%')
          .height('100%')
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
