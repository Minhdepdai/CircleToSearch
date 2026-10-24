import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * Hilog Wrapper chuẩn cho HarmonyOS NEXT
 */
export class Logger {
  private static readonly DOMAIN: number = 0x0001;
  private static readonly TAG: string = 'CircleLens';

  public static debug(format: string, ...args: Object[]): void {
    hilog.debug(Logger.DOMAIN, Logger.TAG, format, args);
  }

  public static info(format: string, ...args: Object[]): void {
    hilog.info(Logger.DOMAIN, Logger.TAG, format, args);
  }

  public static warn(format: string, ...args: Object[]): void {
    hilog.warn(Logger.DOMAIN, Logger.TAG, format, args);
  }

  public static error(format: string, ...args: Object[]): void {
    hilog.error(Logger.DOMAIN, Logger.TAG, format, args);
  }
}
