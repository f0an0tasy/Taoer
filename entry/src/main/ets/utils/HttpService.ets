import { http } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { ServerConfigPreferences } from './ServerConfigPreferences';

const DOMAIN = 0x0000;
const TAG = 'HttpService';

// 默认服务器配置（回退值）
const DEFAULT_IP = '100.64.49.178';
const DEFAULT_PORT = '3000';
const DEFAULT_BASE_URL = `http://${DEFAULT_IP}:${DEFAULT_PORT}`;

// 通用响应结构
export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
}

class HttpService {
  private baseUrl: string = DEFAULT_BASE_URL;
  private configLoaded: boolean = false;
  private context: common.UIAbilityContext | null = null;

  /**
   * 获取 BASE URL（从配置列表动态加载当前激活配置）
   */
  private async getBaseUrl(): Promise<string> {
    // 如果配置已加载，直接返回
    if (this.configLoaded) {
      return this.baseUrl;
    }

    try {
      // 获取上下文（延迟初始化）
      if (!this.context) {
        this.context = getContext(this) as common.UIAbilityContext;
      }

      // 初始化默认配置（如果是首次使用）
      await ServerConfigPreferences.initializeDefaultConfigs(this.context);
      
      // 获取当前激活的配置
      const currentConfig = await ServerConfigPreferences.getCurrentConfig(this.context);
      
      if (currentConfig) {
        this.baseUrl = `http://${currentConfig.ip}:${currentConfig.port}`;
        hilog.info(DOMAIN, TAG, 'Loaded baseUrl from config "%{public}s": %{public}s', 
          currentConfig.name, this.baseUrl);
      } else {
        // 如果没有配置，使用默认值
        this.baseUrl = DEFAULT_BASE_URL;
        hilog.warn(DOMAIN, TAG, 'No config found, using default baseUrl: %{public}s', this.baseUrl);
      }
      
      this.configLoaded = true;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load baseUrl, using default: %{public}s', JSON.stringify(error));
      this.baseUrl = DEFAULT_BASE_URL;
      this.configLoaded = true;
    }

    return this.baseUrl;
  }

  /**
   * 刷新配置（当用户修改服务器配置后调用）
   */
  public async refreshConfig(): Promise<void> {
    this.configLoaded = false;
    await this.getBaseUrl();
    hilog.info(DOMAIN, TAG, 'Config refreshed: %{public}s', this.baseUrl);
  }

  /**
   * 获取当前 BASE URL（同步方法，用于显示）
   */
  public getCurrentBaseUrl(): string {
    return this.baseUrl;
  }
  /**
   * GET 请求
   * @param endpoint 接口路径（不含 BASE_URL）
   * @returns 响应数据
   */
  async get<T>(endpoint: string): Promise<ApiResponse<T>> {
    const baseUrl = await this.getBaseUrl();
    const url = `${baseUrl}${endpoint}`;
    hilog.info(DOMAIN, TAG, `GET request: ${url}`);

    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json'
        },
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      hilog.info(DOMAIN, TAG, `GET response: ${response.responseCode}, body: ${response.result}`);

      if (response.responseCode === 200 || response.responseCode === 201) {
        const responseResult: string | Object = response.result as string | Object;
        const result: Object = typeof responseResult === 'string' 
          ? JSON.parse(responseResult) 
          : responseResult;
        return result as ApiResponse<T>;
      } else {
        return {
          success: false,
          error: `HTTP ${response.responseCode}`
        };
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, `GET error: ${JSON.stringify(error)}`);
      return {
        success: false,
        error: JSON.stringify(error)
      };
    }
  }

  /**
   * POST 请求
   * @param endpoint 接口路径（不含 BASE_URL）
   * @param data 请求体数据
   * @returns 响应数据
   */
  async post<T>(endpoint: string, data?: object): Promise<ApiResponse<T>> {
    const baseUrl = await this.getBaseUrl();
    const url = `${baseUrl}${endpoint}`;
    hilog.info(DOMAIN, TAG, `POST request: ${url}, data: ${JSON.stringify(data)}`);

    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: data,
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      hilog.info(DOMAIN, TAG, `POST response: ${response.responseCode}, body: ${response.result}`);

      if (response.responseCode === 200 || response.responseCode === 201) {
        const responseResult: string | Object = response.result as string | Object;
        const result: Object = typeof responseResult === 'string' 
          ? JSON.parse(responseResult) 
          : responseResult;
        return result as ApiResponse<T>;
      } else {
        return {
          success: false,
          error: `HTTP ${response.responseCode}`
        };
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, `POST error: ${JSON.stringify(error)}`);
      return {
        success: false,
        error: JSON.stringify(error)
      };
    }
  }

  /**
   * PUT 请求
   * @param endpoint 接口路径（不含 BASE_URL）
   * @param data 请求体数据
   * @returns 响应数据
   */
  async put<T>(endpoint: string, data?: object): Promise<ApiResponse<T>> {
    const baseUrl = await this.getBaseUrl();
    const url = `${baseUrl}${endpoint}`;
    hilog.info(DOMAIN, TAG, `PUT request: ${url}, data: ${JSON.stringify(data)}`);

    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.PUT,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: data,
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      hilog.info(DOMAIN, TAG, `PUT response: ${response.responseCode}, body: ${response.result}`);

      if (response.responseCode === 200 || response.responseCode === 201) {
        const responseResult: string | Object = response.result as string | Object;
        const result: Object = typeof responseResult === 'string' 
          ? JSON.parse(responseResult) 
          : responseResult;
        return result as ApiResponse<T>;
      } else {
        return {
          success: false,
          error: `HTTP ${response.responseCode}`
        };
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, `PUT error: ${JSON.stringify(error)}`);
      return {
        success: false,
        error: JSON.stringify(error)
      };
    }
  }

  /**
   * DELETE 请求
   * @param endpoint 接口路径（不含 BASE_URL）
   * @returns 响应数据
   */
  async delete<T>(endpoint: string): Promise<ApiResponse<T>> {
    const baseUrl = await this.getBaseUrl();
    const url = `${baseUrl}${endpoint}`;
    hilog.info(DOMAIN, TAG, `DELETE request: ${url}`);

    try {
      const httpRequest = http.createHttp();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.DELETE,
        header: {
          'Content-Type': 'application/json'
        },
        connectTimeout: 30000,
        readTimeout: 30000
      });

      httpRequest.destroy();

      hilog.info(DOMAIN, TAG, `DELETE response: ${response.responseCode}, body: ${response.result}`);

      if (response.responseCode === 200 || response.responseCode === 201) {
        const responseResult: string | Object = response.result as string | Object;
        const result: Object = typeof responseResult === 'string' 
          ? JSON.parse(responseResult) 
          : responseResult;
        return result as ApiResponse<T>;
      } else {
        return {
          success: false,
          error: `HTTP ${response.responseCode}`
        };
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, `DELETE error: ${JSON.stringify(error)}`);
      return {
        success: false,
        error: JSON.stringify(error)
      };
    }
  }

  /**
   * 将文件 URI 复制到应用沙箱临时目录（支持多种 URI 格式）
   * @param fileUri 文件 URI（如 file://media/... 或沙箱路径 /data/storage/...）
   * @returns 临时文件的沙箱路径，如果复制失败则返回空字符串
   */
  private copyFileToSandbox(fileUri: string): string {
    let srcFile: fs.File | null = null;
    let destFile: fs.File | null = null;
    let tempFilePath: string = '';

    try {
      // 获取应用上下文
      const context = getContext(this) as common.UIAbilityContext;
      
      // 创建临时目录（如果不存在）
      const tmpDir = context.filesDir + '/tmp';
      if (!fs.accessSync(tmpDir)) {
        fs.mkdirSync(tmpDir, true);
      }
      
      // 生成临时文件路径
      const fileName = fileUri.split('/').pop() || `temp_${Date.now()}.jpg`;
      tempFilePath = `${tmpDir}/${Date.now()}_${fileName}`;
      
      hilog.info(DOMAIN, TAG, `=== File Copy Debug ===`);
      hilog.info(DOMAIN, TAG, `Source URI: ${fileUri}`);
      hilog.info(DOMAIN, TAG, `Target path: ${tempFilePath}`);
      hilog.info(DOMAIN, TAG, `Is media URI: ${fileUri.startsWith('file://media')}`);
      hilog.info(DOMAIN, TAG, `Is sandbox path: ${fileUri.startsWith('/data/storage')}`);
      
      // 打开源文件（支持 file://media 和普通路径）
      srcFile = fs.openSync(fileUri, fs.OpenMode.READ_ONLY);
      hilog.info(DOMAIN, TAG, `Source file opened successfully, fd: ${srcFile.fd}`);
      
      // 创建目标文件
      destFile = fs.openSync(tempFilePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      hilog.info(DOMAIN, TAG, `Target file created successfully, fd: ${destFile.fd}`);
      
      // 获取源文件大小
      const stat = fs.statSync(srcFile.fd);
      const fileSize = stat.size;
      hilog.info(DOMAIN, TAG, `Source file size: ${fileSize} bytes`);
      
      if (fileSize === 0) {
        hilog.error(DOMAIN, TAG, `Source file is empty!`);
        tempFilePath = '';
        return tempFilePath;
      }
      
      // 缓冲区大小（4KB）
      const bufferSize = 4096;
      const buffer = new ArrayBuffer(bufferSize);
      
      // 循环读取并写入
      let totalRead = 0;
      let readLen = 0;
      do {
        readLen = fs.readSync(srcFile.fd, buffer);
        if (readLen > 0) {
          fs.writeSync(destFile.fd, buffer, { length: readLen });
          totalRead += readLen;
        }
      } while (readLen > 0);
      
      hilog.info(DOMAIN, TAG, `Copied ${totalRead} bytes to sandbox`);
      hilog.info(DOMAIN, TAG, `======================`);
      
    } catch (error) {
      hilog.error(DOMAIN, TAG, `=== File Copy Error ===`);
      hilog.error(DOMAIN, TAG, `Source URI: ${fileUri}`);
      hilog.error(DOMAIN, TAG, `Target path: ${tempFilePath}`);
      hilog.error(DOMAIN, TAG, `Error details: ${JSON.stringify(error)}`);
      hilog.error(DOMAIN, TAG, `Error message: ${error?.message || 'unknown'}`);
      hilog.error(DOMAIN, TAG, `Error code: ${error?.code || 'unknown'}`);
      hilog.error(DOMAIN, TAG, `=======================`);
      // 如果复制失败，返回空字符串
      tempFilePath = '';
    } finally {
      // 关闭文件
      if (srcFile) {
        try {
          fs.closeSync(srcFile);
          hilog.info(DOMAIN, TAG, `Source file closed`);
        } catch (e) {
          hilog.error(DOMAIN, TAG, `Failed to close source file: ${JSON.stringify(e)}`);
        }
      }
      if (destFile) {
        try {
          fs.closeSync(destFile);
          hilog.info(DOMAIN, TAG, `Target file closed`);
        } catch (e) {
          hilog.error(DOMAIN, TAG, `Failed to close target file: ${JSON.stringify(e)}`);
        }
      }
    }
    
    return tempFilePath;
  }

  /**
   * 文件上传（使用 http 模块和 multiFormDataList 支持 multipart/form-data）
   * @param endpoint 接口路径（不含 BASE_URL）
   * @param fileUri 文件 URI（如 file://media/... 或沙箱路径）
   * @param fileField 表单字段名（如 'avatar', 'productImage', 'cardImage'）
   * @returns 响应数据，data 为服务器返回的图片 URL
   */
  async uploadFile(endpoint: string, fileUri: string, fileField: string): Promise<ApiResponse<string>> {
    const baseUrl = await this.getBaseUrl();
    const url = `${baseUrl}${endpoint}`;
    hilog.info(DOMAIN, TAG, `=== Upload File Debug ===`);
    hilog.info(DOMAIN, TAG, `Endpoint: ${endpoint}`);
    hilog.info(DOMAIN, TAG, `Full URL: ${url}`);
    hilog.info(DOMAIN, TAG, `File URI: ${fileUri}`);
    hilog.info(DOMAIN, TAG, `Field name: ${fileField}`);
    hilog.info(DOMAIN, TAG, `========================`);

    const httpRequest = http.createHttp();
    let tempFilePath: string = ''; // 临时文件路径（用于清理）
    let filePath: string = fileUri; // 实际用于上传的文件路径
    
    try {
      // 检查 URI 类型并处理
      const isMediaUri = fileUri.startsWith('file://media');
      const isSandboxPath = fileUri.startsWith('/data/storage');
      
      hilog.info(DOMAIN, TAG, `URI type analysis:`);
      hilog.info(DOMAIN, TAG, `  - Is media URI: ${isMediaUri}`);
      hilog.info(DOMAIN, TAG, `  - Is sandbox path: ${isSandboxPath}`);
      
      if (isMediaUri) {
        // 媒体库 URI，必须复制到沙箱
        hilog.info(DOMAIN, TAG, `Processing media library URI, copying to sandbox...`);
        tempFilePath = this.copyFileToSandbox(fileUri);
        
        if (!tempFilePath) {
          hilog.error(DOMAIN, TAG, `Failed to copy media file to sandbox`);
          return {
            success: false,
            message: '无法读取媒体文件，请检查权限'
          };
        }
        
        filePath = tempFilePath;
        hilog.info(DOMAIN, TAG, `Using sandbox path: ${filePath}`);
        
      } else if (isSandboxPath) {
        // 沙箱路径，尝试复制到临时目录（避免权限问题）
        hilog.info(DOMAIN, TAG, `Processing sandbox path, attempting to copy to temp...`);
        tempFilePath = this.copyFileToSandbox(fileUri);
        
        if (tempFilePath) {
          // 复制成功，使用临时文件
          filePath = tempFilePath;
          hilog.info(DOMAIN, TAG, `Copied to temp path: ${filePath}`);
        } else {
          // 复制失败，回退使用原路径
          hilog.warn(DOMAIN, TAG, `Copy failed, fallback to original path: ${fileUri}`);
          filePath = fileUri;
        }
        
      } else {
        // 其他格式，直接尝试使用
        hilog.warn(DOMAIN, TAG, `Unknown URI format, attempting direct use: ${fileUri}`);
        filePath = fileUri;
      }
      
      // 验证文件是否存在
      try {
        const fileExists = fs.accessSync(filePath);
        hilog.info(DOMAIN, TAG, `File exists check: ${fileExists}`);
        
        if (!fileExists) {
          hilog.error(DOMAIN, TAG, `File does not exist: ${filePath}`);
          return {
            success: false,
            message: '文件不存在'
          };
        }
        
        // 获取文件大小
        const stat = fs.statSync(filePath);
        hilog.info(DOMAIN, TAG, `File size: ${stat.size} bytes`);
        
        if (stat.size === 0) {
          hilog.error(DOMAIN, TAG, `File is empty: ${filePath}`);
          return {
            success: false,
            message: '文件为空'
          };
        }
      } catch (accessError) {
        hilog.error(DOMAIN, TAG, `File access error: ${JSON.stringify(accessError)}`);
        return {
          success: false,
          message: `文件访问失败: ${accessError?.message || 'unknown'}`
        };
      }
      
      // 生成短文件名，避免服务器端 multer 文件名长度限制
      const originalName = fileUri.split('/').pop() || 'image.jpg';
      const ext = originalName.includes('.') ? originalName.substring(originalName.lastIndexOf('.')) : '.jpg';
      let shortFileName = `upload_${Date.now()}_${Math.floor(Math.random() * 10000)}${ext}`;
      
      // 确保文件名总长度不超过 64 字符
      if (shortFileName.length > 64) {
        shortFileName = shortFileName.substring(0, 64 - ext.length) + ext;
      }
      
      hilog.info(DOMAIN, TAG, `Original name: ${originalName}, Generated short name: ${shortFileName}`);
      hilog.info(DOMAIN, TAG, `Prepared for upload: filePath=${filePath}, fileName=${shortFileName}, field=${fileField}`);

      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'multipart/form-data'
        },
        multiFormDataList: [
          {
            name: fileField,
            contentType: 'image/jpeg',
            filePath: filePath,
            remoteFileName: shortFileName
          }
        ],
        connectTimeout: 30000,
        readTimeout: 30000
      });

      hilog.info(DOMAIN, TAG, `=== Upload Response ===`);
      hilog.info(DOMAIN, TAG, `Status code: ${response.responseCode}`);
      hilog.info(DOMAIN, TAG, `Response body: ${response.result}`);
      hilog.info(DOMAIN, TAG, `======================`);

      if (response.responseCode === 200 || response.responseCode === 201) {
        const responseResult: string | Object = response.result as string | Object;
        const result: Object = typeof responseResult === 'string'
          ? JSON.parse(responseResult)
          : responseResult;

        const apiResult = result as ApiResponse<string>;
        hilog.info(DOMAIN, TAG, `Parsed result: success=${apiResult.success}, data=${apiResult.data}, message=${apiResult.message}`);

        return apiResult;
      } else {
        return {
          success: false,
          message: `上传失败: HTTP ${response.responseCode}`
        };
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, `=== Upload Error ===`);
      hilog.error(DOMAIN, TAG, `File URI: ${fileUri}`);
      hilog.error(DOMAIN, TAG, `File path: ${filePath}`);
      hilog.error(DOMAIN, TAG, `Temp file: ${tempFilePath}`);
      hilog.error(DOMAIN, TAG, `Error details: ${JSON.stringify(error)}`);
      hilog.error(DOMAIN, TAG, `Error message: ${error?.message || 'unknown'}`);
      hilog.error(DOMAIN, TAG, `Error code: ${error?.code || 'unknown'}`);
      hilog.error(DOMAIN, TAG, `====================`);
      return {
        success: false,
        message: `上传异常: ${error?.message || JSON.stringify(error)}`
      };
    } finally {
      httpRequest.destroy();
      
      // 清理临时文件（无论成功或失败）
      if (tempFilePath) {
        try {
          fs.unlinkSync(tempFilePath);
          hilog.info(DOMAIN, TAG, `Cleaned up temp file: ${tempFilePath}`);
        } catch (e) {
          hilog.error(DOMAIN, TAG, `Failed to clean up temp file: ${tempFilePath}, error: ${JSON.stringify(e)}`);
        }
      }
    }
  }
}

// 导出单例
export const httpService = new HttpService();
