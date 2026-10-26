import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        return;
      }
      let win: window.Window = windowStage.getMainWindowSync();
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