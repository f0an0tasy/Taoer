import { router } from '@kit.ArkUI';
import { dbManager, User } from '../db/DatabaseManager';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import AppStorage from '@ohos.app.ability.common';

const DOMAIN = 0x0000;

@Entry
@Component
struct ChangeUsernamePage {
  @State newUsername: string = '';
  @State confirmUsername: string = '';
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
            Text('修改用户名')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
              .textShadow({ radius: 2, color: 'rgba(0, 0, 0, 0.3)', offsetX: 1, offsetY: 1 })
              .margin({ top: 80, bottom: 10 })
            
            Text('请输入您的新用户名')
              .fontSize(16)
              .fontColor('rgba(255, 255, 255, 0.9)')
              .fontWeight(FontWeight.Normal)
              .margin({ bottom: 40 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 修改用户名表单区域
          Column({ space: 16 }) {
            // 当前用户名显示（只读）
            Row() {
              Text('当前用户名：')
                .fontSize(16)
                .fontColor('rgba(255, 255, 255, 0.8)')
              Text(this.currentUser.username)
                .fontSize(16)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
            }
            .width('85%')
            .justifyContent(FlexAlign.Start)
            .margin({ bottom: 8 })

            // 新用户名输入框
            TextInput({ placeholder: '新用户名' })
              .width('85%')
              .height(48)
              .placeholderColor('#999999')
              .placeholderFont({ size: 16 })
              .fontColor('#333333')
              .fontSize(16)
              .backgroundColor('rgba(255, 255, 255, 0.95)')
              .borderRadius(24)
              .padding({ left: 20, right: 20 })
              .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.1)', offsetX: 0, offsetY: 2 })
              .onChange((value) => this.newUsername = value)

            // 确认新用户名输入框
            TextInput({ placeholder: '确认新用户名' })
              .width('85%')
              .height(48)
              .placeholderColor('#999999')
              .placeholderFont({ size: 16 })
              .fontColor('#333333')
              .fontSize(16)
              .backgroundColor('rgba(255, 255, 255, 0.95)')
              .borderRadius(24)
              .padding({ left: 20, right: 20 })
              .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.1)', offsetX: 0, offsetY: 2 })
              .onChange((value) => this.confirmUsername = value)

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
              .onClick(() => this.handleChangeUsername())
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

  private async handleChangeUsername() {
    // 验证输入
    if (!this.newUsername || !this.confirmUsername) {
      promptAction.showToast({ message: '请填写所有字段' });
      return;
    }

    if (this.newUsername.length < 3) {
      promptAction.showToast({ message: '新用户名长度至少3个字符' });
      return;
    }

    if (this.newUsername === this.currentUser.username) {
      promptAction.showToast({ message: '新用户名不能与当前用户名相同' });
      return;
    }

    if (this.newUsername !== this.confirmUsername) {
      promptAction.showToast({ message: '两次输入的用户名不一致' });
      return;
    }

    this.isLoading = true;
    try {
      // 检查新用户名是否已被其他用户使用
      const usernameExists = await dbManager.isUsernameExist(this.newUsername, this.currentUser.id);
      if (usernameExists) {
        promptAction.showToast({ message: '用户名已被占用' });
        return;
      }

      // 更新用户名
      const success = await dbManager.updateUsername(this.currentUser.id!, this.newUsername);
      
      if (success) {
        hilog.info(DOMAIN, 'ChangeUsername', 'Username updated successfully from %{public}s to %{public}s', this.currentUser.username, this.newUsername);
        
        // 更新 AppStorage 中的 currentUser 对象
        const updatedUser: User = {
          id: this.currentUser.id,
          username: this.newUsername,
          password: this.currentUser.password,
          avatar: this.currentUser.avatar
        };
        AppStorage.setOrCreate('currentUser', updatedUser);
        
        promptAction.showToast({ message: '用户名修改成功' });
        
        // 返回上一页
        router.back();
      } else {
        promptAction.showToast({ message: '用户名修改失败，请重试' });
      }
    } catch (error) {
      hilog.error(DOMAIN, 'ChangeUsername', 'Username update failed: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '用户名修改失败，请重试' });
    } finally {
      this.isLoading = false;
    }
  }
}
