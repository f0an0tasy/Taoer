import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { httpService, ApiResponse } from '../utils/HttpService';

const DOMAIN = 0x0000;
const TAG = 'DatabaseManager';

// 数据模型接口
export interface User {
  id?: number;
  username: string;
  password?: string;
  avatar?: string;
  studentId?: string;
  cardImage?: string;
}

export interface Product {
  id?: number;
  publisherId: number;
  title: string;
  content: string;
  price: number;
  category: string;
  image: string; // 保留兼容旧数据
  images?: string[]; // 新增多图字段
  specs: string;
}

export interface Order {
  id?: number;
  orderNo: string;
  productId: number;
  productTitle: string;
  productImage: string;
  price: number;
  quantity: number;
  specs: string;
  createTime: number;
  userId: number;
  address?: string;
  status?: string;
  sellerId?: number;
  shippingMethod?: string;
  trackingNumber?: string;
  shippingAddress?: string;
  buyerAddress?: string;
  refundStatus?: string;
}

export interface Favorite {
  id?: number;
  userId: number;
  productId: number;
  createTime: number;
}

export interface ProductWithFavoriteTime extends Product {
  favoriteTime: number;
}

export interface Comment {
  id?: number;
  orderId: number;
  productId: number;
  userId: number;
  userName: string;
  userAvatar?: string;
  content: string;
  createTime: number;
  rating: number;
}

export interface Address {
  id?: number;
  userId: number;
  consignee: string;
  phone: string;
  province: string;
  city: string;
  district: string;
  detailAddress: string;
  tag?: string;
  isDefault: number;
  createTime: number;
}

export interface Refund {
  id?: number;
  orderId: number;
  orderNo: string;
  userId: number;
  sellerId: number;
  productId: number;
  reason: string;
  description?: string;
  status: string;
  type: string;
  applyTime: number;
  processTime?: number;
  reply?: string;
}

// 评价结果接口，包含成功状态和消息
export interface CommentResult {
  success: boolean;
  message: string;
}

// 请求参数接口
interface LoginRequest {
  username: string;
  password: string;
}

interface UpdatePasswordRequest {
  newPassword: string;
}

interface UpdateUsernameRequest {
  newUsername: string;
}

interface UpdateAvatarRequest {
  avatarPath: string;
}

interface UpdateStatusRequest {
  status: string;
}

interface UpdateRefundStatusRequest {
  refundStatus: string;
}

interface ShippingRequest {
  shippingMethod: string;
  trackingNumber: string;
  shippingAddress: string;
}

interface FavoriteRequest {
  userId: number;
  productId: number;
}

interface SetDefaultAddressRequest {
  userId: number;
}

interface ProcessRefundRequest {
  status: string;
  reply: string;
}

interface CreateOrderRequest {
  orderNo: string;
  productId: number;
  productTitle: string;
  productImage: string;
  price: number;
  quantity: number;
  specs: string;
  createTime: number;
  userId: number;
  address?: string;
  status?: string;
  sellerId?: number;
  shippingMethod?: string;
  trackingNumber?: string;
  shippingAddress?: string;
  buyerAddress?: string;
  refundStatus?: string;
}

interface AddCommentRequest {
  orderId: number;
  productId: number;
  userId: number;
  userName: string;
  content: string;
  rating: number;
  userAvatar?: string;
}

class DatabaseManager {
  // 初始化 - 网络模式下无需初始化本地数据库
  async init(context: common.UIAbilityContext): Promise<void> {
    hilog.info(DOMAIN, TAG, 'DatabaseManager initialized (network mode)');
  }

  // --- User Operations ---
  async checkUsernameExists(username: string): Promise<boolean> {
    const response = await httpService.get<boolean>(`/api/users/check?username=${encodeURIComponent(username)}`);
    return response.success && response.data === true;
  }

  async register(user: User): Promise<number> {
    const response = await httpService.post<number>('/api/users/register', user);
    return response.success && response.data ? response.data : -1;
  }

  async login(username: string, password: string): Promise<User | null> {
    const loginData: LoginRequest = { username, password };
    const response = await httpService.post<User>('/api/users/login', loginData);
    return response.success && response.data ? response.data : null;
  }

  async updatePassword(userId: number, newPassword: string): Promise<boolean> {
    const data: UpdatePasswordRequest = { newPassword };
    const response = await httpService.put<boolean>(`/api/users/${userId}/password`, data);
    return response.success && response.data === true;
  }

  async updateUsername(userId: number, newUsername: string): Promise<boolean> {
    const data: UpdateUsernameRequest = { newUsername };
    const response = await httpService.put<boolean>(`/api/users/${userId}/username`, data);
    return response.success && response.data === true;
  }

  async updateUserAvatar(userId: number, avatarPath: string): Promise<boolean> {
    const data: UpdateAvatarRequest = { avatarPath };
    const response = await httpService.put<boolean>(`/api/users/${userId}/avatar`, data);
    return response.success && response.data === true;
  }

  async isUsernameExist(username: string, excludeUserId?: number): Promise<boolean> {
    const params = excludeUserId !== undefined 
      ? `?username=${encodeURIComponent(username)}&excludeUserId=${excludeUserId}`
      : `?username=${encodeURIComponent(username)}`;
    const response = await httpService.get<boolean>(`/api/users/exists${params}`);
    return response.success && response.data === true;
  }

  async getUserById(userId: number): Promise<User | null> {
    const response = await httpService.get<User>(`/api/users/${userId}`);
    return response.success && response.data ? response.data : null;
  }

  // --- Product Operations ---
  async insertProduct(p: Product): Promise<number> {
    const response = await httpService.post<number>('/api/products', p);
    return response.success && response.data ? response.data : -1;
  }

  async queryProductCount(): Promise<number> {
    const response = await httpService.get<number>('/api/products/count');
    return response.success && response.data ? response.data : 0;
  }

  async getAllProducts(keyword: string = ''): Promise<Product[]> {
    const params = keyword ? `?keyword=${encodeURIComponent(keyword)}` : '';
    const response = await httpService.get<Product[]>(`/api/products${params}`);
    return response.success && response.data ? response.data : [];
  }

  async getProductsByCategory(category: string): Promise<Product[]> {
    const response = await httpService.get<Product[]>(`/api/products/category/${encodeURIComponent(category)}`);
    return response.success && response.data ? response.data : [];
  }

  async getProductsByPublisher(userId: number): Promise<Product[]> {
    const response = await httpService.get<Product[]>(`/api/products/publisher/${userId}`);
    return response.success && response.data ? response.data : [];
  }

  async deleteProduct(id: number): Promise<number> {
    const response = await httpService.delete<number>(`/api/products/${id}`);
    return response.success && response.data ? response.data : -1;
  }

  async getProductById(productId: number): Promise<Product | null> {
    const response = await httpService.get<Product>(`/api/products/${productId}`);
    return response.success && response.data ? response.data : null;
  }

  // --- Order Operations ---
  async createOrder(order: Order, userId: number): Promise<number> {
    const orderData: CreateOrderRequest = {
      orderNo: order.orderNo,
      productId: order.productId,
      productTitle: order.productTitle,
      productImage: order.productImage,
      price: order.price,
      quantity: order.quantity,
      specs: order.specs,
      createTime: order.createTime,
      userId: userId,
      address: order.address,
      status: order.status,
      sellerId: order.sellerId,
      shippingMethod: order.shippingMethod,
      trackingNumber: order.trackingNumber,
      shippingAddress: order.shippingAddress,
      buyerAddress: order.buyerAddress,
      refundStatus: order.refundStatus
    };
    const response = await httpService.post<number>('/api/orders', orderData);
    return response.success && response.data ? response.data : -1;
  }

  async getOrders(userId: number, keyword: string = ''): Promise<Order[]> {
    const params = keyword ? `?keyword=${encodeURIComponent(keyword)}` : '';
    const response = await httpService.get<Order[]>(`/api/orders/user/${userId}${params}`);
    return response.success && response.data ? response.data : [];
  }

  async deleteOrder(id: number, userId: number): Promise<number> {
    const response = await httpService.delete<number>(`/api/orders/${id}?userId=${userId}`);
    return response.success && response.data ? response.data : -1;
  }

  async getSellerOrders(sellerId: number): Promise<Order[]> {
    const response = await httpService.get<Order[]>(`/api/orders/seller/${sellerId}`);
    return response.success && response.data ? response.data : [];
  }

  async updateOrderStatus(orderId: number, status: string): Promise<boolean> {
    const data: UpdateStatusRequest = { status };
    const response = await httpService.put<boolean>(`/api/orders/${orderId}/status`, data);
    return response.success && response.data === true;
  }

  async updateOrderShipping(orderId: number, shippingMethod: string, trackingNumber: string, shippingAddress: string): Promise<boolean> {
    const data: ShippingRequest = { 
      shippingMethod, 
      trackingNumber, 
      shippingAddress 
    };
    const response = await httpService.put<boolean>(`/api/orders/${orderId}/shipping`, data);
    return response.success && response.data === true;
  }

  async getOrderById(orderId: number): Promise<Order | null> {
    const response = await httpService.get<Order>(`/api/orders/${orderId}`);
    return response.success && response.data ? response.data : null;
  }

  async deleteOrderForSeller(orderId: number, sellerId: number): Promise<boolean> {
    const response = await httpService.delete<boolean>(`/api/orders/${orderId}/seller?sellerId=${sellerId}`);
    return response.success && response.data === true;
  }

  async updateOrderRefundStatus(orderId: number, refundStatus: string): Promise<boolean> {
    const data: UpdateRefundStatusRequest = { refundStatus };
    const response = await httpService.put<boolean>(`/api/orders/${orderId}/refund-status`, data);
    return response.success && response.data === true;
  }

  // --- Favorite Operations ---
  async addFavorite(userId: number, productId: number): Promise<boolean> {
    const data: FavoriteRequest = { userId, productId };
    const response = await httpService.post<boolean>('/api/favorites', data);
    return response.success && response.data === true;
  }

  async removeFavorite(userId: number, productId: number): Promise<boolean> {
    const response = await httpService.delete<boolean>(`/api/favorites?userId=${userId}&productId=${productId}`);
    return response.success && response.data === true;
  }

  async isFavorite(userId: number, productId: number): Promise<boolean> {
    const response = await httpService.get<boolean>(`/api/favorites/check?userId=${userId}&productId=${productId}`);
    return response.success && response.data === true;
  }

  async getFavoritesByUser(userId: number): Promise<ProductWithFavoriteTime[]> {
    const response = await httpService.get<ProductWithFavoriteTime[]>(`/api/favorites/user/${userId}`);
    return response.success && response.data ? response.data : [];
  }

  // --- Comment Operations ---
  async addComment(orderId: number, productId: number, userId: number, userName: string, content: string, rating: number, userAvatar?: string): Promise<CommentResult> {
    const data: AddCommentRequest = { 
      orderId, 
      productId, 
      userId, 
      userName, 
      content, 
      rating, 
      userAvatar 
    };
    // 服务器返回 data 为新创建的评价记录 ID（数字），不是布尔值
    const response = await httpService.post<number>('/api/comments', data);
    
    hilog.info(DOMAIN, TAG, `addComment response: success=${response.success}, data=${response.data}, message=${response.message}`);
    
    // 返回详细结果，包含 success 和 message
    // 只要 response.success 为 true 且 data 存在（有有效的评价ID），即为成功
    return {
      success: response.success === true && response.data !== undefined && response.data !== null,
      message: response.message || (response.success ? '评价成功' : '评价失败')
    };
  }

  async getCommentsByProductId(productId: number): Promise<Comment[]> {
    const response = await httpService.get<Comment[]>(`/api/comments/product/${productId}`);
    return response.success && response.data ? response.data : [];
  }

  async hasCommented(orderId: number, productId: number, userId: number): Promise<boolean> {
    const response = await httpService.get<boolean>(`/api/comments/check?orderId=${orderId}&productId=${productId}&userId=${userId}`);
    return response.success && response.data === true;
  }

  // --- Address Operations ---
  async getAddressList(userId: number): Promise<Address[]> {
    const response = await httpService.get<Address[]>(`/api/addresses/user/${userId}`);
    return response.success && response.data ? response.data : [];
  }

  async addAddress(address: Address): Promise<number> {
    const response = await httpService.post<number>('/api/addresses', address);
    return response.success && response.data ? response.data : -1;
  }

  async updateAddress(address: Address): Promise<boolean> {
    const response = await httpService.put<boolean>(`/api/addresses/${address.id}`, address);
    return response.success && response.data === true;
  }

  async deleteAddress(addressId: number): Promise<boolean> {
    const response = await httpService.delete<boolean>(`/api/addresses/${addressId}`);
    return response.success && response.data === true;
  }

  async setDefaultAddress(userId: number, addressId: number): Promise<boolean> {
    const data: SetDefaultAddressRequest = { userId };
    const response = await httpService.put<boolean>(`/api/addresses/${addressId}/default`, data);
    return response.success && response.data === true;
  }

  async getDefaultAddress(userId: number): Promise<Address | null> {
    const response = await httpService.get<Address>(`/api/addresses/default/${userId}`);
    return response.success && response.data ? response.data : null;
  }

  async getAddressById(addressId: number): Promise<Address | null> {
    const response = await httpService.get<Address>(`/api/addresses/${addressId}`);
    return response.success && response.data ? response.data : null;
  }

  // --- Refund Operations ---
  async applyRefund(refund: Refund): Promise<number> {
    const response = await httpService.post<number>('/api/refunds', refund);
    return response.success && response.data ? response.data : -1;
  }

  async getRefundByOrderId(orderId: number): Promise<Refund | null> {
    const response = await httpService.get<Refund>(`/api/refunds/order/${orderId}`);
    return response.success && response.data ? response.data : null;
  }

  async getRefundsForSeller(sellerId: number): Promise<Refund[]> {
    const response = await httpService.get<Refund[]>(`/api/refunds/seller/${sellerId}`);
    return response.success && response.data ? response.data : [];
  }

  async getRefundById(refundId: number): Promise<Refund | null> {
    const response = await httpService.get<Refund>(`/api/refunds/${refundId}`);
    return response.success && response.data ? response.data : null;
  }

  async processRefund(refundId: number, status: string, reply: string): Promise<boolean> {
    const data: ProcessRefundRequest = { status, reply };
    const response = await httpService.put<boolean>(`/api/refunds/${refundId}/process`, data);
    return response.success && response.data === true;
  }

  async deleteRefund(refundId: number, sellerId: number): Promise<boolean> {
    const response = await httpService.delete<boolean>(`/api/refunds/${refundId}?sellerId=${sellerId}`);
    return response.success && response.data === true;
  }

  async getRefundsForUser(userId: number): Promise<Refund[]> {
    const response = await httpService.get<Refund[]>(`/api/refunds/user/${userId}`);
    return response.success && response.data ? response.data : [];
  }
}

// 导出单例
export const dbManager = new DatabaseManager();
