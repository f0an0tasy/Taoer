import { router, promptAction } from '@kit.ArkUI';
import { dbManager, User, Refund } from '../db/DatabaseManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

// 退款原因选项
const REFUND_REASONS: string[] = [
  '商品质量问题',
  '描述不符',
  '商品损坏',
  '发错商品',
  '不想要了',
  '其他原因'
];

// 退款类型选项
const REFUND_TYPES: string[] = [
  '仅退款',
  '退货退款'
];

@Entry
@Component
struct ApplyRefundPage {
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  
  // 订单信息（从路由参数获取）
  @State orderId: number = 0;
  @State orderNo: string = '';
  @State productId: number = 0;
  @State productTitle: string = '';
  @State productImage: string = '';
  @State price: number = 0;
  @State specs: string = '';
  @State sellerId: number = 0;
  @State buyerId: number = 0;
  
  // 表单数据
  @State refundType: string = '仅退款';
  @State refundReason: string = '';
  @State description: string = '';
  @State isSubmitting: boolean = false;
  
  // UI 状态
  @State showReasonPicker: boolean = false;
  @State showTypePicker: boolean = false;

  async aboutToAppear() {
    // 获取路由参数
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.orderId = params['orderId'] as number || 0;
      this.orderNo = params['orderNo'] as string || '';
      this.productId = params['productId'] as number || 0;
      this.productTitle = params['productTitle'] as string || '';
      this.productImage = params['productImage'] as string || '';
      this.price = params['price'] as number || 0;
      this.specs = params['specs'] as string || '';
      this.sellerId = params['sellerId'] as number || 0;
      this.buyerId = params['userId'] as number || 0;
      
      hilog.info(DOMAIN, 'ApplyRefund', 'Order info: orderId=%{public}d, productTitle=%{public}s', this.orderId, this.productTitle);
    }
    
    // 验证用户登录状态
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
  }

  // 提交退款申请
  async submitRefund() {
    // 表单验证
    if (!this.refundReason) {
      promptAction.showToast({ message: '请选择退款原因' });
      return;
    }
    
    if (this.orderId === 0 || this.productId === 0) {
      promptAction.showToast({ message: '订单信息错误' });
      return;
    }
    
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      return;
    }
    
    this.isSubmitting = true;
    
    try {
      const refund: Refund = {
        orderId: this.orderId,
        orderNo: this.orderNo,
        userId: this.user.id,
        sellerId: this.sellerId,
        productId: this.productId,
        reason: this.refundReason,
        description: this.description,
        status: '待处理',
        type: this.refundType,
        applyTime: Date.now()
      };
      
      const refundId = await dbManager.applyRefund(refund);
      
      if (refundId > 0) {
        hilog.info(DOMAIN, 'ApplyRefund', 'Refund applied successfully: refundId=%{public}d', refundId);
        
        // 更新订单状态为"退款处理中"
        const statusUpdated = await dbManager.updateOrderStatus(this.orderId, '退款处理中');
        if (!statusUpdated) {
          hilog.error(DOMAIN, 'ApplyRefund', 'Failed to update order status to 退款处理中');
        }
        
        // 更新订单退款状态为"申请中"
        const refundStatusUpdated = await dbManager.updateOrderRefundStatus(this.orderId, '申请中');
        if (!refundStatusUpdated) {
          hilog.error(DOMAIN, 'ApplyRefund', 'Failed to update order refund status to 申请中');
        }
        
        // 触发订单列表刷新
        AppStorage.setOrCreate('orderRefreshTrigger', Date.now());
        
        promptAction.showToast({ message: '退款申请已提交' });
        
        // 返回订单列表页
        router.back();
      } else if (refundId === -1) {
        promptAction.showToast({ message: '该订单已有待处理的退款申请' });
      } else {
        promptAction.showToast({ message: '提交失败，请重试' });
      }
    } catch (error) {
      hilog.error(DOMAIN, 'ApplyRefund', 'Failed to submit refund: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '提交失败，请重试' });
    } finally {
      this.isSubmitting = false;
    }
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('<')
          .fontSize(24)
          .padding(15)
          .onClick(() => router.back())
        
        Text('申请退款')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        Text('')
          .width(54)
      }
      .width('100%')
      .backgroundColor('#fff')
      
      // 内容区域
      Scroll() {
        Column() {
          // 商品信息卡片
          Column() {
            Row({ space: 12 }) {
              Image(this.productImage)
                .width(80)
                .height(80)
                .borderRadius(8)
                .objectFit(ImageFit.Cover)
              
              Column({ space: 6 }) {
                Text(this.productTitle)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                
                Text(`规格: ${this.specs}`)
                  .fontSize(12)
                  .fontColor('#666')
                
                Text(`¥${this.price.toFixed(2)}`)
                  .fontSize(14)
                  .fontColor('#FF4D4F')
                  .fontWeight(FontWeight.Bold)
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(15)
          }
          .width('100%')
          .backgroundColor('#fff')
          .borderRadius(8)
          .margin({ top: 10 })
          
          // 退款信息表单
          Column() {
            // 退款类型
            Row() {
              Text('退款类型')
                .fontSize(14)
                .fontColor('#333')
                .width(80)
              
              Row() {
                Text(this.refundType)
                  .fontSize(14)
                  .fontColor('#333')
                  .layoutWeight(1)
                
                Text('>')
                  .fontSize(14)
                  .fontColor('#999')
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.End)
              .onClick(() => {
                this.showTypePicker = true;
              })
            }
            .width('100%')
            .padding(15)
            
            Divider().color('#f0f0f0')
            
            // 退款原因
            Row() {
              Text('退款原因')
                .fontSize(14)
                .fontColor('#333')
                .width(80)
              
              Row() {
                Text(this.refundReason || '请选择退款原因')
                  .fontSize(14)
                  .fontColor(this.refundReason ? '#333' : '#999')
                  .layoutWeight(1)
                
                Text('>')
                  .fontSize(14)
                  .fontColor('#999')
              }
              .layoutWeight(1)
              .justifyContent(FlexAlign.End)
              .onClick(() => {
                this.showReasonPicker = true;
              })
            }
            .width('100%')
            .padding(15)
            
            Divider().color('#f0f0f0')
            
            // 详细描述
            Column() {
              Text('详细描述（选填）')
                .fontSize(14)
                .fontColor('#333')
                .width('100%')
                .margin({ bottom: 10 })
              
              TextArea({ text: this.description, placeholder: '请输入详细描述，最多200字' })
                .width('100%')
                .height(100)
                .backgroundColor('#f5f5f5')
                .borderRadius(8)
                .maxLength(200)
                .onChange((value: string) => {
                  this.description = value;
                })
            }
            .width('100%')
            .padding(15)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .backgroundColor('#fff')
          .borderRadius(8)
          .margin({ top: 10 })
          
          // 提示信息
          Column() {
            Text('温馨提示')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333')
              .width('100%')
              .margin({ bottom: 8 })
            
            Text('1. 退款申请提交后，卖家将在48小时内处理')
              .fontSize(12)
              .fontColor('#666')
              .width('100%')
            
            Text('2. 如果卖家同意退款，款项将原路退回')
              .fontSize(12)
              .fontColor('#666')
              .width('100%')
              .margin({ top: 4 })
            
            Text('3. 如有疑问，请联系卖家协商处理')
              .fontSize(12)
              .fontColor('#666')
              .width('100%')
              .margin({ top: 4 })
          }
          .width('100%')
          .padding(15)
          .backgroundColor('#fff')
          .borderRadius(8)
          .margin({ top: 10 })
          .alignItems(HorizontalAlign.Start)
          
          // 提交按钮
          Button(this.isSubmitting ? '提交中...' : '提交申请')
            .width('90%')
            .height(45)
            .backgroundColor(this.isSubmitting ? '#ccc' : '#FF4D4F')
            .fontColor('#fff')
            .fontSize(16)
            .borderRadius(22)
            .margin({ top: 30, bottom: 30 })
            .enabled(!this.isSubmitting)
            .onClick(() => this.submitRefund())
        }
        .width('100%')
        .padding({ left: 15, right: 15 })
      }
      .layoutWeight(1)
      .backgroundColor('#f5f5f5')
      
      // 退款原因选择弹窗
      if (this.showReasonPicker) {
        Column() {
          Column() {
            Text('选择退款原因')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 15, bottom: 15 })
            
            Divider().color('#f0f0f0')
            
            List() {
              ForEach(REFUND_REASONS, (reason: string) => {
                ListItem() {
                  Row() {
                    Text(reason)
                      .fontSize(14)
                      .fontColor('#333')
                    
                    if (this.refundReason === reason) {
                      Text('✓')
                        .fontSize(16)
                        .fontColor('#FF4D4F')
                    }
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  .padding(15)
                  .onClick(() => {
                    this.refundReason = reason;
                    this.showReasonPicker = false;
                  })
                }
              })
            }
            .width('100%')
            .height(300)
            
            Divider().color('#f0f0f0')
            
            Text('取消')
              .fontSize(16)
              .fontColor('#666')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(15)
              .onClick(() => {
                this.showReasonPicker = false;
              })
          }
          .width('100%')
          .backgroundColor('#fff')
          .borderRadius({ topLeft: 16, topRight: 16 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .justifyContent(FlexAlign.End)
        .onClick(() => {
          this.showReasonPicker = false;
        })
      }
      
      // 退款类型选择弹窗
      if (this.showTypePicker) {
        Column() {
          Column() {
            Text('选择退款类型')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ top: 15, bottom: 15 })
            
            Divider().color('#f0f0f0')
            
            List() {
              ForEach(REFUND_TYPES, (type: string) => {
                ListItem() {
                  Row() {
                    Text(type)
                      .fontSize(14)
                      .fontColor('#333')
                    
                    if (this.refundType === type) {
                      Text('✓')
                        .fontSize(16)
                        .fontColor('#FF4D4F')
                    }
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.SpaceBetween)
                  .padding(15)
                  .onClick(() => {
                    this.refundType = type;
                    this.showTypePicker = false;
                  })
                }
              })
            }
            .width('100%')
            .height(120)
            
            Divider().color('#f0f0f0')
            
            Text('取消')
              .fontSize(16)
              .fontColor('#666')
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding(15)
              .onClick(() => {
                this.showTypePicker = false;
              })
          }
          .width('100%')
          .backgroundColor('#fff')
          .borderRadius({ topLeft: 16, topRight: 16 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .justifyContent(FlexAlign.End)
        .onClick(() => {
          this.showTypePicker = false;
        })
      }
    }
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}
