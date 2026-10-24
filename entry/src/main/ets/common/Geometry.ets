/**
 * Hình học thuần (không phụ thuộc Kit nào) cho thao tác khoanh vùng.
 * Tách riêng để có thể unit test trực tiếp (entry/src/test/Geometry.test.ets).
 */
export interface Point {
  x: number;
  y: number;
}

export interface BoundingBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export class Geometry {
  /** Số điểm tối thiểu để coi là một nét khoanh (tránh chạm/vuốt nhầm) */
  public static readonly MIN_POINTS: number = 12;
  /** Kích thước tối thiểu (px canvas) của hộp bao nét vẽ */
  public static readonly MIN_BOX_SIZE: number = 24;
  /** Điểm cuối phải cách điểm đầu < tỉ lệ này của chu vi hộp bao */
  public static readonly CLOSE_RATIO: number = 0.25;

  /**
   * Hộp bao nét vẽ. Trả về null nếu không có điểm nào.
   * Không ép kích thước tối thiểu để không làm lệch vùng crop.
   */
  public static boundingBoxOf(points: Point[]): BoundingBox | null {
    if (points.length === 0) {
      return null;
    }
    let minX = points[0].x;
    let maxX = points[0].x;
    let minY = points[0].y;
    let maxY = points[0].y;
    for (let i = 1; i < points.length; i++) {
      const p = points[i];
      if (p.x < minX) {
        minX = p.x;
      }
      if (p.x > maxX) {
        maxX = p.x;
      }
      if (p.y < minY) {
        minY = p.y;
      }
      if (p.y > maxY) {
        maxY = p.y;
      }
    }
    return { x: minX, y: minY, width: maxX - minX, height: maxY - minY };
  }

  /**
   * Nét vẽ có khép thành vòng kín không:
   * - đủ số điểm tối thiểu
   * - hộp bao đủ lớn ở cả hai chiều
   * - điểm cuối quay về gần điểm đầu
   */
  public static isClosedStroke(points: Point[]): boolean {
    if (points.length < Geometry.MIN_POINTS) {
      return false;
    }
    const box = Geometry.boundingBoxOf(points);
    if (box === null) {
      return false;
    }
    if (box.width < Geometry.MIN_BOX_SIZE || box.height < Geometry.MIN_BOX_SIZE) {
      return false;
    }
    const first = points[0];
    const last = points[points.length - 1];
    const gap = Math.sqrt(Math.pow(first.x - last.x, 2) + Math.pow(first.y - last.y, 2));
    const perimeter = (box.width + box.height) * 2;
    return gap <= perimeter * Geometry.CLOSE_RATIO;
  }

  /** Nới hộp ra mỗi phía `pad` px rồi kẹp trong khung [0,maxW]x[0,maxH]. */
  public static padBox(box: BoundingBox, pad: number, maxW: number, maxH: number): BoundingBox {
    const left = Math.max(0, box.x - pad);
    const top = Math.max(0, box.y - pad);
    const right = Math.min(maxW, box.x + box.width + pad);
    const bottom = Math.min(maxH, box.y + box.height + pad);
    return { x: left, y: top, width: Math.max(0, right - left), height: Math.max(0, bottom - top) };
  }

  /**
   * Đổi hộp từ toạ độ canvas sang toạ độ pixel ảnh, khi ảnh hiển thị ImageFit.Contain
   * ở giữa canvas (có dải letterbox). Phần hộp nằm ngoài ảnh bị cắt bỏ.
   * Trả về null nếu hộp không giao với ảnh hoặc số liệu đầu vào không hợp lệ.
   */
  public static mapCanvasBoxToImage(box: BoundingBox, canvasW: number, canvasH: number,
    imageW: number, imageH: number): BoundingBox | null {
    if (canvasW <= 0 || canvasH <= 0 || imageW <= 0 || imageH <= 0) {
      return null;
    }
    const scale = Math.min(canvasW / imageW, canvasH / imageH);
    const renderedW = imageW * scale;
    const renderedH = imageH * scale;
    const offsetX = (canvasW - renderedW) / 2;
    const offsetY = (canvasH - renderedH) / 2;

    const left = Math.max(box.x, offsetX);
    const top = Math.max(box.y, offsetY);
    const right = Math.min(box.x + box.width, offsetX + renderedW);
    const bottom = Math.min(box.y + box.height, offsetY + renderedH);
    if (right <= left || bottom <= top) {
      return null;
    }
    return {
      x: (left - offsetX) / scale,
      y: (top - offsetY) / scale,
      width: (right - left) / scale,
      height: (bottom - top) / scale
    };
  }
}
