import { router, promptAction } from '@kit.ArkUI';
import { dbManager, Product, User } from '../db/DatabaseManager';

@Entry
@Component
struct MyPublishPage {
  @StorageLink('currentUser') user: User = {} as User;
  @State myProducts: Product[] = [];

  async aboutToAppear() {
    this.refreshData();
  }

  async refreshData() {
    if (this.user && this.user.id) {
      this.myProducts = await dbManager.getProductsByPublisher(this.user.id);
    }
  }

  async handleDelete(id: number) {
    // 弹窗确认
    AlertDialog.show({
      title: '确认下架',
      message: '确定要删除这个商品吗？删除后无法恢复。',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: '#FF4D4F',
        action: async () => {
          await dbManager.deleteProduct(id);
          this.refreshData();
          promptAction.showToast({ message: '商品已删除' });
        }
      }
    })
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('<').fontSize(24).onClick(() => router.back()).padding(15)
        Text('我发布的').fontSize(18).fontWeight(FontWeight.Bold)
      }.width('100%').backgroundColor(Color.White)

      if (this.myProducts.length === 0) {
        Column() {
          Text('暂时没有发布商品哦').fontColor('#999').margin({ top: 100 })
          Button('去发布')
            .margin({ top: 20 })
            .onClick(() => router.pushUrl({ url: 'pages/PublishPage' }))
        }.width('100%').height('100%')
      } else {
        List({ space: 10 }) {
          ForEach(this.myProducts, (item: Product) => {
            ListItem() {
              Row() {
                // 图片
                Image(item.image) // 占位图
                  .width(80).height(80).borderRadius(6).backgroundColor('#eee')

                // 内容
                Column() {
                  Text(item.title).fontSize(16).fontWeight(FontWeight.Bold).maxLines(1)
                  Text(item.content).fontSize(12).fontColor('#999').maxLines(1).margin({ top: 5 })
                  Row() {
                    Text(`¥${item.price}`).fontColor('#FF4D4F').fontSize(16)
                    Text('编辑').fontSize(12).fontColor('#3366FF').visibility(Visibility.Hidden) // 预留编辑功能位置
                  }.width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ top: 10 })
                }
                .layoutWeight(1)
                .padding({ left: 10 })
                .alignItems(HorizontalAlign.Start)

                // 删除按钮区域
                Column() {
                  Button('下架')
                    .type(ButtonType.Capsule)
                    .backgroundColor('#FF4D4F')
                    .height(28)
                    .fontSize(12)
                    .onClick(() => this.handleDelete(item.id!))
                }
                .justifyContent(FlexAlign.Center)
                .height(80)
                .padding({ left: 10 })
              }
              .padding(10)
              .backgroundColor(Color.White)
              .borderRadius(8)
            }
          })
        }
        .padding(10)
        .layoutWeight(1)
      }
    }
    .height('100%')
    .backgroundColor('#F9F9F9')
  }
}