import { router, promptAction } from '@kit.ArkUI';
import { dbManager, Address, User } from '../db/DatabaseManager';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AreaHelper, AreaEntity } from '@nutpi/china_area';
import { http } from '@kit.NetworkKit';

const DOMAIN = 0x0000;

@Entry
@Component
struct AddressEditPage {
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  
  // 表单字段
  @State consignee: string = ''; // 收货人
  @State phone: string = ''; // 手机号
  @State province: string = ''; // 省
  @State city: string = ''; // 市
  @State district: string = ''; // 区
  @State detailAddress: string = ''; // 详细地址
  @State selectedTag: string = ''; // 地址标签
  
  // 页面模式：add-新增，edit-编辑
  @State mode: string = 'add';
  @State addressId: number = 0;
  @State isDefault: number = 0;

  // 地址标签选项
  private tagOptions: string[] = ['家', '公司', '学校', '父母', '朋友', '自定义'];

  // 省市区三级联动相关
  @State provinceList: string[] = []; // 省份名称列表
  @State cityList: string[] = []; // 城市名称列表
  @State districtList: string[] = []; // 区县名称列表
  @State selectedProvinceIndex: number = 0;
  @State selectedCityIndex: number = 0;
  @State selectedDistrictIndex: number = 0;
  
  // 存储完整的区域数据
  private provinceListData: AreaEntity[] = [];
  private cityListData: AreaEntity[] = [];
  private districtListData: AreaEntity[] = [];

  async aboutToAppear() {
    // 验证用户是否登录
    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '请先登录' });
      router.replaceUrl({ url: 'pages/LoginPage' });
      return;
    }

    // 初始化省市区数据
    this.loadRegionData();

    // 获取路由参数
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.mode = (params['mode'] as string) || 'add';
      
      if (this.mode === 'edit') {
        // 编辑模式：填充表单数据
        this.addressId = (params['addressId'] as number) || 0;
        this.consignee = (params['consignee'] as string) || '';
        this.phone = (params['phone'] as string) || '';
        this.province = (params['province'] as string) || '';
        this.city = (params['city'] as string) || '';
        this.district = (params['district'] as string) || '';
        this.detailAddress = (params['detailAddress'] as string) || '';
        this.selectedTag = (params['tag'] as string) || '';
        this.isDefault = (params['isDefault'] as number) || 0;
      }
    }
    
    hilog.info(DOMAIN, 'AddressEditPage', 'Mode: %{public}s, addressId: %{public}d', this.mode, this.addressId);
  }

  // 加载省市区数据（使用库内置的本地数据）
  private loadRegionData() {
    // 获取省份列表
    this.provinceListData = AreaHelper.getAreaSync();
    this.provinceList = this.provinceListData.map(item => item.text);
    
    if (this.provinceListData.length > 0) {
      // 默认选中第一个省份
      this.selectedProvinceIndex = 0;
      this.province = this.provinceListData[0].text;
      this.onProvinceChange(0);
    }

    // 如果是编辑模式且已有省市区数据，则回显选中项
    if (this.mode === 'edit' && this.province && this.city && this.district) {
      this.setSelectedRegionFromExisting();
    }
  }

  // 根据已有的省市区字符串设置选中索引
  private setSelectedRegionFromExisting() {
    // 设置省份
    const provinceIndex = this.provinceList.findIndex(name => name === this.province);
    if (provinceIndex >= 0) {
      this.selectedProvinceIndex = provinceIndex;
      this.onProvinceChange(provinceIndex);
      
      // 设置城市
      const cityIndex = this.cityList.findIndex(name => name === this.city);
      if (cityIndex >= 0) {
        this.selectedCityIndex = cityIndex;
        this.onCityChange(cityIndex);
        
        // 设置区县
        const districtIndex = this.districtList.findIndex(name => name === this.district);
        if (districtIndex >= 0) {
          this.selectedDistrictIndex = districtIndex;
          this.district = this.districtListData[districtIndex].text;
        }
      }
    }
  }

  // 省份改变时更新城市列表
  private onProvinceChange(index: number) {
    if (index < 0 || index >= this.provinceListData.length) {
      return;
    }
    
    this.selectedProvinceIndex = index;
    this.province = this.provinceListData[index].text;
    
    // 根据省份名称获取城市列表
    this.cityListData = AreaHelper.getCityByNameSync(this.province);
    this.cityList = this.cityListData.map(item => item.text);
    
    if (this.cityListData.length > 0) {
      // 默认选中第一个城市
      this.selectedCityIndex = 0;
      this.city = this.cityListData[0].text;
      this.onCityChange(0);
    } else {
      // 清空城市和区县
      this.cityList = [];
      this.city = '';
      this.districtList = [];
      this.district = '';
      this.selectedCityIndex = 0;
      this.selectedDistrictIndex = 0;
    }
  }

  // 城市改变时更新区县列表
  private onCityChange(index: number) {
    if (index < 0 || index >= this.cityListData.length) {
      return;
    }
    
    this.selectedCityIndex = index;
    this.city = this.cityListData[index].text;
    
    // 根据城市名称获取区县列表
    this.districtListData = AreaHelper.getDistrictByNameSync(this.city);
    this.districtList = this.districtListData.map(item => item.text);
    
    if (this.districtListData.length > 0) {
      // 默认选中第一个区县
      this.selectedDistrictIndex = 0;
      this.district = this.districtListData[0].text;
    } else {
      // 清空区县
      this.districtList = [];
      this.district = '';
      this.selectedDistrictIndex = 0;
    }
  }

  // 区县改变
  private onDistrictChange(index: number) {
    if (index < 0 || index >= this.districtListData.length) {
      return;
    }
    
    this.selectedDistrictIndex = index;
    this.district = this.districtListData[index].text;
  }

  // 校验表单
  private validateForm(): boolean {
    // 收货人姓名不能为空
    if (!this.consignee || this.consignee.trim().length === 0) {
      promptAction.showToast({ message: '请输入收货人姓名' });
      return false;
    }

    // 手机号不能为空
    if (!this.phone || this.phone.trim().length === 0) {
      promptAction.showToast({ message: '请输入手机号' });
      return false;
    }

    // 手机号格式校验（11位数字）
    const phoneRegex = /^1[3-9]\d{9}$/;
    if (!phoneRegex.test(this.phone.trim())) {
      promptAction.showToast({ message: '请输入正确的手机号' });
      return false;
    }

    // 省市区校验
    if (!this.province || !this.city || !this.district) {
      promptAction.showToast({ message: '请选择完整的省市区信息' });
      return false;
    }

    // 详细地址不能为空
    if (!this.detailAddress || this.detailAddress.trim().length === 0) {
      promptAction.showToast({ message: '请输入详细地址' });
      return false;
    }

    return true;
  }

  // 保存地址
  async saveAddress() {
    if (!this.validateForm()) {
      return;
    }

    if (!this.user || !this.user.id) {
      promptAction.showToast({ message: '用户信息错误' });
      return;
    }

    try {
      if (this.mode === 'add') {
        // 新增地址
        const address: Address = {
          userId: this.user.id,
          consignee: this.consignee.trim(),
          phone: this.phone.trim(),
          province: this.province.trim(),
          city: this.city.trim(),
          district: this.district.trim(),
          detailAddress: this.detailAddress.trim(),
          tag: this.selectedTag,
          isDefault: 0, // 新增地址默认不是默认地址
          createTime: Date.now()
        };

        const insertId = await dbManager.addAddress(address);
        if (insertId > 0) {
          promptAction.showToast({ message: '添加成功' });
          router.back();
        } else {
          promptAction.showToast({ message: '添加失败' });
        }
      } else {
        // 编辑地址
        const address: Address = {
          id: this.addressId,
          userId: this.user.id,
          consignee: this.consignee.trim(),
          phone: this.phone.trim(),
          province: this.province.trim(),
          city: this.city.trim(),
          district: this.district.trim(),
          detailAddress: this.detailAddress.trim(),
          tag: this.selectedTag,
          isDefault: this.isDefault,
          createTime: Date.now()
        };

        const success = await dbManager.updateAddress(address);
        if (success) {
          promptAction.showToast({ message: '更新成功' });
          router.back();
        } else {
          promptAction.showToast({ message: '更新失败' });
        }
      }
    } catch (error) {
      hilog.error(DOMAIN, 'AddressEditPage', 'Failed to save address: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '保存失败' });
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('<')
          .fontSize(24)
          .onClick(() => router.back())
          .padding(15)
        Text(this.mode === 'add' ? '新增地址' : '编辑地址')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .margin({ left: -40 })
          .textAlign(TextAlign.Center)
        Blank().width(54)
      }
      .width('100%')
      .backgroundColor('#fff')
      .height(56)

      // 表单内容
      Scroll() {
        Column() {
          // 收货人姓名
          Column() {
            Text('收货人姓名')
              .fontSize(14)
              .fontColor('#666')
              .margin({ bottom: 8 })
            TextInput({ placeholder: '请输入收货人姓名', text: this.consignee })
              .height(45)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .onChange((value) => {
                this.consignee = value;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          // 手机号
          Column() {
            Text('手机号')
              .fontSize(14)
              .fontColor('#666')
              .margin({ bottom: 8 })
            TextInput({ placeholder: '请输入手机号', text: this.phone })
              .height(45)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .type(InputType.PhoneNumber)
              .maxLength(11)
              .onChange((value) => {
                this.phone = value;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          // 所在地区 - 三个 TextPicker 组件水平排列
          Column() {
            Text('所在地区')
              .fontSize(14)
              .fontColor('#666')
              .margin({ bottom: 8 })
            
            Row() {
              // 省份选择
              TextPicker({ range: this.provinceList, selected: this.selectedProvinceIndex })
                .height(150)
                .layoutWeight(1)
                .backgroundColor('#F5F5F5')      // 添加：与输入框背景色一致
                .onChange((value: string | string[], index: number | number[]) => {
                  if (typeof index === 'number') {
                    this.onProvinceChange(index);
                  }
                })
              
              // 城市选择
              TextPicker({ range: this.cityList, selected: this.selectedCityIndex })
                .height(150)
                .layoutWeight(1)
                .backgroundColor('#F5F5F5')      // 添加：与输入框背景色一致
                .onChange((value: string | string[], index: number | number[]) => {
                  if (typeof index === 'number') {
                    this.onCityChange(index);
                  }
                })
              
              // 区县选择
              TextPicker({ range: this.districtList, selected: this.selectedDistrictIndex })
                .height(150)
                .layoutWeight(1)
                .backgroundColor('#F5F5F5')      // 添加：与输入框背景色一致
                .onChange((value: string | string[], index: number | number[]) => {
                  if (typeof index === 'number') {
                    this.onDistrictChange(index);
                  }
                })
            }
            .width('100%')
            .height(150)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          // 详细地址
          Column() {
            Text('详细地址')
              .fontSize(14)
              .fontColor('#666')
              .margin({ bottom: 8 })
            TextArea({ placeholder: '请输入详细地址（街道、楼栋、门牌号等）', text: this.detailAddress })
              .height(80)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .onChange((value) => {
                this.detailAddress = value;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 20 })

          // 地址标签
          Column() {
            Text('地址标签（可选）')
              .fontSize(14)
              .fontColor('#666')
              .margin({ bottom: 8 })
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.tagOptions, (tag: string) => {
                Button(tag)
                  .type(ButtonType.Normal)
                  .height(32)
                  .fontSize(14)
                  .backgroundColor(this.selectedTag === tag ? '#3366FF' : '#F5F5F5')
                  .fontColor(this.selectedTag === tag ? '#fff' : '#666')
                  .borderRadius(16)
                  .margin({ right: 10, bottom: 10 })
                  .onClick(() => {
                    if (this.selectedTag === tag) {
                      this.selectedTag = ''; // 取消选择
                    } else {
                      this.selectedTag = tag;
                    }
                  })
              })
            }
            .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .margin({ bottom: 30 })
        }
        .width('100%')
        .padding(20)
      }
      .layoutWeight(1)
      .backgroundColor('#fff')

      // 底部保存按钮
      Column() {
        Button('保存地址')
          .width('90%')
          .height(45)
          .backgroundColor('#3366FF')
          .fontColor('#fff')
          .borderRadius(22)
          .onClick(() => this.saveAddress())
      }
      .width('100%')
      .padding({ bottom: 20 })
      .backgroundColor('#fff')
    }
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}