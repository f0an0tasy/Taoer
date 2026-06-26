import { router } from '@kit.ArkUI';
import { dbManager, User } from '../db/DatabaseManager';
import { ShoppingCartPreferences } from '../utils/ShoppingCartPreferences';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const USER_KEY = 'current_user';

@Entry
@Component
struct LoginPage {
  @State username: string = '';
  @State password: string = '';
  @State isLoading: boolean = false;
  
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  @StorageLink('pf') pf: preferences.Preferences | null = null;

  async handleLogin() {
    if (!this.username || !this.password) {
      promptAction.showToast({ message: '请输入用户名和密码' });
      return;
    }

    this.isLoading = true;
    try {
      const loggedInUser = await dbManager.login(this.username, this.password);
      
      if (loggedInUser) {
        // 更新当前用户到AppStorage
        this.user = loggedInUser;
        AppStorage.setOrCreate('currentUser', loggedInUser);
        
        // 持久化用户信息到Preferences
        if (this.pf) {
          await this.pf.put(USER_KEY, JSON.stringify(loggedInUser));
          await this.pf.flush();
          hilog.info(DOMAIN, 'LoginPage', 'User info saved: %{public}s', loggedInUser.username);
        }
        
        // 登录成功后加载购物车数据
        const cartItems = await ShoppingCartPreferences.loadCart(
          getContext(this) as common.UIAbilityContext, 
          loggedInUser.id!.toString()
        );
        hilog.info(DOMAIN, 'LoginPage', 'Loaded %{public}d cart items after login', cartItems.length);
        
        promptAction.showToast({ message: '登录成功' });
        router.replaceUrl({ url: 'pages/MainPage' });
      } else {
        promptAction.showToast({ message: '用户名或密码错误' });
      }
    } catch (error) {
      hilog.error(DOMAIN, 'LoginPage', 'Login failed: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '登录失败，请重试' });
    } finally {
      this.isLoading = false;
    }
  }

  // 第三方登录点击处理
  handleThirdPartyLogin(platform: string) {
    hilog.info(DOMAIN, 'LoginPage', 'Third party login clicked: %{public}s', platform);
    promptAction.showToast({ message: '暂未开放' });
  }

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
            Text('登录账号以使用更多服务')
              .fontSize(18)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
              .textShadow({ radius: 2, color: 'rgba(0, 0, 0, 0.3)', offsetX: 1, offsetY: 1 })
              .margin({ top: 80, bottom: 40 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 登录表单区域
          Column({ space: 16 }) {
            // 账号输入框
            TextInput({ placeholder: '账号' })
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
              .onChange((value) => {
                this.username = value;
                hilog.debug(DOMAIN, 'LoginPage', 'Username input changed');
              })

            // 密码输入框
            TextInput({ placeholder: '密码' })
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
              .onChange((value) => {
                this.password = value;
                hilog.debug(DOMAIN, 'LoginPage', 'Password input changed');
              })

            // 登录按钮
            Button('登录')
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
              .onClick(() => this.handleLogin())
              .margin({ top: 8 })

            // 注册账号链接
            Row() {
              Text('还没有账号？')
                .fontSize(14)
                .fontColor('rgba(255, 255, 255, 0.8)')
              Text('注册账号')
                .fontSize(14)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .onClick(() => {
                  hilog.info(DOMAIN, 'LoginPage', 'Navigate to RegisterPage');
                  router.pushUrl({ url: 'pages/RegisterPage' });
                })
            }
            .margin({ top: 16 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 占位空间，将底部模块推到最底部
          Column()
            .width('100%')
            .layoutWeight(1)

          // 底部其他登录方式
          Column() {
            // 分隔线
            Row() {
              Line()
                .width(60)
                .height(1)
                .backgroundColor('rgba(255, 255, 255, 0.3)')
              Text('其他登录方式')
                .fontSize(14)
                .fontColor('rgba(255, 255, 255, 0.7)')
                .margin({ left: 12, right: 12 })
              Line()
                .width(60)
                .height(1)
                .backgroundColor('rgba(255, 255, 255, 0.3)')
            }
            .margin({ bottom: 24 })

            // 第三方登录图标
            Row({ space: 40 }) {
              // 淘宝
              Image($r('app.media.taobao'))
                .width(44)
                .height(44)
                .objectFit(ImageFit.Contain)
                .onClick(() => this.handleThirdPartyLogin('淘宝'))

              // 支付宝
              Image($r('app.media.alipay'))
                .width(44)
                .height(44)
                .objectFit(ImageFit.Contain)
                .onClick(() => this.handleThirdPartyLogin('支付宝'))

              // 华为
              Image($r('app.media.huawei'))
                .width(44)
                .height(44)
                .objectFit(ImageFit.Contain)
                .onClick(() => this.handleThirdPartyLogin('华为'))
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)
          .margin({ bottom: 40 })
        }
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 右上角服务器设置入口（放在 Stack 最后，确保最高层级）
      Row() {
        Blank()
        
        // 设置按钮 - 使用 Button 组件确保点击事件可靠
        Button('设置')
          .fontSize(14)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
          .width(60)              // 增大宽度，确保点击区域足够
          .height(44)             // 符合 HarmonyOS 最小触摸区域要求（44vp）
          .borderRadius(22)
          .backgroundColor('rgba(255, 255, 255, 0.25)')
          .type(ButtonType.Normal) // 使用 Normal 类型，自定义样式
          .onClick(() => {
            // 第一行输出明显日志，确认点击事件触发
            hilog.info(DOMAIN, 'LoginPage', '========== Settings Button Clicked ==========');
            
            router.pushUrl({ url: 'pages/ServerConfigPage' })
              .then(() => {
                hilog.info(DOMAIN, 'LoginPage', 'Navigate to ServerConfigPage success');
              })
              .catch((err: Error) => {
                hilog.error(DOMAIN, 'LoginPage', 'Navigate to ServerConfigPage failed: %{public}s', err.message);
                promptAction.showToast({ message: '跳转失败: ' + err.message });
              });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 50 })
      .position({ x: 0, y: 0 })
      .zIndex(999)  // 确保层级最高，不被其他组件遮挡
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
