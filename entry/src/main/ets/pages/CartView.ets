import { router } from '@kit.ArkUI';
import { dbManager, Product, User } from '../db/DatabaseManager';
import { ShoppingCartPreferences, CartItem } from '../utils/ShoppingCartPreferences';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@Entry
@Component
export struct CartView {
  @State cartItems: CartItem[] = [];
  @State totalPrice: number = 0;
  @State totalQuantity: number = 0;
  @State isLoading: boolean = true;
  
  // 从存储链接获取当前用户
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  
  // 监听购物车更新时间戳，当购物车数据变化时自动重新加载
  @StorageLink('cartUpdateTimestamp') @Watch('onCartUpdate') cartUpdateTimestamp: number = 0;
  
  /**
   * 购物车更新回调函数
   * 当 cartUpdateTimestamp 变化时自动调用，重新加载购物车数据
   */
  private onCartUpdate() {
    hilog.info(DOMAIN, 'CartPersist', 'CartView detected cart update, timestamp: %{public}d', this.cartUpdateTimestamp);
    this.loadCartData();
  }
  
  aboutToAppear() {
    hilog.info(DOMAIN, 'CartPersist', 'CartView aboutToAppear, user: %{public}s', this.user.username);
    this.loadCartData();
  }
  
  /**
   * 加载购物车数据
   */
  private async loadCartData() {
    this.isLoading = true;
    try {
      if (this.user && this.user.id) {
        const items = await ShoppingCartPreferences.loadCart(getContext(this) as common.UIAbilityContext, this.user.id!.toString());
        this.cartItems = items;
        this.calculateTotals();
        hilog.info(DOMAIN, 'CartPersist', 'CartView loaded %{public}d items for user %{public}s', items.length, this.user.id!.toString());
      } else {
        this.cartItems = [];
        this.calculateTotals();
        hilog.info(DOMAIN, 'CartPersist', 'CartView: No user logged in, cart is empty');
      }
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'CartView failed to load cart data: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '加载购物车失败' });
    } finally {
      this.isLoading = false;
    }
  }
  
  /**
   * 计算总价和总数量
   */
  private calculateTotals() {
    this.totalQuantity = this.cartItems.reduce((total, item) => total + item.quantity, 0);
    this.totalPrice = this.cartItems.reduce((total, item) => total + (item.price * item.quantity), 0);
  }
  
  /**
   * 增加商品数量
   */
  private async increaseQuantity(item: CartItem) {
    await ShoppingCartPreferences.updateQuantity(
      getContext(this) as common.UIAbilityContext,
      this.user.id!.toString(),
      item.productId,
      item.specs,
      item.quantity + 1
    );
    this.loadCartData();
  }
  
  /**
   * 减少商品数量
   */
  private async decreaseQuantity(item: CartItem) {
    await ShoppingCartPreferences.updateQuantity(
      getContext(this) as common.UIAbilityContext,
      this.user.id!.toString(),
      item.productId,
      item.specs,
      item.quantity - 1
    );
    this.loadCartData();
  }
  
  /**
   * 从购物车移除商品
   */
  private async removeFromCart(item: CartItem) {
    try {
      await ShoppingCartPreferences.removeFromCart(
        getContext(this) as common.UIAbilityContext,
        this.user.id!.toString(),
        item.productId,
        item.specs
      );
      this.loadCartData();
      promptAction.showToast({ message: '商品已移除' });
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'CartView failed to remove item: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '移除商品失败' });
    }
  }
  
  /**
   * 清空购物车
   */
  private async clearCart() {
    try {
      await ShoppingCartPreferences.clearCart(
        getContext(this) as common.UIAbilityContext,
        this.user.id!.toString()
      );
      this.loadCartData();
      promptAction.showToast({ message: '购物车已清空' });
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'CartView failed to clear cart: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '清空购物车失败' });
    }
  }
  
  /**
   * 去结算
   */
  private goToCheckout() {
    // 检查购物车是否为空
    if (this.cartItems.length === 0) {
      promptAction.showToast({ message: '购物车为空，请先添加商品' });
      return;
    }

    // 检查用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }

    try {
      // 将购物车商品列表和总金额作为参数传递
      const params: Record<string, Object> = {
        'cartItems': JSON.stringify(this.cartItems),
        'totalPrice': this.totalPrice,
        'totalQuantity': this.totalQuantity
      };

      hilog.info(DOMAIN, 'CartPersist', 'Navigating to OrderConfirmPage with %{public}d items, total: %{public}f', 
        this.cartItems.length, this.totalPrice);

      // 跳转到订单确认页面
      router.pushUrl({
        url: 'pages/OrderConfirmPage',
        params: params
      });
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Failed to navigate to checkout: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '跳转失败，请重试' });
    }
  }
  
  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        // 顶部栏
        Row() {
          Text('购物车').fontSize(18).fontWeight(FontWeight.Bold)
        }
        .width('100%')
        .padding({ left: 15, right: 15, top: 15, bottom: 15 })
        .backgroundColor('#fff')
        
        // 购物车内容
        if (this.isLoading) {
          Column() {
            Text('加载中...').fontSize(16).padding(20)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.cartItems.length === 0) {
          Column() {
            Text('购物车为空').fontSize(16).padding(20)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else {
          Column() {
            // 购物车商品列表
            List() {
              ForEach(this.cartItems, (item: CartItem) => {
                ListItem() {
                  Row() {
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
                        .width('60%')
                      
                      Text(`规格: ${item.specs}`)
                        .fontSize(12)
                        .fontColor('#666')
                      
                      Text(`¥${item.price.toFixed(2)}`)
                        .fontSize(14)
                        .fontColor('#FF4D4F')
                        .fontWeight(FontWeight.Bold)
                    }
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: 12 })
                    
                    // 数量控制
                    Row() {
                      Text('-')
                        .fontSize(20)
                        .width(24)
                        .height(24)
                        .backgroundColor('#f0f0f0')
                        .borderRadius(12)
                        .textAlign(TextAlign.Center)
                        .onClick(() => this.decreaseQuantity(item))
                      
                      Text(`${item.quantity}`)
                        .fontSize(14)
                        .width(40)
                        .textAlign(TextAlign.Center)
                      
                      Text('+')
                        .fontSize(20)
                        .width(24)
                        .height(24)
                        .backgroundColor('#f0f0f0')
                        .borderRadius(12)
                        .textAlign(TextAlign.Center)
                        .onClick(() => this.increaseQuantity(item))
                    }
                    .alignItems(VerticalAlign.Center)
                    
                    // 删除按钮 - 使用文本图标
                    Text('×')
                      .fontSize(20)
                      .fontColor('#FF4D4F')
                      .width(24)
                      .height(24)
                      .textAlign(TextAlign.Center)
                      .onClick(() => this.removeFromCart(item))
                  }
                  .width('100%')
                  .padding(12)
                  .border({ width: 1, color: '#eee' })
                }
              }, (item: CartItem) => `${item.productId}_${item.specs}`)
            }
            .width('100%')
            .layoutWeight(1)
            
            // 购物车底部栏
            Row() {
              Column() {
                Text('总计:')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                
                Text(`¥${this.totalPrice.toFixed(2)}`)
                  .fontSize(20)
                  .fontColor('#FF4D4F')
                  .fontWeight(FontWeight.Bold)
              }
              .alignItems(HorizontalAlign.Start)
              
              Button('去结算')
                .width(120)
                .height(40)
                .backgroundColor('#3366FF')
                .borderRadius(20)
                .onClick(() => this.goToCheckout())
            }
            .width('100%')
            .padding(15)
            .backgroundColor('#fff')
            .border({ width: { top: 1 }, color: '#eee' })
          }
          .width('100%')
          .layoutWeight(1)
        }
      }
      .height('100%')
      .backgroundColor('#f5f5f5')

      // 左下角 AI 建议按钮
      Image($r('app.media.aiadvice'))
        .width(56)
        .height(56)
        .objectFit(ImageFit.Contain)
        .align(Alignment.BottomStart)
        .margin({ left: 20, bottom: 80 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/Home' });
        })
    }
    .height('100%')
  }
}
