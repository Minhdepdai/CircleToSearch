import { describe, it, expect } from '@ohos/hypium';
import { Geometry, Point, BoundingBox } from '../main/ets/common/Geometry';

export default function localUnitTest() {
  describe('GeometryTest', () => {
    it('testBoundingBoxOfEmpty', 0, () => {
      const box = Geometry.boundingBoxOf([]);
      expect(box).assertNull();
    });

    it('testBoundingBoxOfPoints', 0, () => {
      const pts: Point[] = [
        { x: 10, y: 20 },
        { x: 50, y: 80 },
        { x: 30, y: 15 }
      ];
      const box = Geometry.boundingBoxOf(pts);
      expect(box !== null).assertTrue();
      if (box !== null) {
        expect(box.x).assertEqual(10);
        expect(box.y).assertEqual(15);
        expect(box.width).assertEqual(40);
        expect(box.height).assertEqual(65);
      }
    });

    it('testIsClosedStrokeRejectsFewPoints', 0, () => {
      const pts: Point[] = [
        { x: 0, y: 0 },
        { x: 100, y: 0 },
        { x: 100, y: 100 },
        { x: 0, y: 100 },
        { x: 0, y: 0 }
      ];
      // < 12 points => false
      expect(Geometry.isClosedStroke(pts)).assertFalse();
    });

    it('testIsClosedStrokeAcceptsValidCircle', 0, () => {
      const pts: Point[] = [];
      const centerX = 200;
      const centerY = 200;
      const radius = 50;
      const count = 16;
      for (let i = 0; i < count; i++) {
        const rad = (i / count) * 2 * Math.PI;
        pts.push({
          x: Math.round(centerX + radius * Math.cos(rad)),
          y: Math.round(centerY + radius * Math.sin(rad))
        });
      }
      // loop back to first point
      pts.push({ x: pts[0].x, y: pts[0].y });
      expect(Geometry.isClosedStroke(pts)).assertTrue();
    });

    it('testPadBox', 0, () => {
      const box: BoundingBox = { x: 10, y: 10, width: 20, height: 20 };
      const padded = Geometry.padBox(box, 5, 100, 100);
      expect(padded.x).assertEqual(5);
      expect(padded.y).assertEqual(5);
      expect(padded.width).assertEqual(30);
      expect(padded.height).assertEqual(30);
    });

    it('testMapCanvasBoxToImage', 0, () => {
      // Canvas 1000x2000, image 1000x1000
      // scale = min(1, 2) = 1
      // rendered: 1000x1000, offsetX = 0, offsetY = (2000-1000)/2 = 500
      const box: BoundingBox = { x: 100, y: 600, width: 200, height: 300 };
      const mapped = Geometry.mapCanvasBoxToImage(box, 1000, 2000, 1000, 1000);
      expect(mapped !== null).assertTrue();
      if (mapped !== null) {
        expect(mapped.x).assertEqual(100);
        expect(mapped.y).assertEqual(100);
        expect(mapped.width).assertEqual(200);
        expect(mapped.height).assertEqual(300);
      }
    });
  });
}
