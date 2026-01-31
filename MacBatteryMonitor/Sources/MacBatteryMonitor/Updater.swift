import Cocoa

/// 极简 GitHub 更新检查器
class GitHubUpdater {
    static let shared = GitHubUpdater()
    
    private let repoOwner = "dxylxy"
    private let repoName = "MacBatteryMonitor-JingDian"
    private let currentVersion = "3.1.0"
    
    private init() {}
    
    /// 检查更新
    /// - Parameter manual: 是否是手动触发（如果是手动触发，没有更新时也会提示）
    func checkForUpdates(manual: Bool = false) {
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.setValue("MacBatteryMonitor-Updater", forHTTPHeaderField: "User-Agent")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                if manual {
                    DispatchQueue.main.async {
                        self.showAlert(
                            title: LocalizedString("update.check_error.title", comment: ""),
                            message: LocalizedString("update.check_error.message", comment: "")
                        )
                    }
                }
                print("Check update failed: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else { return }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // 1. 检查是否包含发布信息
                    if let tagName = json["tag_name"] as? String,
                       let htmlUrl = json["html_url"] as? String {
                        
                        let latestVersion = tagName.replacingOccurrences(of: "v", with: "")
                        let body = json["body"] as? String ?? ""
                        
                        if self.isNewerVersion(latest: latestVersion, current: self.currentVersion) {
                            DispatchQueue.main.async {
                                self.showUpdateAlert(version: latestVersion, notes: body, url: htmlUrl)
                            }
                        } else if manual {
                            DispatchQueue.main.async {
                                self.showAlert(
                                    title: LocalizedString("update.no_updates.title", comment: ""),
                                    message: String(format: LocalizedString("update.no_updates.message", comment: ""), self.currentVersion)
                                )
                            }
                        }
                    } 
                    // 2. 检查是否为 API 错误 (例如 API rate limit exceeded)
                    else if let message = json["message"] as? String {
                        print("GitHub API Error: \(message)")
                        if manual {
                            DispatchQueue.main.async {
                                self.showAlert(
                                    title: LocalizedString("update.check_error.title", comment: ""),
                                    message: "GitHub API Error: \(message)"
                                )
                            }
                        }
                    } 
                    // 3. 未知响应格式
                    else {
                        print("Unknown JSON response: \(json)")
                        if manual {
                            DispatchQueue.main.async {
                                self.showAlert(
                                    title: LocalizedString("update.check_error.title", comment: ""),
                                    message: LocalizedString("update.check_error.message", comment: "")
                                )
                            }
                        }
                    }
                }
            } catch {
                print("Parse update JSON failed: \(error)")
                if manual {
                    DispatchQueue.main.async {
                        self.showAlert(
                           title: LocalizedString("update.check_error.title", comment: ""),
                           message: LocalizedString("update.check_error.message", comment: "")
                        )
                    }
                }
            }
        }.resume()
    }
    
    /// 版本号比较 (SemVer)
    private func isNewerVersion(latest: String, current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(latestParts.count, currentParts.count) {
            let latestPart = i < latestParts.count ? latestParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            
            if latestPart > currentPart { return true }
            if latestPart < currentPart { return false }
        }
        
        return false
    }
    
    private func showUpdateAlert(version: String, notes: String, url: String) {
        let alert = NSAlert()
        alert.messageText = LocalizedString("update.title", comment: "")
        alert.informativeText = String(format: LocalizedString("update.message", comment: ""), version, self.currentVersion, notes)
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: LocalizedString("update.button.download", comment: ""))
        alert.addButton(withTitle: LocalizedString("update.button.later", comment: ""))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let downloadUrl = URL(string: url) {
                NSWorkspace.shared.open(downloadUrl)
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizedString("alert.ok", comment: ""))
        alert.runModal()
    }
}
