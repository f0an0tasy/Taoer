import { router, promptAction } from '@kit.ArkUI';
import { dbManager, Order, User, Address, Product } from '../db/DatabaseManager';
import { CartItem, ShoppingCartPreferences } from '../utils/ShoppingCartPreferences';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

interface RouterParams {
  cartItems: string;
  totalPrice: number;
  fromBuyNow?: boolean; // 是否从"立即购买"进入
}

// 支付方式枚举
enum PaymentMethod {
  ALIPAY = '支付宝',
  WECHAT = '微信支付',
  BANK_CARD = '银行卡'
}

@Entry
@Component
struct OrderConfirmPage {
  @State cartItems: CartItem[] = [];
  @State totalPrice: number = 0;
  @State isSubmitting: boolean = false;
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  @State selectedAddress: Address | null = null; // 当前选中的收货地址
  @State paymentMethod: PaymentMethod = PaymentMethod.ALIPAY; // 默认选中支付宝
  @State fromBuyNow: boolean = false; // 是否从"立即购买"进入
  @State productCache: Map<number, Product> = new Map(); // 商品信息缓存

  async aboutToAppear() {
    // 验证用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }

    // 获取路由传递的参数
    const params = router.getParams() as RouterParams;
    if (params && params.cartItems) {
      this.cartItems = JSON.parse(params.cartItems) as CartItem[];
      this.totalPrice = params.totalPrice || 0;
      this.fromBuyNow = params.fromBuyNow || false;
      hilog.info(DOMAIN, 'OrderConfirm', 'Loaded %{public}d items, total: %{public}f, fromBuyNow: %{public}s', 
        this.cartItems.length, this.totalPrice, this.fromBuyNow.toString());
    }

    // 加载默认收货地址
    await this.loadDefaultAddress();
  }

  // 页面显示时刷新地址（从地址列表页返回时触发）
  async onPageShow() {
    // 从 AppStorage 中读取选中的地址ID
    const selectedAddressId = AppStorage.get<number>('selectedAddressId');
    if (selectedAddressId) {
      const address = await dbManager.getAddressById(selectedAddressId);
      if (address) {
        this.selectedAddress = address;
        hilog.info(DOMAIN, 'OrderConfirm', 'Selected address: %{public}s', address.consignee);
      }
      // 清除 AppStorage 中的地址ID
      AppStorage.delete('selectedAddressId');
    } else if (!this.selectedAddress) {
      // 如果没有选中地址，尝试加载默认地址
      await this.loadDefaultAddress();
    }
  }

  // 加载默认收货地址
  async loadDefaultAddress() {
    if (this.user && this.user.id) {
      const defaultAddress = await dbManager.getDefaultAddress(this.user.id);
      if (defaultAddress) {
        this.selectedAddress = defaultAddress;
        hilog.info(DOMAIN, 'OrderConfirm', 'Loaded default address: %{public}s', defaultAddress.consignee);
      } else {
        hilog.info(DOMAIN, 'OrderConfirm', 'No default address found');
      }
    }
  }

  // 跳转到地址列表页选择地址
  goToSelectAddress() {
    router.pushUrl({
      url: 'pages/AddressListPage',
      params: { selectMode: true } // 选择模式
    });
  }

  /**
   * 生成订单号
   */
  private generateOrderNo(): string {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
    return `ORD${timestamp}${random}`;
  }

  /**
   * 提交订单（立即支付）
   */
  private async submitOrder() {
    if (this.isSubmitting) return;
    
    // 检查是否已选择收货地址
    if (!this.selectedAddress) {
      promptAction.showToast({ message: '请先选择收货地址' });
      // 跳转到地址列表页
      this.goToSelectAddress();
      return;
    }

    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }

    this.isSubmitting = true;
    
    try {
      // 将买家地址信息转为JSON字符串（作为buyerAddress快照）
      const buyerAddressJson = JSON.stringify({
        consignee: this.selectedAddress.consignee,
        phone: this.selectedAddress.phone,
        province: this.selectedAddress.province,
        city: this.selectedAddress.city,
        district: this.selectedAddress.district,
        detailAddress: this.selectedAddress.detailAddress,
        tag: this.selectedAddress.tag
      });

      // 为每个购物车商品创建订单
      const createTime = Date.now();
      for (const item of this.cartItems) {
        // 获取商品信息以获取 sellerId（publisherId）
        let sellerId = 0;
        try {
          const product = await this.getProductById(item.productId);
          if (product) {
            sellerId = product.publisherId;
            hilog.info(DOMAIN, 'OrderConfirm', 'Got sellerId=%{public}d for productId=%{public}d', sellerId, item.productId);
          }
        } catch (error) {
          hilog.error(DOMAIN, 'OrderConfirm', 'Failed to get product info: %{public}s', JSON.stringify(error));
        }

        const order: Order = {
          orderNo: this.generateOrderNo(),
          productId: item.productId,
          productTitle: item.title,
          productImage: item.image,
          price: item.price,
          quantity: item.quantity,
          specs: item.specs,
          createTime: createTime,
          userId: this.user.id!,
          address: buyerAddressJson, // 兼容旧字段
          status: '待发货', // 订单状态设为待发货（跳过支付流程）
          sellerId: sellerId, // 卖家ID
          buyerAddress: buyerAddressJson // 买家收货地址快照
        };
        
        await dbManager.createOrder(order, this.user.id!);
        hilog.info(DOMAIN, 'OrderConfirm', 'Created order: %{public}s, sellerId=%{public}d, payment: %{public}s', 
          order.orderNo, sellerId, this.paymentMethod);
      }

      // 如果不是从"立即购买"进入，则清空购物车
      if (!this.fromBuyNow) {
        await ShoppingCartPreferences.clearCart(getContext(this) as common.UIAbilityContext, this.user.id!.toString());
        hilog.info(DOMAIN, 'OrderConfirm', 'Cleared shopping cart');
      }
      
      promptAction.showToast({ message: '订单创建成功' });
      
      // 跳转到订单列表页
      router.replaceUrl({ url: 'pages/OrderListPage' });
    } catch (error) {
      hilog.error(DOMAIN, 'OrderConfirm', 'Failed to create order: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '订单创建失败，请重试' });
    } finally {
      this.isSubmitting = false;
    }
  }

  // 根据商品ID获取商品信息
  private async getProductById(productId: number): Promise<Product | null> {
    // 先从缓存中查找
    if (this.productCache.has(productId)) {
      return this.productCache.get(productId) || null;
    }
    
    // 从数据库查询
    try {
      const allProducts = await dbManager.getAllProducts();
      const product = allProducts.find(p => p.id === productId);
      if (product) {
        this.productCache.set(productId, product);
      }
      return product || null;
    } catch (error) {
      hilog.error(DOMAIN, 'OrderConfirm', 'Failed to get product by id: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('<')
          .fontSize(24)
          .padding(15)
          .onClick(() => router.back())
        
        Text('确认订单')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .backgroundColor('#fff')

      Scroll() {
        Column() {
          // 收货地址区域
          Column() {
            if (this.selectedAddress) {
              // 已选择地址
              Row() {
                Column({ space: 8 }) {
                  // 收货人信息行
                  Row({ space: 10 }) {
                    Text(this.selectedAddress.consignee)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                    
                    Text(this.selectedAddress.phone)
                      .fontSize(14)
                      .fontColor('#666')
                    
                    // 默认标签
                    if (this.selectedAddress.isDefault === 1) {
                      Text('默认')
                        .fontSize(12)
                        .fontColor('#fff')
                        .backgroundColor('#FF6B35')
                        .borderRadius(4)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    }
                    
                    // 地址标签（家、公司等）
                    if (this.selectedAddress.tag && this.selectedAddress.tag.length > 0) {
                      Text(this.selectedAddress.tag)
                        .fontSize(12)
                        .fontColor('#3366FF')
                        .backgroundColor('#E8F0FF')
                        .borderRadius(4)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    }
                  }
                  
                  // 详细地址
                  Text(`${this.selectedAddress.province}${this.selectedAddress.city}${this.selectedAddress.district}${this.selectedAddress.detailAddress}`)
                    .fontSize(14)
                    .fontColor('#333')
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                
                // 右箭头
                Text('>')
                  .fontSize(20)
                  .fontColor('#999')
              }
              .width('100%')
              .padding(15)
              .onClick(() => this.goToSelectAddress())
            } else {
              // 未选择地址
              Row() {
                Text('请选择收货地址')
                  .fontSize(16)
                  .fontColor('#999')
                  .layoutWeight(1)
                
                Text('>')
                  .fontSize(20)
                  .fontColor('#999')
              }
              .width('100%')
              .padding(15)
              .onClick(() => this.goToSelectAddress())
            }
          }
          .width('100%')
          .backgroundColor('#fff')
          .margin({ top: 10 })
          .borderRadius(8)

          // 订单商品列表
          Column() {
            Text('订单商品')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .padding({ left: 15, top: 15, bottom: 10 })

            Column({ space: 10 }) {
              ForEach(this.cartItems, (item: CartItem, index: number) => {
                Row({ space: 12 }) {
                  // 商品图片
                  Image(item.image)
                    .width(80)
                    .height(80)
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)

                  // 商品信息
                  Column({ space: 8 }) {
                    Text(item.title)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .maxLines(2)

                    Text(`规格: ${item.specs}`)
                      .fontSize(12)
                      .fontColor('#666')

                    Row() {
                      Text(`¥${item.price.toFixed(2)}`)
                        .fontSize(14)
                        .fontColor('#FF4D4F')
                        .fontWeight(FontWeight.Bold)

                      Text(`x${item.quantity}`)
                        .fontSize(12)
                        .fontColor('#999')
                        .margin({ left: 10 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#fff')
                .borderRadius(8)
              }, (item: CartItem, index: number) => `${item.productId}_${index}`)
            }
            .width('100%')
            .padding({ left: 15, right: 15 })
          }
          .width('100%')
          .backgroundColor('#f5f5f5')
          .margin({ top: 10 })

          // 支付方式选择
          Column() {
            Text('支付方式')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')
              .padding({ left: 15, top: 15, bottom: 10 })

            Column({ space: 0 }) {
              // 支付宝
              this.PaymentMethodItem(
                '支付宝',
                'https://img.alicdn.com/imgextra/i1/O1CN01fZPfQz1cT0GHGvJ1F_!!6000000003614-2-tps-80-80.png',
                PaymentMethod.ALIPAY
              )

              // 微信支付
              this.PaymentMethodItem(
                '微信支付',
                'https://img.alicdn.com/imgextra/i3/O1CN01uHvQKm1sZgZ3pZJvK_!!6000000005786-2-tps-80-80.png',
                PaymentMethod.WECHAT
              )

              // 银行卡
              this.PaymentMethodItem(
                '银行卡',
                'https://img.alicdn.com/imgextra/i4/O1CN01vZQfXz1cT0GIGvJ1F_!!6000000003614-2-tps-80-80.png',
                PaymentMethod.BANK_CARD
              )
            }
            .width('100%')
          }
          .width('100%')
          .backgroundColor('#fff')
          .margin({ top: 10, bottom: 100 })
          .borderRadius(8)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 底部结算栏
      Column() {
        Row() {
          Column() {
            Text('合计金额')
              .fontSize(14)
              .fontColor('#666')

            Text(`¥${this.totalPrice.toFixed(2)}`)
              .fontSize(24)
              .fontColor('#FF4D4F')
              .fontWeight(FontWeight.Bold)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button(this.isSubmitting ? '提交中...' : '立即支付')
            .width(140)
            .height(44)
            .backgroundColor(this.isSubmitting ? '#ccc' : '#FF4D4F')
            .borderRadius(22)
            .enabled(!this.isSubmitting)
            .onClick(() => this.submitOrder())
        }
        .width('100%')
        .padding(15)
        .backgroundColor('#fff')
      }
    }
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  // 支付方式选项组件
  @Builder
  PaymentMethodItem(name: string, icon: string, method: PaymentMethod) {
    Row() {
      Image(icon)
        .width(32)
        .height(32)
        .borderRadius(4)
      
      Text(name)
        .fontSize(15)
        .margin({ left: 12 })
        .layoutWeight(1)
      
      // 单选指示器
      if (this.paymentMethod === method) {
        Text('✓')
          .fontSize(18)
          .fontColor('#FF4D4F')
          .fontWeight(FontWeight.Bold)
      } else {
        Text('○')
          .fontSize(18)
          .fontColor('#ccc')
      }
    }
    .width('100%')
    .padding({ left: 15, right: 15, top: 12, bottom: 12 })
    .backgroundColor(this.paymentMethod === method ? '#FFF5F5' : '#fff')
    .onClick(() => {
      this.paymentMethod = method;
      hilog.info(DOMAIN, 'OrderConfirm', 'Selected payment method: %{public}s', method);
    })
  }
}
