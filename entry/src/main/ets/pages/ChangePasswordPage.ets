import { router } from '@kit.ArkUI';
import { dbManager, User } from '../db/DatabaseManager';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import AppStorage from '@ohos.app.ability.common';

const DOMAIN = 0x0000;

@Entry
@Component
struct ChangePasswordPage {
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State confirmPassword: string = '';
  @State isLoading: boolean = false;

  @StorageLink('currentUser') currentUser: User = { username: '未登录' } as User;

  build() {
    Stack() {
      // 背景层1：主渐变（深蓝到亮蓝到浅蓝到白色）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [
            ['#0A3D62', 0.0],    // 深蓝
            ['#4A90E2', 0.3],    // 亮蓝
            ['#B8E1FC', 0.6],    // 浅蓝
            ['#FFFFFF', 1.0]     // 白色
          ]
        })

      // 背景层2：径向渐变高光效果（顶部）
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [50, 20],
          radius: 80,
          colors: [
            ['rgba(255, 255, 255, 0.4)', 0.0],
            ['rgba(255, 255, 255, 0.1)', 0.5],
            ['rgba(255, 255, 255, 0.0)', 1.0]
          ]
        })

      // 背景层3：斜向渐变增强流动感
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 45,
          colors: [
            ['rgba(74, 144, 226, 0.3)', 0.0],
            ['rgba(184, 225, 252, 0.2)', 0.5],
            ['rgba(255, 255, 255, 0.0)', 1.0]
          ]
        })

      // 背景层4：波浪形状（使用半透明渐变模拟）
      Column()
        .width('100%')
        .height('40%')
        .linearGradient({
          angle: 180,
          colors: [
            ['rgba(255, 255, 255, 0.0)', 0.0],
            ['rgba(255, 255, 255, 0.15)', 0.5],
            ['rgba(184, 225, 252, 0.2)', 1.0]
          ]
        })
        .margin({ top: '30%' })

      // 主内容区域（使用 Scroll 包裹，防止内容过长时被遮挡）
      Scroll() {
        Column() {
          // 顶部欢迎区域
          Column() {
            Text('修改密码')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
              .textShadow({ radius: 2, color: 'rgba(0, 0, 0, 0.3)', offsetX: 1, offsetY: 1 })
              .margin({ top: 80, bottom: 10 })
            
            Text('请输入您的旧密码和新密码')
              .fontSize(16)
              .fontColor('rgba(255, 255, 255, 0.9)')
              .fontWeight(FontWeight.Normal)
              .margin({ bottom: 40 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 修改密码表单区域
          Column({ space: 16 }) {
            // 旧密码输入框
            TextInput({ placeholder: '旧密码' })
              .width('85%')
              .height(48)
              .type(InputType.Password)
              .placeholderColor('#999999')
              .placeholderFont({ size: 16 })
              .fontColor('#333333')
              .fontSize(16)
              .backgroundColor('rgba(255, 255, 255, 0.95)')
              .borderRadius(24)
              .padding({ left: 20, right: 20 })
              .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.1)', offsetX: 0, offsetY: 2 })
              .onChange((value) => this.oldPassword = value)

            // 新密码输入框
            TextInput({ placeholder: '新密码' })
              .width('85%')
              .height(48)
              .type(InputType.Password)
              .placeholderColor('#999999')
              .placeholderFont({ size: 16 })
              .fontColor('#333333')
              .fontSize(16)
              .backgroundColor('rgba(255, 255, 255, 0.95)')
              .borderRadius(24)
              .padding({ left: 20, right: 20 })
              .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.1)', offsetX: 0, offsetY: 2 })
              .onChange((value) => this.newPassword = value)

            // 确认新密码输入框
            TextInput({ placeholder: '确认新密码' })
              .width('85%')
              .height(48)
              .type(InputType.Password)
              .placeholderColor('#999999')
              .placeholderFont({ size: 16 })
              .fontColor('#333333')
              .fontSize(16)
              .backgroundColor('rgba(255, 255, 255, 0.95)')
              .borderRadius(24)
              .padding({ left: 20, right: 20 })
              .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.1)', offsetX: 0, offsetY: 2 })
              .onChange((value) => this.confirmPassword = value)

            // 确认修改按钮
            Button('确认修改')
              .width('85%')
              .height(48)
              .fontSize(18)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
              .linearGradient({
                angle: 90,
                colors: [
                  ['#3366FF', 0.0],
                  ['#4A90E2', 1.0]
                ]
              })
              .borderRadius(24)
              .shadow({ radius: 12, color: 'rgba(51, 102, 255, 0.4)', offsetX: 0, offsetY: 4 })
              .enabled(!this.isLoading)
              .opacity(this.isLoading ? 0.5 : 1)
              .onClick(() => this.handleChangePassword())
              .margin({ top: 8 })

            // 返回链接
            Row() {
              Text('不想修改了？')
                .fontSize(14)
                .fontColor('rgba(255, 255, 255, 0.8)')
              Text('返回设置')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .onClick(() => router.back())
            }
            .margin({ top: 16 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 占位空间
          Column()
            .width('100%')
            .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  private async handleChangePassword() {
    // 验证输入
    if (!this.oldPassword || !this.newPassword || !this.confirmPassword) {
      promptAction.showToast({ message: '请填写所有字段' });
      return;
    }

    if (this.newPassword.length < 3) {
      promptAction.showToast({ message: '新密码长度至少3位' });
      return;
    }

    if (this.newPassword === this.oldPassword) {
      promptAction.showToast({ message: '新密码不能与旧密码相同' });
      return;
    }

    if (this.newPassword !== this.confirmPassword) {
      promptAction.showToast({ message: '两次新密码不一致' });
      return;
    }

    this.isLoading = true;
    try {
      // 验证旧密码
      const user = await dbManager.login(this.currentUser.username, this.oldPassword);
      if (!user) {
        promptAction.showToast({ message: '原密码错误' });
        return;
      }

      // 更新密码
      const success = await dbManager.updatePassword(user.id!, this.newPassword);
      
      if (success) {
        hilog.info(DOMAIN, 'ChangePassword', 'Password updated successfully for user: %{public}s', this.currentUser.username);
        promptAction.showToast({ message: '密码修改成功，请重新登录' });
        
        // 清除用户信息
        AppStorage.setOrCreate('currentUser', { username: '未登录' } as User);
        
        // 跳转到登录页
        router.replaceUrl({ url: 'pages/LoginPage' });
      } else {
        promptAction.showToast({ message: '密码修改失败，请重试' });
      }
    } catch (error) {
      hilog.error(DOMAIN, 'ChangePassword', 'Password update failed: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '密码修改失败，请重试' });
    } finally {
      this.isLoading = false;
    }
  }
}
