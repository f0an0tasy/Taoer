import { router, promptAction } from '@kit.ArkUI';
import { dbManager, User, Product } from '../db/DatabaseManager';
import { CoverData, getAlbum } from '../utlis/SelectImage';
import { httpService } from '../utils/HttpService';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const MAX_IMAGE_COUNT = 9; // 最多选择9张图片

@Entry
@Component
struct PublishPage {
  @StorageLink('currentUser') user: User = {} as User;

  @State title: string = '';
  @State content: string = '';
  @State price: string = '';
  @State specs: string = '';
  @State selectedCategory: string = '电子数码';

  // 多图相关状态
  @State selectedImageUris: string[] = []; // 已选择的本地图片URI
  @State uploadedImageUrls: string[] = []; // 已上传的图片URL
  @State isUploading: boolean = false;
  @State uploadingIndex: number = -1; // 当前正在上传的图片索引

  private categories: string[] = ['电子数码', '书籍资料', '生活乐器', '运动健身', '衣物鞋帽'];

  // 选择图片
  async handleSelectImages() {
    if (this.isUploading) return;
    
    // 计算还能选择多少张
    const remainingCount = MAX_IMAGE_COUNT - this.selectedImageUris.length;
    if (remainingCount <= 0) {
      promptAction.showToast({ message: `最多只能选择${MAX_IMAGE_COUNT}张图片` });
      return;
    }

    try {
      const data: CoverData = await getAlbum(remainingCount);
      
      if (!data.imageUrl || data.imageUrl.length === 0) {
        promptAction.showToast({ message: '未选择图片' });
        return;
      }

      // 添加新选择的图片URI
      for (const uri of data.imageUrl) {
        if (this.selectedImageUris.length < MAX_IMAGE_COUNT) {
          this.selectedImageUris.push(uri);
        }
      }
      
      hilog.info(DOMAIN, 'PublishPage', 'Selected %{public}d images, total: %{public}d', 
        data.imageUrl.length, this.selectedImageUris.length);
    } catch (error) {
      hilog.error(DOMAIN, 'PublishPage', 'Image selection error: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '图片选择失败' });
    }
  }

  // 上传所有图片
  async uploadAllImages(): Promise<boolean> {
    if (this.selectedImageUris.length === 0) {
      return true; // 没有图片需要上传
    }

    this.isUploading = true;
    this.uploadedImageUrls = [];

    for (let i = 0; i < this.selectedImageUris.length; i++) {
      this.uploadingIndex = i;
      const uri = this.selectedImageUris[i];
      
      hilog.info(DOMAIN, 'PublishPage', 'Uploading image %{public}d/%{public}d: %{public}s', 
        i + 1, this.selectedImageUris.length, uri);

      try {
        const uploadResult = await httpService.uploadFile('/api/upload/product', uri, 'productImage');
        
        if (uploadResult.success && uploadResult.data) {
          this.uploadedImageUrls.push(uploadResult.data);
          hilog.info(DOMAIN, 'PublishPage', 'Upload success, URL: %{public}s', uploadResult.data);
        } else {
          hilog.error(DOMAIN, 'PublishPage', 'Upload failed for image %{public}d: %{public}s', 
            i + 1, uploadResult.message || 'unknown');
          this.isUploading = false;
          this.uploadingIndex = -1;
          promptAction.showToast({ message: `第${i + 1}张图片上传失败: ${uploadResult.message || '请重试'}` });
          return false;
        }
      } catch (error) {
        hilog.error(DOMAIN, 'PublishPage', 'Upload exception for image %{public}d: %{public}s', 
          i + 1, JSON.stringify(error));
        this.isUploading = false;
        this.uploadingIndex = -1;
        promptAction.showToast({ message: `第${i + 1}张图片上传失败` });
        return false;
      }
    }

    this.isUploading = false;
    this.uploadingIndex = -1;
    hilog.info(DOMAIN, 'PublishPage', 'All %{public}d images uploaded successfully', this.uploadedImageUrls.length);
    return true;
  }

  // 删除指定索引的图片
  handleRemoveImage(index: number) {
    this.selectedImageUris.splice(index, 1);
    // 如果已上传的URL数量大于当前选择的图片数量，也删除对应的URL
    if (this.uploadedImageUrls.length > this.selectedImageUris.length) {
      this.uploadedImageUrls.splice(index, 1);
    }
    hilog.info(DOMAIN, 'PublishPage', 'Removed image at index %{public}d, remaining: %{public}d', 
      index, this.selectedImageUris.length);
  }

  // 发布商品
  async handlePublish() {
    if (!this.title || !this.price || !this.content) {
      promptAction.showToast({ message: '请填写完整信息' });
      return;
    }

    // 先上传所有图片
    if (this.selectedImageUris.length > 0) {
      promptAction.showToast({ message: '正在上传图片...' });
      const uploadSuccess = await this.uploadAllImages();
      if (!uploadSuccess) {
        return; // 上传失败，不继续发布
      }
    }

    // 发布商品，使用 images 字段
    const productData: Product = {
      publisherId: this.user.id || 1,
      title: this.title,
      content: this.content,
      price: parseFloat(this.price),
      category: this.selectedCategory,
      image: this.uploadedImageUrls[0] || '', // 兼容旧字段，使用第一张图
      images: this.uploadedImageUrls, // 新增多图字段
      specs: this.specs || '默认规格'
    };

    hilog.info(DOMAIN, 'PublishPage', 'Publishing product with %{public}d images', this.uploadedImageUrls.length);

    const result = await dbManager.insertProduct(productData);
    
    if (result > 0) {
      promptAction.showToast({ message: '发布成功！' });
      router.back();
    } else {
      promptAction.showToast({ message: '发布失败，请重试' });
    }
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('取消').fontSize(16).fontColor('#666').onClick(() => router.back())
        Text('发布宝贝').fontSize(18).fontWeight(FontWeight.Bold)
        Text('发布').fontSize(16).fontColor('#3366FF').fontWeight(FontWeight.Medium)
          .onClick(() => this.handlePublish())
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .padding(15)
      .backgroundColor(Color.White)

      Scroll() {
        Column({ space: 15 }) {
          // 多图上传区域
          Column() {
            // 已选图片列表
            if (this.selectedImageUris.length > 0) {
              Grid() {
                ForEach(this.selectedImageUris, (uri: string, index: number) => {
                  GridItem() {
                    Stack({ alignContent: Alignment.TopEnd }) {
                      // 图片缩略图
                      Image(uri)
                        .width(80)
                        .height(80)
                        .objectFit(ImageFit.Cover)
                        .borderRadius(8)
                      
                      // 上传中遮罩
                      if (this.isUploading && this.uploadingIndex === index) {
                        Column() {
                          LoadingProgress()
                            .width(24)
                            .height(24)
                            .color(Color.White)
                        }
                        .width(80)
                        .height(80)
                        .borderRadius(8)
                        .backgroundColor('rgba(0,0,0,0.5)')
                        .justifyContent(FlexAlign.Center)
                      }
                      
                      // 删除按钮
                      Column() {
                        Text('×')
                          .fontSize(14)
                          .fontColor(Color.White)
                          .fontWeight(FontWeight.Bold)
                      }
                      .width(20)
                      .height(20)
                      .borderRadius(10)
                      .backgroundColor('rgba(255,77,79,0.9)')
                      .justifyContent(FlexAlign.Center)
                      .margin({ top: 2, right: 2 })
                      .onClick(() => this.handleRemoveImage(index))
                    }
                    .width(80)
                    .height(80)
                  }
                })
                
                // 添加按钮（如果未达到最大数量）
                if (this.selectedImageUris.length < MAX_IMAGE_COUNT) {
                  GridItem() {
                    Column() {
                      if (this.isUploading) {
                        LoadingProgress()
                          .width(24)
                          .height(24)
                          .color('#999')
                      } else {
                        Image($r('app.media.icon_add'))
                          .width(24)
                          .height(24)
                          .fillColor('#999')
                      }
                      Text(`${this.selectedImageUris.length}/${MAX_IMAGE_COUNT}`)
                        .fontSize(10)
                        .fontColor('#999')
                        .margin({ top: 4 })
                    }
                    .width(80)
                    .height(80)
                    .backgroundColor('#F5F5F5')
                    .borderRadius(8)
                    .justifyContent(FlexAlign.Center)
                    .onClick(() => this.handleSelectImages())
                  }
                }
              }
              .columnsTemplate('1fr 1fr 1fr 1fr')
              .columnsGap(8)
              .rowsGap(8)
              .width('100%')
              .height(this.selectedImageUris.length > 0 ? 88 : 0)
            } else {
              // 未选择图片时的占位
              Column() {
                Image($r('app.media.icon_add'))
                  .width(40)
                  .height(40)
                  .fillColor('#999')
                Text('添加图片（最多9张）')
                  .fontSize(12)
                  .fontColor('#999')
                  .margin({ top: 5 })
              }
              .width(100)
              .height(100)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .justifyContent(FlexAlign.Center)
              .onClick(() => this.handleSelectImages())
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .padding({ top: 10, bottom: 10 })

          Divider().color('#eee')

          // 标题
          TextInput({ placeholder: '标题 品牌型号都是买家喜欢搜索的' })
            .onChange((val) => this.title = val)
            .backgroundColor(Color.Transparent)
            .fontSize(16)
            .padding(10)

          Divider().color('#eee')

          // 描述
          TextArea({ placeholder: '描述一下宝贝的转手原因、入手渠道和使用感受吧...' })
            .onChange((val) => this.content = val)
            .backgroundColor(Color.Transparent)
            .height(120)
            .fontSize(14)
            .padding(10)
            .align(Alignment.TopStart)

          Divider().color('#eee')

          // 价格
          Row() {
            Text('价格').fontSize(16).width(80)
            TextInput({ placeholder: '0.00' })
              .type(InputType.Number)
              .onChange((val) => this.price = val)
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
              .fontColor('#FF4D4F')
          }.padding({ top: 10, bottom: 10 })

          Divider().color('#eee')

          // 规格
          Row() {
            Text('规格').fontSize(16).width(80)
            TextInput({ placeholder: '如：9成新 / 2023版' })
              .onChange((val) => this.specs = val)
              .backgroundColor(Color.Transparent)
              .layoutWeight(1)
              .textAlign(TextAlign.End)
          }.padding({ top: 10, bottom: 10 })

          Divider().color('#eee')

          // 分类选择
          Row() {
            Text('分类').fontSize(16).width(80)
            Row() {
              Text(this.selectedCategory).fontSize(16).fontColor('#666')
              Text('>').fontColor('#ccc').margin({ left: 5 })
            }
            .onClick(() => {
              TextPickerDialog.show({
                range: this.categories,
                selected: 0,
                onAccept: (value) => {
                  this.selectedCategory = value.value as string;
                }
              })
            })
          }.width('100%').justifyContent(FlexAlign.SpaceBetween).padding({ top: 10, bottom: 10 })

        }
        .padding(20)
        .backgroundColor(Color.White)
        .borderRadius(12)
        .margin(10)
      }
    }
    .height('100%')
    .backgroundColor('#F9F9F9')
  }
}
