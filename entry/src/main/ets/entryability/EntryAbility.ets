import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { dbManager, User } from '../db/DatabaseManager';

const DOMAIN = 0x0000;
const PREFERENCES_NAME = 'myStore';
const USER_KEY = 'current_user';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    
    // 初始化数据库
    await dbManager.init(this.context);
    
    // 获取Preferences实例
    const pf = await preferences.getPreferences(this.context, PREFERENCES_NAME);
    AppStorage.setOrCreate('pf', pf);
    
    // 尝试恢复用户登录状态
    await this.restoreUserLogin(pf);
    
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  /**
   * 恢复用户登录状态
   */
  private async restoreUserLogin(pf: preferences.Preferences): Promise<void> {
    try {
      const userData = await pf.get(USER_KEY, '') as string;
      if (userData) {
        const user = JSON.parse(userData) as User;
        // 验证用户是否仍然有效（可选：可以查询数据库验证）
        AppStorage.setOrCreate('currentUser', user);
        hilog.info(DOMAIN, 'CartPersist', 'Restored user login: %{public}s', user.username);
      } else {
        hilog.info(DOMAIN, 'CartPersist', 'No saved user found');
      }
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Failed to restore user login: %{public}s', JSON.stringify(error));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 检查是否有已登录用户
    const currentUser = AppStorage.get<User>('currentUser');
    const startPage = currentUser && currentUser.id ? 'pages/MainPage' : 'pages/LoginPage';
    
    hilog.info(DOMAIN, 'CartPersist', 'Starting page: %{public}s', startPage);

    windowStage.loadContent(startPage, (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}