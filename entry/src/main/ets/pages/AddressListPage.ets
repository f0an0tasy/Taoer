import { router, promptAction } from '@kit.ArkUI';
import { dbManager, Address, User } from '../db/DatabaseManager';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

interface RouterParams {
  selectMode?: boolean; // 选择模式（从订单确认页进入）
}

@Entry
@Component
struct AddressListPage {
  @State addressList: Address[] = [];
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  @State selectMode: boolean = false; // 是否为选择模式

  async aboutToAppear() {
    // 验证用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }

    // 检查是否为选择模式
    const params = router.getParams() as RouterParams;
    if (params && params.selectMode) {
      this.selectMode = true;
      hilog.info(DOMAIN, 'AddressListPage', 'Select mode enabled');
    }

    await this.refreshAddressList();
  }

  // 页面显示时刷新地址列表（从编辑页返回时触发）
  async onPageShow() {
    if (this.user && this.user.id) {
      await this.refreshAddressList();
    }
  }

  // 刷新地址列表
  async refreshAddressList() {
    if (this.user && this.user.id) {
      this.addressList = await dbManager.getAddressList(this.user.id);
      hilog.info(DOMAIN, 'AddressListPage', 'Loaded %{public}d addresses', this.addressList.length);
    }
  }

  // 跳转到地址编辑页（新增）
  goToAddAddress() {
    router.pushUrl({
      url: 'pages/AddressEditPage',
      params: { mode: 'add' }
    });
  }

  // 跳转到地址编辑页（编辑）
  goToEditAddress(address: Address) {
    router.pushUrl({
      url: 'pages/AddressEditPage',
      params: {
        mode: 'edit',
        addressId: address.id,
        consignee: address.consignee,
        phone: address.phone,
        province: address.province,
        city: address.city,
        district: address.district,
        detailAddress: address.detailAddress,
        tag: address.tag,
        isDefault: address.isDefault
      }
    });
  }

  // 设置默认地址
  async setDefaultAddress(address: Address) {
    if (!address.id) {
      promptAction.showToast({ message: '地址信息错误' });
      return;
    }
    
    if (address.isDefault === 1) {
      promptAction.showToast({ message: '该地址已是默认地址' });
      return;
    }

    const success = await dbManager.setDefaultAddress(this.user.id!, address.id);
    if (success) {
      promptAction.showToast({ message: '已设为默认地址' });
      await this.refreshAddressList();
    } else {
      promptAction.showToast({ message: '设置失败' });
    }
  }

  // 删除地址
  async deleteAddress(address: Address) {
    if (!address.id) {
      promptAction.showToast({ message: '地址信息错误' });
      return;
    }

    // 检查是否为默认地址
    if (address.isDefault === 1) {
      promptAction.showToast({ message: '默认地址不可删除，请先设置其他地址为默认' });
      return;
    }

    // 弹窗确认
    AlertDialog.show({
      title: '确认删除',
      message: '确定要删除该地址吗？',
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '确定',
        action: async () => {
          const success = await dbManager.deleteAddress(address.id!);
          if (success) {
            promptAction.showToast({ message: '删除成功' });
            await this.refreshAddressList();
          } else {
            promptAction.showToast({ message: '删除失败' });
          }
        }
      }
    });
  }

  // 选择地址（选择模式下使用）
  selectAddress(address: Address) {
    if (!address.id) {
      promptAction.showToast({ message: '地址信息错误' });
      return;
    }
    
    hilog.info(DOMAIN, 'AddressListPage', 'Selected address: %{public}s', address.consignee);
    // 使用 AppStorage 传递选中的地址ID
    AppStorage.setOrCreate('selectedAddressId', address.id);
    // 返回订单确认页
    router.back();
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        // 【修改】返回按钮：使用 Row 容器包装，确保点击区域明确且足够大
        Row() {
          Text('<')
            .fontSize(24)
            .fontColor('#333')
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          hilog.info(DOMAIN, 'AddressListPage', 'Back button clicked');
          router.back();
        })
        
        Text('我的地址')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        // 占位，保持标题居中
        Row().width(44)
      }
      .width('100%')
      .backgroundColor('#fff')
      .height(56)
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      // 地址列表
      if (this.addressList.length === 0) {
        // 空状态
        Column() {
          Text('暂无地址')
            .fontSize(16)
            .fontColor('#999')
            .margin({ top: 100 })
          Text('点击下方按钮添加新地址')
            .fontSize(14)
            .fontColor('#ccc')
            .margin({ top: 10 })
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        List({ space: 10 }) {
          ForEach(this.addressList, (item: Address) => {
            ListItem() {
              Column() {
                // 收货人信息行
                Row() {
                  Text(item.consignee)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                  Text(item.phone)
                    .fontSize(14)
                    .fontColor('#666')
                    .margin({ left: 15 })
                  if (item.isDefault === 1) {
                    Text('默认')
                      .fontSize(12)
                      .fontColor('#fff')
                      .backgroundColor('#FF6B35')
                      .borderRadius(4)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .margin({ left: 10 })
                  }
                }
                .width('100%')
                .margin({ bottom: 8 })

                // 地址信息
                Text(`${item.province}${item.city}${item.district}${item.detailAddress}`)
                  .fontSize(14)
                  .fontColor('#333')
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                  .margin({ bottom: 8 })

                // 标签（如果有）
                if (item.tag && item.tag.length > 0) {
                  Text(item.tag)
                    .fontSize(12)
                    .fontColor('#3366FF')
                    .backgroundColor('#E8F0FF')
                    .borderRadius(4)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .margin({ bottom: 8 })
                }

                // 操作按钮行（非选择模式下显示）
                if (!this.selectMode) {
                  Row() {
                    // 设为默认按钮
                    if (item.isDefault !== 1) {
                      Button('设为默认')
                        .type(ButtonType.Normal)
                        .height(28)
                        .fontSize(12)
                        .backgroundColor('#fff')
                        .fontColor('#3366FF')
                        .border({ width: 1, color: '#3366FF' })
                        .borderRadius(14)
                        .onClick(() => this.setDefaultAddress(item))
                    }
                    
                    Blank().layoutWeight(1)

                    // 编辑按钮
                    Button('编辑')
                      .type(ButtonType.Normal)
                      .height(28)
                      .fontSize(12)
                      .backgroundColor('#fff')
                      .fontColor('#666')
                      .border({ width: 1, color: '#ddd' })
                      .borderRadius(14)
                      .margin({ left: 10 })
                      .onClick(() => this.goToEditAddress(item))

                    // 删除按钮
                    Button('删除')
                      .type(ButtonType.Normal)
                      .height(28)
                      .fontSize(12)
                      .backgroundColor('#fff')
                      .fontColor('#FF4D4F')
                      .border({ width: 1, color: '#FF4D4F' })
                      .borderRadius(14)
                      .margin({ left: 10 })
                      .onClick(() => this.deleteAddress(item))
                  }
                  .width('100%')
                }
              }
              .width('100%')
              .padding(15)
              .backgroundColor(Color.White)
              .borderRadius(8)
              .onClick(() => {
                // 选择模式下点击地址项返回订单确认页
                if (this.selectMode) {
                  this.selectAddress(item);
                }
              })
            }
          })
        }
        .layoutWeight(1)
        .padding({ left: 10, right: 10, top: 10, bottom: 70 })
        .backgroundColor('#F5F5F5')
      }

      // 底部新增按钮
      Column() {
        Button('新增地址')
          .width('90%')
          .height(45)
          .backgroundColor('#3366FF')
          .fontColor('#fff')
          .borderRadius(22)
          .onClick(() => this.goToAddAddress())
      }
      .width('100%')
      .padding({ bottom: 20 })
      .backgroundColor('#fff')
    }
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}
