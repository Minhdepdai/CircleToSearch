# Lộ Trình Phát Triển (Task Roadmap - Smart Sidebar Edition)

Dự án **Harmony Circle to Search** trên **HarmonyOS NEXT (API 24)**. Trạng thái cập nhật sau đợt cải tiến lớn (3 chế độ tìm kiếm + lịch sử + share sheet).

---

## 🟢 Giai đoạn 1: Nền tảng MVP (ĐÃ HOÀN THÀNH ✅)

- [x] Cấu hình đa nhiệm & cửa sổ nổi cho Smart Sidebar (`supportWindowMode`, metadata).
- [x] Cửa sổ trong suốt tự pop-up `CircleCropPage`.
- [x] `ScreenCaptureService` chụp màn hình + `CircleCropPage` khoanh tròn.
- [x] `LensUploadService` upload multipart lên Google Lens.
- [x] `LensResultPage` webview + tiêm CSS/JS dọn UI.

---

## 🟢 Giai đoạn 2: Mở rộng tính năng (ĐÃ HOÀN THÀNH ✅)

- [x] **Nhận ảnh chia sẻ từ Share Sheet hệ thống** (`ohos.want.action.sendData` + uri `image/*`):
  - `EntryAbility.handleIncomingWant()` nạp ảnh → `AppStorage` → mở trang khoanh với nền thật.
  - Luồng khuyến nghị: knuckle khoanh vùng → Share → Circle Lens.
- [x] **3 chế độ xử lý trên chip bar** (`CircleCropPage`):
  - *Tìm kiếm hình ảnh* → `LensResultPage` (upload Google Lens).
  - *Trích xuất văn bản (OCR)* → `TextResultPage` (CoreVisionKit on-device, copy 1 chạm).
  - *Dịch thuật* → `TranslateResultPage` (OCR + Google Translate tự sang tiếng Việt).
- [x] **Lưu lịch sử 20 vùng khoanh gần nhất** (`HistoryService` + `HistoryPage`):
  - Ảnh JPEG trong `cacheDir/history`, metadata trong `Preferences`, tự dọn file cũ.
  - Mở lại mục lịch sử để khoanh tiếp trên ảnh cũ.
- [x] **Kiểm tra vòng khoanh khép kín** (`CircleCropPage.isClosedCircle()`):
  - ≥ 12 điểm + điểm cuối về gần đầu + bbox ≥ 24×24px; không đạt thì gợi ý vẽ lại.

---

## 🟢 Giai đoạn 3: Nâng cấp kỹ thuật (ĐÃ HOÀN THÀNH ✅)

- [x] Sửa lỗi build: icon `sys.media` không tồn tại (`ohos_ic_public_scan`, `ohos_ic_public_restore`), bundleName khớp signing profile.
- [x] `ImageService`: crop bằng `desiredRegion` (không phá ảnh gốc), scale ≤ 1440px, `packToData`.
- [x] `LensUploadService`: `multiFormDataList` native, bắt redirect đầu qua `on('headersReceive')`, 3 lớp fallback URL.
- [x] `ScreenCaptureService`: `AVImageGenerator.fetchFrameByTime` trích frame, dọn file tạm trong `finally`.
- [x] Bỏ toàn bộ API deprecated: `setUIContent`, `packToData`, `getUIContext().getRouter()`, `getHostContext()` — build 0 warning deprecated.
- [x] Webview inject: CSS đa selector dự phòng + MutationObserver chống SPA re-render.
- [x] Bỏ quyền MICROPHONE không cần thiết.

---

## 🟡 Giai đoạn 4: Việc cần làm tiếp (TODO)

- [ ] **Test trên máy thật**: toàn bộ luồng Smart Sidebar / Share sheet / OCR (cần thiết bị Kirin có NPU).
- [ ] **Map tọa độ canvas → ảnh**: hiện `mapBoxToImage()` trả nguyên tọa độ (ảnh hiển thị `ImageFit.Contain` có thể lệch tỉ lệ); cần map theo tỉ lệ hiển thị thực tế khi test máy.
- [ ] **Tinh chỉnh OCR ngôn ngữ**: dùng `getSupportedLanguages()` + hint ngôn ngữ người dùng thay vì nhận diện tự động hoàn toàn.
- [ ] **Chế độ dịch nhiều cặp ngôn ngữ**: dropdown chọn ngôn ngữ đích thay vì cố định `tl=vi`.
- [ ] **Bộ chọn engine**: cấu hình hoán đổi Google Lens ↔ Bing Visual Search ↔ Vision API theo `LENS_API_SPEC.md` phương án A/B/C.
- [ ] **Cử chỉ chỉnh lại vùng khoanh** (kéo góc bbox) trước khi gửi.
- [ ] **Đóng gói release**: signing release certificate + rút gọn tài nguyên.
