import AppKit
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController?
    
    private let hasShownWelcomeKey = "hasShownWelcome"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        
        // 首次启动检测
        if !UserDefaults.standard.bool(forKey: hasShownWelcomeKey) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showWelcomeGuide()
            }
        }
    }
    
    private func showWelcomeGuide() {
        let alert = NSAlert()
        alert.messageText = LocalizedString("welcome.title", comment: "")
        alert.informativeText = LocalizedString("welcome.message", comment: "")
        alert.alertStyle = .informational
        
        // 设置应用图标
        if let icon = getAppIcon() {
            alert.icon = icon
        }
        
        alert.addButton(withTitle: LocalizedString("welcome.enable_launch", comment: ""))
        alert.addButton(withTitle: LocalizedString("welcome.later", comment: ""))
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            // 自动开启自启动
            LaunchAtLogin.register()
        }
        
        UserDefaults.standard.set(true, forKey: hasShownWelcomeKey)
    }
    
    // 获取应用图标（优先使用资源文件，开发模式下回退到本地路径）
    private func getAppIcon() -> NSImage? {
        if let image = NSImage(named: "AppIcon") {
            return image
        }
        // 开发模式下的回退路径
        let devIconPath = "/Users/lyon/Documents/bluetooth Android/BatteryMonitor/AppIcon.iconset/icon_128x128@2x.png"
        if FileManager.default.fileExists(atPath: devIconPath) {
            return NSImage(contentsOfFile: devIconPath)
        }
        return nil
    }

    func applicationWillTerminate(_ notification: Notification) {
        // 退出前同步保存数据
        EnergyHistoryManager.shared.saveHistory(sync: true)
    }
}
