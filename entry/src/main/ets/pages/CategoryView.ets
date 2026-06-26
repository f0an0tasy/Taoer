import { router } from '@kit.ArkUI';
import { dbManager, Product } from '../db/DatabaseManager';

@Component
export struct CategoryView {
  @State categories: string[] = ['电子数码', '书籍资料', '生活乐器', '运动健身', '衣物鞋帽'];
  @State currentCateIndex: number = 0;
  @State cateProducts: Product[] = [];

  async aboutToAppear() {
    this.loadCateData();
  }

  async loadCateData() {
    this.cateProducts = await dbManager.getProductsByCategory(this.categories[this.currentCateIndex]);
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Row() {
        // 左侧 Tab
        List() {
          ForEach(this.categories, (item: string, index: number) => {
            ListItem() {
              Text(item)
                .fontSize(14)
                .fontColor(this.currentCateIndex === index ? '#3366FF' : '#333')
                .fontWeight(this.currentCateIndex === index ? FontWeight.Bold : FontWeight.Normal)
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 20, bottom: 20 })
                .backgroundColor(this.currentCateIndex === index ? '#fff' : '#F5F5F5')
            }
            .onClick(() => {
              this.currentCateIndex = index;
              this.loadCateData();
            })
          })
        }.width('25%').height('100%').backgroundColor('#F5F5F5')

        // 右侧内容
        List() {
          ForEach(this.cateProducts, (item: Product) => {
            ListItem() {
              Row() {
                Image(item.image).width(80).height(80).borderRadius(8).backgroundColor('#eee')
                Column() {
                  Text(item.title).fontSize(16).fontWeight(FontWeight.Bold)
                  Text(item.content).fontSize(12).fontColor('#999').margin({ top: 5 }).maxLines(2)
                  Text(`¥${item.price}`).fontColor('#FF4D4F').fontSize(16).margin({ top: 10 })
                }
                .alignItems(HorizontalAlign.Start)
                .padding({ left: 10 })
                .layoutWeight(1)
              }
              .padding(10)
              .backgroundColor(Color.White)
              .margin({ bottom: 10 })
              .borderRadius(8)
              .onClick(() => {
                router.pushUrl({ url: 'pages/ProductDetail', params: { product: item } });
              })
            }
          })
        }
        .width('75%')
        .height('100%')
        .padding(10)
        .backgroundColor('#fff')
      }
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
    }
    .height('100%')
  }
}
