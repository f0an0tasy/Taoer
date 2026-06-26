import { router } from '@kit.ArkUI';
import { dbManager, Order, Product, User, Comment } from '../db/DatabaseManager'; // 添加 Comment 导入
import { ShoppingCartPreferences, CartItem } from '../utils/ShoppingCartPreferences';
import { promptAction } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@Entry
@Component
struct ProductDetail {
  @State product: Product = {} as Product;
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  @State isFavorited: boolean = false; // 收藏状态
  @State commentList: Comment[] = []; // 评论列表
  @State isLoadingComments: boolean = false; // 评论加载状态
  
  async aboutToAppear() {
    const params = router.getParams() as Record<string, Product>;
    if (params && params.product) {
      this.product = params.product;
    }
    
    // 查询当前商品是否已被收藏
    if (this.user && this.user.id && this.product.id) {
      try {
        this.isFavorited = await dbManager.isFavorite(this.user.id, this.product.id);
        hilog.info(DOMAIN, 'ProductDetail', 'Favorite status: %{public}s', this.isFavorited.toString());
      } catch (error) {
        hilog.error(DOMAIN, 'ProductDetail', 'Failed to check favorite status: %{public}s', JSON.stringify(error));
      }
    }

    // 加载评论列表
    await this.loadComments();
  }

  // 加载评论列表
  async loadComments() {
    if (!this.product.id) return;
    
    this.isLoadingComments = true;
    try {
      this.commentList = await dbManager.getCommentsByProductId(this.product.id);
      hilog.info(DOMAIN, 'ProductDetail', 'Loaded %{public}d comments', this.commentList.length);
    } catch (error) {
      hilog.error(DOMAIN, 'ProductDetail', 'Failed to load comments: %{public}s', JSON.stringify(error));
      this.commentList = [];
    } finally {
      this.isLoadingComments = false;
    }
  }

  // 格式化时间戳为日期字符串
  formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
  
  // 获取评论用户头像路径
  getCommentAvatar(userAvatar?: string, userName?: string): string | Resource {
    // 如果是匿名用户，直接返回默认头像
    if (userName === '匿名用户') {
      return $r('app.media.avatar_default');
    }
    
    // 如果头像路径存在且不为空
    if (userAvatar && userAvatar.trim() !== '') {
      // 如果是 file:// 开头的 URI（媒体库URI或已加前缀的沙箱路径），直接使用
      if (userAvatar.startsWith('file://')) {
        return userAvatar;
      }
      // 如果是 http:// 或 https:// 开头的网络URL，直接使用
      if (userAvatar.startsWith('http://') || userAvatar.startsWith('https://')) {
        return userAvatar;
      }
      // 否则认为是沙箱绝对路径，添加 file:// 前缀
      return `file://${userAvatar}`;
    }
    // 否则返回默认头像
    return $r('app.media.avatar_default');
  }
  
  /**
   * 立即购买 - 跳转到订单确认页面
   */
  private handleBuy() {
    // 验证用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }

    try {
      // 将当前商品转换为购物车商品结构
      // 优先使用 images[0]，兼容旧的 image 字段
      const productImage = (this.product.images && this.product.images.length > 0) 
        ? this.product.images[0] 
        : (this.product.image || '');
      
      const cartItem: CartItem = {
        productId: this.product.id!,
        title: this.product.title,
        price: this.product.price,
        image: productImage,
        quantity: 1,
        specs: this.product.specs || '' // 如果规格为空，传空字符串
      };

      // 构造包含单个商品的数组
      const cartItems: CartItem[] = [cartItem];
      
      // 计算总价
      const totalPrice = cartItem.price * cartItem.quantity;
      const totalQuantity = cartItem.quantity;

      // 构造跳转参数
      const params: Record<string, Object> = {
        'cartItems': JSON.stringify(cartItems),
        'totalPrice': totalPrice,
        'totalQuantity': totalQuantity
      };

      hilog.info(DOMAIN, 'ProductDetail', 'Navigating to OrderConfirmPage with product %{public}d, price: %{public}f', 
        this.product.id!, totalPrice);

      // 跳转到订单确认页面
      router.pushUrl({
        url: 'pages/OrderConfirmPage',
        params: params
      });
    } catch (error) {
      hilog.error(DOMAIN, 'ProductDetail', 'Failed to navigate to checkout: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '跳转失败，请重试' });
    }
  }
  
  /**
   * 添加到购物车
   */
  private async addToCart() {
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }
    
    // 优先使用 images[0]，兼容旧的 image 字段
    const productImage = (this.product.images && this.product.images.length > 0) 
      ? this.product.images[0] 
      : (this.product.image || '');
    
    const cartItem: CartItem = {
      productId: this.product.id!,
      title: this.product.title,
      price: this.product.price,
      image: productImage,
      quantity: 1,
      specs: this.product.specs
    };
    
    try {
      await ShoppingCartPreferences.addToCart(
        getContext(this) as common.UIAbilityContext,
        this.user.id.toString(),
        cartItem
      );
      hilog.info(DOMAIN, 'CartPersist', 'ProductDetail: Added item %{public}d to cart', this.product.id!);
      promptAction.showToast({ message: '已添加到购物车' });
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'ProductDetail failed to add to cart: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '添加到购物车失败' });
    }
  }

  /**
   * 处理收藏/取消收藏
   */
  private async handleFavorite() {
    // 验证用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.pushUrl({ url: 'pages/LoginPage' });
      return;
    }

    if (!this.product.id) {
      promptAction.showToast({ message: '商品信息错误' });
      return;
    }

    try {
      if (this.isFavorited) {
        // 取消收藏
        const success = await dbManager.removeFavorite(this.user.id, this.product.id);
        if (success) {
          this.isFavorited = false;
          promptAction.showToast({ message: '已取消收藏' });
          hilog.info(DOMAIN, 'ProductDetail', 'Removed from favorites: productId=%{public}d', this.product.id);
        } else {
          promptAction.showToast({ message: '取消收藏失败' });
        }
      } else {
        // 添加收藏
        const success = await dbManager.addFavorite(this.user.id, this.product.id);
        if (success) {
          this.isFavorited = true;
          promptAction.showToast({ message: '已收藏' });
          hilog.info(DOMAIN, 'ProductDetail', 'Added to favorites: productId=%{public}d', this.product.id);
        } else {
          promptAction.showToast({ message: '收藏失败或已收藏' });
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, 'ProductDetail', 'Favorite operation failed: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '操作失败，请重试' });
    }
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('<').fontSize(24).onClick(() => router.back()).padding(15)
        Text('商品详情').fontSize(18).fontWeight(FontWeight.Bold)
      }.width('100%')

      Scroll() {
        Column({ space: 15 }) {
          // 多图展示区域 - 在商品描述上方显示所有图片
          if (this.product.images && this.product.images.length > 0) {
            // 有多张图片时，垂直排列显示
            Column({ space: 8 }) {
              ForEach(this.product.images, (imageUrl: string, index: number) => {
                Image(imageUrl)
                  .width('100%')
                  .height(300)
                  .objectFit(ImageFit.Contain)
                  .backgroundColor('#eee')
              })
            }
            .width('100%')
          } else if (this.product.image) {
            // 兼容旧数据：只有单张图片
            Image(this.product.image)
              .width('100%')
              .height(300)
              .objectFit(ImageFit.Contain)
              .backgroundColor('#eee')
          } else {
            // 无图片时显示默认占位图
            Column() {
              Image($r('app.media.icon'))
                .width(120)
                .height(120)
                .objectFit(ImageFit.Contain)
              Text('暂无图片')
                .fontSize(14)
                .fontColor('#999')
                .margin({ top: 8 })
            }
            .width('100%')
            .height(300)
            .backgroundColor('#eee')
            .justifyContent(FlexAlign.Center)
          }

          Column() {
            Text(`¥${this.product.price}`).fontSize(24).fontColor('#FF4D4F').fontWeight(FontWeight.Bold)
            Text(this.product.title).fontSize(20).fontWeight(FontWeight.Bold).margin({ top: 10 })

            Row() {
              Text(`规格: ${this.product.specs}`).fontSize(12).fontColor('#666').backgroundColor('#f0f0f0').padding(5).borderRadius(4)
              Text(`分类: ${this.product.category}`).fontSize(12).fontColor('#666').margin({ left: 10 })
            }.margin({ top: 10 })

            Text('商品描述').fontSize(16).fontWeight(FontWeight.Bold).margin({ top: 20, bottom: 10 })
            Text(this.product.content).fontSize(14).fontColor('#333').lineHeight(24)

            // ========== 新增：用户评价区域 ==========
            Column() {
              Text('用户评价')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .margin({ top: 20, bottom: 10 })

              if (this.isLoadingComments) {
                // 加载中
                Row() {
                  LoadingProgress()
                    .width(24)
                    .height(24)
                    .color('#999')
                  Text('加载中...')
                    .fontSize(14)
                    .fontColor('#999')
                    .margin({ left: 8 })
                }
                .width('100%')
                .justifyContent(FlexAlign.Center)
                .padding(20)
              } else if (this.commentList.length === 0) {
                // 暂无评价
                Column() {
                  Text('暂无评价，快来抢沙发~')
                    .fontSize(14)
                    .fontColor('#999')
                    .padding(20)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
              } else {
                // 评价列表
                ForEach(this.commentList, (comment: Comment) => {
                  Column() {
                    Row() {
                      // 用户头像（动态显示真实头像或默认头像，匿名用户显示默认头像）
                      Image(this.getCommentAvatar(comment.userAvatar, comment.userName))
                        .width(36)
                        .height(36)
                        .borderRadius(18)
                        .backgroundColor('#f0f0f0')
                      
                      Column() {
                        Text(comment.userName || '匿名用户')
                          .fontSize(14)
                          .fontWeight(FontWeight.Bold)
                        Text(this.formatTime(comment.createTime))
                          .fontSize(12)
                          .fontColor('#999')
                          .margin({ top: 2 })
                      }
                      .layoutWeight(1)
                      .alignItems(HorizontalAlign.Start)
                      .margin({ left: 10 })
                    }
                    .width('100%')

                    // 星级评分显示
                    Row({ space: 4 }) {
                      ForEach([1, 2, 3, 4, 5], (star: number) => {
                        SymbolGlyph(star <= (comment.rating || 5) ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
                          .fontSize(14)
                          .fontColor(star <= (comment.rating || 5) ? ['#FF9500'] : ['#ccc'])
                      })
                    }
                    .width('100%')
                    .justifyContent(FlexAlign.Start)
                    .margin({ top: 8 })

                    Text(comment.content)
                      .fontSize(14)
                      .fontColor('#333')
                      .lineHeight(22)
                      .margin({ top: 10 })
                      .textAlign(TextAlign.Start)
                      .width('100%')
                  }
                  .width('100%')
                  .padding({ top: 12, bottom: 12 })
                  .border({ width: { bottom: 1 }, color: '#f0f0f0' })
                })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            // ========== 用户评价区域结束 ==========
          }.padding(20).alignItems(HorizontalAlign.Start)
        }
      }.layoutWeight(1)

      // 底部栏 - 修复：使用响应式布局，删除留言功能
      Row() {
        // 收藏按钮
        Column() { 
          SymbolGlyph(this.isFavorited ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
            .fontSize(24)
            .fontColor(this.isFavorited ? ['#FF9500'] : ['#666'])
          Text(this.isFavorited ? '已收藏' : '收藏')
            .fontSize(12)
            .fontColor(this.isFavorited ? '#FF9500' : '#666')
            .margin({ top: 4 })
        }
        .width('15%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => this.handleFavorite())
        
        // 按钮区域
        Row({ space: 8 }) {
          Button('立即购买')
            .type(ButtonType.Normal)
            .backgroundColor('#3366FF')
            .width('42%')
            .height(40)
            .borderRadius(20)
            .onClick(() => this.handleBuy())
          
          Button('加入购物车')
            .type(ButtonType.Normal)
            .backgroundColor('#FF9500')
            .width('42%')
            .height(40)
            .borderRadius(20)
            .onClick(() => this.addToCart())
        }
        .width('80%')
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .height(60)
      .padding({ left: 12, right: 12 })
      .border({ width: { top: 1 }, color: '#eee' })
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .height('100%')
    .backgroundColor('#fff')
  }
}