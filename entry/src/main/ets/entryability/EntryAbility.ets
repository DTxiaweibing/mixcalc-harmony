import { UIAbility, AbilityConstant, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { applyHomeBars, setupImmersive, syncWindowMode } from '../common/WindowChrome';

export default class EntryAbility extends UIAbility {
  private maximizeStarted: boolean = false;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  }

  /**
   * 防御性兜底：静态方向已按设备类型分流（手机 base=portrait / 平板 tablet=auto_rotation），
   * 平板本来就是 AUTO_ROTATION，正常转屏由系统重建窗口，不依赖这里。
   * 万一某些机型配置变更时把窗口方向带偏，再声明一次。
   * 手机不走这里：手机由 applyWindowSetup 锁 PORTRAIT，不需要自动旋转。
   */
  onConfigurationUpdate(newConfig: Configuration): void {
    if (deviceInfo.deviceType === 'phone' || newConfig.direction === undefined) {
      return;
    }
    window.getLastWindow(this.context).then((win: window.Window) => {
      win.setPreferredOrientation(window.Orientation.AUTO_ROTATION).catch((e: BusinessError) => {
        console.error('reapply auto rotation failed: ' + e.code);
      });
    }).catch((e: BusinessError) => {
      console.error('getLastWindow failed: ' + e.code);
    });
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
      // 窗口已建好：系统可能直接恢复上次的分屏 / 悬浮窗状态，按真实模式决定系统栏归谁
      this.refreshWindowMode(windowStage);
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
    // 静态方向由 module.json5 的 $string:entry_orientation 按设备类型解析：
    // 手机 base=portrait（启动窗口直接竖屏），平板 tablet=auto_rotation（横屏铺满）。
    // 这里再按 deviceInfo 锁一次只作兜底（资源索引解析异常、折叠屏单屏态等），
    // 仍在加载内容之前完成，不影响启动首帧。
    // 手机（含折叠屏单屏态）在这里锁 PORTRAIT。
    const isPhone: boolean = deviceInfo.deviceType === 'phone';
    win.setPreferredOrientation(
      isPhone ? window.Orientation.PORTRAIT : window.Orientation.AUTO_ROTATION
    ).catch((e: BusinessError) => {
      console.error('setPreferredOrientation failed: ' + e.code);
    });
    applyHomeBars(win);
    // 边到边：窗口铺满整屏（含状态栏 / 导航条区域），标题栏和表尾自己把背景画进去，
    // 内容靠 WindowChrome 写进 AppStorage 的避让高度留出安全距离。
    // 和方向一样必须在 loadContent 之前设，否则第一帧还是旧的安全区布局。
    setupImmersive(win);
    // supportWindowMode 里加了 split 后，系统可能恢复上次的分屏状态。
    // 平板启动时主动最大化一次，保证默认全屏；用户仍可在使用中手动分屏。
    // FOLLOW_APP_IMMERSIVE_SETTING：保留应用自己设置的状态栏/导航栏，不强制沉浸。
    if (!isPhone && !this.maximizeStarted) {
      this.maximizeStarted = true;
      win.maximize(window.MaximizePresentation.FOLLOW_APP_IMMERSIVE_SETTING)
        .then(() => {
          // 最大化后窗口模式才稳定（自由多窗下是 MAXIMIZE），再读一次
          syncWindowMode(win);
        })
        .catch((e: BusinessError) => {
          this.maximizeStarted = false;
          console.error('maximize failed: ' + e.code);
        });
    }
  }

  private refreshWindowMode(windowStage: window.WindowStage): void {
    try {
      syncWindowMode(windowStage.getMainWindowSync());
    } catch (e) {
      console.error('getMainWindowSync failed: ' + e);
    }
  }
}
