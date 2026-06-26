import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { http } from '@kit.NetworkKit';
import { ServerConfigPreferences, ServerConfig } from '../utils/ServerConfigPreferences';

const DOMAIN = 0x0000;
const TAG = 'ServerConfigPage';

@Entry
@Component
struct ServerConfigPage {
  // 配置列表
  @State configs: ServerConfig[] = [];
  
  // 刷新标识，用于强制刷新ForEach
  @State refreshFlag: number = 0;
  
  // 新配置输入
  @State newConfigName: string = '';
  @State newConfigIp: string = '';
  @State newConfigPort: string = '';
  
  // 当前激活配置
  @State currentConfig: ServerConfig | null = null;
  
  // UI状态
  @State isTesting: boolean = false;
  @State showDeleteDialog: boolean = false;
  @State configToDelete: ServerConfig | null = null;
  
  private context: common.UIAbilityContext | null = null;

  async aboutToAppear() {
    // 获取上下文
    this.context = getContext(this) as common.UIAbilityContext;
    
    // 初始化默认配置（如果是首次使用）
    await ServerConfigPreferences.initializeDefaultConfigs(this.context);
    
    // 加载配置列表
    await this.loadConfigs();
  }

  /**
   * 加载配置列表
   */
  private async loadConfigs(): Promise<void> {
    try {
      if (!this.context) {
        hilog.error(DOMAIN, TAG, 'Context is null');
        return;
      }

      // 加载配置列表 - 创建新数组引用以确保ForEach重新渲染
      const loadedConfigs = await ServerConfigPreferences.loadConfigs(this.context);
      this.configs = [...loadedConfigs]; // 使用展开运算符创建新数组引用
      
      // 加载当前配置
      this.currentConfig = await ServerConfigPreferences.getCurrentConfig(this.context);
      
      // 添加详细日志，确认数据更新
      hilog.info(DOMAIN, TAG, 'Loaded %{public}d configs', this.configs.length);
      hilog.info(DOMAIN, TAG, 'Current config: %{public}s', 
        this.currentConfig ? `${this.currentConfig.name} (id: ${this.currentConfig.id})` : 'null');
      
      // 打印每个配置的isCurrent状态
      this.configs.forEach((config, index) => {
        hilog.info(DOMAIN, TAG, 'Config[%{public}d]: %{public}s, isCurrent=%{public}s', 
          index, config.name, config.isCurrent.toString());
      });
      
      // 触发强制刷新
      this.refreshFlag++;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to load configs: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 添加新配置
   */
  private async addConfig(): Promise<void> {
    // 验证输入
    if (!this.newConfigName || !this.newConfigIp || !this.newConfigPort) {
      promptAction.showToast({ message: '请填写完整信息' });
      return;
    }

    // 验证IP格式
    if (!ServerConfigPreferences.validateIp(this.newConfigIp)) {
      promptAction.showToast({ message: 'IP地址格式不正确' });
      return;
    }

    // 验证端口号
    if (!ServerConfigPreferences.validatePort(this.newConfigPort)) {
      promptAction.showToast({ message: '端口号范围应为1-65535' });
      return;
    }

    try {
      if (!this.context) {
        hilog.error(DOMAIN, TAG, 'Context is null');
        return;
      }

      // 创建新配置
      const newConfig: ServerConfig = {
        id: ServerConfigPreferences.generateId(),
        name: this.newConfigName,
        ip: this.newConfigIp,
        port: this.newConfigPort,
        isCurrent: true  // 新添加的配置自动设为当前
      };

      // 保存配置
      await ServerConfigPreferences.addConfig(this.context, newConfig);
      
      // 清空输入
      this.newConfigName = '';
      this.newConfigIp = '';
      this.newConfigPort = '';
      
      // 重新加载配置列表
      await this.loadConfigs();
      
      promptAction.showToast({ message: '配置已添加并设为当前' });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to add config: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '添加失败，请重试' });
    }
  }

  /**
   * 切换配置
   */
  private async switchConfig(config: ServerConfig): Promise<void> {
    try {
      if (!this.context) {
        hilog.error(DOMAIN, TAG, 'Context is null');
        return;
      }

      hilog.info(DOMAIN, TAG, 'Switching to config: %{public}s (id: %{public}s)', config.name, config.id);
      
      // 切换配置
      await ServerConfigPreferences.switchConfig(this.context, config.id);
      
      // 重新加载配置列表 - 确保UI状态同步
      await this.loadConfigs();
      
      // 强制触发UI更新 - 通过创建新数组引用
      this.configs = [...this.configs];
      
      hilog.info(DOMAIN, TAG, 'Switch completed. Current config: %{public}s', 
        this.currentConfig ? this.currentConfig.name : 'null');
      
      promptAction.showToast({ message: `已切换到 ${config.name}` });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to switch config: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '切换失败，请重试' });
    }
  }

  /**
   * 显示删除确认对话框
   */
  private showDeleteConfirm(config: ServerConfig): void {
    this.configToDelete = config;
    this.showDeleteDialog = true;
  }

  /**
   * 确认删除配置
   */
  private async confirmDelete(): Promise<void> {
    if (!this.configToDelete || !this.context) {
      return;
    }

    try {
      await ServerConfigPreferences.deleteConfig(this.context, this.configToDelete.id);
      await this.loadConfigs();
      
      promptAction.showToast({ message: '配置已删除' });
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to delete config: %{public}s', JSON.stringify(error));
      const errorMsg = error instanceof Error ? error.message : '删除失败';
      promptAction.showToast({ message: errorMsg });
    } finally {
      this.showDeleteDialog = false;
      this.configToDelete = null;
    }
  }

  /**
   * 测试当前配置连接
   */
  private async testConnection(): Promise<void> {
    if (!this.currentConfig) {
      promptAction.showToast({ message: '请先选择一个配置' });
      return;
    }

    this.isTesting = true;
    promptAction.showToast({ message: '正在测试连接...' });

    try {
      const url = `http://${this.currentConfig.ip}:${this.currentConfig.port}/api/products`;
      hilog.info(DOMAIN, TAG, 'Testing connection: %{public}s', url);

      const httpRequest = http.createHttp();
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'Content-Type': 'application/json'
        },
        connectTimeout: 10000,
        readTimeout: 10000
      });

      httpRequest.destroy();

      hilog.info(DOMAIN, TAG, 'Test response: %{public}d', response.responseCode);

      if (response.responseCode === 200 || response.responseCode === 201) {
        promptAction.showToast({ message: '连接成功' });
      } else {
        promptAction.showToast({ message: `连接失败：HTTP ${response.responseCode}` });
      }
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Test connection error: %{public}s', JSON.stringify(error));
      promptAction.showToast({ message: '连接失败，请检查地址' });
    } finally {
      this.isTesting = false;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('<')
          .fontSize(24)
          .onClick(() => router.back())
          .width(50)
          .height(50)
          .textAlign(TextAlign.Center)
        
        Text('服务器设置')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        Blank().width(50)
      }
      .width('100%')
      .height(60)
      .backgroundColor('#ffffff')
      .shadow({ radius: 2, color: '#e0e0e0', offsetY: 2 })

      Scroll() {
        Column({ space: 20 }) {
          // ========== 上半部分：添加新配置 ==========
          Column({ space: 15 }) {
            Text('添加新配置')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')
            
            // 配置名称输入
            Column({ space: 8 }) {
              Text('配置名称')
                .fontSize(14)
                .fontColor('#666666')
                .width('100%')
              
              TextInput({ placeholder: '如：校园热点、宿舍WiFi', text: this.newConfigName })
                .width('100%')
                .height(45)
                .backgroundColor('#f5f5f5')
                .borderRadius(8)
                .type(InputType.Normal)
                .onChange((value: string) => {
                  this.newConfigName = value;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // IP地址输入
            Column({ space: 8 }) {
              Text('IP地址')
                .fontSize(14)
                .fontColor('#666666')
                .width('100%')
              
              TextInput({ placeholder: '例如：192.168.1.100', text: this.newConfigIp })
                .width('100%')
                .height(45)
                .backgroundColor('#f5f5f5')
                .borderRadius(8)
                .type(InputType.Normal)
                .onChange((value: string) => {
                  this.newConfigIp = value;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 端口号输入
            Column({ space: 8 }) {
              Text('端口号')
                .fontSize(14)
                .fontColor('#666666')
                .width('100%')
              
              TextInput({ placeholder: '例如：3000', text: this.newConfigPort })
                .width('100%')
                .height(45)
                .backgroundColor('#f5f5f5')
                .borderRadius(8)
                .type(InputType.Number)
                .onChange((value: string) => {
                  this.newConfigPort = value;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 添加按钮
            Button('添加并保存')
              .width('100%')
              .height(45)
              .fontSize(16)
              .backgroundColor('#007DFF')
              .fontColor('#ffffff')
              .borderRadius(8)
              .onClick(() => this.addConfig())
          }
          .width('90%')
          .padding(15)
          .backgroundColor('#ffffff')
          .borderRadius(12)

          // ========== 下半部分：已有配置列表 ==========
          Column({ space: 15 }) {
            Text('已保存配置')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .width('100%')

            // 配置列表
            ForEach(this.configs, (config: ServerConfig) => {
              Row() {
                // 配置信息
                Column({ space: 4 }) {
                  Text(config.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#333333')
                  
                  Text(`${config.ip}:${config.port}`)
                    .fontSize(12)
                    .fontColor('#999999')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 当前使用徽章
                if (config.isCurrent) {
                  Text('✅ 当前使用')
                    .fontSize(12)
                    .fontColor('#007DFF')
                    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                    .backgroundColor('#E8F4FF')
                    .borderRadius(4)
                }

                // 删除按钮
                Button({ type: ButtonType.Circle }) {
                  Text('🗑️')
                    .fontSize(18)
                }
                .width(36)
                .height(36)
                .backgroundColor('#f5f5f5')
                .margin({ left: 10 })
                .onClick(() => this.showDeleteConfirm(config))
              }
              .width('100%')
              .padding(12)
              .backgroundColor(config.isCurrent ? '#F0F8FF' : '#f9f9f9')
              .borderRadius(8)
              .border({ width: config.isCurrent ? 1 : 0, color: '#007DFF' })
              .onClick(() => {
                if (!config.isCurrent) {
                  this.switchConfig(config);
                }
              })
            }, (config: ServerConfig) => `${config.id}_${this.refreshFlag}`)

            // 当前服务器地址显示
            if (this.currentConfig) {
              Column() {
                Text('当前服务器地址')
                  .fontSize(14)
                  .fontColor('#666666')
                  .margin({ bottom: 8 })
                
                Text(`http://${this.currentConfig.ip}:${this.currentConfig.port}`)
                  .fontSize(16)
                  .fontColor('#333333')
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .padding(15)
              .backgroundColor('#f0f0f0')
              .borderRadius(8)
              .margin({ top: 10 })
            }

            // 测试连接按钮
            Button('测试连接')
              .width('100%')
              .height(45)
              .fontSize(16)
              .backgroundColor('#ffffff')
              .fontColor('#333333')
              .borderRadius(8)
              .border({ width: 1, color: '#e0e0e0' })
              .enabled(!this.isTesting)
              .onClick(() => this.testConnection())
          }
          .width('90%')
          .padding(15)
          .backgroundColor('#ffffff')
          .borderRadius(12)

          // 帮助提示
          Column() {
            Text('提示：')
              .fontSize(12)
              .fontColor('#999999')
              .fontWeight(FontWeight.Bold)
            
            Text('1. 点击配置项可快速切换服务器')
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 5 })
            
            Text('2. 至少保留一个配置')
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 3 })
            
            Text('3. 新添加的配置自动设为当前使用')
              .fontSize(12)
              .fontColor('#999999')
              .margin({ top: 3 })
          }
          .width('90%')
          .alignItems(HorizontalAlign.Start)
          .margin({ top: 10 })
        }
        .width('100%')
        .margin({ top: 20 })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
    .bindSheet($$this.showDeleteDialog, this.deleteDialogBuilder(), {
      height: 200,
      backgroundColor: Color.White,
      dragBar: false
    })
  }

  /**
   * 删除确认对话框构建器
   */
  @Builder
  deleteDialogBuilder() {
    Column({ space: 20 }) {
      Text('确认删除')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
      
      Text(`确定要删除配置"${this.configToDelete?.name}"吗？`)
        .fontSize(14)
        .fontColor('#666666')
      
      Row({ space: 15 }) {
        Button('取消')
          .width('40%')
          .height(40)
          .backgroundColor('#f5f5f5')
          .fontColor('#333333')
          .onClick(() => {
            this.showDeleteDialog = false;
            this.configToDelete = null;
          })
        
        Button('删除')
          .width('40%')
          .height(40)
          .backgroundColor('#FF4444')
          .fontColor('#ffffff')
          .onClick(() => this.confirmDelete())
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .padding(20)
  }
}
