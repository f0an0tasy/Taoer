import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@Entry
@Component
struct SettingPage {
  build() {
    Column() {
      // 设置页面
      Column({ space: 20 }) {
        Text('设置').fontSize(24).fontWeight(FontWeight.Bold).margin({ top: 50 })
        
        // 更改用户名菜单项
        this.MenuItem('更改用户名', 'app.media.ic_setting', () => {
          router.pushUrl({ url: 'pages/ChangeUsernamePage' });
        })
        Divider().color('#f0f0f0')
        
        // 修改密码菜单项
        this.MenuItem('修改密码', 'app.media.ic_setting', () => {
          router.pushUrl({ url: 'pages/ChangePasswordPage' });
        })
        Divider().color('#f0f0f0')
        
        // 服务器设置菜单项
        this.MenuItem('服务器设置', 'app.media.ic_setting', () => {
          router.pushUrl({ url: 'pages/ServerConfigPage' });
        })
        Divider().color('#f0f0f0')
        
        // 其他设置项可以在这里添加
        this.MenuItem('关于我们', 'app.media.ic_info', () => {
          promptAction.showToast({ message: '关于我们功能开发中' });
        })
        Divider().color('#f0f0f0')
        
        this.MenuItem('帮助中心', 'app.media.ic_help', () => {
          promptAction.showToast({ message: '帮助中心功能开发中' });
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
    }
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder MenuItem(title: string, icon: string, action: () => void) {
    Row() {
      // Image($r(icon)).width(20).height(20).margin({ right: 10 }) // 实际需图标
      Text(title).fontSize(16).layoutWeight(1)
      Text('>').fontColor('#ccc')
    }
    .width('90%')
    .padding(20)
    .onClick(action)
  }
}