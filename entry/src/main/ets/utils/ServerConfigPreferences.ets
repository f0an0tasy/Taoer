import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'ServerConfigPrefs';

// 服务器配置项接口
export interface ServerConfig {
  id: string;           // 唯一标识（时间戳）
  name: string;         // 配置名称（如"校园热点"、"宿舍WiFi"）
  ip: string;           // IP地址
  port: string;         // 端口号
  isCurrent: boolean;   // 是否为当前激活配置
}

// Preferences 配置键
const PREFS_NAME = 'ServerConfig';
const KEY_SERVER_CONFIGS = 'server_configs';       // 配置列表
const KEY_CURRENT_CONFIG_ID = 'current_config_id'; // 当前激活配置ID

// 默认配置
const DEFAULT_CONFIGS: ServerConfig[] = [
  {
    id: '1',
    name: 'CSU-Student',
    ip: '100.64.49.178',
    port: '3000',
    isCurrent: true
  },
  {
    id: '2',
    name: 'iPhone15pro热点',
    ip: '172.20.10.2',
    port: '3000',
    isCurrent: false
  }
];

export class ServerConfigPreferences {
  /**
   * 获取Preferences实例
   */
  private static async getPreferences(context: common.UIAbilityContext): Promise<preferences.Preferences> {
    return await preferences.getPreferences(context, PREFS_NAME);
  }

  /**
   * 初始化默认配置（首次使用时调用）
   */
  public static async initializeDefaultConfigs(context: common.UIAbilityContext): Promise<void> {
    try {
      const pref = await ServerConfigPreferences.getPreferences(context);
      const existingConfigs = await pref.get(KEY_SERVER_CONFIGS, '') as string;
      
      // 如果配置列表为空，初始化默认配置
      if (!existingConfigs) {
        const configsJson = JSON.stringify(DEFAULT_CONFIGS);
        await pref.put(KEY_SERVER_CONFIGS, configsJson);
        await pref.put(KEY_CURRENT_CONFIG_ID, DEFAULT_CONFIGS[0].id);
        await pref.flush();
        hilog.info(DOMAIN, TAG, 'Initialized default server configs');
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize default configs: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 加载所有服务器配置
   */
  public static async loadConfigs(context: common.UIAbilityContext): Promise<ServerConfig[]> {
    try {
      const pref = await ServerConfigPreferences.getPreferences(context);
      const configsJson = await pref.get(KEY_SERVER_CONFIGS, '') as string;
      
      if (!configsJson) {
        // 如果没有配置，初始化默认配置
        await ServerConfigPreferences.initializeDefaultConfigs(context);
        return DEFAULT_CONFIGS;
      }
      
      const configs = JSON.parse(configsJson) as ServerConfig[];
      hilog.info(DOMAIN, TAG, 'Loaded %{public}d server configs', configs.length);
      return configs;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load configs: %{public}s', JSON.stringify(error));
      return DEFAULT_CONFIGS;
    }
  }

  /**
   * 保存所有服务器配置
   */
  public static async saveConfigs(context: common.UIAbilityContext, configs: ServerConfig[]): Promise<void> {
    try {
      const pref = await ServerConfigPreferences.getPreferences(context);
      const configsJson = JSON.stringify(configs);
      await pref.put(KEY_SERVER_CONFIGS, configsJson);
      await pref.flush();
      
      // 通知配置已更新
      AppStorage.setOrCreate('serverConfigUpdated', Date.now());
      
      hilog.info(DOMAIN, TAG, 'Saved %{public}d server configs', configs.length);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to save configs: %{public}s', JSON.stringify(error));
      throw new Error(JSON.stringify(error));
    }
  }

  /**
   * 获取当前激活的配置
   */
  public static async getCurrentConfig(context: common.UIAbilityContext): Promise<ServerConfig | null> {
    try {
      const configs = await ServerConfigPreferences.loadConfigs(context);
      const currentConfig = configs.find(c => c.isCurrent);
      
      if (currentConfig) {
        return currentConfig;
      }
      
      // 如果没有当前配置，返回第一个配置
      if (configs.length > 0) {
        return configs[0];
      }
      
      return null;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to get current config: %{public}s', JSON.stringify(error));
      return null;
    }
  }

  /**
   * 切换当前激活配置
   */
  public static async switchConfig(context: common.UIAbilityContext, configId: string): Promise<void> {
    try {
      const configs = await ServerConfigPreferences.loadConfigs(context);
      
      // 更新所有配置的 isCurrent 状态
      configs.forEach(config => {
        config.isCurrent = config.id === configId;
      });
      
      await ServerConfigPreferences.saveConfigs(context, configs);
      
      // 更新当前配置ID
      const pref = await ServerConfigPreferences.getPreferences(context);
      await pref.put(KEY_CURRENT_CONFIG_ID, configId);
      await pref.flush();
      
      hilog.info(DOMAIN, TAG, 'Switched to config: %{public}s', configId);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to switch config: %{public}s', JSON.stringify(error));
      throw new Error(JSON.stringify(error));
    }
  }

  /**
   * 添加新配置
   */
  public static async addConfig(context: common.UIAbilityContext, config: ServerConfig): Promise<void> {
    try {
      const configs = await ServerConfigPreferences.loadConfigs(context);
      
      // 如果新配置设为当前，取消其他配置的当前状态
      if (config.isCurrent) {
        configs.forEach(c => c.isCurrent = false);
      }
      
      configs.push(config);
      await ServerConfigPreferences.saveConfigs(context, configs);
      
      hilog.info(DOMAIN, TAG, 'Added new config: %{public}s', config.name);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to add config: %{public}s', JSON.stringify(error));
      throw new Error(JSON.stringify(error));
    }
  }

  /**
   * 删除配置
   */
  public static async deleteConfig(context: common.UIAbilityContext, configId: string): Promise<void> {
    try {
      const configs = await ServerConfigPreferences.loadConfigs(context);
      
      // 至少保留一个配置
      if (configs.length <= 1) {
        throw new Error('至少保留一个配置');
      }
      
      // 找到要删除的配置
      const configToDelete = configs.find(c => c.id === configId);
      const wasCurrent = configToDelete?.isCurrent || false;
      
      // 过滤掉要删除的配置
      const updatedConfigs = configs.filter(c => c.id !== configId);
      
      // 如果删除的是当前配置，自动激活第一个配置
      if (wasCurrent && updatedConfigs.length > 0) {
        updatedConfigs[0].isCurrent = true;
      }
      
      await ServerConfigPreferences.saveConfigs(context, updatedConfigs);
      
      hilog.info(DOMAIN, TAG, 'Deleted config: %{public}s', configId);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to delete config: %{public}s', JSON.stringify(error));
      throw new Error(JSON.stringify(error));
    }
  }

  /**
   * 更新配置
   */
  public static async updateConfig(context: common.UIAbilityContext, config: ServerConfig): Promise<void> {
    try {
      const configs = await ServerConfigPreferences.loadConfigs(context);
      const index = configs.findIndex(c => c.id === config.id);
      
      if (index !== -1) {
        // 如果更新后的配置设为当前，取消其他配置的当前状态
        if (config.isCurrent) {
          configs.forEach(c => c.isCurrent = false);
        }
        
        configs[index] = config;
        await ServerConfigPreferences.saveConfigs(context, configs);
        
        hilog.info(DOMAIN, TAG, 'Updated config: %{public}s', config.name);
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to update config: %{public}s', JSON.stringify(error));
      throw new Error(JSON.stringify(error));
    }
  }

  /**
   * 验证IP格式
   */
  public static validateIp(ip: string): boolean {
    const ipPattern = /^(\d{1,3}\.){3}\d{1,3}$/;
    if (!ipPattern.test(ip)) {
      return false;
    }
    
    // 验证每个数字范围
    const parts = ip.split('.');
    for (const part of parts) {
      const num = parseInt(part);
      if (isNaN(num) || num < 0 || num > 255) {
        return false;
      }
    }
    
    return true;
  }

  /**
   * 验证端口号
   */
  public static validatePort(port: string): boolean {
    const portNum = parseInt(port);
    return !isNaN(portNum) && portNum >= 1 && portNum <= 65535;
  }

  /**
   * 生成唯一ID
   */
  public static generateId(): string {
    return Date.now().toString();
  }
}
