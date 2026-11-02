import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // 方向和系统栏必须在 loadContent 之前设好。窗口（含启动图）是系统按当前方向创建的，
    // 等页面渲染完再设就会出现「先横着闪一下，再竖过来」，而且首帧窗口宽度还是横屏值。
    this.applyWindowSetup(windowStage);
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        return;
      }
      // 兜底：个别机型 loadContent 之前拿不到主窗口，这里再设一次（幂等）
      this.applyWindowSetup(windowStage);
    });
  }

  private applyWindowSetup(windowStage: window.WindowStage): void {
    let win: window.Window;
    try {
      win = windowStage.getMainWindowSync();
    } catch (e) {
      console.error('getMainWindowSync failed: ' + e);
      return;
    }
    // 手机（含折叠屏单屏态）锁竖屏；平板跟随系统自动旋转，横屏竖屏都用满窗口宽度
    const isPhone: boolean = deviceInfo.deviceType === 'phone';
    win.setPreferredOrientation(
      isPhone ? window.Orientation.PORTRAIT : window.Orientation.AUTO_ROTATION
    ).catch((e: BusinessError) => {
      console.error('setPreferredOrientation failed: ' + e.code);
    });
    win.setWindowSystemBarProperties({
      statusBarColor: '#1F6B30',
      statusBarContentColor: '#FFFFFF',
      navigationBarColor: '#FFFFFF',
      navigationBarContentColor: '#000000'
    }).catch((e: BusinessError) => {
      console.error('setWindowSystemBarProperties failed: ' + e.code);
    });
  }
}
