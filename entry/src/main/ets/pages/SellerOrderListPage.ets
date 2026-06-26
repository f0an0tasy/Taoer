import { router, promptAction } from '@kit.ArkUI';
import { dbManager, Order, User, Refund } from '../db/DatabaseManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

// 买家地址接口
interface BuyerAddress {
  consignee: string;
  phone: string;
  province: string;
  city: string;
  district: string;
  detailAddress: string;
  tag?: string;
}

@Entry
@Component
struct SellerOrderListPage {
  @State orders: Order[] = [];
  @State isLoading: boolean = false;
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  @State isRefreshing: boolean = false;
  @State pendingRefundCount: number = 0; // 待处理的退款申请数量
  // 删除订单确认对话框状态
  @State showDeleteOrderDialog: boolean = false;
  @State selectedOrderId: number = 0;
  // 监听订单刷新触发器（从退款处理页面跳转回来时触发）
  @StorageLink('orderRefreshTrigger') @Watch('onOrderRefresh') orderRefreshTrigger: number = 0;

  async aboutToAppear() {
    // 验证用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }
    
    await this.loadOrders();
  }

  // 页面显示时刷新订单列表（从发货页面返回时触发）
  async onPageShow() {
    // 清空旧数据，强制显示加载状态
    this.orders = [];
    // 延迟确保数据库事务提交完成
    setTimeout(() => {
      this.loadOrders();
    }, 200);
  }

  // 监听订单刷新触发器（从退款处理页面跳转回来时触发）
  onOrderRefresh() {
    if (this.orderRefreshTrigger > 0 && this.user && this.user.id) {
      hilog.info(DOMAIN, 'SellerOrderList', 'Received order refresh trigger, refreshing orders');
      this.loadOrders();
    }
  }

  // 加载卖家订单列表
  async loadOrders() {
    if (!this.user || !this.user.id) return;
    
    this.isLoading = true;
    try {
      this.orders = await dbManager.getSellerOrders(this.user.id);
      // 加载待处理的退款申请数量
      await this.loadPendingRefundCount();
      hilog.info(DOMAIN, 'SellerOrderList', 'Loaded %{public}d seller orders', this.orders.length);
    } catch (error) {
      hilog.error(DOMAIN, 'SellerOrderList', 'Failed to load orders: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '加载订单失败' });
    } finally {
      this.isLoading = false;
    }
  }

  // 加载待处理的退款申请数量
  async loadPendingRefundCount() {
    if (!this.user || !this.user.id) return;
    
    try {
      const refunds = await dbManager.getRefundsForSeller(this.user.id);
      this.pendingRefundCount = refunds.filter(r => r.status === '待处理').length;
      hilog.info(DOMAIN, 'SellerOrderList', 'Pending refund count: %{public}d', this.pendingRefundCount);
    } catch (error) {
      hilog.error(DOMAIN, 'SellerOrderList', 'Failed to load refund count: %{public}s', JSON.stringify(error));
    }
  }

  // 下拉刷新
  async onRefresh() {
    this.isRefreshing = true;
    await this.loadOrders();
    this.isRefreshing = false;
  }

  // 解析买家地址
  parseBuyerAddress(buyerAddressJson: string | undefined): BuyerAddress | null {
    try {
      if (!buyerAddressJson || buyerAddressJson.length === 0) return null;
      return JSON.parse(buyerAddressJson) as BuyerAddress;
    } catch (error) {
      hilog.error(DOMAIN, 'SellerOrderList', 'Failed to parse buyer address: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  // 隐藏手机号中间四位
  maskPhone(phone: string): string {
    if (!phone || phone.length < 7) return phone;
    return phone.substring(0, 3) + '****' + phone.substring(7);
  }

  // 获取买家显示信息
  getBuyerDisplayInfo(order: Order): string {
    const buyerAddr = this.parseBuyerAddress(order.buyerAddress || order.address);
    if (buyerAddr) {
      return `${buyerAddr.consignee} ${this.maskPhone(buyerAddr.phone)}`;
    }
    return '未知';
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

  // 获取订单状态颜色
  getStatusColor(status: string): string {
    switch (status) {
      case '待付款':
        return '#FF9500';
      case '待发货':
        return '#FF4D4F';
      case '待签收': // 修改：统一使用"待签收"（与数据库一致）
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
        return '#666666';
    }
  }

  // 获取卖家视角的订单状态文本
  // 卖家视角：待签收时显示"已发货"（表示卖家已发货，等待买家签收）
  getSellerStatusText(status: string | undefined): string {
    if (!status) return '待付款';
    
    switch (status) {
      case '待签收':
        return '已发货'; // 修改：卖家视角显示"已发货"
      case '退款处理中':
        return '退款处理中'; // 退款处理中状态直接显示
      default:
        return status; // 其他状态直接显示
    }
  }

  // 跳转到发货页面
  goToDelivery(order: Order) {
    router.pushUrl({
      url: 'pages/DeliveryPage',
      params: {
        orderId: order.id,
        orderNo: order.orderNo,
        productTitle: order.productTitle,
        productImage: order.productImage,
        price: order.price,
        quantity: order.quantity,
        specs: order.specs,
        buyerAddress: order.buyerAddress || order.address
      }
    });
  }

  // 跳转到退款申请列表页面
  goToRefundList() {
    router.pushUrl({
      url: 'pages/SellerRefundListPage'
    });
  }

  // 显示删除订单确认对话框
  showDeleteOrderConfirmDialog(orderId: number) {
    this.selectedOrderId = orderId;
    this.showDeleteOrderDialog = true;
  }

  // 确认删除订单
  async confirmDeleteOrder() {
    if (this.selectedOrderId === 0 || !this.user || !this.user.id) return;
    
    try {
      const success = await dbManager.deleteOrderForSeller(this.selectedOrderId, this.user.id);
      if (success) {
        hilog.info(DOMAIN, 'SellerOrderList', 'Order deleted: orderId=%{public}d', this.selectedOrderId);
        promptAction.showToast({ message: '删除成功' });
        // 刷新订单列表
        await this.loadOrders();
      } else {
        promptAction.showToast({ message: '删除失败，只能删除交易成功、已退款、已取消的订单' });
      }
    } catch (error) {
      hilog.error(DOMAIN, 'SellerOrderList', 'Failed to delete order: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '删除失败，请重试' });
    } finally {
      this.showDeleteOrderDialog = false;
      this.selectedOrderId = 0;
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶部栏
        Row() {
          Text('<')
            .fontSize(24)
            .padding(15)
            .onClick(() => router.back())

          Text('我的卖出')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          // 退款入口按钮
          Row() {
            Text('退款')
              .fontSize(14)
              .fontColor('#FF4D4F')

            if (this.pendingRefundCount > 0) {
              Text(`${this.pendingRefundCount}`)
                .fontSize(10)
                .fontColor('#fff')
                .backgroundColor('#FF4D4F')
                .borderRadius(8)
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .margin({ left: 4 })
            }
          }
          .padding({ right: 15 })
          .onClick(() => this.goToRefundList())
        }
        .width('100%')
        .backgroundColor('#fff')

        // 订单列表
        if (this.isLoading && this.orders.length === 0) {
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
        } else if (this.orders.length === 0) {
          // 空状态
          Column() {
            Text('📦')
              .fontSize(60)

            Text('暂无卖出订单')
              .fontSize(16)
              .fontColor('#999')
              .margin({ top: 15 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          // 订单列表（支持下拉刷新）
          Refresh({ refreshing: $$this.isRefreshing }) {
            List({ space: 10 }) {
              ForEach(this.orders, (order: Order) => {
                ListItem() {
                  this.OrderItem(order)
                }
              }, (order: Order) => order.id?.toString() || order.orderNo)
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

      // ========== 删除订单确认对话框 ==========
      if (this.showDeleteOrderDialog) {
        Column() {
          Column() {
            Text('删除订单')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 15 })

            Text('确定要删除此订单吗？删除后不可恢复。')
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
                  this.showDeleteOrderDialog = false;
                  this.selectedOrderId = 0;
                })

              Button('确定')
                .type(ButtonType.Normal)
                .backgroundColor('#FF4D4F')
                .fontColor('#fff')
                .width(100)
                .height(40)
                .borderRadius(20)
                .onClick(() => this.confirmDeleteOrder())
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
          this.showDeleteOrderDialog = false;
          this.selectedOrderId = 0;
        })
      }
    }
    .height('100%')
  }

  // 订单项组件
  @Builder
  OrderItem(order: Order) {
    Column() {
      // 订单头部：订单号 + 时间
      Row() {
        Text(`订单号: ${order.orderNo}`)
          .fontSize(12)
          .fontColor('#999')
          .layoutWeight(1)
        
        Text(this.formatTime(order.createTime))
          .fontSize(12)
          .fontColor('#999')
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 12, bottom: 8 })

      Divider().color('#f0f0f0')

      // 商品信息
      Row({ space: 12 }) {
        // 商品图片
        Image(order.productImage)
          .width(80)
          .height(80)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)

        // 商品详情
        Column({ space: 6 }) {
          Text(order.productTitle)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(`规格: ${order.specs}`)
            .fontSize(12)
            .fontColor('#666')

          Row() {
            Text(`¥${order.price.toFixed(2)}`)
              .fontSize(14)
              .fontColor('#FF4D4F')
              .fontWeight(FontWeight.Bold)

            Text(`x${order.quantity}`)
              .fontSize(12)
              .fontColor('#999')
              .margin({ left: 10 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(15)

      Divider().color('#f0f0f0')

      // 买家信息
      Row() {
        Text('买家:')
          .fontSize(13)
          .fontColor('#666')

        Text(this.getBuyerDisplayInfo(order))
          .fontSize(13)
          .fontColor(this.getBuyerDisplayInfo(order) === '未知' ? '#999' : '#333')
          .margin({ left: 8 })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 15, right: 15, top: 8, bottom: 8 })

      Divider().color('#f0f0f0')

      // 订单底部：状态 + 操作
      Row() {
        // 订单状态（卖家视角：待签收时显示"已发货"）
        Text(this.getSellerStatusText(order.status))
          .fontSize(14)
          .fontColor(this.getStatusColor(order.status || '待付款'))
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)

        // 实付款
        Text(`实付款: ¥${(order.price * order.quantity).toFixed(2)}`)
          .fontSize(13)
          .fontColor('#333')
          .margin({ right: 15 })

        // 操作按钮（只有"待发货"时才显示"去发货"按钮，"已退款"时不显示任何按钮）
        if (order.status === '待发货') {
          Button('去发货')
            .fontSize(13)
            .height(32)
            .backgroundColor('#FF4D4F')
            .borderRadius(16)
            .onClick(() => this.goToDelivery(order))
        }
        
        // 删除订单按钮（只有"交易成功"或"已退款"才显示删除按钮）
        if (order.status === '交易成功' || order.status === '已退款') {
          Button('删除订单')
            .type(ButtonType.Normal)
            .backgroundColor('#fff')
            .fontColor('#333')
            .border({ width: 1, color: '#ddd' })
            .height(26)
            .fontSize(12)
            .borderRadius(13)
            .margin({ left: 10 })
            .onClick(() => {
              if (order.id) {
                this.showDeleteOrderConfirmDialog(order.id);
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
