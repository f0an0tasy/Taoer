import { router, promptAction } from '@kit.ArkUI';
import { dbManager, User, Refund, Order } from '../db/DatabaseManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@Entry
@Component
struct RefundDetailPage {
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  
  @State refundId: number = 0;
  @State refund: Refund | null = null;
  @State order: Order | null = null;
  @State buyerName: string = '加载中...';
  @State isLoading: boolean = true;
  
  // 卖家回复
  @State reply: string = '';
  @State isProcessing: boolean = false;
  
  // 确认对话框
  @State showConfirmDialog: boolean = false;
  @State confirmAction: string = ''; // 'agree' 或 'reject'

  async aboutToAppear() {
    // 验证用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    
    // 获取路由参数
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.refundId = params['refundId'] as number || 0;
      hilog.info(DOMAIN, 'RefundDetail', 'RefundId: %{public}d', this.refundId);
    }
    
    await this.loadData();
  }

  // 加载数据
  async loadData() {
    if (this.refundId === 0) return;
    
    this.isLoading = true;
    try {
      // 获取退款申请信息
      this.refund = await dbManager.getRefundById(this.refundId);
      
      if (this.refund) {
        // 获取订单信息
        this.order = await dbManager.getOrderById(this.refund.orderId);
        
        // 获取买家信息
        const buyer = await dbManager.getUserById(this.refund.userId);
        this.buyerName = buyer?.username || '未知用户';
        
        // 如果已有回复，显示
        if (this.refund.reply) {
          this.reply = this.refund.reply;
        }
        
        hilog.info(DOMAIN, 'RefundDetail', 'Loaded refund: orderId=%{public}d, status=%{public}s', 
          this.refund.orderId, this.refund.status);
      }
    } catch (error) {
      hilog.error(DOMAIN, 'RefundDetail', 'Failed to load data: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  // 格式化时间
  formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hour = date.getHours().toString().padStart(2, '0');
    const minute = date.getMinutes().toString().padStart(2, '0');
    return `${year}-${month}-${day} ${hour}:${minute}`;
  }

  // 获取退款状态颜色
  getStatusColor(status: string): string {
    switch (status) {
      case '待处理':
        return '#FF9500';
      case '已同意':
        return '#52C41A';
      case '已拒绝':
        return '#FF4D4F';
      case '已取消':
        return '#999999';
      default:
        return '#666666';
    }
  }

  // 显示确认对话框
  showConfirm(action: string) {
    this.confirmAction = action;
    this.showConfirmDialog = true;
  }

  // 处理退款（同意/拒绝）
  async processRefund() {
    if (!this.refund || !this.refund.id) return;
    
    this.isProcessing = true;
    
    try {
      const status = this.confirmAction === 'agree' ? '已同意' : '已拒绝';
      const success = await dbManager.processRefund(this.refund.id, status, this.reply);
      
      if (success) {
        hilog.info(DOMAIN, 'RefundDetail', 'Refund processed: refundId=%{public}d, status=%{public}s', 
          this.refund.id, status);
        
        // 如果同意退款，需要同步更新订单状态为"已退款"
        if (this.confirmAction === 'agree') {
          const orderSuccess = await dbManager.updateOrderStatus(this.refund.orderId, '已退款');
          if (orderSuccess) {
            hilog.info(DOMAIN, 'RefundDetail', 'Order status updated to 已退款: orderId=%{public}d', 
              this.refund.orderId);
          } else {
            hilog.error(DOMAIN, 'RefundDetail', 'Failed to update order status: orderId=%{public}d', 
              this.refund.orderId);
          }
        }
        
        // 触发页面刷新
        AppStorage.setOrCreate('orderRefreshTrigger', Date.now());
        AppStorage.setOrCreate('refundRefreshTrigger', Date.now());
        
        promptAction.showToast({ 
          message: this.confirmAction === 'agree' ? '已同意退款' : '已拒绝退款' 
        });
        
        // 使用 router.back() 返回上一页
        router.back();
      } else {
        promptAction.showToast({ message: '操作失败，请重试' });
      }
    } catch (error) {
      hilog.error(DOMAIN, 'RefundDetail', 'Failed to process refund: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '操作失败，请重试' });
    } finally {
      this.isProcessing = false;
      this.showConfirmDialog = false;
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
        
        Text('退款详情')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        Text('')
          .width(54)
      }
      .width('100%')
      .backgroundColor('#fff')
      
      if (this.isLoading) {
        // 加载中
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
            .color('#3366FF')
          
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999')
            .margin({ top: 10 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.refund && this.order) {
        // 内容区域
        Scroll() {
          Column() {
            // 退款状态卡片
            Column() {
              Row() {
                Text('退款状态')
                  .fontSize(14)
                  .fontColor('#666')
                
                Text(this.refund.status)
                  .fontSize(16)
                  .fontColor(this.getStatusColor(this.refund.status))
                  .fontWeight(FontWeight.Bold)
                  .layoutWeight(1)
                  .textAlign(TextAlign.End)
              }
              .width('100%')
              .padding(15)
            }
            .width('100%')
            .backgroundColor('#fff')
            .borderRadius(8)
            .margin({ top: 10 })
            
            // 商品信息卡片
            Column() {
              Text('商品信息')
                .fontSize(14)
                .fontColor('#666')
                .width('100%')
                .margin({ bottom: 10 })
              
              Row({ space: 12 }) {
                Image(this.order.productImage)
                  .width(80)
                  .height(80)
                  .borderRadius(8)
                  .objectFit(ImageFit.Cover)
                
                Column({ space: 6 }) {
                  Text(this.order.productTitle)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  
                  Text(`规格: ${this.order.specs}`)
                    .fontSize(12)
                    .fontColor('#666')
                  
                  Text(`¥${this.order.price.toFixed(2)}`)
                    .fontSize(14)
                    .fontColor('#FF4D4F')
                    .fontWeight(FontWeight.Bold)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
              }
              .width('100%')
            }
            .width('100%')
            .padding(15)
            .backgroundColor('#fff')
            .borderRadius(8)
            .margin({ top: 10 })
            .alignItems(HorizontalAlign.Start)
            
            // 买家信息卡片
            Column() {
              Text('买家信息')
                .fontSize(14)
                .fontColor('#666')
                .width('100%')
                .margin({ bottom: 10 })
              
              Row() {
                Text('买家昵称:')
                  .fontSize(13)
                  .fontColor('#333')
                
                Text(this.buyerName)
                  .fontSize(13)
                  .fontColor('#666')
                  .margin({ left: 8 })
              }
              .width('100%')
              .margin({ bottom: 8 })
              
              Row() {
                Text('订单号:')
                  .fontSize(13)
                  .fontColor('#333')
                
                Text(this.refund.orderNo)
                  .fontSize(13)
                  .fontColor('#666')
                  .margin({ left: 8 })
              }
              .width('100%')
            }
            .width('100%')
            .padding(15)
            .backgroundColor('#fff')
            .borderRadius(8)
            .margin({ top: 10 })
            .alignItems(HorizontalAlign.Start)
            
            // 退款申请信息卡片
            Column() {
              Text('退款申请信息')
                .fontSize(14)
                .fontColor('#666')
                .width('100%')
                .margin({ bottom: 10 })
              
              Row() {
                Text('退款类型:')
                  .fontSize(13)
                  .fontColor('#333')
                  .width(80)
                
                Text(this.refund.type)
                  .fontSize(13)
                  .fontColor('#666')
              }
              .width('100%')
              .margin({ bottom: 8 })
              
              Row() {
                Text('退款原因:')
                  .fontSize(13)
                  .fontColor('#333')
                  .width(80)
                
                Text(this.refund.reason)
                  .fontSize(13)
                  .fontColor('#666')
              }
              .width('100%')
              .margin({ bottom: 8 })
              
              Row() {
                Text('申请时间:')
                  .fontSize(13)
                  .fontColor('#333')
                  .width(80)
                
                Text(this.formatTime(this.refund.applyTime))
                  .fontSize(13)
                  .fontColor('#666')
              }
              .width('100%')
              
              if (this.refund.description) {
                Row() {
                  Text('详细描述:')
                    .fontSize(13)
                    .fontColor('#333')
                    .width(80)
                  
                  Text(this.refund.description)
                    .fontSize(13)
                    .fontColor('#666')
                    .layoutWeight(1)
                }
                .width('100%')
                .margin({ top: 8 })
                .alignItems(VerticalAlign.Top)
              }
              
              // 如果已处理，显示处理信息
              if (this.refund.status !== '待处理' && this.refund.processTime) {
                Divider().color('#f0f0f0').margin({ top: 12, bottom: 12 })
                
                Row() {
                  Text('处理时间:')
                    .fontSize(13)
                    .fontColor('#333')
                    .width(80)
                  
                  Text(this.formatTime(this.refund.processTime))
                    .fontSize(13)
                    .fontColor('#666')
                }
                .width('100%')
                
                if (this.refund.reply) {
                  Row() {
                    Text('卖家回复:')
                      .fontSize(13)
                      .fontColor('#333')
                      .width(80)
                    
                    Text(this.refund.reply)
                      .fontSize(13)
                      .fontColor('#666')
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .margin({ top: 8 })
                  .alignItems(VerticalAlign.Top)
                }
              }
            }
            .width('100%')
            .padding(15)
            .backgroundColor('#fff')
            .borderRadius(8)
            .margin({ top: 10 })
            .alignItems(HorizontalAlign.Start)
            
            // 只有待处理状态才显示处理区域
            if (this.refund.status === '待处理') {
              // 卖家回复区域
              Column() {
                Text('回复内容（选填）')
                  .fontSize(14)
                  .fontColor('#333')
                  .width('100%')
                  .margin({ bottom: 10 })
                
                TextArea({ text: this.reply, placeholder: '请输入回复内容' })
                  .width('100%')
                  .height(100)
                  .backgroundColor('#f5f5f5')
                  .borderRadius(8)
                  .onChange((value: string) => {
                    this.reply = value;
                  })
              }
              .width('100%')
              .padding(15)
              .backgroundColor('#fff')
              .borderRadius(8)
              .margin({ top: 10 })
              .alignItems(HorizontalAlign.Start)
              
              // 操作按钮
              Row({ space: 15 }) {
                Button('拒绝退款')
                  .width('45%')
                  .height(45)
                  .backgroundColor('#fff')
                  .fontColor('#FF4D4F')
                  .border({ width: 1, color: '#FF4D4F' })
                  .fontSize(16)
                  .borderRadius(22)
                  .enabled(!this.isProcessing)
                  .onClick(() => this.showConfirm('reject'))
                
                Button('同意退款')
                  .width('45%')
                  .height(45)
                  .backgroundColor('#52C41A')
                  .fontColor('#fff')
                  .fontSize(16)
                  .borderRadius(22)
                  .enabled(!this.isProcessing)
                  .onClick(() => this.showConfirm('agree'))
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ top: 20, bottom: 30 })
            }
          }
          .width('100%')
          .padding({ left: 15, right: 15 })
        }
        .layoutWeight(1)
        .backgroundColor('#f5f5f5')
      } else {
        // 数据加载失败
        Column() {
          Text('数据加载失败')
            .fontSize(16)
            .fontColor('#999')
          
          Button('返回')
            .margin({ top: 20 })
            .onClick(() => router.back())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      
      // 确认对话框
      if (this.showConfirmDialog) {
        Column() {
          Column() {
            Text(this.confirmAction === 'agree' ? '确认同意退款' : '确认拒绝退款')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 15 })
            
            if (this.confirmAction === 'agree') {
              Text('同意后，订单将变为"已退款"状态，款项将退回买家。')
                .fontSize(14)
                .fontColor('#666')
                .margin({ bottom: 20 })
            } else {
              Text('拒绝后，买家可以重新申请退款。')
                .fontSize(14)
                .fontColor('#666')
                .margin({ bottom: 20 })
            }
            
            Row({ space: 15 }) {
              Button('取消')
                .type(ButtonType.Normal)
                .backgroundColor('#f5f5f5')
                .fontColor('#333')
                .width(100)
                .height(40)
                .borderRadius(20)
                .onClick(() => {
                  this.showConfirmDialog = false;
                })
              
              Button('确认')
                .type(ButtonType.Normal)
                .backgroundColor(this.confirmAction === 'agree' ? '#52C41A' : '#FF4D4F')
                .fontColor('#fff')
                .width(100)
                .height(40)
                .borderRadius(20)
                .enabled(!this.isProcessing)
                .onClick(() => this.processRefund())
            }
          }
          .padding(20)
          .backgroundColor('#fff')
          .borderRadius(12)
          .width('80%')
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.5)')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.showConfirmDialog = false;
        })
      }
    }
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}
