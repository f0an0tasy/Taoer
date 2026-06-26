import { router } from '@kit.ArkUI';
import { dbManager, Product } from '../db/DatabaseManager';

@Component
export struct HomeView {
  @State searchKey: string = '';
  @State productList: Product[] = [];
  @State isRefreshing: boolean = false;

  async aboutToAppear() {
    this.refreshData();
  }

  async refreshData() {
    this.productList = await dbManager.getAllProducts(this.searchKey);
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Column() {
          // 搜索栏
          Row() {
            TextInput({ placeholder: '搜索好物...', text: this.searchKey })
              .width('85%')
              .height(40)
              .backgroundColor('#F5F5F5')
              .borderRadius(20)
              .padding({ left: 15 })
              .onChange((val) => {
                this.searchKey = val;
                this.refreshData(); // 实时搜索
              })
          }.padding({ left: 15, right: 15, top: 10, bottom: 10 })

          // 商品列表 (瀑布流或Grid)
          Grid() {
            ForEach(this.productList, (item: Product) => {
              GridItem() {
                Column() {
                  // 修改：优先使用 images[0]，兼容旧的 image 字段，无图时显示默认占位图
                  Image(item.images && item.images.length > 0 ? item.images[0] : (item.image || $r('app.media.icon')))
                    .width('100%')
                    .height(120)
                    .objectFit(ImageFit.ScaleDown)
                    .borderRadius({ topLeft: 10, topRight: 10 })
                    .backgroundColor(Color.White)

                  Column() {
                    Text(item.title).fontSize(16).fontWeight(FontWeight.Medium).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    Text(item.content).fontSize(12).fontColor('#999').maxLines(1).margin({ top: 4 })
                    Row() {
                      Text(`¥${item.price}`).fontColor('#FF4D4F').fontSize(16).fontWeight(FontWeight.Bold)
                      Text(item.specs).fontSize(10).fontColor('#ccc').backgroundColor('#F5F5F5').padding(3).borderRadius(4)
                    }.justifyContent(FlexAlign.SpaceBetween).width('100%').margin({ top: 8 })
                  }.padding(10)
                }
                .backgroundColor(Color.White)
                .borderRadius(10)
                .shadow({ radius: 5, color: '#10000000', offsetY: 2 })
                .onClick(() => {
                  // 跳转详情
                  router.pushUrl({ url: 'pages/ProductDetail', params: { product: item } });
                })
              }
            })
          }
          .columnsTemplate('1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
          .padding(10)
          .layoutWeight(1)
        }
        .backgroundColor('#F9F9F9')
        .height('100%')

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

        // 右下角发布按钮
        Image($r('app.media.icon_add'))
          .width(56)
          .height(56)
          .objectFit(ImageFit.Contain)
          .margin({ right: 20, bottom: 20 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/PublishPage' });
          })
      }
      .height('100%')
    }
    .onStateChange((refreshStatus: RefreshStatus) => {
      console.info('Refresh onStatueChange state is ' + refreshStatus);
    })
    .onOffsetChange((value: number) => {
      console.info('Refresh onOffsetChange offset:' + value);
    })
    .onRefreshing(() => {
      this.refreshData()
      setTimeout(() => {
        this.isRefreshing = false;
      }, 2000)
      console.log('onRefreshing test');
    })
    .backgroundColor(0x89CFF0)
    .refreshOffset(64)
    .pullToRefresh(true)
  }

}
