import { router } from '@kit.ArkUI';
import { dbManager, Product, User, ProductWithFavoriteTime } from '../db/DatabaseManager';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

@Entry
@Component
struct FavoriteListPage {
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  @State favoriteList: ProductWithFavoriteTime[] = [];
  @State isLoading: boolean = false;
  @State isRefreshing: boolean = false;

  async aboutToAppear() {
    await this.loadFavorites();
  }

  /**
   * 加载收藏列表
   */
  private async loadFavorites() {
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.back();
      return;
    }

    this.isLoading = true;
    try {
      this.favoriteList = await dbManager.getFavoritesByUser(this.user.id);
      hilog.info(DOMAIN, 'FavoriteListPage', 'Loaded %{public}d favorites', this.favoriteList.length);
    } catch (error) {
      hilog.error(DOMAIN, 'FavoriteListPage', 'Failed to load favorites: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '加载收藏列表失败' });
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 下拉刷新
   */
  private async handleRefresh() {
    this.isRefreshing = true;
    await this.loadFavorites();
    this.isRefreshing = false;
  }

  /**
   * 删除收藏
   */
  private async handleDelete(productId: number, productTitle: string) {
    // 弹出确认对话框
    promptAction.showDialog({
      title: '确认删除',
      message: `确定要取消收藏"${productTitle}"吗？`,
      buttons: [
        { text: '取消', color: '#666666' },
        { text: '确定', color: '#FF4D4F' }
      ]
    }).then(async (result) => {
      if (result.index === 1) { // 点击了"确定"
        try {
          const success = await dbManager.removeFavorite(this.user.id!, productId);
          if (success) {
            // 从列表中移除该项
            this.favoriteList = this.favoriteList.filter(item => item.id !== productId);
            promptAction.showToast({ message: '已取消收藏' });
            hilog.info(DOMAIN, 'FavoriteListPage', 'Removed favorite: productId=%{public}d', productId);
          } else {
            promptAction.showToast({ message: '删除失败' });
          }
        } catch (error) {
          hilog.error(DOMAIN, 'FavoriteListPage', 'Failed to remove favorite: %{public}s', JSON.stringify(error));
          promptAction.showToast({ message: '删除失败，请重试' });
        }
      }
    }).catch((error: Error) => {
      hilog.error(DOMAIN, 'FavoriteListPage', 'Dialog error: %{public}s', JSON.stringify(error));
    });
  }

  /**
   * 跳转到商品详情页
   */
  private navigateToDetail(product: Product) {
    router.pushUrl({
      url: 'pages/ProductDetail',
      params: { product: product }
    });
  }

  /**
   * 格式化时间
   */
  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const year = date.getFullYear();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('<')
          .fontSize(24)
          .onClick(() => router.back())
          .padding(15)
        Text('我的收藏')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: -15 }) // 居中标题
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      // 内容区域
      if (this.isLoading) {
        // 加载中状态
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
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else if (this.favoriteList.length === 0) {
        // 空状态
        Column() {
          SymbolGlyph($r('sys.symbol.heart_slash'))
            .fontSize(60)
            .fontColor(['#ccc'])
          Text('暂无收藏商品')
            .fontSize(16)
            .fontColor('#999')
            .margin({ top: 20 })
          Text('去逛逛，收藏喜欢的商品吧~')
            .fontSize(14)
            .fontColor('#ccc')
            .margin({ top: 10 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .width('100%')
      } else {
        // 收藏列表
        Refresh({ refreshing: $$this.isRefreshing }) {
          List({ space: 10 }) {
            ForEach(this.favoriteList, (item: ProductWithFavoriteTime) => {
              ListItem() {
                Row() {
                  // 商品图片
                  Image(item.image)
                    .width(100)
                    .height(100)
                    .backgroundColor('#f0f0f0')
                    .borderRadius(8)
                    .objectFit(ImageFit.Cover)

                  // 商品信息
                  Column() {
                    Text(item.title)
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })

                    Text(`¥${item.price}`)
                      .fontSize(18)
                      .fontColor(Color.Red)
                      .fontWeight(FontWeight.Bold)
                      .margin({ top: 8 })

                    Row() {
                      Text(`规格: ${item.specs}`)
                        .fontSize(12)
                        .fontColor('#666')
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .layoutWeight(1)
                    }
                    .margin({ top: 4 })

                    Text(`收藏时间: ${this.formatTime(item.favoriteTime)}`)
                      .fontSize(12)
                      .fontColor('#999')
                      .margin({ top: 4 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  .padding({ left: 12, right: 8 })
                  .justifyContent(FlexAlign.SpaceBetween)

                  // 删除按钮
                  Column() {
                    SymbolGlyph($r('sys.symbol.trash'))
                      .fontSize(20)
                      .fontColor([Color.Red])
                  }
                  .width(40)
                  .height('100%')
                  .justifyContent(FlexAlign.Center)
                  .onClick(() => this.handleDelete(item.id!, item.title))
                }
                .width('100%')
                .height(120)
                .backgroundColor('#fff')
                .borderRadius(8)
                .padding(10)
                .onClick(() => this.navigateToDetail(item))
              }
              .swipeAction({ end: this.deleteButton(item) })
            }, (item: ProductWithFavoriteTime) => item.id!.toString())
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        }
        .onRefreshing(() => this.handleRefresh())
        .layoutWeight(1)
      }
    }
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  /**
   * 滑动删除按钮
   */
  @Builder deleteButton(item: ProductWithFavoriteTime) {
    Button({ type: ButtonType.Normal }) {
      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(20)
        .fontColor(['#fff'])
    }
    .width(60)
    .height('100%')
    .backgroundColor('#FF4D4F')
    .borderRadius(8)
    .onClick(() => this.handleDelete(item.id!, item.title))
  }
}
