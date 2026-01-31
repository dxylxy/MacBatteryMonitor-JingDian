import AppKit

// 设置为菜单栏应用（无 Dock 图标）
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

app.run()
