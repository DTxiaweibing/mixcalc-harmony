import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        return;
      }
      let win: window.Window = windowStage.getMainWindowSync();
      // 手机锁竖屏；平板跟随系统自动旋转，横屏竖屏都用满窗口宽度
      const isPhone: boolean = deviceInfo.deviceType === 'phone';
      win.setPreferredOrientation(
        isPhone ? window.Orientation.PORTRAIT : window.Orientation.AUTO_ROTATION
      ).catch((e: BusinessError) => {
      });
      win.setWindowSystemBarProperties({
        statusBarColor: '#1F6B30',
        statusBarContentColor: '#FFFFFF',
        navigationBarColor: '#FFFFFF',
        navigationBarContentColor: '#000000'
      }).catch((e: BusinessError) => {
      });
    });
  }
}