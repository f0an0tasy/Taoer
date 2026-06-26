import { router, promptAction } from '@kit.ArkUI';
import { dbManager, Order, User, Refund } from '../db/DatabaseManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@Entry
@Component
struct OrderListPage {
  @State orderList: Order[] = [];
  @State searchKey: string = '';
  @State isRefreshing: boolean = false; // 下拉刷新状态
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  // 存储每个订单的评价状态：key为"orderId_productId"
  @State commentedMap: Map<string, boolean> = new Map<string, boolean>();
  // 确认签收对话框状态
  @State showConfirmDialog: boolean = false;
  @State selectedOrderId: number = 0;
  // 监听 AppStorage 中的刷新信号（从 CommentPage 跳转回来时触发）
  @StorageLink('refreshOrders') @Watch('onRefreshOrders') refreshOrdersSignal: number = 0;
  // 监听订单刷新触发器（从退款处理页面跳转回来时触发）
  @StorageLink('orderRefreshTrigger') @Watch('onOrderRefresh') orderRefreshTrigger: number = 0;

  async aboutToAppear() {
    // 验证用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    this.refreshOrders();
  }

  // 页面显示时刷新订单列表（从评价页返回时触发）
  onPageShow() {
    if (this.user && this.user.id) {
      this.refreshOrders();
    }
  }

  // 监听 AppStorage 刷新信号（从 CommentPage 跳转回来时触发）
  onRefreshOrders() {
    if (this.refreshOrdersSignal > 0 && this.user && this.user.id) {
      hilog.info(DOMAIN, 'OrderList', 'Received refresh signal, refreshing orders');
      this.refreshOrders();
    }
  }

  // 监听订单刷新触发器（从退款处理页面跳转回来时触发）
  onOrderRefresh() {
    if (this.orderRefreshTrigger > 0 && this.user && this.user.id) {
      hilog.info(DOMAIN, 'OrderList', 'Received order refresh trigger, refreshing orders');
      this.refreshOrders();
    }
  }

  async refreshOrders() {
    // 关键修改：传入当前用户ID，只查询该用户的订单
    if (this.user && this.user.id) {
      this.orderList = await dbManager.getOrders(this.user.id, this.searchKey);
      // 加载每个订单的评价状态
      await this.loadCommentStatus();
    }
  }

  // 加载所有订单的评价状态
  async loadCommentStatus() {
    if (!this.user || !this.user.id) return;
    
    const newCommentedMap = new Map<string, boolean>();
    for (const order of this.orderList) {
      if (order.id && order.productId) {
        const key = `${order.id}_${order.productId}`;
        const hasCommented = await dbManager.hasCommented(order.id, order.productId, this.user.id);
        newCommentedMap.set(key, hasCommented);
      }
    }
    this.commentedMap = newCommentedMap;
  }

  // 跳转到评价页面
  goToCommentPage(order: Order) {
    if (!order.id || !order.productId) {
      promptAction.showToast({ message: '订单信息错误' });
      return;
    }
    router.pushUrl({
      url: 'pages/CommentPage',
      params: {
        orderId: order.id,
        productId: order.productId,
        productTitle: order.productTitle,
        productImage: order.productImage,
        price: order.price,
        specs: order.specs
      }
    });
  }

  // 跳转到退款申请页面
  goToApplyRefund(order: Order) {
    if (!order.id || !order.productId || !order.sellerId) {
      promptAction.showToast({ message: '订单信息不完整' });
      return;
    }
    router.pushUrl({
      url: 'pages/ApplyRefundPage',
      params: {
        orderId: order.id,
        orderNo: order.orderNo,
        productId: order.productId,
        productTitle: order.productTitle,
        productImage: order.productImage,
        price: order.price,
        specs: order.specs,
        sellerId: order.sellerId,
        userId: order.userId,
        orderStatus: order.status // 传递订单状态
      }
    });
  }

  async deleteOrder(id: number) {
    // 关键修改：传入当前用户ID，验证删除权限
    if (this.user && this.user.id) {
      await dbManager.deleteOrder(id, this.user.id);
      this.refreshOrders();
      promptAction.showToast({ message: '订单已删除' });
    }
  }

  // 显示确认签收对话框
  showConfirmReceiveDialog(orderId: number) {
    this.selectedOrderId = orderId;
    this.showConfirmDialog = true;
  }

  // 确认签收订单
  async confirmReceive() {
    if (this.selectedOrderId === 0) return;
    
    try {
      const success = await dbManager.updateOrderStatus(this.selectedOrderId, '交易成功');
      if (success) {
        hilog.info(DOMAIN, 'OrderList', 'Order received: orderId=%{public}d', this.selectedOrderId);
        promptAction.showToast({ message: '签收成功' });
        // 刷新订单列表
        await this.refreshOrders();
      } else {
        promptAction.showToast({ message: '签收失败，请重试' });
      }
    } catch (error) {
      hilog.error(DOMAIN, 'OrderList', 'Failed to confirm receive: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '签收失败，请重试' });
    } finally {
      this.showConfirmDialog = false;
      this.selectedOrderId = 0;
    }
  }

  // 获取订单状态颜色
  getStatusColor(status: string | undefined): string {
    switch (status) {
      case '待付款':
        return '#FF9500';
      case '待发货':
        return '#FF4D4F';
      case '待签收':
        return '#1890FF';
      case '交易成功':
        return '#52C41A';
      case '已取消':
        return '#999999';
      case '已退款':
        return '#999999';
      case '退款处理中':
        return '#FF9500'; // 橙色，表示退款正在处理
      default:
        return '#3366FF';
    }
  }

  build() {
    Column() {
      // 标题
      Row() {
        Text('<').fontSize(24).onClick(() => router.back()).padding(15)
        Text('我的订单').fontSize(18).fontWeight(FontWeight.Bold)
      }.width('100%')

      // 搜索
      TextInput({ placeholder: '搜索订单号/商品标题', text: this.searchKey })
        .margin(10)
        .backgroundColor('#F5F5F5')
        .onChange((val) => {
          this.searchKey = val;
          this.refreshOrders();
        })

      // ========== 下拉刷新区域 ==========
      Refresh({ refreshing: $$this.isRefreshing }) {
        List({ space: 10 }) {
          ForEach(this.orderList, (item: Order) => {
            ListItem() {
              Column() {
                Row() {
                  Text(`订单号: ${item.orderNo}`).fontSize(12).fontColor('#999')
                  // 显示订单状态
                  Text(item.status || '待付款').fontSize(12).fontColor(this.getStatusColor(item.status))
                }.justifyContent(FlexAlign.SpaceBetween).width('100%').margin({ bottom: 10 })

                Row({ space: 10 }) {
                  Image(item.productImage).width(60).height(60).borderRadius(4).backgroundColor('#eee')
                  Column() {
                    Text(item.productTitle).fontSize(14).fontWeight(FontWeight.Bold).maxLines(2)
                    Text(`规格: ${item.specs}`).fontSize(10).fontColor('#999').margin({ top: 4 })
                  }.layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Column() {
                    Text(`¥${item.price}`).fontSize(14)
                    Text(`x${item.quantity}`).fontSize(12).fontColor('#999')
                  }.alignItems(HorizontalAlign.End)
                }

                Row() {
                  Text(`实付款 ¥${item.price * item.quantity}`).fontSize(14).fontWeight(FontWeight.Bold)
                  
                  // ========== 根据订单状态显示不同按钮 ==========
                  // 状态为"待发货"：显示"退款"按钮（不可删除）
                  if (item.status === '待发货') {
                    // 退款按钮：根据退款状态显示不同样式
                    if (item.refundStatus === '退款中') {
                      Text('退款中')
                        .fontSize(12)
                        .fontColor('#FF9500')
                        .margin({ left: 10 })
                    } else if (item.refundStatus === '已退款') {
                      Text('已退款')
                        .fontSize(12)
                        .fontColor('#52C41A')
                        .margin({ left: 10 })
                    } else if (item.refundStatus === '已拒绝') {
                      Button('再次退款')
                        .type(ButtonType.Normal)
                        .backgroundColor('#FF9500')
                        .fontColor('#fff')
                        .height(26)
                        .fontSize(12)
                        .borderRadius(13)
                        .margin({ left: 10 })
                        .onClick(() => this.goToApplyRefund(item))
                    } else {
                      Button('退款')
                        .type(ButtonType.Normal)
                        .backgroundColor('#FF9500')
                        .fontColor('#fff')
                        .height(26)
                        .fontSize(12)
                        .borderRadius(13)
                        .margin({ left: 10 })
                        .onClick(() => this.goToApplyRefund(item))
                    }
                    // 待发货状态不可删除订单
                  }
                  // 状态为"待签收"：显示"退款" + "确认签收"按钮（不可删除）
                  else if (item.status === '待签收') {
                    // 退款按钮：根据退款状态显示不同样式
                    if (item.refundStatus === '退款中') {
                      Text('退款中')
                        .fontSize(12)
                        .fontColor('#FF9500')
                        .margin({ left: 10 })
                    } else if (item.refundStatus === '已退款') {
                      Text('已退款')
                        .fontSize(12)
                        .fontColor('#52C41A')
                        .margin({ left: 10 })
                    } else if (item.refundStatus === '已拒绝') {
                      Button('再次退款')
                        .type(ButtonType.Normal)
                        .backgroundColor('#FF9500')
                        .fontColor('#fff')
                        .height(26)
                        .fontSize(12)
                        .borderRadius(13)
                        .margin({ left: 10 })
                        .onClick(() => this.goToApplyRefund(item))
                    } else {
                      Button('退款')
                        .type(ButtonType.Normal)
                        .backgroundColor('#FF9500')
                        .fontColor('#fff')
                        .height(26)
                        .fontSize(12)
                        .borderRadius(13)
                        .margin({ left: 10 })
                        .onClick(() => this.goToApplyRefund(item))
                    }
                    
                    Button('确认签收')
                      .type(ButtonType.Normal)
                      .backgroundColor('#FF4D4F')
                      .fontColor('#fff')
                      .height(26)
                      .fontSize(12)
                      .borderRadius(13)
                      .margin({ left: 10 })
                      .onClick(() => this.showConfirmReceiveDialog(item.id!))
                    // 待签收状态不可删除订单
                  }
                  // 状态为"交易成功"：显示"退款" + "评价" + "删除订单"按钮（如果已评价则隐藏评价按钮）
                  else if (item.status === '交易成功') {
                    // 退款按钮：根据退款状态显示不同样式
                    if (item.refundStatus === '退款中') {
                      Text('退款中')
                        .fontSize(12)
                        .fontColor('#FF9500')
                        .margin({ left: 10 })
                    } else if (item.refundStatus === '已退款') {
                      Text('已退款')
                        .fontSize(12)
                        .fontColor('#52C41A')
                        .margin({ left: 10 })
                    } else if (item.refundStatus === '已拒绝') {
                      Button('再次退款')
                        .type(ButtonType.Normal)
                        .backgroundColor('#FF9500')
                        .fontColor('#fff')
                        .height(26)
                        .fontSize(12)
                        .borderRadius(13)
                        .margin({ left: 10 })
                        .onClick(() => this.goToApplyRefund(item))
                    } else {
                      Button('退款')
                        .type(ButtonType.Normal)
                        .backgroundColor('#FF9500')
                        .fontColor('#fff')
                        .height(26)
                        .fontSize(12)
                        .borderRadius(13)
                        .margin({ left: 10 })
                        .onClick(() => this.goToApplyRefund(item))
                    }
                    
                    if (item.id && item.productId) {
                      if (this.commentedMap.get(`${item.id}_${item.productId}`)) {
                        // 已评价：显示灰色不可点击文本
                        Text('已评价')
                          .fontSize(12)
                          .fontColor('#999')
                          .margin({ left: 10 })
                      } else {
                        // 未评价：显示可点击按钮
                        Button('评价')
                          .type(ButtonType.Normal)
                          .backgroundColor('#3366FF')
                          .fontColor('#fff')
                          .height(26)
                          .fontSize(12)
                          .borderRadius(13)
                          .margin({ left: 10 })
                          .onClick(() => this.goToCommentPage(item))
                      }
                    }
                    
                    Button('删除订单')
                      .type(ButtonType.Normal)
                      .backgroundColor('#fff')
                      .fontColor('#333')
                      .border({ width: 1, color: '#ddd' })
                      .height(26)
                      .fontSize(12)
                      .borderRadius(13)
                      .margin({ left: 10 })
                      .onClick(() => this.deleteOrder(item.id!))
                  }
                  // 其他状态（待付款、已取消、已退款等）：只有"已退款"才显示删除按钮
                  else {
                    // 已退款状态：显示删除订单按钮
                    if (item.status === '已退款') {
                      Button('删除订单')
                        .type(ButtonType.Normal)
                        .backgroundColor('#fff')
                        .fontColor('#333')
                        .border({ width: 1, color: '#ddd' })
                        .height(26)
                        .fontSize(12)
                        .borderRadius(13)
                        .margin({ left: 10 })
                        .onClick(() => this.deleteOrder(item.id!))
                    }
                    // 其他状态（待付款、已取消等）不可删除订单
                  }
                }.width('100%').justifyContent(FlexAlign.End).margin({ top: 10 })
              }
              .padding(15)
              .backgroundColor(Color.White)
              .borderRadius(8)
            }
          })
        }
        .layoutWeight(1)
        .padding(10)
        .backgroundColor('#F9F9F9')
      }
      .onRefreshing(() => {
        // 下拉刷新回调
        this.refreshOrders();
        setTimeout(() => {
          this.isRefreshing = false;
        }, 1000);
      })
      .refreshOffset(64)
      .pullToRefresh(true)
      
      // ========== 确认签收对话框 ==========
      if (this.showConfirmDialog) {
        Column() {
          Column() {
            Text('确认签收')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 15 })
            
            Text('您是否已收到商品？确认后订单将完成。')
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
                  this.showConfirmDialog = false;
                  this.selectedOrderId = 0;
                })
              
              Button('确认')
                .type(ButtonType.Normal)
                .backgroundColor('#FF4D4F')
                .fontColor('#fff')
                .width(100)
                .height(40)
                .borderRadius(20)
                .onClick(() => this.confirmReceive())
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
          this.showConfirmDialog = false;
          this.selectedOrderId = 0;
        })
      }
    }
    .height('100%')
    .backgroundColor('#F9F9F9')
  }
}