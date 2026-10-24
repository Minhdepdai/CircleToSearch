import { http } from '@kit.NetworkKit';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';

export interface UploadResult {
  success: boolean;
  resultUrl?: string;
  errorMessage?: string;
}

/** Wrapper chứa URL redirect bắt được từ sự kiện headersReceive */
interface LocationHolder {
  url: string;
}

/**
 * Service upload ảnh trực tiếp lên Google Lens Web qua multipart/form-data.
 * Dùng multiFormDataList native của NetworkKit (thay vì đóng gói multipart thủ công)
 * và bắt redirect 302 đầu tiên qua requestInStream + on_headersReceive.
 */
export class LensUploadService {
  /**
   * Upload ảnh nén JPEG lên Google Lens và lấy link kết quả tìm kiếm.
   *
   * Cách hoạt động: POST bằng requestInStream, tạm vô hiệu hóa auto-follow redirect
   * (maxRedirects=1 để stack không tự nhảy nhiều tầng) và chụp header Location ngay
   * khi nhận phản hồi đầu tiên qua on_headersReceive. Nếu header cuối vẫn là 200,
   * quét HTML/redirect-location từ kết quả.
   */
  public static async uploadToGoogleLens(imageBytes: ArrayBuffer): Promise<UploadResult> {
    const httpRequest = http.createHttp();

    try {
      Logger.info('Bắt đầu upload ảnh lên Google Lens (%{public}d bytes)...', imageBytes.byteLength);

      // Bắt header phản hồi đầu tiên (kể cả khi là redirect 302/303).
      // Dùng wrapper object vì ArkTS không nhận type-narrowing qua biến bị callback gán.
      const captured: LocationHolder = { url: '' };

      httpRequest.on('headersReceive', (header: Object) => {
        const headers = header as Record<string, string>;
        const location = LensUploadService.getHeader(headers, 'location');
        if (location && location.length > 0 && captured.url === '') {
          captured.url = location;
        }
      });

      const response = await httpRequest.request(Constants.LENS_UPLOAD_URL, {
        method: http.RequestMethod.POST,
        header: {
          'User-Agent': Constants.LENS_USER_AGENT,
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'vi-VN,vi;q=0.9,en-US;q=0.8,en;q=0.7',
          'Origin': 'https://lens.google.com',
          'Referer': 'https://lens.google.com/'
        },
        // NetworkKit hỗ trợ khai báo form data native: tự sinh boundary + multipart
        multiFormDataList: [
          {
            name: 'encoded_image',
            contentType: 'image/jpeg',
            remoteFileName: 'screenshot.jpg',
            data: imageBytes
          }
        ],
        // Google Lens trả 302/303 -> giữ ở mức thấp để dễ đọc Location,
        // headersReceive vẫn bắn header phản hồi đầu tiên trước khi follow.
        maxLimit: 10 * 1024 * 1024,
        readTimeout: 20000,
        connectTimeout: 10000,
        // Giữ body dưới dạng text để có thể đọc meta/JS redirect của Lens.
        expectDataType: http.HttpDataType.STRING
      });

      const responseCode = response.responseCode;
      Logger.info('Google Lens Response Code: %{public}d', responseCode);

      // 1) Ưu tiên Location bắt được ở phản hồi redirect đầu tiên
      const redirectedUrl = LensUploadService.toAbsoluteLensUrl(captured.url);
      if (redirectedUrl !== '') {
        Logger.info('Bắt được redirect đầu tiên: %{public}s', redirectedUrl);
        return { success: true, resultUrl: redirectedUrl };
      }

      // 2) Nếu stack follow redirect rồi, header cuối vẫn có thể chứa Location cuối cùng
      const finalHeaders = response.header as Record<string, string>;
      let locationUrl = LensUploadService.getHeader(finalHeaders, 'location');

      // 3) Phản hồi 200 kèm HTML chứa JS redirect / meta refresh
      if (!locationUrl && typeof response.result === 'string') {
        const googleSearchMatch = response.result.match(/https:\/\/(?:www\.)?google\.[a-z.]+\/search\?[^"'\s<>]+/);
        const lensMatch = response.result.match(/(?:https?:)?\\?\/{0,2}lens\.google\.com\\?\/[^"'\s<>\\]+|\/(?:v3\/)?(?:search|results)\?[^"'\s<>]+/);
        const match = googleSearchMatch || lensMatch;
        if (match && match[0]) {
          locationUrl = match[0].replace(/\\\//g, '/');
        }
      }

      const resultUrl = LensUploadService.toAbsoluteLensUrl(locationUrl || '');
      if (resultUrl !== '') {
        Logger.info('Tìm thấy URL kết quả: %{public}s', resultUrl);
        return { success: true, resultUrl: resultUrl };
      }

      // Không mở trang Lens trống vì người dùng sẽ tưởng việc tìm kiếm đã thành công.
      Logger.warn('Google Lens không trả URL: code=%{public}d, headers=%{public}s', responseCode, JSON.stringify(finalHeaders));
      return {
        success: false,
        errorMessage: 'Google Lens không trả kết quả. Hãy thử lại với ảnh khác hoặc kiểm tra kết nối mạng.'
      };
    } catch (err) {
      Logger.error('Lỗi trong quá trình upload Google Lens: %{public}s', JSON.stringify(err));
      return {
        success: false,
        errorMessage: `Lỗi kết nối mạng: ${JSON.stringify(err)}`
      };
    } finally {
      httpRequest.off('headersReceive');
      httpRequest.destroy();
    }
  }

  private static getHeader(headers: Record<string, string>, name: string): string | undefined {
    const lowerName = name.toLowerCase();
    for (const key of Object.keys(headers)) {
      if (key.toLowerCase() === lowerName) {
        return headers[key];
      }
    }
    return undefined;
  }

  /**
   * Google Lens hiện redirect kết quả sang https://www.google.com/search?... .
   * Trước đây chỉ chấp nhận lens.google.com nên đã vứt URL đúng này và báo lỗi.
   */
  private static toAbsoluteLensUrl(url: string): string {
    const value = url.trim();
    if (/^https:\/\/(?:www\.)?google\.[a-z.]+\/search\?/.test(value)) {
      return value;
    }
    if (value.startsWith('https://lens.google.com/') || value.startsWith('http://lens.google.com/')) {
      return value;
    }
    if (value.startsWith('//lens.google.com/')) {
      return `https:${value}`;
    }
    if (value.startsWith('/')) {
      return `https://lens.google.com${value}`;
    }
    return '';
  }
}
