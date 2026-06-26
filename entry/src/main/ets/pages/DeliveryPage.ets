import { router, promptAction } from '@kit.ArkUI';
import { dbManager, Address, User } from '../db/DatabaseManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

// 路由参数接口
interface RouterParams {
  orderId: number;
  orderNo: string;
  productTitle: string;
  productImage: string;
  price: number;
  quantity: number;
  specs: string;
  buyerAddress: string;
}

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

// 发货方式枚举
enum ShippingMethod {
  TAO_ER = '淘二快递',
  SELF = '自行发货'
}

@Entry
@Component
struct DeliveryPage {
  @State orderId: number = 0;
  @State orderNo: string = '';
  @State productTitle: string = '';
  @State productImage: string = '';
  @State price: number = 0;
  @State quantity: number = 1;
  @State specs: string = '';
  @State buyerAddressJson: string = '';
  @State buyerAddress: BuyerAddress | null = null;
  
  @State selectedShippingAddress: Address | null = null; // 选中的发货地址
  @State shippingMethod: ShippingMethod = ShippingMethod.TAO_ER; // 发货方式
  @State trackingNumber: string = ''; // 快递单号
  @State isSubmitting: boolean = false;
  
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;

  async aboutToAppear() {
    // 获取路由参数
    const params = router.getParams() as RouterParams;
    if (params) {
      this.orderId = params.orderId || 0;
      this.orderNo = params.orderNo || '';
      this.productTitle = params.productTitle || '';
      this.productImage = params.productImage || '';
      this.price = params.price || 0;
      this.quantity = params.quantity || 1;
      this.specs = params.specs || '';
      this.buyerAddressJson = params.buyerAddress || '';
      
      // 解析买家地址
      if (this.buyerAddressJson) {
        try {
          this.buyerAddress = JSON.parse(this.buyerAddressJson) as BuyerAddress;
          hilog.info(DOMAIN, 'Delivery', 'Parsed buyer address: %{public}s', this.buyerAddress?.consignee || '');
        } catch (error) {
          hilog.error(DOMAIN, 'Delivery', 'Failed to parse buyer address: %{public}s', JSON.stringify(error));
        }
      }
      
      hilog.info(DOMAIN, 'Delivery', 'Loaded order: %{public}s', this.orderNo);
    }

    // 加载默认发货地址
    await this.loadDefaultShippingAddress();
  }

  // 页面显示时刷新地址（从地址列表页返回时触发）
  async onPageShow() {
    // 从 AppStorage 中读取选中的地址ID
    const selectedAddressId = AppStorage.get<number>('selectedAddressId');
    if (selectedAddressId) {
      const address = await dbManager.getAddressById(selectedAddressId);
      if (address) {
        this.selectedShippingAddress = address;
        hilog.info(DOMAIN, 'Delivery', 'Selected shipping address: %{public}s', address.consignee);
      }
      // 清除 AppStorage 中的地址ID
      AppStorage.delete('selectedAddressId');
    } else if (!this.selectedShippingAddress) {
      // 如果没有选中地址，尝试加载默认地址
      await this.loadDefaultShippingAddress();
    }
  }

  // 加载默认发货地址
  async loadDefaultShippingAddress() {
    if (this.user && this.user.id) {
      const defaultAddress = await dbManager.getDefaultAddress(this.user.id);
      if (defaultAddress) {
        this.selectedShippingAddress = defaultAddress;
        hilog.info(DOMAIN, 'Delivery', 'Loaded default shipping address: %{public}s', defaultAddress.consignee);
      }
    }
  }

  // 跳转到地址列表页选择发货地址
  goToSelectShippingAddress() {
    router.pushUrl({
      url: 'pages/AddressListPage',
      params: { selectMode: true } // 选择模式
    });
  }

  // 生成虚拟快递单号
  generateTrackingNumber(): string {
    const timestamp = Date.now();
    const random = Math.floor(Math.random() * 1000000).toString().padStart(6, '0');
    return `TAO${timestamp}${random}`;
  }

  // 提交发货
  async submitDelivery() {
    if (this.isSubmitting) return;

    // 校验：必须已选择发货地址
    if (!this.selectedShippingAddress) {
      promptAction.showToast({ message: '请选择发货地址' });
      return;
    }

    // 校验：如果选择"自己发货"且单号为空
    if (this.shippingMethod === ShippingMethod.SELF && !this.trackingNumber.trim()) {
      promptAction.showToast({ message: '请填写快递单号' });
      return;
    }

    this.isSubmitting = true;

    try {
      // 将发货地址转为JSON字符串
      const shippingAddressJson = JSON.stringify({
        consignee: this.selectedShippingAddress.consignee,
        phone: this.selectedShippingAddress.phone,
        province: this.selectedShippingAddress.province,
        city: this.selectedShippingAddress.city,
        district: this.selectedShippingAddress.district,
        detailAddress: this.selectedShippingAddress.detailAddress,
        tag: this.selectedShippingAddress.tag
      });

      // 确定快递单号
      let finalTrackingNumber = this.trackingNumber.trim();
      if (this.shippingMethod === ShippingMethod.TAO_ER) {
        // 淘二快递自动生成单号
        finalTrackingNumber = this.generateTrackingNumber();
      }

      // 更新订单发货信息
      const success = await dbManager.updateOrderShipping(
        this.orderId,
        this.shippingMethod,
        finalTrackingNumber,
        shippingAddressJson
      );

      if (success) {
        hilog.info(DOMAIN, 'Delivery', 'Delivery submitted: orderId=%{public}d, method=%{public}s, tracking=%{public}s', 
          this.orderId, this.shippingMethod, finalTrackingNumber);
        promptAction.showToast({ message: '发货成功' });
        
        // 使用 router.back() 返回上一页，列表页通过 onPageShow 自动刷新
        router.back();
      } else {
        promptAction.showToast({ message: '发货失败，请重试' });
      }
    } catch (error) {
      hilog.error(DOMAIN, 'Delivery', 'Failed to submit delivery: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '发货失败，请重试' });
    } finally {
      this.isSubmitting = false;
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
        
        Text('发货')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        Text('')
          .width(54)
      }
      .width('100%')
      .backgroundColor('#fff')

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

                Text(`规格: ${this.specs}`)
                  .fontSize(12)
                  .fontColor('#666')

                Row() {
                  Text(`¥${this.price.toFixed(2)}`)
                    .fontSize(14)
                    .fontColor('#FF4D4F')
                    .fontWeight(FontWeight.Bold)

                  Text(`x${this.quantity}`)
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
          }
          .width('100%')
          .backgroundColor('#fff')
          .borderRadius(8)
          .margin({ top: 10 })

          // 选择发货地址
          Column() {
            Row() {
              Text('发货地址')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)

              Text('>')
                .fontSize(20)
                .fontColor('#999')
            }
            .width('100%')
            .padding({ left: 15, right: 15, top: 15, bottom: 10 })

            if (this.selectedShippingAddress) {
              Column({ space: 8 }) {
                Row({ space: 10 }) {
                  Text(this.selectedShippingAddress.consignee)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)

                  Text(this.selectedShippingAddress.phone)
                    .fontSize(14)
                    .fontColor('#666')

                  if (this.selectedShippingAddress.isDefault === 1) {
                    Text('默认')
                      .fontSize(12)
                      .fontColor('#fff')
                      .backgroundColor('#FF6B35')
                      .borderRadius(4)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  }

                  if (this.selectedShippingAddress.tag && this.selectedShippingAddress.tag.length > 0) {
                    Text(this.selectedShippingAddress.tag)
                      .fontSize(12)
                      .fontColor('#3366FF')
                      .backgroundColor('#E8F0FF')
                      .borderRadius(4)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  }
                }

                Text(`${this.selectedShippingAddress.province}${this.selectedShippingAddress.city}${this.selectedShippingAddress.district}${this.selectedShippingAddress.detailAddress}`)
                  .fontSize(14)
                  .fontColor('#333')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: 15, right: 15, bottom: 15 })
            } else {
              Row() {
                Text('请选择发货地址')
                  .fontSize(15)
                  .fontColor('#999')
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 15, right: 15, bottom: 15 })
            }
          }
          .width('100%')
          .backgroundColor('#fff')
          .borderRadius(8)
          .margin({ top: 10 })
          .onClick(() => this.goToSelectShippingAddress())

          // 买家收货地址（只读）
          Column() {
            Row() {
              Text('买家收货地址')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 15, right: 15, top: 15, bottom: 10 })

            if (this.buyerAddress) {
              Column({ space: 8 }) {
                Row({ space: 10 }) {
                  Text(this.buyerAddress.consignee)
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)

                  Text(this.buyerAddress.phone)
                    .fontSize(14)
                    .fontColor('#666')

                  if (this.buyerAddress.tag && this.buyerAddress.tag.length > 0) {
                    Text(this.buyerAddress.tag)
                      .fontSize(12)
                      .fontColor('#3366FF')
                      .backgroundColor('#E8F0FF')
                      .borderRadius(4)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  }
                }

                Text(`${this.buyerAddress.province}${this.buyerAddress.city}${this.buyerAddress.district}${this.buyerAddress.detailAddress}`)
                  .fontSize(14)
                  .fontColor('#333')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding({ left: 15, right: 15, bottom: 15 })
            } else {
              Row() {
                Text('暂无买家地址信息')
                  .fontSize(15)
                  .fontColor('#999')
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 15, right: 15, bottom: 15 })
            }
          }
          .width('100%')
          .backgroundColor('#fff')
          .borderRadius(8)
          .margin({ top: 10 })

          // 发货方式选择
          Column() {
            Row() {
              Text('发货方式')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 15, right: 15, top: 15, bottom: 10 })

            Column({ space: 0 }) {
              // 淘二快递
              Row() {
                Text('使用淘二专属快递')
                  .fontSize(15)
                  .layoutWeight(1)

                if (this.shippingMethod === ShippingMethod.TAO_ER) {
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
              .backgroundColor(this.shippingMethod === ShippingMethod.TAO_ER ? '#FFF5F5' : '#fff')
              .onClick(() => {
                this.shippingMethod = ShippingMethod.TAO_ER;
                hilog.info(DOMAIN, 'Delivery', 'Selected shipping method: %{public}s', ShippingMethod.TAO_ER);
              })

              Divider().color('#f0f0f0')

              // 自己发货
              Row() {
                Text('自己发货')
                  .fontSize(15)
                  .layoutWeight(1)

                if (this.shippingMethod === ShippingMethod.SELF) {
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
              .backgroundColor(this.shippingMethod === ShippingMethod.SELF ? '#FFF5F5' : '#fff')
              .onClick(() => {
                this.shippingMethod = ShippingMethod.SELF;
                hilog.info(DOMAIN, 'Delivery', 'Selected shipping method: %{public}s', ShippingMethod.SELF);
              })
            }
            .width('100%')

            // 快递单号输入（仅自己发货时显示）
            if (this.shippingMethod === ShippingMethod.SELF) {
              Column() {
                Text('快递单号')
                  .fontSize(14)
                  .fontColor('#666')
                  .width('100%')
                  .margin({ bottom: 8 })

                TextInput({ placeholder: '请输入快递单号', text: $$this.trackingNumber })
                  .width('100%')
                  .height(44)
                  .backgroundColor('#f5f5f5')
                  .borderRadius(8)
                  .type(InputType.Normal)
              }
              .width('100%')
              .padding({ left: 15, right: 15, top: 15, bottom: 15 })
              .backgroundColor('#fff')
            }
          }
          .width('100%')
          .backgroundColor('#fff')
          .borderRadius(8)
          .margin({ top: 10, bottom: 100 })
        }
        .width('100%')
        .padding({ left: 10, right: 10 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 底部提交按钮
      Column() {
        Button(this.isSubmitting ? '提交中...' : '确认发货')
          .width('90%')
          .height(48)
          .backgroundColor(this.isSubmitting ? '#ccc' : '#FF4D4F')
          .borderRadius(24)
          .enabled(!this.isSubmitting)
          .onClick(() => this.submitDelivery())
      }
      .width('100%')
      .padding({ top: 15, bottom: 15 })
      .backgroundColor('#fff')
    }
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}
