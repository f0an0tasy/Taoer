import { router, promptAction } from '@kit.ArkUI';
import { dbManager, User } from '../db/DatabaseManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const MAX_CONTENT_LENGTH = 200;

@Entry
@Component
struct CommentPage {
  @State orderId: number = 0;
  @State productId: number = 0;
  @State productTitle: string = '';
  @State productImage: string = '';
  @State price: number = 0;
  @State specs: string = '';
  @State content: string = '';
  @State rating: number = 5; // 默认5星评分
  @State isSubmitting: boolean = false;
  @State isAnonymous: boolean = false; // 匿名评价开关
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;

  aboutToAppear() {
    const params = router.getParams() as Record<string, number | string>;
    if (params) {
      this.orderId = params['orderId'] as number;
      this.productId = params['productId'] as number;
      this.productTitle = params['productTitle'] as string;
      this.productImage = params['productImage'] as string;
      this.price = params['price'] as number;
      this.specs = params['specs'] as string;
    }
    hilog.info(DOMAIN, 'CommentPage', 'Loaded with orderId=%{public}d, productId=%{public}d', this.orderId, this.productId);
  }

  // 提交评价
  async submitComment() {
    // 验证用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }

    // 验证评价内容
    if (!this.content.trim()) {
      promptAction.showToast({ message: '请输入评价内容' });
      return;
    }

    if (this.content.length > MAX_CONTENT_LENGTH) {
      promptAction.showToast({ message: '评价内容不能超过200字' });
      return;
    }

    // 防抖：如果正在提交，直接返回
    if (this.isSubmitting) {
      hilog.warn(DOMAIN, 'CommentPage', 'Submit in progress, ignore duplicate click');
      return;
    }

    this.isSubmitting = true;
    try {
      // 根据匿名开关决定用户名和头像
      const commentUserName = this.isAnonymous ? '匿名用户' : this.user.username;
      const commentUserAvatar = this.isAnonymous ? '' : (this.user.avatar || '');

      hilog.info(DOMAIN, 'CommentPage', 'Submitting comment: orderId=%{public}d, productId=%{public}d, userId=%{public}d, anonymous=%{public}s', 
        this.orderId, this.productId, this.user.id, this.isAnonymous.toString());

      const result = await dbManager.addComment(
        this.orderId,
        this.productId,
        this.user.id,
        commentUserName,
        this.content.trim(),
        this.rating,
        commentUserAvatar
      );

      hilog.info(DOMAIN, 'CommentPage', 'Comment result: success=%{public}s, message=%{public}s', 
        result.success.toString(), result.message);

      if (result.success) {
        // 评价成功，返回上一页（订单列表）
        promptAction.showToast({ message: '评价成功' });
        hilog.info(DOMAIN, 'CommentPage', 'Comment submitted successfully, navigating back');
        router.back();
      } else {
        // 评价失败，检查是否已评价
        const message = result.message.toLowerCase();
        if (message.includes('已评价') || message.includes('重复') || message.includes('already')) {
          // 已评价过该商品，返回上一页（订单列表）
          promptAction.showToast({ message: '您已评价过该商品' });
          hilog.info(DOMAIN, 'CommentPage', 'User has already commented, navigating back');
          router.back();
        } else {
          // 其他错误
          promptAction.showToast({ message: result.message || '评价失败，请重试' });
          hilog.error(DOMAIN, 'CommentPage', 'Comment failed: %{public}s', result.message);
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, 'CommentPage', 'Failed to submit comment: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '网络错误，请检查网络连接' });
    } finally {
      // 恢复按钮状态（如果页面未跳转）
      this.isSubmitting = false;
    }
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('<')
          .fontSize(24)
          .onClick(() => router.back())
          .padding(15)
        Text('发表评价')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')

      Scroll() {
        Column({ space: 15 }) {
          // 商品信息卡片
          Column() {
            Row({ space: 10 }) {
              Image(this.productImage)
                .width(80)
                .height(80)
                .borderRadius(4)
                .backgroundColor('#eee')
              Column() {
                Text(this.productTitle)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .maxLines(2)
                Text(`规格: ${this.specs}`)
                  .fontSize(12)
                  .fontColor('#999')
                  .margin({ top: 4 })
                Text(`¥${this.price}`)
                  .fontSize(14)
                  .fontColor('#FF4D4F')
                  .fontWeight(FontWeight.Bold)
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
            .padding(15)
          }
          .backgroundColor(Color.White)
          .borderRadius(8)

          // 星级评分区域
          Column() {
            Text('商品评分')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 10 })

            Row({ space: 8 }) {
              ForEach([1, 2, 3, 4, 5], (star: number) => {
                SymbolGlyph(star <= this.rating ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
                  .fontSize(28)
                  .fontColor(star <= this.rating ? ['#FF9500'] : ['#ccc'])
                  .onClick(() => {
                    this.rating = star;
                  })
              })
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)

            Text(`${this.rating}星`)
              .fontSize(14)
              .fontColor('#666')
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(15)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .alignItems(HorizontalAlign.Start)

          // 匿名评价选项
          Row() {
            Text('匿名评价')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.isAnonymous })
              .selectedColor('#3366FF')
              .onChange((isOn: boolean) => {
                this.isAnonymous = isOn;
                hilog.info(DOMAIN, 'CommentPage', 'Anonymous mode: %{public}s', isOn ? 'ON' : 'OFF');
              })
          }
          .width('100%')
          .padding(15)
          .backgroundColor(Color.White)
          .borderRadius(8)

          // 评价输入区域
          Column() {
            Text('评价内容')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 10 })

            TextArea({ placeholder: '请输入评价内容（最多200字）', text: this.content })
              .width('100%')
              .height(150)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .maxLength(MAX_CONTENT_LENGTH)
              .onChange((value: string) => {
                this.content = value;
              })

            // 字数统计
            Row() {
              Blank()
              Text(`${this.content.length}/${MAX_CONTENT_LENGTH}`)
                .fontSize(12)
                .fontColor('#999')
            }
            .width('100%')
            .margin({ top: 5 })
          }
          .width('100%')
          .padding(15)
          .backgroundColor(Color.White)
          .borderRadius(8)
          .alignItems(HorizontalAlign.Start)

          // 提交按钮
          Button(this.isSubmitting ? '提交中...' : '提交评价')
            .width('100%')
            .height(45)
            .backgroundColor(this.isSubmitting ? '#ccc' : '#3366FF')
            .fontColor('#fff')
            .fontSize(16)
            .borderRadius(8)
            .margin({ top: 20 })
            .enabled(!this.isSubmitting)
            .onClick(() => this.submitComment())
        }
        .padding(15)
      }
      .layoutWeight(1)
      .backgroundColor('#F9F9F9')
    }
    .height('100%')
    .backgroundColor('#F9F9F9')
  }
}
