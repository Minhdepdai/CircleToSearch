# BỘ PROMPT BÀN GIAO CHO CLAUDE (SMART SIDEBAR EDITION)

> **Hướng dẫn sử dụng**: Bạn hãy copy toàn bộ nội dung trong khung bên dưới và gửi cho **Claude** khi muốn Claude viết tiếp các tính năng mới hoặc tinh chỉnh ứng dụng.

---

```markdown
Chào Claude! Tôi đang phát triển một ứng dụng Native trên nền tảng **HarmonyOS NEXT (API 24 - HarmonyOS 6.1.1+)** bằng ngôn ngữ **ArkTS** và framework **ArkUI** (Stage Model).

Ứng dụng có tên là: **Harmony Circle to Search (Circle Lens - Smart Sidebar Edition)**
Mục tiêu của dự án là mang trải nghiệm tìm kiếm hình ảnh tương tự "Google Circle to Search" lên các thiết bị Huawei thuần HarmonyOS NEXT mà không cần GMS hay Android Container (DroidTong).

### 1. Luồng Trải nghiệm Người dùng (User Flow)
Khác với các app thông thường, ứng dụng này được tích hợp trực tiếp vào **Thanh bên thông minh (Huawei Smart Sidebar)**:
1. Người dùng đang ở bất kỳ ứng dụng nào, vuốt từ mép màn hình vào để mở Smart Sidebar -> Chạm icon "Circle Lens".
2. Ứng dụng lập tức tự động pop-up một **cửa sổ trong suốt (#00000000) tràn màn hình**.
3. `ScreenCaptureService` chụp đóng băng khung hình nền hiện tại.
4. Giao diện `CircleCropPage` hiện ra với lớp tối mờ nhẹ: Người dùng dùng ngón tay vẽ khoanh tròn bất kỳ vật thể nào trên màn hình (với hiệu ứng viền phát sáng Google Lens).
5. Ngay khi người dùng nhấc tay ra (`onActionEnd`), ứng dụng tự động cắt ảnh (crop bounding box) và nén sang JPEG.
6. `LensUploadService` gửi HTTP POST multipart lên `https://lens.google.com/v3/upload` và bắt redirect HTTP 302/303 để lấy link kết quả.
7. `LensResultPage` hiển thị kết quả dạng **Cửa sổ nổi (Floating Card)** đè trên màn hình cũ. Webview được tiêm CSS/JS ẩn sạch logo Google, thanh tìm kiếm web để tạo cảm giác 100% Native Lens.
8. Người dùng xem xong kết quả bấm nút "X" trên thanh tiêu đề, ứng dụng gọi `context.terminateSelf()` để tắt cửa sổ nổi và quay lại ứng dụng trước đó liền mạch.

### 2. Cấu trúc Mã nguồn Hiện tại
- `build-profile.json5`: Cấu hình target API Level 24 (compileSdkVersion 24).
- `entry/src/main/module.json5`: Khai báo hỗ trợ multi-window `supportWindowMode: ["floating", "fullscreen"]`, metadata `supportWindowModeInFreeMultiWindow` để tương thích Smart Sidebar, quyền mạng `INTERNET` và quyền media capture.
- `entry/src/main/ets/entryability/EntryAbility.ets`: Cấu hình cửa sổ trong suốt `#00000000`, tràn viền toàn màn hình và tự động nạp thẳng `pages/CircleCropPage`.
- `entry/src/main/ets/services/ScreenCaptureService.ets`: Chụp nhanh màn hình nền thông qua `AVScreenCaptureRecorder` (`@kit.MediaKit`).
- `entry/src/main/ets/services/ImageService.ets`: Đọc file, crop PixelMap và nén sang JPEG qua `ImagePacker`.
- `entry/src/main/ets/services/LensUploadService.ets`: Đóng gói multipart/form-data upload ảnh lên Google Lens.
- `entry/src/main/ets/pages/CircleCropPage.ets`: Canvas bắt cử chỉ ngón tay vẽ vòng tròn, tự động crop và gửi lên Lens khi nhấc tay; có nút đóng terminateSelf().
- `entry/src/main/ets/pages/LensResultPage.ets`: Hiển thị kết quả Google Lens dạng Cửa sổ nổi (Floating Card) với CSS/JS injection dọn sạch giao diện web.
- `entry/src/main/ets/components/LensLoadingView.ets`: Hiệu ứng quét ảnh hào quang Google đa sắc.
- `entry/src/main/ets/common/Constants.ets` & `Logger.ets`: Hằng số, script injection và hilog wrapper.

### 3. Quy tắc Lập trình ArkTS & HarmonyOS NEXT (BẮT BUỘC)
1. **Kiểu dữ liệu tĩnh tuyệt đối (Strict Typing)**: Không sử dụng kiểu `any`. Mọi biến và tham số đều phải có type/interface cụ thể.
2. **Component & State**: Dùng `@Component struct MyView`, `@Entry`, `@State`, `@Prop`, `@Link`.
3. **Module Imports chuẩn Kit**: Dùng `@kit.ArkWeb`, `@kit.ImageKit`, `@kit.NetworkKit`, `@kit.MediaKit`, `@kit.AbilityKit`.
4. **Đóng ứng dụng nổi đúng chuẩn**: Dùng `(getContext(this) as common.UIAbilityContext).terminateSelf()`.

### 4. Nhiệm vụ Tiếp theo của bạn
[HÃY CHỌN HOẶC GHI YÊU CẦU CỦA BẠN VÀO ĐÂY, VÍ DỤ:]
- **Nhiệm vụ 1**: Thêm nút chuyển đổi tab nhanh trên `LensTopBar.ets`: "Tìm kiếm", "Dịch thuật (Translate)", "Văn bản (Text/OCR)" bằng cách nối thêm tham số truy vấn vào URL của Google Lens.
- **Nhiệm vụ 2**: Tạo dịch vụ lưu lịch sử tìm kiếm cục bộ bằng `@kit.ArkData` (Preferences) để người dùng có thể xem lại các vật thể đã khoanh trước đó.
- **Nhiệm vụ 3**: Tối ưu thuật toán nhận diện nét vẽ kín (Closed loop detection) trong `CircleCropPage.ets` để chỉ kích hoạt tìm kiếm khi người dùng vẽ xong một vòng tròn khép kín.

Hãy xem lại các file mã nguồn hiện có và triển khai nhiệm vụ trên một cách chuẩn mực, tối ưu và sạch sẽ nhất!
```
