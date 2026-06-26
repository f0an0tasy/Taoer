import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;

// 购物车商品接口
export interface CartItem {
  productId: number;
  title: string;
  price: number;
  image: string;
  quantity: number;
  specs: string;
}

export class ShoppingCartPreferences {
  private static readonly PREFS_NAME = 'ShoppingCart';
  private static readonly CART_KEY_PREFIX = 'cart_';
  
  /**
   * 获取当前用户的购物车Preferences实例
   */
  private static getPreferences(context: common.UIAbilityContext, userId: string): Promise<preferences.Preferences> {
    const prefName = `${ShoppingCartPreferences.CART_KEY_PREFIX}${userId}`;
    return preferences.getPreferences(context, prefName);
  }
  
  /**
   * 保存购物车数据
   */
  public static async saveCart(context: common.UIAbilityContext, userId: string, cartItems: CartItem[]): Promise<void> {
    try {
      const pref = await ShoppingCartPreferences.getPreferences(context, userId);
      const cartData = JSON.stringify(cartItems);
      await pref.put('cart_items', cartData);
      await pref.flush();
      hilog.info(DOMAIN, 'CartPersist', 'Saved %{public}d items for user %{public}s', cartItems.length, userId);
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Failed to save cart data: %{public}s', JSON.stringify(error));
      throw new Error(JSON.stringify(error));
    }
  }
  
  /**
   * 加载购物车数据
   */
  public static async loadCart(context: common.UIAbilityContext, userId: string): Promise<CartItem[]> {
    try {
      const pref = await ShoppingCartPreferences.getPreferences(context, userId);
      const cartData = await pref.get('cart_items', '[]') as string;
      const cartItems = JSON.parse(cartData) as CartItem[];
      hilog.info(DOMAIN, 'CartPersist', 'Loaded %{public}d items for user %{public}s', cartItems.length, userId);
      return cartItems;
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Failed to load cart data: %{public}s', JSON.stringify(error));
      return [];
    }
  }
  
  /**
   * 添加商品到购物车
   */
  public static async addToCart(context: common.UIAbilityContext, userId: string, item: CartItem): Promise<void> {
    try {
      const currentCart = await ShoppingCartPreferences.loadCart(context, userId);
      const existingIndex = currentCart.findIndex(cartItem => cartItem.productId === item.productId && cartItem.specs === item.specs);
      
      if (existingIndex !== -1) {
        // 如果商品已存在，增加数量
        currentCart[existingIndex].quantity += item.quantity;
        hilog.info(DOMAIN, 'CartPersist', 'Updated quantity for item %{public}d in cart', item.productId);
      } else {
        // 如果商品不存在，添加新商品
        currentCart.push(item);
        hilog.info(DOMAIN, 'CartPersist', 'Added new item %{public}d to cart', item.productId);
      }
      
      await ShoppingCartPreferences.saveCart(context, userId, currentCart);
      // 通知购物车数据已更新
      AppStorage.setOrCreate('cartUpdateTimestamp', Date.now());
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Failed to add item to cart: %{public}s', JSON.stringify(error));
      throw new Error(JSON.stringify(error));
    }
  }
  
  /**
   * 从购物车移除商品
   */
  public static async removeFromCart(context: common.UIAbilityContext, userId: string, productId: number, specs: string): Promise<void> {
    try {
      const currentCart = await ShoppingCartPreferences.loadCart(context, userId);
      const updatedCart = currentCart.filter(item => !(item.productId === productId && item.specs === specs));
      await ShoppingCartPreferences.saveCart(context, userId, updatedCart);
      // 通知购物车数据已更新
      AppStorage.setOrCreate('cartUpdateTimestamp', Date.now());
      hilog.info(DOMAIN, 'CartPersist', 'Removed item %{public}d from cart for user', productId);
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Failed to remove item from cart: %{public}s', JSON.stringify(error));
      throw new Error(JSON.stringify(error));
    }
  }
  
  /**
   * 更新购物车商品数量
   */
  public static async updateQuantity(context: common.UIAbilityContext, userId: string, productId: number, specs: string, quantity: number): Promise<void> {
    try {
      const currentCart = await ShoppingCartPreferences.loadCart(context, userId);
      const itemIndex = currentCart.findIndex(item => item.productId === productId && item.specs === specs);
      
      if (itemIndex !== -1) {
        if (quantity <= 0) {
          // 如果数量为0或负数，从购物车移除
          currentCart.splice(itemIndex, 1);
          hilog.info(DOMAIN, 'CartPersist', 'Removed item %{public}d (quantity <= 0)', productId);
        } else {
          currentCart[itemIndex].quantity = quantity;
          hilog.info(DOMAIN, 'CartPersist', 'Updated quantity for item %{public}d to %{public}d', productId, quantity);
        }
        await ShoppingCartPreferences.saveCart(context, userId, currentCart);
        // 通知购物车数据已更新
        AppStorage.setOrCreate('cartUpdateTimestamp', Date.now());
      }
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Failed to update item quantity: %{public}s', JSON.stringify(error));
      throw new Error(JSON.stringify(error));
    }
  }
  
  /**
   * 清空购物车
   */
  public static async clearCart(context: common.UIAbilityContext, userId: string): Promise<void> {
    try {
      await ShoppingCartPreferences.saveCart(context, userId, []);
      // 通知购物车数据已更新
      AppStorage.setOrCreate('cartUpdateTimestamp', Date.now());
      hilog.info(DOMAIN, 'CartPersist', 'Cleared cart for user %{public}s', userId);
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Failed to clear cart: %{public}s', JSON.stringify(error));
      throw new Error(JSON.stringify(error));
    }
  }
  
  /**
   * 获取购物车商品总数
   */
  public static async getCartItemCount(context: common.UIAbilityContext, userId: string): Promise<number> {
    try {
      const cartItems = await ShoppingCartPreferences.loadCart(context, userId);
      return cartItems.length;
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Failed to get cart item count: %{public}s', JSON.stringify(error));
      return 0;
    }
  }
  
  /**
   * 获取购物车商品总数量（所有商品的数量之和）
   */
  public static async getTotalQuantity(context: common.UIAbilityContext, userId: string): Promise<number> {
    try {
      const cartItems = await ShoppingCartPreferences.loadCart(context, userId);
      return cartItems.reduce((total, item) => total + item.quantity, 0);
    } catch (error) {
      hilog.error(DOMAIN, 'CartPersist', 'Failed to get total quantity: %{public}s', JSON.stringify(error));
      return 0;
    }
  }
}