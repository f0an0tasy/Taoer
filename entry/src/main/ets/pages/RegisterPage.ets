import { router } from '@kit.ArkUI';
import { dbManager, User } from '../db/DatabaseManager';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { relationalStore } from '@kit.ArkData';
// [新增] 导入图片选择和上传所需模块
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
  @State isLoading: boolean = false;
  // [新增] 图片上传相关状态变量
  @State cardImageUri: string = '';           // 用于预览的图片 URI（如 file://media/...）
  @State uploadedCardImageUrl: string = '';   // 上传成功后服务器返回的图片 URL
  @State isUploading: boolean = false;        // 标记上传中状态（防止重复提交）

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

            // [新增] 校园卡图片上传区域
            Column() {
              if (this.cardImageUri) {
                // 显示缩略图和删除按钮
                Stack({ alignContent: Alignment.TopEnd }) {
                  Image(this.cardImageUri)
                    .width(80)
                    .height(80)
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)
                    .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.2)', offsetX: 0, offsetY: 2 })

                  // 删除按钮
                  Button({ type: ButtonType.Circle }) {
                    Text('×')
                      .fontSize(16)
                      .fontColor('#FFFFFF')
                      .fontWeight(FontWeight.Bold)
                  }
                  .width(24)
                  .height(24)
                  .backgroundColor('rgba(0, 0, 0, 0.6)')
                  .margin({ top: -8, right: -8 })
                  .onClick(() => this.handleDeleteCardImage())
                }
                .width(80)
                .height(80)
                .margin({ top: 8 })
              } else {
                // 上传提示区域
                Row() {
                  Text('📷')
                    .fontSize(20)
                  Text('点击上传校园卡图片')
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ left: 8 })
                }
                .width('85%')
                .height(80)
                .justifyContent(FlexAlign.Center)
                .backgroundColor('rgba(255, 255, 255, 0.95)')
                .borderRadius(8)
                .border({ width: 1, color: '#E0E0E0', style: BorderStyle.Dashed })
                .shadow({ radius: 4, color: 'rgba(0, 0, 0, 0.1)', offsetX: 0, offsetY: 1 })
                .onClick(() => this.handleSelectCardImage())
              }

              // 上传中进度提示
              if (this.isUploading) {
                Row() {
                  LoadingProgress()
                    .width(20)
                    .height(20)
                    .color('#4A90E2')
                  Text('上传中...')
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ left: 8 })
                }
                .margin({ top: 8 })
              }

              // 上传成功提示
              if (this.uploadedCardImageUrl && !this.isUploading) {
                Text('✓ 图片已上传')
                  .fontSize(12)
                  .fontColor('#52C41A')
                  .margin({ top: 4 })
              }
            }
            .width('85%')
            .alignItems(HorizontalAlign.Center)

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
              .enabled(!this.isLoading && !this.isUploading)
              .opacity((this.isLoading || this.isUploading) ? 0.5 : 1)
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
   * 校验学号是否在允许范围内
   * 允许范围：8209230301-8209230333 和 8209230401-8209230433
   */
  private isValidStudentId(studentId: string): boolean {
    // 先校验是否为10位数字
    const studentIdRegex = /^\d{10}$/;
    if (!studentIdRegex.test(studentId)) {
      return false;
    }
    
    // 转为数字并判断是否在允许范围内
    const num = parseInt(studentId, 10);
    const inRange1 = num >= 8209230301 && num <= 8209230333;
    const inRange2 = num >= 8209230401 && num <= 8209230433;
    
    return inRange1 || inRange2;
  }

  // [新增] 选择校园卡图片
  private async handleSelectCardImage() {
    if (this.isUploading) {
      return; // 防止重复点击
    }

    try {
      // 创建图片选择器
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      
      // 选择单张图片
      const photoSelectOptions: photoAccessHelper.PhotoSelectOptions = {
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      };
      
      const photoSelectResult = await photoPicker.select(photoSelectOptions);
      
      if (photoSelectResult.photoUris && photoSelectResult.photoUris.length > 0) {
        const uri = photoSelectResult.photoUris[0];
        hilog.info(DOMAIN, 'RegisterPage', 'Selected image URI: %{public}s', uri);
        
        // 显示缩略图
        this.cardImageUri = uri;
        
        // 开始上传
        await this.uploadCardImage(uri);
      }
    } catch (error) {
      hilog.error(DOMAIN, 'RegisterPage', 'Failed to select image: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '选择图片失败' });
    }
  }

  // [新增] 上传校园卡图片
  private async uploadCardImage(uri: string) {
    this.isUploading = true;
    
    try {
      const response = await httpService.uploadFile('/api/upload/card', uri, 'cardImage');
      
      if (response.success && response.data) {
        this.uploadedCardImageUrl = response.data;
        hilog.info(DOMAIN, 'RegisterPage', 'Image uploaded successfully: %{public}s', response.data);
        promptAction.showToast({ message: '图片上传成功' });
      } else {
        hilog.error(DOMAIN, 'RegisterPage', 'Image upload failed: %{public}s', response.message || 'unknown');
        promptAction.showToast({ message: response.message || '图片上传失败' });
        this.uploadedCardImageUrl = '';
      }
    } catch (error) {
      hilog.error(DOMAIN, 'RegisterPage', 'Image upload error: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '图片上传失败' });
      this.uploadedCardImageUrl = '';
    } finally {
      this.isUploading = false;
    }
  }

  // [新增] 删除已选择的图片
  private handleDeleteCardImage() {
    this.cardImageUri = '';
    this.uploadedCardImageUrl = '';
    hilog.info(DOMAIN, 'RegisterPage', 'Card image deleted');
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

    // 校验学号是否在允许范围内
    if (!this.isValidStudentId(this.studentId)) {
      promptAction.showToast({ 
        message: '学号不在允许注册的范围内（仅限8209230301-8209230333和8209230401-8209230433）' 
      });
      return;
    }

    // [新增] 校验校园卡图片
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

      // [修改] 注册新用户，使用上传后的图片 URL
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
