import Foundation
import AppKit
import IOKit.ps

/// 电池信息结构体
struct BatteryInfo {
    let currentCapacity: Int
    let maxCapacity: Int
    let designCapacity: Int
    let percentage: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let cycleCount: Int
    let temperature: Double
    let amperage: Int
    let voltage: Int
    let timeToEmpty: Int
    let timeToFull: Int
    let systemHealthPercent: Int?  // 系统报告的电池健康百分比
    
    var healthPercentage: Int {
        // 优先使用系统报告的健康值（与系统设置一致）
        if let systemHealth = systemHealthPercent {
            return systemHealth
        }
        // 回退到计算值
        guard designCapacity > 0 else { return 0 }
        return Int(Double(maxCapacity) / Double(designCapacity) * 100)
    }
    
    var powerWatts: Double {
        return Double(abs(amperage)) * Double(voltage) / 1_000_000
    }
    
    static func current() -> BatteryInfo? {
        let batteryData = getSmartBatteryInfo()
        guard !batteryData.isEmpty else { return nil }
        
        var isCharging = false
        var isPluggedIn = false
        var timeToEmpty = -1
        var timeToFull = -1
        var systemPercentage: Int? = nil
        
        // 从系统 API 获取百分比（与系统状态栏一致）
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
           let source = sources.first,
           let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
            isCharging = info[kIOPSIsChargingKey as String] as? Bool ?? false
            isPluggedIn = (info[kIOPSPowerSourceStateKey as String] as? String) == kIOPSACPowerValue as String
            timeToEmpty = info[kIOPSTimeToEmptyKey as String] as? Int ?? -1
            timeToFull = info[kIOPSTimeToFullChargeKey as String] as? Int ?? -1
            // 使用系统优化的百分比，与系统状态栏一致
            systemPercentage = info[kIOPSCurrentCapacityKey as String] as? Int
        }
        
        let currentCapacity = batteryData["AppleRawCurrentCapacity"] as? Int ?? 0
        let maxCapacity = batteryData["AppleRawMaxCapacity"] as? Int ?? 
                          batteryData["NominalChargeCapacity"] as? Int ?? 0
        let designCapacity = batteryData["DesignCapacity"] as? Int ?? 0
        let cycleCount = batteryData["CycleCount"] as? Int ?? 0
        let rawTemp = batteryData["Temperature"] as? Int ?? 0
        let temperature = (Double(rawTemp) / 10.0) - 273.15
        let amperage = batteryData["Amperage"] as? Int ?? 0
        let voltage = batteryData["Voltage"] as? Int ?? 0
        
        // 获取系统报告的电池健康百分比（与系统设置一致）
        let systemHealthPercent = batteryData["MaximumCapacityPercent"] as? Int
        
        // 优先使用系统百分比，否则回退到原始计算
        let percentage = systemPercentage ?? (maxCapacity > 0 ? Int(Double(currentCapacity) / Double(maxCapacity) * 100) : 0)
        
        return BatteryInfo(
            currentCapacity: currentCapacity,
            maxCapacity: maxCapacity,
            designCapacity: designCapacity,
            percentage: percentage,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            cycleCount: cycleCount,
            temperature: temperature,
            amperage: amperage,
            voltage: voltage,
            timeToEmpty: timeToEmpty,
            timeToFull: timeToFull,
            systemHealthPercent: systemHealthPercent
        )
    }
    
    private static func getSmartBatteryInfo() -> [String: Any] {
        var result: [String: Any] = [:]
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return result }
        defer { IOObjectRelease(service) }
        
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let properties = props?.takeRetainedValue() as? [String: Any] else {
            return result
        }
        
        result["AppleRawCurrentCapacity"] = properties["AppleRawCurrentCapacity"]
        result["AppleRawMaxCapacity"] = properties["AppleRawMaxCapacity"]
        result["NominalChargeCapacity"] = properties["NominalChargeCapacity"]
        result["DesignCapacity"] = properties["DesignCapacity"]
        result["CycleCount"] = properties["CycleCount"]
        result["Temperature"] = properties["Temperature"]
        result["Amperage"] = properties["Amperage"]
        result["Voltage"] = properties["Voltage"]
        result["MaximumCapacityPercent"] = properties["MaximumCapacityPercent"]  // 系统电池健康
        
        return result
    }
}

/// 应用能耗记录
struct AppEnergyRecord: Codable {
    let name: String
    let pid: Int
    let timestamp: Date
    let cpuPercent: Double
}

/// 生成平滑渐变热力条样式的进度指示器
/// 使用 Unicode 水平渐变字符实现无级调节效果，比方块更加美观平滑
func makeBarChart(value: Double, maxValue: Double, width: Int = 8) -> String {
    guard maxValue > 0 else { return String(repeating: " ", count: width) }
    let ratio = min(1.0, max(0, value / maxValue))
    
    // 使用 8 级水平渐变块字符（从空到满）：
    // " " (空), "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"
    // 这些字符宽度依次增加 1/8，实现平滑渐变效果
    let gradientChars: [Character] = [" ", "▏", "▎", "▍", "▌", "▋", "▊", "▉", "█"]
    
    // 计算填充了多少个完整的格子，以及最后一个格子的部分填充比例
    let totalFill = ratio * Double(width)
    let fullBlocks = Int(totalFill)
    let partialFill = totalFill - Double(fullBlocks)
    
    var result = ""
    
    for i in 0..<width {
        if i < fullBlocks {
            // 完全填充的格子
            result.append("█")
        } else if i == fullBlocks {
            // 部分填充的格子 - 选择对应的渐变字符
            let charIndex = Int(partialFill * 8)
            result.append(gradientChars[min(charIndex, 8)])
        } else {
            // 未填充的格子 - 使用空格保持宽度
            result.append(" ")
        }
    }
    
    return result
}

/// 辅助结构体：用于电池历史记录的序列化 (Tuple 不支持 Codable)
struct BatteryHistoryPoint: Codable {
    let time: Date
    let capacity: Int
    let percentage: Int
    let isCharging: Bool
}

/// 简化版的能耗记录 (用于持久化，节省空间)
struct SimpleEnergyRecord: Codable {
    let t: Date     // time
    let c: Double   // cpu percent for this app
    let total: Double?  // total CPU of all apps at this time (optional for backward compatibility)
}

struct SimpleTotalCPURecord: Codable {
    let t: Date
    let v: Double
}

/// 历史数据容器 (优化后的紧凑格式)
struct HistoryData: Codable {
    let appData: [String: [SimpleEnergyRecord]] // 应用名称 -> 记录列表
    let batteryHistory: [BatteryHistoryPoint]
    let totalCPUHistory: [SimpleTotalCPURecord]? // 总 CPU 历史 (Optional ensures backward compatibility)
}

/// 能耗历史管理器
class EnergyHistoryManager {
    static let shared = EnergyHistoryManager()
    
    private var records: [AppEnergyRecord] = []
    private var batteryHistory: [(time: Date, capacity: Int, percentage: Int, isCharging: Bool)] = []
    private var cachedCurrentApps: [AppEnergyRecord] = []
    private var runningProcesses: Set<String> = []
    private var appHistory: [String: [(time: Date, cpuPercent: Double)]] = [:]  // 每个应用的 CPU 历史
    private var totalCPUHistory: [(time: Date, totalCPU: Double)] = []  // 每个时间点的总 CPU
    private let queue = DispatchQueue(label: "energy.history", qos: .background)
    
    // 持久化路径
    private var persistenceURL: URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let appDir = appSupport.appendingPathComponent("BatteryMonitor")
        // 确保目录存在
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("history.json")
    }
    
    private init() {
        self.loadHistory()
        
        // 启动自动保存定时器 (每 5 分钟)
        let timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.saveHistory()
        }
        RunLoop.main.add(timer, forMode: .common)
        
        // 监听系统休眠和唤醒
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(handleWake), name: NSWorkspace.didWakeNotification, object: nil)
    }
    
    // MARK: - Sleep/Wake Handling
    
    @objc private func handleSleep() {
        // 休眠前强制更新一次并在后台线程同步保存
        updateInBackground { [weak self] in
            // 使用 sync: true 确保在系统挂起前写入文件
            self?.saveHistory(sync: true)
        }
    }
    
    @objc private func handleWake() {
        // 唤醒后立即更新数据
        // 稍微延迟一下以确保硬件已准备好
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateInBackground()
        }
    }
    
    /// 保存历史数据
    /// - Parameter sync: 是否同步保存 (用于退出应用时)
    func saveHistory(sync: Bool = false) {
        let work = { [weak self] in
            guard let self = self, let url = self.persistenceURL else { return }
            
            // 1. 转换电池历史
            let batteryPoints = self.batteryHistory.map {
                BatteryHistoryPoint(time: $0.time, capacity: $0.capacity, percentage: $0.percentage, isCharging: $0.isCharging)
            }
            
            // 2. 转换应用历史为紧凑格式
            var appData: [String: [SimpleEnergyRecord]] = [:]
            for (name, history) in self.appHistory {
                appData[name] = history.map { SimpleEnergyRecord(t: $0.time, c: $0.cpuPercent, total: nil) }
            }
            
            // 3. 转换总 CPU 历史
            let totalCPURecords = self.totalCPUHistory.map { SimpleTotalCPURecord(t: $0.time, v: $0.totalCPU) }
            
            let data = HistoryData(
                appData: appData,
                batteryHistory: batteryPoints,
                totalCPUHistory: totalCPURecords
            )
            
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(data)
                try jsonData.write(to: url, options: .atomic)
                // print("History saved to \(url.path)")
            } catch {
                print("Failed to save history: \(error)")
            }
        }
        
        if sync {
            queue.sync(execute: work)
        } else {
            queue.async(execute: work)
        }
    }
    
    /// 加载历史数据
    private func loadHistory() {
        queue.sync {
            guard let url = self.persistenceURL, FileManager.default.fileExists(atPath: url.path) else { return }
            
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                
                // 尝试加载新格式
                if let history = try? decoder.decode(HistoryData.self, from: data) {
                    self.batteryHistory = history.batteryHistory.map {
                        ($0.time, $0.capacity, $0.percentage, $0.isCharging)
                    }
                    
                    self.appHistory.removeAll()
                    self.records.removeAll()
                    
                    // 恢复 run-time 数据结构
                    for (name, simpleRecords) in history.appData {
                        // 恢复 appHistory
                        self.appHistory[name] = simpleRecords.map { ($0.t, $0.c) }
                        
                        // 恢复 records (重建 AppEnergyRecord 平铺列表)
                        // 注意：我们这里重建 records 主要是为了兼容 getTodayTopApps 等依赖 records 的代码
                        // PID 丢失了，填 0 即可，不影响统计
                        for simple in simpleRecords {
                            self.records.append(AppEnergyRecord(name: name, pid: 0, timestamp: simple.t, cpuPercent: simple.c))
                        }
                    }
                    
                    // 恢复总 CPU 历史
                    if let totalHistory = history.totalCPUHistory {
                        self.totalCPUHistory = totalHistory.map { ($0.t, $0.v) }
                    } else {
                        self.totalCPUHistory = []
                    }
                } 
                // 尝试加载旧格式 (兼容性处理 - 如果需要)
                else {
                    // 旧格式定义 (临时用于解码)
                    struct OldHistoryData: Codable {
                        let records: [AppEnergyRecord]
                        let batteryHistory: [BatteryHistoryPoint]
                    }
                    
                    if let oldHistory = try? decoder.decode(OldHistoryData.self, from: data) {
                        self.records = oldHistory.records
                        self.batteryHistory = oldHistory.batteryHistory.map {
                            ($0.time, $0.capacity, $0.percentage, $0.isCharging)
                        }
                        
                        // 重建 appHistory 索引
                        self.appHistory.removeAll()
                        for record in self.records where record.cpuPercent > 0 {
                            self.appHistory[record.name, default: []].append((record.timestamp, record.cpuPercent))
                        }
                    }
                }
                
            } catch {
                print("Failed to load history: \(error)")
            }
        }
    }
    
    /// 后台更新所有数据
    func updateInBackground(completion: (() -> Void)? = nil) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let apps = self.fetchCurrentApps()
            self.cachedCurrentApps = apps
            self.runningProcesses = Set(apps.map { $0.name })
            
            let now = Date()
            if let info = BatteryInfo.current() {
                self.records.append(contentsOf: apps.filter { $0.cpuPercent > 0 })
                self.batteryHistory.append((now, info.currentCapacity, info.percentage, info.isCharging))
                
                // 计算当前时刻所有应用的总 CPU 使用率
                let totalCPU = apps.reduce(0.0) { $0 + $1.cpuPercent }
                self.totalCPUHistory.append((now, totalCPU))
                
                // 存储每个应用的 CPU 历史
                for app in apps where app.cpuPercent > 0 {
                    if self.appHistory[app.name] == nil {
                        self.appHistory[app.name] = []
                    }
                    self.appHistory[app.name]?.append((now, app.cpuPercent))
                }
                
                // 保留 48 小时的数据
                let cutoff = now.addingTimeInterval(-172800) // 48 hours
                self.records = self.records.filter { $0.timestamp > cutoff }
                self.batteryHistory = self.batteryHistory.filter { $0.time > cutoff }
                self.totalCPUHistory = self.totalCPUHistory.filter { $0.time > cutoff }
                
                // 清理每个应用的历史数据
                for (name, history) in self.appHistory {
                    self.appHistory[name] = history.filter { $0.time > cutoff }
                }
                // 移除空的历史记录
                self.appHistory = self.appHistory.filter { !$0.value.isEmpty }
            }
            
            DispatchQueue.main.async { completion?() }
        }
    }
    
    /// 快速更新当前应用（用于实时刷新）
    func quickUpdateCurrentApps() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let apps = self.fetchCurrentApps()
            self.cachedCurrentApps = apps
            self.runningProcesses = Set(apps.map { $0.name })
        }
    }
    
    func getCachedCurrentApps() -> [AppEnergyRecord] {
        var result: [AppEnergyRecord] = []
        queue.sync { result = self.cachedCurrentApps }
        return result
    }
    
    func isRunning(_ name: String) -> Bool {
        var result = false
        queue.sync { result = self.runningProcesses.contains(name) }
        return result
    }
    
    /// 获取应用的 PID（用于强制退出）
    func getPidForApp(_ name: String) -> Int? {
        var result: Int? = nil
        queue.sync {
            result = cachedCurrentApps.first { $0.name == name }?.pid
        }
        return result
    }
    
    func getBatteryDrain(hours: Int) -> (mah: Int, percent: Int) {
        var result = (mah: 0, percent: 0)
        queue.sync {
            let cutoff = Date().addingTimeInterval(-Double(hours * 3600))
            let filtered = batteryHistory.filter { $0.time > cutoff }
            if let first = filtered.first, let last = filtered.last {
                result.mah = max(0, first.capacity - last.capacity)
                result.percent = max(0, first.percentage - last.percentage)
            }
        }
        return result
    }
    
    /// 获取电池曲线图数据（48小时）
    func getBatteryChartData(hours: Int = 48) -> [(time: Date, percentage: Int, isCharging: Bool)] {
        var result: [(time: Date, percentage: Int, isCharging: Bool)] = []
        queue.sync {
            let cutoff = Date().addingTimeInterval(-Double(hours * 3600))
            result = batteryHistory.filter { $0.time > cutoff }.map { ($0.time, $0.percentage, $0.isCharging) }
        }
        return result
    }
    
    /// 获取单个应用的 CPU 历史（48小时）
    func getAppCPUHistory(appName: String, hours: Int = 48) -> [(time: Date, cpuPercent: Double)] {
        var result: [(time: Date, cpuPercent: Double)] = []
        queue.sync {
            let cutoff = Date().addingTimeInterval(-Double(hours * 3600))
            if let history = appHistory[appName] {
                result = history.filter { $0.time > cutoff }
            }
        }
        return result
    }
    
    /// 获取单个应用的能耗贡献百分比历史（0-100%）
    /// 返回该应用在每个时间点对总耗电的贡献占比
    func getAppEnergyContributionHistory(appName: String, hours: Int = 36) -> [(time: Date, contributionPercent: Double)] {
        var result: [(time: Date, contributionPercent: Double)] = []
        queue.sync {
            let cutoff = Date().addingTimeInterval(-Double(hours * 3600))
            
            // 获取该应用的历史
            guard let appHist = appHistory[appName] else { return }
            let filteredAppHist = appHist.filter { $0.time > cutoff }
            
            // 创建时间到总CPU的映射（允许一定的时间误差）
            let totalCPUDict = Dictionary(totalCPUHistory.filter { $0.time > cutoff }.map { ($0.time, $0.totalCPU) }) { first, _ in first }
            
            for point in filteredAppHist {
                // 查找最接近的总CPU记录（时间误差在5秒内）
                var totalCPU: Double = 0
                for (time, total) in totalCPUDict {
                    if abs(time.timeIntervalSince(point.time)) < 5 {
                        totalCPU = total
                        break
                    }
                }
                
                // 计算贡献百分比
                let contribution: Double
                if totalCPU > 0 {
                    contribution = min(100, (point.cpuPercent / totalCPU) * 100)
                } else {
                    contribution = 0
                }
                
                result.append((point.time, contribution))
            }
        }
        return result
    }
    
    /// 获取今日应用排行（从午夜开始计算）
    func getTodayTopApps(count: Int = 10) -> [(name: String, percentEstimate: Double, isRunning: Bool)] {
        var result: [(name: String, percentEstimate: Double, isRunning: Bool)] = []
        
        queue.sync {
            // 计算今天午夜时间
            let calendar = Calendar.current
            let todayStart = calendar.startOfDay(for: Date())
            
            let filteredRecords = records.filter { $0.timestamp >= todayStart }
            let filteredBattery = batteryHistory.filter { $0.time >= todayStart }
            
            // 计算今日电量消耗
            var totalDrainPercent = 0
            if let first = filteredBattery.first, let last = filteredBattery.last {
                totalDrainPercent = max(0, first.percentage - last.percentage)
            }
            
            var appCPU: [String: Double] = [:]
            var totalCPU: Double = 0
            
            for record in filteredRecords {
                appCPU[record.name, default: 0] += record.cpuPercent
                totalCPU += record.cpuPercent
            }
            
            result = appCPU.map { name, cpu in
                let cpuShare = totalCPU > 0 ? (cpu / totalCPU * 100) : 0
                let percentEstimate = Double(totalDrainPercent) * cpuShare / 100
                let running = runningProcesses.contains(name)
                return (name, percentEstimate, running)
            }.sorted { $0.percentEstimate > $1.percentEstimate }
            .prefix(count).map { $0 }
        }
        
        return result
    }
    
    func getTopApps(hours: Int, count: Int = 10) -> [(name: String, cpuShare: Double, mahEstimate: Double, percentEstimate: Double, isRunning: Bool)] {
        var result: [(name: String, cpuShare: Double, mahEstimate: Double, percentEstimate: Double, isRunning: Bool)] = []
        
        queue.sync {
            let cutoff = Date().addingTimeInterval(-Double(hours * 3600))
            let filteredRecords = records.filter { $0.timestamp > cutoff }
            let filteredBattery = batteryHistory.filter { $0.time > cutoff }
            
            var totalDrainMah = 0
            var totalDrainPercent = 0
            if let first = filteredBattery.first, let last = filteredBattery.last {
                totalDrainMah = max(0, first.capacity - last.capacity)
                totalDrainPercent = max(0, first.percentage - last.percentage)
            }
            
            var appCPU: [String: Double] = [:]
            var totalCPU: Double = 0
            
            for record in filteredRecords {
                appCPU[record.name, default: 0] += record.cpuPercent
                totalCPU += record.cpuPercent
            }
            
            result = appCPU.map { name, cpu in
                let cpuShare = totalCPU > 0 ? (cpu / totalCPU * 100) : 0
                let mahEstimate = Double(totalDrainMah) * cpuShare / 100
                let percentEstimate = Double(totalDrainPercent) * cpuShare / 100
                let running = runningProcesses.contains(name)
                return (name, cpuShare, mahEstimate, percentEstimate, running)
            }.sorted { $0.cpuShare > $1.cpuShare }
            .prefix(count).map { $0 }
        }
        
        return result
    }
    
    /// 获取最大 CPU 占用（用于柱状图比例）
    func getMaxCPU() -> Double {
        var maxCPU: Double = 0
        queue.sync {
            maxCPU = cachedCurrentApps.max(by: { $0.cpuPercent < $1.cpuPercent })?.cpuPercent ?? 1
        }
        return max(1, maxCPU)
    }
    
    /// 系统进程黑名单（这些进程不显示给用户）
    private let systemProcessBlacklist: Set<String> = [
        "kernel_task", "launchd", "WindowServer", "loginwindow", "SystemUIServer",
        "Finder", "Dock", "Spotlight", "mds", "mds_stores", "mdworker", "mdworker_shared",
        "cfprefsd", "distnoted", "trustd", "secinitd", "securityd", "coreservicesd",
        "bluetoothd", "airportd", "wifid", "locationd", "nsurlsessiond", "networkserviceproxy",
        "powerd", "thermald", "syslogd", "logd", "configd", "notifyd", "usernoted",
        "WindowManager", "ControlCenter", "NotificationCenter", "AXVisualSupportAgent",
        "coreaudiod", "audioclocksyncd", "corespeechd", "audio", "AppleSpell",
        "backupd", "cloudd", "bird", "netbiosd", "CalendarAgent", "AddressBookSource",
        "VTEncoderXPCService", "com.apple.WebKit.GPU", "com.apple.WebKit.WebContent",
        "com.apple.WebKit.Networking", "com.apple.DriverKit-AppleUserHIDDrivers",
        "com.apple.Safari.SafeBrowsing", "SafariCloudHistoryPushAgent",
        "smd", "containermanagerd", "runningboardd", "CommCenter", "UserEventAgent",
        "sharingd", "rapportd", "IMDPersistenceAgent", "identityservicesd", "imagent",
        "akd", "amsaccountsd", "amsengagementd", "callservicesd", "deleted",
        "diagnosticd", "diskarbitrationd", "diskmanagementd", "fileproviderd",
        "fseventsd", "hidd", "iconservicesagent", "lsd", "mediaanalysisd",
        "opendirectoryd", "pbs", "sandboxd", "secd", "symptomsd", "sysextd",
        "syspolicyd", "timed", "trustdFileHelper", "universalaccessd", "usermanagerd",
        "warmd", "xpcproxy", "duetexpertd", "siriknowledged", "parsecd",
        "suggestd", "coreduetd", "intelligenceplatformd", "knowledgeconstructiond",
        "contextstored", "proactiveeventtrackerd", "peopled", "photoanalysisd",
        "ReportCrash", "storeaccountd", "bookassetd", "fud", "gamecontrollerd",
        "avconferenced", "WiFiAgent", "WirelessRadioManagerd", "ctkd", "pkd",
        "AMPDevicesAgent", "AMPLibraryAgent", "AMPArtworkAgent", "AMPDeviceDiscoveryAgent",
        "CVMServer", "gpuinfo", "MTLCompilerService"
    ]
    
    /// 将 Helper/子进程名称归并到主应用名称
    private func getAppName(from processName: String) -> String {
        var name = processName
        
        // 移除常见的 Helper 后缀
        let helperPatterns = [
            " Helper (Renderer)", " Helper (GPU)", " Helper (Plugin)",
            " Helper", " Renderer", " GPU Process", " Plugin",
            " Networking", " Web Content", " Extension",
            "-Helper", "-Renderer", "-GPU",
            ".Helper", ".Renderer", ".GPU",
            " (Renderer)", " (GPU)", " (Plugin)"
        ]
        
        for pattern in helperPatterns {
            if name.hasSuffix(pattern) {
                name = String(name.dropLast(pattern.count))
                break
            }
        }
        
        // 处理 com.apple.xxx 格式
        if name.hasPrefix("com.apple.") {
            // 只保留最后一个组件
            if let lastPart = name.components(separatedBy: ".").last {
                name = lastPart
            }
        }
        
        // 处理其他 bundle identifier 格式 (com.xxx.yyy)
        if name.hasPrefix("com.") || name.hasPrefix("cn.") || name.hasPrefix("io.") {
            if let lastPart = name.components(separatedBy: ".").last {
                name = lastPart
            }
        }
        
        return name
    }
    
    /// 检查是否为系统进程 (排除噪音)
    private func isSystemProcess(_ name: String) -> Bool {
        // 1. 白名单：如果是明确的用户应用，直接放行 (避免误杀)
        let whitelist = ["Safari", "Xcode", "Finder", "Terminal", "iTerm", "Visual Studio Code", "Cursor", "Chrome", "Firefox", "Music", "Mail", "Notes", "Preview", "System Settings", "System Preferences", "WeChat", "QQ", "DingTalk"]
        if whitelist.contains(name) {
            return false
        }
        
        // 2. 黑名单：已知系统进程
        if systemProcessBlacklist.contains(name) {
            return true
        }
        
        // 3. 特征过滤：系统守护进程、插件、扩展
        // 包含以下后缀的通常是噪音
        let noiseSuffixes = [
            "d", "d_sim", "agent", "Agent", "service", "Service", "helper", "Helper",
            "Extension", "extension", "Plugin", "plugin", "XPC", "xpc",
            "Daemon", "daemon", "Wrapper", "wrapper", "LoginItem", "Runner", "runner",
            "XPCService", "XPCServices"
        ]
        
        for suffix in noiseSuffixes {
            if name.hasSuffix(suffix) {
                return true
            }
        }
        
        // com.apple. 开头的通常是系统服务
        if name.hasPrefix("com.apple.") {
            return true
        }
        
        // 4. 其他关键字过滤
        if name.contains("Widget") || name.contains("Spotlight") || name.contains("Core") || name.contains("Siri") {
            return true
        }
        
        return false
    }
    
    private func fetchCurrentApps() -> [AppEnergyRecord] {
        var appCPU: [String: (cpu: Double, pid: Int)] = [:]
        let now = Date()
        
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-Aceo", "pid,pcpu,comm", "-r"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                let lines = output.components(separatedBy: "\n")
                
                for line in lines.dropFirst() {
                    let parts = line.trimmingCharacters(in: .whitespaces)
                        .components(separatedBy: .whitespaces)
                        .filter { !$0.isEmpty }
                    
                    if parts.count >= 3 {
                        let pid = Int(parts[0]) ?? 0
                        let cpu = Double(parts[1]) ?? 0
                        var rawName = parts[2...].joined(separator: " ")
                        
                        // 提取路径中的最后一个组件
                        if let lastComponent = rawName.components(separatedBy: "/").last {
                            rawName = lastComponent
                        }
                        
                        // 跳过特殊进程
                        if rawName.hasPrefix("(") || rawName == "BatteryMonitor" || rawName == "静电" || rawName == "ps" {
                            continue
                        }
                        
                        // 跳过系统进程
                        if isSystemProcess(rawName) {
                            continue
                        }
                        
                        // 归并到主应用名称
                        let appName = getAppName(from: rawName)
                        
                        // 再次检查归并后的名称是否为系统进程
                        if isSystemProcess(appName) {
                            continue
                        }
                        
                        // 累加同一应用的 CPU 使用率
                        if let existing = appCPU[appName] {
                            appCPU[appName] = (cpu: existing.cpu + cpu, pid: existing.pid)
                        } else {
                            appCPU[appName] = (cpu: cpu, pid: pid)
                        }
                    }
                }
            }
        } catch {}
        
        // 转换为 AppEnergyRecord 数组
        var apps: [AppEnergyRecord] = []
        for (name, data) in appCPU {
            apps.append(AppEnergyRecord(name: name, pid: data.pid, timestamp: now, cpuPercent: data.cpu))
        }
        
        // 按 CPU 使用率排序
        apps.sort { $0.cpuPercent > $1.cpuPercent }
        
        return apps
    }
    
    // MARK: - 导出报告功能
    
    /// 导出能耗报告为 CSV 格式
    func exportToCSV(hours: Int) -> String {
        var csv = LocalizedString("csv.header", comment: "")
        
        let apps = getTopApps(hours: hours, count: 50)
        let drain = getBatteryDrain(hours: hours)
        
        // 添加汇总信息
        csv += String(format: LocalizedString("csv.report_time", comment: ""), formatDate(Date()))
        csv += String(format: LocalizedString("csv.period", comment: ""), hours)
        csv += String(format: LocalizedString("csv.total_drain", comment: ""), drain.mah, drain.percent)
        csv += "\n"
        
        for app in apps {
            let status = app.isRunning ? LocalizedString("app.running", comment: "") : LocalizedString("app.closed", comment: "")
            csv += "\"\(app.name)\",\(String(format: "%.2f", app.cpuShare)),\(String(format: "%.1f", app.mahEstimate)),\(String(format: "%.2f", app.percentEstimate)),\(status)\n"
        }
        
        return csv
    }
    
    /// 导出能耗报告为 JSON 格式
    func exportToJSON(hours: Int) -> String {
        let apps = getTopApps(hours: hours, count: 50)
        let drain = getBatteryDrain(hours: hours)
        let batteryInfo = BatteryInfo.current()
        
        var json: [String: Any] = [
            "reportTime": formatDate(Date()),
            "periodHours": hours,
            "summary": [
                "totalDrainMah": drain.mah,
                "totalDrainPercent": drain.percent
            ]
        ]
        
        if let info = batteryInfo {
            json["batteryStatus"] = [
                "currentCapacity": info.currentCapacity,
                "maxCapacity": info.maxCapacity,
                "percentage": info.percentage,
                "healthPercentage": info.healthPercentage,
                "cycleCount": info.cycleCount,
                "temperature": info.temperature,
                "isCharging": info.isCharging,
                "powerWatts": info.powerWatts
            ]
        }
        
        var appList: [[String: Any]] = []
        for app in apps {
            appList.append([
                "name": app.name,
                "cpuShare": app.cpuShare,
                "mahEstimate": app.mahEstimate,
                "percentEstimate": app.percentEstimate,
                "isRunning": app.isRunning
            ])
        }
        json["applications"] = appList
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{\"error\": \"\(LocalizedString("json.error", comment: ""))\"}"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
