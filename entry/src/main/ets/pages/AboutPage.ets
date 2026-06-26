import { router } from '@kit.ArkUI';

@Entry
@Component
struct AboutPage {
  build() {
    Stack() {
      // 背景层1：主渐变（深蓝到亮蓝到浅蓝到白色）
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [
            ['#0A3D62', 0.0],    // 深蓝
            ['#4A90E2', 0.3],    // 亮蓝
            ['#B8E1FC', 0.6],    // 浅蓝
            ['#FFFFFF', 1.0]     // 白色
          ]
        })

      // 背景层2：径向渐变高光效果（顶部）
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: [50, 20],
          radius: 80,
          colors: [
            ['rgba(255, 255, 255, 0.4)', 0.0],
            ['rgba(255, 255, 255, 0.1)', 0.5],
            ['rgba(255, 255, 255, 0.0)', 1.0]
          ]
        })

      // 背景层3：斜向渐变增强流动感
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 45,
          colors: [
            ['rgba(74, 144, 226, 0.3)', 0.0],
            ['rgba(184, 225, 252, 0.2)', 0.5],
            ['rgba(255, 255, 255, 0.0)', 1.0]
          ]
        })

      // 主内容区域
      Scroll() {
        Column() {
          // 顶部标题区域
          Column() {
            Text('关于我们')
              .fontSize(24)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
              .textShadow({ radius: 2, color: 'rgba(0, 0, 0, 0.3)', offsetX: 1, offsetY: 1 })
              .margin({ top: 80, bottom: 40 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 内容卡片区域
          Column() {
            // 应用名称
            Text('淘二')
              .fontSize(28)
              .fontColor('#0A3D62')
              .fontWeight(FontWeight.Bold)
              .margin({ top: 30, bottom: 15 })

            // 副标题
            Text('面向中南大学学生用户的专属二手商店')
              .fontSize(16)
              .fontColor('#666666')
              .fontWeight(FontWeight.Normal)
              .margin({ bottom: 30 })
              .textAlign(TextAlign.Center)

            // 分割线
            Divider()
              .width('60%')
              .color('#E0E0E0')
              .margin({ bottom: 30 })

            // 功能介绍标题
            Text('在这里，你可以：')
              .fontSize(16)
              .fontColor('#333333')
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 20 })

            // 功能列表
            Column({ space: 12 }) {
              this.FeatureItem('发布闲置物品，轻松转手')
              this.FeatureItem('浏览校内商品，淘到好物')
              this.FeatureItem('安全交易，校园专属')
              this.FeatureItem('与校友互动，共享资源')
            }
            .width('85%')
            .alignItems(HorizontalAlign.Start)
            .margin({ bottom: 40 })
          }
          .width('90%')
          .backgroundColor('rgba(255, 255, 255, 0.95)')
          .borderRadius(20)
          .padding({ left: 20, right: 20, bottom: 30 })
          .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.15)', offsetX: 0, offsetY: 8 })

          // 返回按钮
          Button('返回设置')
            .width('85%')
            .height(48)
            .fontSize(18)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .linearGradient({
              angle: 90,
              colors: [
                ['#3366FF', 0.0],
                ['#4A90E2', 1.0]
              ]
            })
            .borderRadius(24)
            .shadow({ radius: 12, color: 'rgba(51, 102, 255, 0.4)', offsetX: 0, offsetY: 4 })
            .margin({ top: 30, bottom: 40 })
            .onClick(() => router.back())

          // 占位空间
          Column()
            .width('100%')
            .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder FeatureItem(text: string) {
    Row() {
      Text('·')
        .fontSize(16)
        .fontColor('#4A90E2')
        .fontWeight(FontWeight.Bold)
        .margin({ right: 8 })
      
      Text(text)
        .fontSize(15)
        .fontColor('#555555')
        .fontWeight(FontWeight.Normal)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
