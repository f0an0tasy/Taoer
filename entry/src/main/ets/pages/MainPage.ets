import { router } from '@kit.ArkUI';
import { HomeView } from './HomeView';
import { CategoryView } from './CategoryView';
import { ProfileView } from './ProfileView';
import { CartView } from './CartView';
import { dbManager } from '../db/DatabaseManager';

import { common } from '@kit.AbilityKit';

@Entry
@Component
struct MainPage {
  @State currentIndex: number = 0;
  private controller: TabsController = new TabsController();

  async aboutToAppear() {
    // 初始化数据库
    await dbManager.init(getContext(this) as common.UIAbilityContext);
    
    // 处理路由参数：支持从其他页面跳转并切换到指定 Tab
    const params = router.getParams() as Record<string, number | string | boolean>;
    if (params) {
      // 切换到指定 Tab
      const tabIndex = params['tabIndex'] as number;
      if (tabIndex !== undefined && tabIndex >= 0 && tabIndex <= 3) {
        // 使用 setTimeout 确保 Tabs 组件已渲染完成
        setTimeout(() => {
          this.controller.changeIndex(tabIndex);
          this.currentIndex = tabIndex;
        }, 100);
      }
      
      // 触发订单列表刷新（通过 AppStorage 通知 OrderListPage）
      const refreshOrders = params['refreshOrders'] as boolean;
      if (refreshOrders === true) {
        AppStorage.setOrCreate('refreshOrders', Date.now());
      }
    }
  }

  @Builder TabBuilder(title: string, index: number, symbolIcon: Resource) {
    Column() {
      // 使用 SymbolGlyph 矢量图标，可动态设置颜色
      SymbolGlyph(symbolIcon)
        .fontSize(24)
        .fontColor([this.currentIndex === index ? '#3366FF' : Color.Black])
      Text(title)
        .fontColor(this.currentIndex === index ? '#3366FF' : Color.Black)
        .fontSize(10)
        .margin({ top: 4 })
    }.justifyContent(FlexAlign.Center).height('100%').width('100%')
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
      TabContent() {
        HomeView()
      }.tabBar(this.TabBuilder('首页', 0, $r('sys.symbol.house')))

      TabContent() {
        CategoryView()
      }.tabBar(this.TabBuilder('分类', 1, $r('sys.symbol.grid')))

      TabContent() {
        CartView()
      }.tabBar(this.TabBuilder('购物车', 2, $r('sys.symbol.cart')))

      TabContent() {
        ProfileView()
      }.tabBar(this.TabBuilder('我的', 3, $r('sys.symbol.person')))
    }
    .animationDuration(0)
    .onChange((index) => this.currentIndex = index)
    .scrollable(false)
  }
}
