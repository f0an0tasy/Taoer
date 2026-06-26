import { router, promptAction } from '@kit.ArkUI';
import { dbManager, User, Refund, Order } from '../db/DatabaseManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@Entry
@Component
struct SellerRefundListPage {
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  @State refunds: Refund[] = [];
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;
  
  // 订单信息缓存（用于显示商品图片和标题）
  @State orderMap: Map<number, Order> = new Map<number, Order>();
  
  // 删除退款申请确认对话框状态
  @State showDeleteRefundDialog: boolean = false;
  @State selectedRefundId: number = 0;

  async aboutToAppear() {
    // 验证用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    
    await this.loadRefunds();
  }

  // 页面显示时刷新列表
  async onPageShow() {
    // 清空旧数据，强制显示加载状态
    this.refunds = [];
    // 延迟确保数据库事务提交完成
    setTimeout(() => {
      this.loadRefunds();
    }, 200);
  }

  // 加载退款申请列表
  async loadRefunds() {
    if (!this.user || !this.user.id) return;
    
    this.isLoading = true;
    try {
      this.refunds = await dbManager.getRefundsForSeller(this.user.id);
      
      // 加载关联的订单信息
      await this.loadOrderInfo();
      
      hilog.info(DOMAIN, 'SellerRefundList', 'Loaded %{public}d refund applications', this.refunds.length);
    } catch (error) {
      hilog.error(DOMAIN, 'SellerRefundList', 'Failed to load refunds: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '加载失败' });
    } finally {
      this.isLoading = false;
    }
  }

  // 加载订单信息（用于显示商品图片和标题）
  async loadOrderInfo() {
    const newOrderMap = new Map<number, Order>();
    for (const refund of this.refunds) {
      if (!newOrderMap.has(refund.orderId)) {
        const order = await dbManager.getOrderById(refund.orderId);
        if (order) {
          newOrderMap.set(refund.orderId, order);
        }
      }
    }
    this.orderMap = newOrderMap;
  }

  // 下拉刷新
  async onRefresh() {
    this.isRefreshing = true;
    await this.loadRefunds();
    this.isRefreshing = false;
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

  // 跳转到退款详情页面
  goToRefundDetail(refund: Refund) {
    router.pushUrl({
      url: 'pages/RefundDetailPage',
      params: {
        refundId: refund.id
      }
    });
  }

  // 显示删除退款申请确认对话框
  showDeleteRefundConfirmDialog(refundId: number) {
    this.selectedRefundId = refundId;
    this.showDeleteRefundDialog = true;
  }

  // 确认删除退款申请
  async confirmDeleteRefund() {
    if (this.selectedRefundId === 0 || !this.user || !this.user.id) return;
    
    try {
      const success = await dbManager.deleteRefund(this.selectedRefundId, this.user.id);
      if (success) {
        hilog.info(DOMAIN, 'SellerRefundList', 'Refund deleted: refundId=%{public}d', this.selectedRefundId);
        promptAction.showToast({ message: '删除成功' });
        // 刷新退款列表
        await this.loadRefunds();
      } else {
        promptAction.showToast({ message: '删除失败，请重试' });
      }
    } catch (error) {
      hilog.error(DOMAIN, 'SellerRefundList', 'Failed to delete refund: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '删除失败，请重试' });
    } finally {
      this.showDeleteRefundDialog = false;
      this.selectedRefundId = 0;
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶部导航栏
        Row() {
          Text('<')
            .fontSize(24)
            .padding(15)
            .onClick(() => router.back())

          Text('退款申请管理')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Text('')
            .width(54)
        }
        .width('100%')
        .backgroundColor('#fff')

        // 退款列表
        if (this.isLoading && this.refunds.length === 0) {
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
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.refunds.length === 0) {
          // 空状态
          Column() {
            Text('📦')
              .fontSize(60)

            Text('暂无退款申请')
              .fontSize(16)
              .fontColor('#999')
              .margin({ top: 15 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          // 退款列表（支持下拉刷新）
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ space: 10 }) {
              ForEach(this.refunds, (refund: Refund) => {
                ListItem() {
                  this.RefundItem(refund)
                }
              }, (refund: Refund) => refund.id?.toString() || refund.orderNo)
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 10, right: 10, top: 10, bottom: 10 })
          }
          .onRefreshing(() => this.onRefresh())
          .layoutWeight(1)
        }
      }
      .height('100%')
      .backgroundColor('#f5f5f5')

      // ========== 删除退款申请确认对话框 ==========
      if (this.showDeleteRefundDialog) {
        Column() {
          Column() {
            Text('删除退款申请')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 15 })

            Text('确定删除该退款申请记录吗？删除后不可恢复。')
              .fontSize(14)
              .fontColor('#666')
              .margin({ bottom: 20 })

            Row({ space: 15 }) {
              Button('取消')
                .type(ButtonType.Normal)
                .backgroundColor('#f5f5f5')
                .fontColor('#333')
                .width(100)
                .height(40)
                .borderRadius(20)
                .onClick(() => {
                  this.showDeleteRefundDialog = false;
                  this.selectedRefundId = 0;
                })

              Button('确定')
                .type(ButtonType.Normal)
                .backgroundColor('#FF4D4F')
                .fontColor('#fff')
                .width(100)
                .height(40)
                .borderRadius(20)
                .onClick(() => this.confirmDeleteRefund())
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
          // 点击背景关闭对话框
          this.showDeleteRefundDialog = false;
          this.selectedRefundId = 0;
        })
      }
    }
    .height('100%')
  }

  // 退款申请项组件
  @Builder
  RefundItem(refund: Refund) {
    Column() {
      // 头部：订单号 + 状态
      Row() {
        Text(`订单号: ${refund.orderNo}`)
          .fontSize(12)
          .fontColor('#999')
          .layoutWeight(1)
        
        Text(refund.status)
          .fontSize(12)
          .fontColor(this.getStatusColor(refund.status))
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 12, bottom: 8 })
      
      Divider().color('#f0f0f0')
      
      // 商品信息
      Row({ space: 12 }) {
        // 商品图片
        Image(this.orderMap.get(refund.orderId)?.productImage || '')
          .width(70)
          .height(70)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
        
        // 商品详情
        Column({ space: 6 }) {
          Text(this.orderMap.get(refund.orderId)?.productTitle || '商品信息加载中...')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          
          Text(`退款原因: ${refund.reason}`)
            .fontSize(12)
            .fontColor('#666')
          
          Text(`申请时间: ${this.formatTime(refund.applyTime)}`)
            .fontSize(12)
            .fontColor('#999')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(15)
      
      Divider().color('#f0f0f0')
      
      // 底部：退款类型 + 操作按钮
      Row() {
        Text(`类型: ${refund.type}`)
          .fontSize(12)
          .fontColor('#666')
          .layoutWeight(1)

        // 只有待处理状态才显示"去处理"按钮
        if (refund.status === '待处理') {
          Button('去处理')
            .fontSize(13)
            .height(32)
            .backgroundColor('#FF4D4F')
            .borderRadius(16)
            .onClick(() => this.goToRefundDetail(refund))
        } else {
          Button('查看详情')
            .fontSize(13)
            .height(32)
            .backgroundColor('#3366FF')
            .borderRadius(16)
            .onClick(() => this.goToRefundDetail(refund))
        }
        
        // 删除按钮：只有当关联订单状态为"交易成功"或"已退款"时才显示
        if (this.orderMap.get(refund.orderId)?.status === '交易成功' || 
            this.orderMap.get(refund.orderId)?.status === '已退款') {
          Button('删除')
            .type(ButtonType.Normal)
            .backgroundColor('#fff')
            .fontColor('#333')
            .border({ width: 1, color: '#ddd' })
            .height(26)
            .fontSize(12)
            .borderRadius(13)
            .margin({ left: 10 })
            .onClick(() => {
              if (refund.id) {
                this.showDeleteRefundConfirmDialog(refund.id);
              }
            })
        }
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 10, bottom: 12 })
    }
    .width('100%')
    .backgroundColor('#fff')
    .borderRadius(8)
  }
}
