import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { ImageService } from '../services/ImageService';
import { CropNotificationService } from '../services/CropNotificationService';

/**
 * Màn hình chính (Dashboard): hướng dẫn sử dụng, thử nghiệm và lịch sử
 */
@Entry
@Component
struct Index {
  @State private isPicking: boolean = false;
  @State private isEnablingShortcut: boolean = false;

  private async enableCropShortcut(): Promise<void> {
    if (this.isEnablingShortcut) {
      return;
    }

    this.isEnablingShortcut = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const published = await CropNotificationService.publish(context);
      this.getUIContext().getPromptAction().showToast({
        message: published ? 'Đã tạo thông báo Crop. Chạm thông báo để bắt đầu.' : 'Hãy cho phép thông báo để dùng lối tắt này.'
      });
    } catch (error) {
      Logger.error('Không thể tạo thông báo Crop: %{public}s', String(error));
    } finally {
      this.isEnablingShortcut = false;
    }
  }

  /**
   * Chọn ảnh từ thư viện để thử trải nghiệm khoanh tròn
   */
  private async pickImageAndTest(): Promise<void> {
    if (this.isPicking) {
      return;
    }

    this.isPicking = true;
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectResult = await photoViewPicker.select(photoSelectOptions);

      const uri: string | undefined = photoSelectResult.photoUris[0];
      if (!uri) {
        return;
      }

      Logger.info('Đã chọn ảnh từ thư viện: %{public}s', uri);
      const pixelMap = await ImageService.loadPixelMapFromUri(uri);
      AppStorage.setOrCreate<image.PixelMap>(Constants.KEY_PENDING_PIXELMAP, pixelMap);
      AppStorage.setOrCreate<string>(Constants.KEY_IMAGE_SOURCE, Constants.SOURCE_GALLERY);
      this.getUIContext().getRouter().pushUrl({ url: 'pages/CircleCropPage' });
    } catch (error) {
      Logger.error('Lỗi khi chọn ảnh: %{public}s', String(error));
    } finally {
      this.isPicking = false;
    }
  }

  build() {
    Scroll() {
      Column({ space: 20 }) {
        // Header
        Column({ space: 8 }) {
          Row({ space: 10 }) {
            Circle({ width: 14, height: 14 }).fill('#4285F4')
            Circle({ width: 14, height: 14 }).fill('#EA4335')
            Circle({ width: 14, height: 14 }).fill('#FBBC05')
            Circle({ width: 14, height: 14 }).fill('#34A853')
          }
          .margin({ top: 32 })

          Text('Circle Lens')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#202124')

          Text('Thiết lập lối tắt và quản lý lịch sử tìm kiếm')
            .fontSize(14)
            .fontColor('#5F6368')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)

        // Lối tắt chính: notification không che nội dung ứng dụng người dùng đang xem.
        Column({ space: 10 }) {
          Row({ space: 10 }) {
            Image($r('sys.media.ohos_ic_public_scan'))
              .width(22)
              .height(22)
              .fillColor('#1A73E8')
            Text('Lối tắt Crop từ Smart Sidebar')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#202124')
          }
          Text('Chạm Circle Lens ở Smart Sidebar để nhận một thông báo. Chạm thông báo, HarmonyOS sẽ mở trình chọn vùng màn hình; chọn vùng xong bạn chỉ cần khoanh đối tượng để tìm.')
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#3C4043')
          Button(this.isEnablingShortcut ? 'Đang bật...' : 'Tạo thông báo Crop')
            .enabled(!this.isEnablingShortcut)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#1A73E8')
            .borderRadius(22)
            .padding({ left: 20, right: 20 })
            .onClick(() => {
              this.enableCropShortcut();
            })
        }
        .width('92%')
        .padding(18)
        .backgroundColor('#E8F0FE')
        .borderRadius(16)

        // Hướng dẫn luồng cử chỉ Knuckle -> Chia sẻ -> Circle Lens
        Column({ space: 14 }) {
          Row({ space: 10 }) {
            Image($r('sys.media.ohos_ic_public_scan'))
              .width(22)
              .height(22)
              .fillColor('#1A73E8')

            Text('Cách dùng với cử chỉ Knuckle')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#202124')
          }

          Text('1. Dùng 1 khớp ngón tay gõ và khoanh tròn vùng bất kỳ trên màn hình (tính năng chụp màn hình từng vùng của Huawei).\n2. Khi thanh công cụ xuất hiện, bấm nút "Chia sẻ" (Share).\n3. Chọn "Circle Lens" — ảnh vùng đó sẽ được mở sẵn trong trang khoanh tròn để chọn chế độ: Tìm kiếm / Trích text / Dịch thuật.')
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#3C4043')
        }
        .width('92%')
        .padding(18)
        .backgroundColor('#F1F3F4')
        .borderRadius(16)

        // Hướng dẫn ghim vào Smart Sidebar
        Column({ space: 14 }) {
          Row({ space: 10 }) {
            Image($r('sys.media.ohos_ic_public_drawer_open'))
              .width(22)
              .height(22)
              .fillColor('#1A73E8')

            Text('Hoặc mở từ Smart Sidebar')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#202124')
          }

          Text('Vuốt từ mép màn hình vào để mở thanh bên thông minh -> bấm dấu + -> ghim "Circle Lens". Khi cần tìm, chạm icon rồi mở notification “Circle Lens sẵn sàng” để chọn ảnh và khoanh vùng.')
            .fontSize(13)
            .lineHeight(20)
            .fontColor('#3C4043')
        }
        .width('92%')
        .padding(18)
        .backgroundColor('#F1F3F4')
        .borderRadius(16)

        // Các nút chức năng
        Row({ space: 12 }) {
          Button() {
            Row({ space: 8 }) {
              Image($r('sys.media.ohos_ic_public_albums'))
                .width(20)
                .height(20)
                .fillColor(Color.White)
              Text('Chọn ảnh thử')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
            }
          }
          .layoutWeight(1)
          .height(48)
          .backgroundColor('#1A73E8')
          .borderRadius(24)
          .onClick(() => {
            this.pickImageAndTest();
          })

          Button() {
            Row({ space: 8 }) {
              Image($r('sys.media.ohos_ic_public_clock'))
                .width(20)
                .height(20)
                .fillColor('#1A73E8')
              Text('Lịch sử')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1A73E8')
            }
          }
          .layoutWeight(1)
          .height(48)
          .backgroundColor('#FFFFFF')
          .borderRadius(24)
          .border({ width: 1, color: '#1A73E8' })
          .onClick(() => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/HistoryPage' });
          })
        }
        .width('92%')

        // Thông tin kiến trúc
        Column({ space: 8 }) {
          Text(this.isPicking ? 'Đang mở thư viện...' : 'Tìm kiếm hình ảnh • Trích xuất văn bản • Dịch thuật')
            .fontSize(12)
            .fontColor('#9AA0A6')
            .textAlign(TextAlign.Center)
          Text('Stage Model | API 24 | ArkUI Native | Web Shell | CoreVisionKit OCR')
            .fontSize(11)
            .fontColor('#9AA0A6')
            .textAlign(TextAlign.Center)
        }
        .margin({ top: 12, bottom: 24 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
  }
}
