import { router } from '@kit.ArkUI';
import { dbManager, User } from '../db/DatabaseManager';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { relationalStore } from '@kit.ArkData';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { httpService } from '../utils/HttpService';

const DOMAIN = 0x0000;

@Entry
@Component
struct RegisterPage {
  @State username: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State studentId: string = '';              // 校园卡号
  @State cardImageUri: string = '';           // 校园卡图片URI（用于预览）
  @State uploadedCardImageUrl: string = '';   // 服务器返回的图片 URL
  @State isLoading: boolean = false;
  @State isUploading: boolean = false;        // 图片上传状态

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
            Text('创建新账号')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
              .textShadow({ radius: 2, color: 'rgba(0, 0, 0, 0.3)', offsetX: 1, offsetY: 1 })
              .margin({ top: 80, bottom: 10 })
            
            Text('注册账号以使用更多服务')
              .fontSize(16)
              .fontColor('rgba(255, 255, 255, 0.9)')
              .fontWeight(FontWeight.Normal)
              .margin({ bottom: 40 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 注册表单区域
          Column({ space: 16 }) {
            // 用户名输入框
            TextInput({ placeholder: '用户名' })
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
              .onChange((value) => this.username = value)

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
              .onChange((value) => this.password = value)

            // 确认密码输入框
            TextInput({ placeholder: '确认密码' })
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

            // 校园卡号输入框
            TextInput({ placeholder: '请输入10位校园卡号', text: this.studentId })
              .width('85%')
              .height(48)
              .type(InputType.Number)
              .maxLength(10)
              .placeholderColor('#999999')
              .placeholderFont({ size: 16 })
              .fontColor('#333333')
              .fontSize(16)
              .backgroundColor('rgba(255, 255, 255, 0.95)')
              .borderRadius(24)
              .padding({ left: 20, right: 20 })
              .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.1)', offsetX: 0, offsetY: 2 })
              .onChange((value) => {
                // 只允许输入数字，最多10位
                const numericValue = value.replace(/[^0-9]/g, '');
                this.studentId = numericValue.substring(0, 10);
              })

            // 校园卡图片上传区域
            Column() {
              if (this.cardImageUri) {
                // 已选择图片，显示缩略图
                Column() {
                  Image(this.cardImageUri)
                    .width(120)
                    .height(80)
                    .objectFit(ImageFit.Cover)
                    .borderRadius(8)
                  
                  Text('点击更换图片')
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ top: 6 })
                }
                .width('85%')
                .height(120)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .backgroundColor('rgba(255, 255, 255, 0.95)')
                .borderRadius(16)
                .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.1)', offsetX: 0, offsetY: 2 })
              } else {
                // 未选择图片，显示上传提示
                Column() {
                  Text('+')
                    .fontSize(36)
                    .fontColor('#4A90E2')
                    .fontWeight(FontWeight.Bold)
                  
                  Text('点击上传校园卡图片')
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ top: 4 })
                }
                .width('85%')
                .height(120)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .backgroundColor('rgba(255, 255, 255, 0.95)')
                .borderRadius(16)
                .border({ width: 1, color: '#E0E0E0', style: BorderStyle.Dashed })
                .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.1)', offsetX: 0, offsetY: 2 })
              }
            }
            .onClick(() => this.handleSelectCardImage())

            // 注册按钮
            Button('注册')
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
              .onClick(() => this.handleRegister())
              .margin({ top: 8 })

            // 已有账号链接
            Row() {
              Text('已有账号？')
                .fontSize(14)
                .fontColor('rgba(255, 255, 255, 0.8)')
              Text('立即登录')
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

  /**
   * 选择校园卡图片并上传到服务器
   */
  private async handleSelectCardImage() {
    if (this.isUploading) return;
    
    try {
      hilog.info(DOMAIN, 'Register', 'Starting card image selection');
      
      // 创建图片选择器
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      // 选择图片
      const photoSelectResult = await photoPicker.select(photoSelectOptions);
      
      if (!photoSelectResult.photoUris || photoSelectResult.photoUris.length === 0) {
        hilog.info(DOMAIN, 'Register', 'No photo selected');
        return;
      }

      // 保存选择的图片 URI 用于预览
      const selectedUri = photoSelectResult.photoUris[0];
      this.cardImageUri = selectedUri;
      
      hilog.info(DOMAIN, 'Register', 'Card image URI saved: %{public}s', selectedUri);
      
      // 上传图片到服务器
      this.isUploading = true;
      promptAction.showToast({ message: '正在上传校园卡图片...' });
      
      const uploadResult = await httpService.uploadFile('/api/upload/card', selectedUri, 'cardImage');
      
      // 输出完整的上传结果用于调试
      hilog.info(DOMAIN, 'Register', 'Upload result: success=%{public}s, data=%{public}s, message=%{public}s',
        String(uploadResult.success), uploadResult.data || 'null', uploadResult.message || 'null');
      
      if (uploadResult.success && uploadResult.data) {
        this.uploadedCardImageUrl = uploadResult.data;
        hilog.info(DOMAIN, 'Register', 'Card image uploaded successfully, URL: %{public}s', this.uploadedCardImageUrl);
        promptAction.showToast({ message: '校园卡图片已上传' });
      } else {
        // 详细的错误信息
        const errorMsg = uploadResult.message || '图片上传失败，请稍后重试';
        hilog.error(DOMAIN, 'Register', 'Upload failed - success: %{public}s, message: %{public}s',
          String(uploadResult.success), errorMsg);
        hilog.error(DOMAIN, 'Register', 'Full upload result: %{public}s', JSON.stringify(uploadResult));
        promptAction.showToast({ message: errorMsg });
        this.cardImageUri = '';
        this.uploadedCardImageUrl = '';
      }

    } catch (error) {
      hilog.error(DOMAIN, 'Register', 'Failed to select/upload card image: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '图片处理失败，请重试' });
    } finally {
      this.isUploading = false;
    }
  }

  private async handleRegister() {
    // 验证输入
    if (!this.username || !this.password || !this.confirmPassword) {
      promptAction.showToast({ message: '请填写所有字段' });
      return;
    }

    if (this.password.length < 3) {
      promptAction.showToast({ message: '密码长度至少3位' });
      return;
    }

    if (this.password !== this.confirmPassword) {
      promptAction.showToast({ message: '两次密码不一致' });
      return;
    }

    // 校验校园卡号
    if (!this.studentId) {
      promptAction.showToast({ message: '请输入校园卡号' });
      return;
    }

    const studentIdRegex = /^\d{10}$/;
    if (!studentIdRegex.test(this.studentId)) {
      promptAction.showToast({ message: '校园卡号必须为10位数字' });
      return;
    }

    // 校验校园卡图片（必须已上传到服务器）
    if (!this.uploadedCardImageUrl) {
      promptAction.showToast({ message: '请上传校园卡图片' });
      return;
    }

    this.isLoading = true;
    try {
      // 检查用户名是否已存在
      const existingUser = await this.checkUsernameExists(this.username);
      if (existingUser) {
        promptAction.showToast({ message: '用户名已存在' });
        return;
      }

      // 注册新用户，使用服务器返回的图片 URL
      const newUser: User = {
        username: this.username,
        password: this.password,
        studentId: this.studentId,
        cardImage: this.uploadedCardImageUrl
      };
      
      const userId = await dbManager.register(newUser);
      
      if (userId > 0) {
        hilog.info(DOMAIN, 'Register', 'User registered successfully: %{public}s', this.username);
        promptAction.showToast({ message: '注册成功，请登录' });
        router.back(); // 返回登录页
      } else {
        promptAction.showToast({ message: '注册失败，请重试' });
      }
    } catch (error) {
      hilog.error(DOMAIN, 'Register', 'Registration failed: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '注册失败，请重试' });
    } finally {
      this.isLoading = false;
    }
  }

  private async checkUsernameExists(username: string): Promise<boolean> {
    return await dbManager.checkUsernameExists(username);
  }
}
