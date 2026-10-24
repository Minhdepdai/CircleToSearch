import { common, wantAgent } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { Constants } from '../common/Constants';
import { Logger } from '../common/Logger';

/**
 * Cầu nối giữa Smart Sidebar và luồng khoanh ảnh.
 * Sidebar chỉ tạo một notification có hành động rõ ràng; người dùng chủ động chạm
 * notification rồi hệ thống mở bộ chọn vùng màn hình. Cách này không đòi hỏi app
 * tự đọc nội dung của ứng dụng khác, vốn bị HarmonyOS giới hạn vì lý do bảo mật.
 */
export class CropNotificationService {
  public static async publish(context: common.UIAbilityContext): Promise<boolean> {
    try {
      let enabled = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification(context);
        enabled = await notificationManager.isNotificationEnabled();
      }
      if (!enabled) {
        Logger.warn('Thông báo chưa được người dùng cho phép');
        return false;
      }

      const agent = await wantAgent.getWantAgent({
        wants: [{
          bundleName: context.abilityInfo.bundleName,
          abilityName: 'EntryAbility',
          action: Constants.ACTION_OPEN_CROP
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: Constants.CROP_NOTIFICATION_ID,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      });

      const request: notificationManager.NotificationRequest = {
        id: Constants.CROP_NOTIFICATION_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'Circle Lens sẵn sàng',
            text: 'Chạm để chọn vùng màn hình, khoanh đối tượng và tìm bằng Google Lens.'
          }
        },
        wantAgent: agent,
        tapDismissed: true
      };
      await notificationManager.publish(request);
      Logger.info('Đã tạo notification mở luồng crop');
      return true;
    } catch (err) {
      Logger.error('Không thể tạo notification crop: %{public}s', JSON.stringify(err));
      return false;
    }
  }
}
