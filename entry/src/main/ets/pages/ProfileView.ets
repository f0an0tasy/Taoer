import { router } from '@kit.ArkUI';
import { dbManager, Order, User } from '../db/DatabaseManager';
import { ShoppingCartPreferences } from '../utils/ShoppingCartPreferences';
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { httpService, ApiResponse } from '../utils/HttpService';

const DOMAIN = 0x0000;
const USER_KEY = 'current_user';

// 头像更新请求体接口
interface AvatarUpdateRequest {
  avatarPath: string;
}

@Component
export struct ProfileView {
  @StorageLink('currentUser') user: User = { username: '未登录' } as User;
  @StorageLink('pf') pf: preferences.Preferences | null = null;

  /**
   * 获取头像显示路径
   * - 如果是服务器 URL（http:// 或 https://），直接返回
   * - 如果是相册 URI（file://media/...），直接返回
   * - 如果是沙箱绝对路径（/data/...），添加 file:// 前缀
   * - 否则返回默认头像
   */
  private getAvatarSource(): string | Resource {
    if (this.user && this.user.avatar && this.user.avatar.length > 0) {
      // 如果是服务器 URL（http:// 或 https://），直接返回
      if (this.user.avatar.startsWith('http://') || this.user.avatar.startsWith('https://')) {
        return this.user.avatar;
      }
      // 如果是相册 URI（file://media/...），直接返回
      if (this.user.avatar.startsWith('file://media')) {
        return this.user.avatar;
      }
      // 如果是沙箱绝对路径，添加 file:// 前缀
      if (this.user.avatar.startsWith('/')) {
        return 'file://' + this.user.avatar;
      }
      return this.user.avatar;
    }
    // 返回默认头像资源
    return $r('app.media.avatar_default');
  }

  /**
   * 处理头像点击 - 选择并更换头像
   * 上传图片到服务器并保存服务器返回的 URL
   */
  private async handleAvatarClick() {
    try {
      hilog.info(DOMAIN, 'Avatar', 'Starting avatar selection');
      
      // 检查用户是否登录
      if (!this.user || !this.user.id) {
        promptAction.showToast({ message: '请先登录' });
        return;
      }

      // 创建图片选择器
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;

      // 选择图片
      const photoSelectResult = await photoPicker.select(photoSelectOptions);
      hilog.info(DOMAIN, 'Avatar', 'Photo select result: %{public}s', JSON.stringify(photoSelectResult));

      if (!photoSelectResult.photoUris || photoSelectResult.photoUris.length === 0) {
        hilog.info(DOMAIN, 'Avatar', 'No photo selected');
        return;
      }

      // 获取选择的图片 URI
      const sourceUri = photoSelectResult.photoUris[0];
      hilog.info(DOMAIN, 'Avatar', 'Selected photo URI: %{public}s', sourceUri);

      // 上传图片到服务器
      promptAction.showToast({ message: '正在上传头像...' });
      const uploadResult = await httpService.uploadFile('/api/upload/avatar', sourceUri, 'avatar');
      
      if (!uploadResult.success || !uploadResult.data) {
        hilog.error(DOMAIN, 'Avatar', 'Upload failed: %{public}s', uploadResult.message || 'unknown error');
        promptAction.showToast({ message: uploadResult.message || '上传失败' });
        return;
      }

      // 获取服务器返回的图片 URL
      const avatarUrl = uploadResult.data;
      hilog.info(DOMAIN, 'Avatar', 'Upload success, avatar URL: %{public}s', avatarUrl);

      // 调用 API 更新用户头像
      const requestData: AvatarUpdateRequest = { avatarPath: avatarUrl };
      const updateResult: ApiResponse<void> = await httpService.put<void>(`/api/users/${this.user.id}/avatar`, requestData);
      if (!updateResult.success) {
        promptAction.showToast({ message: '更新头像失败' });
        return;
      }

      // 更新 AppStorage
      const updatedUser: User = {
        id: this.user.id,
        username: this.user.username,
        password: this.user.password,
        avatar: avatarUrl,
        studentId: this.user.studentId,
        cardImage: this.user.cardImage
      };
      AppStorage.setOrCreate('currentUser', updatedUser);
      hilog.info(DOMAIN, 'Avatar', 'AppStorage updated');

      // 更新 Preferences
      if (this.pf) {
        await this.pf.put(USER_KEY, JSON.stringify(updatedUser));
        await this.pf.flush();
        hilog.info(DOMAIN, 'Avatar', 'Preferences updated');
      }

      promptAction.showToast({ message: '头像更换成功' });
      hilog.info(DOMAIN, 'Avatar', 'Avatar update completed successfully');

    } catch (error) {
      hilog.error(DOMAIN, 'Avatar', 'Failed to update avatar: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '头像更换失败' });
    }
  }

  /**
   * 退出登录处理
   */
  private async handleLogout() {
    try {
      // 清除持久化的用户信息
      if (this.pf) {
        await this.pf.delete(USER_KEY);
        await this.pf.flush();
        hilog.info(DOMAIN, 'CartPersist', 'User info cleared from Preferences');
      }
      
      // 注意：不清空购物车数据，保留数据供下次登录使用
      // 如果需要清空购物车，可以取消下面注释
      // if (this.user && this.user.id) {
      //   await ShoppingCartPreferences.clearCart(getContext(this) as common.UIAbilityContext, this.user.id.toString());
      // }
      
      // 清除 AppStorage 中的用户信息
      AppStorage.setOrCreate('currentUser', { username: '未登录' } as User);
      hilog.info(DOMAIN, 'CartPersist', 'User logged out, cleared currentUser from AppStorage');
      
      // 清空路由栈并跳转到登录页
      router.clear();
      router.replaceUrl({ url: 'pages/LoginPage' });
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Logout failed: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '退出登录失败' });
    }
  }

  build() {
    Column() {
      // 头部信息
      Column() {
        // 头像显示：优先显示用户头像，否则显示默认头像
        Image(this.getAvatarSource())
          .width(70)
          .height(70)
          .borderRadius(35)
          .backgroundColor('#fff')
          .objectFit(ImageFit.Cover)
          .onClick(() => this.handleAvatarClick())
        // 用户名（点击可修改）
        Text(this.user.username)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 10 })
          .fontColor('#fff')
          .onClick(() => {
            router.pushUrl({ url: 'pages/ChangeUsernamePage' });
          })
        // 校园卡号显示
        Text('校园卡号：' + (this.user.studentId || '未绑定'))
          .fontSize(14)
          .fontColor('#eee')
          .margin({ top: 5 })
        // ID 显示
        Text('ID: ' + (this.user.id || '0000'))
          .fontSize(12)
          .fontColor('#eee')
          .margin({ top: 5 })
      }
      .width('100%')
      .height(200)
      .backgroundColor('#3366FF')
      .justifyContent(FlexAlign.Center)

      // 菜单
      Column() {
        this.MenuItem('我的订单', 'app.media.ic_order', () => {
          router.pushUrl({ url: 'pages/OrderListPage' });
        })
        Divider().color('#f0f0f0')
        // 我的卖出菜单项
        this.MenuItem('我的卖出', 'app.media.ic_order', () => {
          router.pushUrl({ url: 'pages/SellerOrderListPage' });
        })
        Divider().color('#f0f0f0')
        // 我的地址菜单项
        this.MenuItem('我的地址', 'app.media.ic_order', () => {
          router.pushUrl({ url: 'pages/AddressListPage' });
        })
        Divider().color('#f0f0f0')
        // 我的收藏菜单项
        this.MenuItem('我的收藏', 'app.media.ic_order', () => {
          router.pushUrl({ url: 'pages/FavoriteListPage' });
        })
        Divider().color('#f0f0f0')
        // 修改 MenuItem 调用：
        this.MenuItem('我的发布', 'app.media.ic_pub', () => {
          router.pushUrl({ url: 'pages/MyPublishPage' }); // 跳转到我们刚写的页面
        })
        Divider().color('#f0f0f0')
        // 修改 MenuItem 调用：
        this.MenuItem('AI建议', 'app.media.ic_pub', () => {
          router.pushUrl({ url: 'pages/Home' }); // 跳转到我们刚写的页面
        })
        Divider().color('#f0f0f0')
        this.MenuItem('设置', 'app.media.ic_setting', () => {
          router.pushUrl({ url: 'pages/SettingPage' });
        })

        Button('退出登录')
          .width('90%')
          .height(45)
          .margin({ top: 50 })
          .backgroundColor('#FF4D4F')
          .onClick(() => {
            // 添加确认弹窗，防止误触
            AlertDialog.show({
              title: '提示',
              message: '确定要退出登录吗？',
              primaryButton: {
                value: '取消',
                action: () => {
                  // 点击取消，不做任何操作
                }
              },
              secondaryButton: {
                value: '确定',
                action: () => {
                  // 点击确定，执行退出登录
                  this.handleLogout();
                }
              }
            });
          })
      }
      .width('100%')
      .padding({ top: 20 })
      .layoutWeight(1)
      .backgroundColor('#fff')
      .borderRadius({ topLeft: 20, topRight: 20 })
      .margin({ top: -20 }) // 上浮效果
    }
    .height('100%')
    .backgroundColor('#3366FF')
  }

  @Builder MenuItem(title: string, icon: string, action: () => void) {
    Row() {
      // Image($r(icon)).width(20).height(20).margin({ right: 10 }) // 实际需图标
      Text(title).fontSize(16).layoutWeight(1)
      Text('>').fontColor('#ccc')
    }
    .width('100%')
    .padding(20)
    .onClick(action)
  }
}