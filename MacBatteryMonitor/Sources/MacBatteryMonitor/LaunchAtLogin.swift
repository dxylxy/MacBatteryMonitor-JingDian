import ServiceManagement

/// 开机自启动管理
enum LaunchAtLogin {
    /// 注册自启动
    static func register() {
        try? SMAppService.mainApp.register()
    }
    
    /// 取消自启动
    static func unregister() {
        try? SMAppService.mainApp.unregister()
    }
    
    /// 是否已启用
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
    
    /// 切换自启动状态
    static func toggle() {
        if isEnabled {
            unregister()
        } else {
            register()
        }
    }
}
