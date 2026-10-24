import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { Logger } from '../common/Logger';
import { BoundingBox } from '../common/Geometry';

/**
 * Service xử lý ảnh: nạp từ URI, crop theo vùng khoanh, resize và nén JPEG
 */
export class ImageService {
  /** Chiều rộng tối đa khuyến nghị cho ảnh upload Google Lens */
  private static readonly MAX_UPLOAD_WIDTH: number = 1440;
  private static readonly MIN_CROP_SIDE: number = 8;

  /**
   * Đọc file ảnh từ URI (photoAccessHelper) hoặc đường dẫn file và tạo PixelMap
   */
  public static async loadPixelMapFromUri(fileUri: string): Promise<image.PixelMap> {
    Logger.info('Bắt đầu đọc ảnh từ URI: %{public}s', fileUri);
    let file: fileIo.File | null = null;
    try {
      file = fileIo.openSync(fileUri, fileIo.OpenMode.READ_ONLY);
      const imageSource = image.createImageSource(file.fd);
      const decodingOptions: image.DecodingOptions = {
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      };
      const pixelMap = await imageSource.createPixelMap(decodingOptions);
      await imageSource.release();
      Logger.info('Tạo PixelMap thành công');
      return pixelMap;
    } catch (err) {
      Logger.error('Lỗi khi đọc file ảnh từ URI: %{public}s', JSON.stringify(err));
      throw new Error(`Không thể nạp ảnh: ${JSON.stringify(err)}`);
    } finally {
      if (file) {
        try {
          fileIo.closeSync(file);
        } catch (error) {
          Logger.warn('Không thể đóng file ảnh: %{public}s', String(error));
        }
      }
    }
  }

  /**
   * Cắt một vùng hình chữ nhật của PixelMap và trả về PixelMap MỚI (giữ nguyên ảnh gốc).
   * Dùng clone() rồi crop() trên bản sao: không nén lại JPEG nên không mất chất lượng/alpha.
   */
  public static async cropPixelMap(source: image.PixelMap, box: BoundingBox): Promise<image.PixelMap> {
    let copy: image.PixelMap | null = null;
    try {
      const imageInfo = await source.getImageInfo();
      const imgWidth = imageInfo.size.width;
      const imgHeight = imageInfo.size.height;

      // Giới hạn tọa độ trong biên ảnh
      const x = Math.max(0, Math.min(Math.round(box.x), imgWidth - 1));
      const y = Math.max(0, Math.min(Math.round(box.y), imgHeight - 1));
      const width = Math.min(Math.round(box.width), imgWidth - x);
      const height = Math.min(Math.round(box.height), imgHeight - y);

      if (width < ImageService.MIN_CROP_SIDE || height < ImageService.MIN_CROP_SIDE) {
        throw new Error(`Vùng khoanh quá nhỏ: ${width}x${height}`);
      }

      Logger.info('Crop ảnh: x=%{public}d, y=%{public}d, w=%{public}d, h=%{public}d', x, y, width, height);
      copy = await source.clone();
      await copy.crop({ x: x, y: y, size: { width: width, height: height } });
      return copy;
    } catch (err) {
      if (copy) {
        copy.release().catch(() => {});
      }
      Logger.error('Lỗi khi crop ảnh: %{public}s', JSON.stringify(err));
      throw new Error(`Crop ảnh thất bại: ${JSON.stringify(err)}`);
    }
  }

  /** Giải phóng PixelMap (bộ nhớ native) một cách an toàn, không ném lỗi. */
  public static releaseQuietly(pixelMap: image.PixelMap | null | undefined): void {
    if (!pixelMap) {
      return;
    }
    try {
      pixelMap.release().catch(() => {});
    } catch (e) {
      // đã release hoặc không hợp lệ: bỏ qua
    }
  }

  /**
   * Scale PixelMap về chiều rộng nằm trong khoảng tối ưu upload Lens (320-1440px)
   * Chỉ scale khi vượt ngưỡng trên; ảnh nhỏ giữ nguyên để không làm mất chất lượng.
   */
  public static async scaleForUpload(pixelMap: image.PixelMap): Promise<image.PixelMap> {
    try {
      const info = await pixelMap.getImageInfo();
      const w = info.size.width;
      if (w <= ImageService.MAX_UPLOAD_WIDTH) {
        return pixelMap;
      }

      // PixelMap.scale() sửa trực tiếp object đầu vào. Tạo bản copy trước để ảnh dùng cho
      // preview/lịch sử không bị thu nhỏ sau một lượt upload Lens.
      const packer = image.createImagePacker();
      const jpegBytes = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 100 });
      await packer.release();
      const source = image.createImageSource(jpegBytes);
      const scaled = await source.createPixelMap({
        editable: true,
        desiredPixelFormat: image.PixelMapFormat.RGBA_8888
      });
      await source.release();
      const ratio = ImageService.MAX_UPLOAD_WIDTH / w;
      await scaled.scale(ratio, ratio);
      return scaled;
    } catch (err) {
      Logger.warn('Scale ảnh thất bại, dùng ảnh gốc: %{public}s', JSON.stringify(err));
      return pixelMap;
    }
  }

  /**
   * Nén PixelMap sang JPEG ArrayBuffer, tự scale về kích thước tối ưu trước khi nén
   */
  public static async packPixelMapToJpeg(pixelMap: image.PixelMap, quality: number = 85): Promise<ArrayBuffer> {
    let scaled: image.PixelMap | null = null;
    try {
      scaled = await ImageService.scaleForUpload(pixelMap);
      const imagePacker = image.createImagePacker();
      const packingOption: image.PackingOption = {
        format: 'image/jpeg',
        quality: quality
      };
      const data = await imagePacker.packToData(scaled, packingOption);
      await imagePacker.release();
      Logger.info('Nén ảnh JPEG thành công, kích thước: %{public}d bytes', data.byteLength);
      return data;
    } catch (err) {
      Logger.error('Lỗi khi nén ảnh JPEG: %{public}s', JSON.stringify(err));
      throw new Error(`Nén ảnh thất bại: ${JSON.stringify(err)}`);
    } finally {
      // scaleForUpload trả về bản sao khi phải thu nhỏ: giải phóng để không rò bộ nhớ native
      if (scaled !== null && scaled !== pixelMap) {
        ImageService.releaseQuietly(scaled);
      }
    }
  }
}
