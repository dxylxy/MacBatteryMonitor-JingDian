import AppKit
import UniformTypeIdentifiers

/// 应用 CPU 曲线弹出窗口
class AppCPUChartWindow: NSWindow {
    private let chartView: AppCPUChartView
    private var appName: String = ""
    
    init() {
        chartView = AppCPUChartView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        isReleasedWhenClosed = false
        level = .floating
        titlebarAppearsTransparent = false
        
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 250))
        chartView.frame = NSRect(x: 10, y: 10, width: 400, height: 200)
        contentView.addSubview(chartView)
        self.contentView = contentView
    }
    
    func showForApp(name: String, near point: NSPoint) {
        appName = name
        title = "\(name) - " + LocalizedString("chart.energy_contribution_36h", comment: "")
        
        let history = EnergyHistoryManager.shared.getAppEnergyContributionHistory(appName: name, hours: 36)
        chartView.updateData(history, appName: name)
        
        // 定位窗口
        var windowOrigin = point
        windowOrigin.x -= 210  // 居中
        windowOrigin.y -= 260  // 在点击位置上方显示
        
        // 确保不超出屏幕
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            if windowOrigin.x < screenFrame.minX {
                windowOrigin.x = screenFrame.minX + 10
            }
            if windowOrigin.x + 420 > screenFrame.maxX {
                windowOrigin.x = screenFrame.maxX - 430
            }
            if windowOrigin.y < screenFrame.minY {
                windowOrigin.y = point.y + 30  // 改为下方显示
            }
        }
        
        setFrameOrigin(windowOrigin)
        makeKeyAndOrderFront(nil)
    }
}

/// 应用能耗贡献曲线视图（支持悬停交互）
class AppCPUChartView: NSView {
    private var chartData: [(time: Date, contributionPercent: Double)] = []
    private var appName: String = ""
    private var trackingArea: NSTrackingArea?
    private var mouseX: CGFloat? = nil
    
    func updateData(_ data: [(time: Date, contributionPercent: Double)], appName: String) {
        self.chartData = data
        self.appName = appName
        needsDisplay = true
    }
    
    override var isFlipped: Bool { false }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        updateTrackingAreas()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouseX = point.x
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        mouseX = nil
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let padding: CGFloat = 45
        let chartRect = NSRect(
            x: padding,
            y: 25,
            width: bounds.width - padding - 15,
            height: bounds.height - 45
        )
        
        // 绘制网格
        drawGrid(in: chartRect, context: context)
        
        // 绘制曲线
        drawCurve(in: chartRect, context: context)
        
        // 绘制坐标轴标签
        drawAxisLabels(in: chartRect)
        
        // 绘制悬停指示线和数值
        if let mx = mouseX, mx >= chartRect.minX && mx <= chartRect.maxX {
            drawHoverIndicator(at: mx, in: chartRect, context: context)
        }
    }
    
    private func drawGrid(in rect: NSRect, context: CGContext) {
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(0.5)
        
        // 水平网格线
        for i in 1...4 {
            let y = rect.minY + rect.height * CGFloat(i) / 4
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        
        // 垂直网格线
        for i in 0...8 {
            let x = rect.minX + rect.width * CGFloat(i) / 8
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        
        context.strokePath()
        
        context.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)
    }
    
    private func drawCurve(in rect: NSRect, context: CGContext) {
        guard chartData.count > 1 else {
            // 无数据时显示提示
            let noDataText = LocalizedString("chart.no_data", comment: "")
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let size = noDataText.size(withAttributes: attrs)
            let point = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
            noDataText.draw(at: point, withAttributes: attrs)
            return
        }
        
        let now = Date()
        let hoursAgo36 = now.addingTimeInterval(-129600)  // 36 hours
        let timeRange = now.timeIntervalSince(hoursAgo36)
        
        // 能耗贡献百分比已经是 0-100%
        let maxPercent: Double = 100
        
        // 时间间隔阈值：超过 10 分钟认为是休眠/无数据期间
        let gapThreshold: TimeInterval = 600
        
        // 将数据按时间间隔分成多个连续的片段
        var segments: [[(time: Date, contributionPercent: Double)]] = []
        var currentSegment: [(time: Date, contributionPercent: Double)] = []
        var gapRanges: [(start: Date, end: Date)] = []  // 记录无数据区间
        
        for (i, point) in chartData.enumerated() {
            if i == 0 {
                currentSegment.append(point)
            } else {
                let prevPoint = chartData[i - 1]
                let timeDiff = point.time.timeIntervalSince(prevPoint.time)
                
                if timeDiff > gapThreshold {
                    // 时间间隔过大，保存当前片段并开始新片段
                    if !currentSegment.isEmpty {
                        segments.append(currentSegment)
                    }
                    // 记录无数据区间
                    gapRanges.append((start: prevPoint.time, end: point.time))
                    currentSegment = [point]
                } else {
                    currentSegment.append(point)
                }
            }
        }
        // 保存最后一个片段
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }
        
        // 绘制无数据区间的灰色背景
        for gap in gapRanges {
            let startX = rect.minX + CGFloat(gap.start.timeIntervalSince(hoursAgo36) / timeRange) * rect.width
            let endX = rect.minX + CGFloat(gap.end.timeIntervalSince(hoursAgo36) / timeRange) * rect.width
            
            let gapRect = NSRect(x: startX, y: rect.minY, width: endX - startX, height: rect.height)
            NSColor.gray.withAlphaComponent(0.1).setFill()
            NSBezierPath(rect: gapRect).fill()
            
            // 在无数据区间中间绘制虚线
            context.saveGState()
            context.setStrokeColor(NSColor.gray.withAlphaComponent(0.4).cgColor)
            context.setLineWidth(1)
            context.setLineDash(phase: 0, lengths: [4, 4])
            let midX = (startX + endX) / 2
            context.move(to: CGPoint(x: midX, y: rect.minY))
            context.addLine(to: CGPoint(x: midX, y: rect.maxY))
            context.strokePath()
            context.restoreGState()
        }
        
        // 为每个片段分别绘制填充区域和曲线
        for segment in segments {
            guard segment.count > 1 else {
                // 单个点时绘制一个小圆点
                if let singlePoint = segment.first {
                    let x = rect.minX + CGFloat(singlePoint.time.timeIntervalSince(hoursAgo36) / timeRange) * rect.width
                    let y = rect.minY + rect.height * CGFloat(singlePoint.contributionPercent / maxPercent)
                    let dotRect = NSRect(x: x - 3, y: y - 3, width: 6, height: 6)
                    NSColor.systemOrange.setFill()
                    NSBezierPath(ovalIn: dotRect).fill()
                }
                continue
            }
            
            // 绘制填充区域
            let fillPath = NSBezierPath()
            var firstPoint = true
            
            for point in segment {
                let x = rect.minX + CGFloat(point.time.timeIntervalSince(hoursAgo36) / timeRange) * rect.width
                let y = rect.minY + rect.height * CGFloat(point.contributionPercent / maxPercent)
                
                if firstPoint {
                    fillPath.move(to: NSPoint(x: x, y: rect.minY))
                    fillPath.line(to: NSPoint(x: x, y: y))
                    firstPoint = false
                } else {
                    fillPath.line(to: NSPoint(x: x, y: y))
                }
            }
            
            if let lastPoint = segment.last {
                let lastX = rect.minX + CGFloat(lastPoint.time.timeIntervalSince(hoursAgo36) / timeRange) * rect.width
                fillPath.line(to: NSPoint(x: lastX, y: rect.minY))
            }
            fillPath.close()
            
            NSColor.systemOrange.withAlphaComponent(0.3).setFill()
            fillPath.fill()
            
            // 绘制曲线
            let curvePath = NSBezierPath()
            curvePath.lineWidth = 2
            firstPoint = true
            
            for point in segment {
                let x = rect.minX + CGFloat(point.time.timeIntervalSince(hoursAgo36) / timeRange) * rect.width
                let y = rect.minY + rect.height * CGFloat(point.contributionPercent / maxPercent)
                
                if firstPoint {
                    curvePath.move(to: NSPoint(x: x, y: y))
                    firstPoint = false
                } else {
                    curvePath.line(to: NSPoint(x: x, y: y))
                }
            }
            
            NSColor.systemOrange.setStroke()
            curvePath.stroke()
        }
    }
    
    private func drawAxisLabels(in rect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        
        // Y 轴标签 - 显示归一化的 0-100% 相对活跃度
        // 这样用户更容易理解（最高点始终是 100%）
        for i in 0...4 {
            let y = rect.minY + rect.height * CGFloat(i) / 4 - 5
            let value = i * 25  // 0%, 25%, 50%, 75%, 100%
            let text = "\(value)%"
            text.draw(at: NSPoint(x: 5, y: y), withAttributes: attrs)
        }
        
        // X 轴标签
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // 36小时内：显示36小时前、18小时前、现在
        let timeOffsets: [(offset: TimeInterval, label: String)] = [
            (-129600, LocalizedString("time.36h_ago", comment: "")),
            (-64800, LocalizedString("time.18h_ago", comment: "")),
            (0, LocalizedString("time.now", comment: ""))
        ]
        
        for (i, item) in timeOffsets.enumerated() {
            let x = rect.minX + rect.width * CGFloat(i) / 2
            let time = now.addingTimeInterval(item.offset)
            let timeStr = formatter.string(from: time)
            let displayText = item.label + "\n" + timeStr
            
            let size = timeStr.size(withAttributes: attrs)
            displayText.draw(at: NSPoint(x: x - size.width / 2, y: 2), withAttributes: attrs)
        }
    }
    
    /// 绘制悬停指示线和数值
    private func drawHoverIndicator(at x: CGFloat, in rect: NSRect, context: CGContext) {
        guard chartData.count > 1 else { return }
        
        let now = Date()
        let hoursAgo36 = now.addingTimeInterval(-129600)  // 36 hours
        let timeRange = now.timeIntervalSince(hoursAgo36)
        let maxPercent: Double = 100  // 能耗贡献已是 0-100%
        
        // 计算鼠标位置对应的时间
        let ratio = (x - rect.minX) / rect.width
        let hoverTime = hoursAgo36.addingTimeInterval(timeRange * Double(ratio))
        
        // 查找最近的数据点
        var closestPoint: (time: Date, contributionPercent: Double)? = nil
        var minDistance: TimeInterval = .infinity
        
        for point in chartData {
            let distance = abs(point.time.timeIntervalSince(hoverTime))
            if distance < minDistance {
                minDistance = distance
                closestPoint = point
            }
        }
        
        guard let point = closestPoint else { return }
        
        // 阈值检查：如果鼠标位置离最近的数据点超过 30 分钟，则不显示
        if minDistance > 1800 { return }
        
        // 绘制垂直指示线
        context.setStrokeColor(NSColor.systemBlue.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [4, 2])
        context.move(to: CGPoint(x: x, y: rect.minY))
        context.addLine(to: CGPoint(x: x, y: rect.maxY))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
        
        // 计算曲线上的 Y 坐标
        let curveY = rect.minY + rect.height * CGFloat(point.contributionPercent / maxPercent)
        
        // 绘制交叉点圆圈
        let circleRect = NSRect(x: x - 4, y: curveY - 4, width: 8, height: 8)
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fillEllipse(in: circleRect)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: circleRect)
        
        // 绘制悬停信息框
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        let timeStr = formatter.string(from: point.time)
        // 直接显示能耗贡献百分比
        let valueStr = String(format: "%.0f%%", point.contributionPercent)
        let infoText = "\(timeStr)\n\(valueStr)"
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = infoText.size(withAttributes: attrs)
        
        // 信息框位置（在指示线旁边）
        var boxX = x + 8
        if boxX + textSize.width + 12 > rect.maxX {
            boxX = x - textSize.width - 20
        }
        let boxY = curveY - textSize.height / 2 - 4
        
        let boxRect = NSRect(x: boxX, y: boxY, width: textSize.width + 12, height: textSize.height + 8)
        
        // 绘制背景
        context.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
        let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4)
        boxPath.fill()
        
        // 绘制文本
        infoText.draw(at: NSPoint(x: boxX + 6, y: boxY + 4), withAttributes: attrs)
    }
}

/// 电池曲线图视图 - 显示 48 小时电量变化（支持横向滚动和悬停交互）
class BatteryChartView: NSView {
    private var chartData: [(time: Date, percentage: Int, isCharging: Bool)] = []
    private var trackingArea: NSTrackingArea?
    private var mouseX: CGFloat? = nil  // 鼠标 X 坐标（用于绘制指示线）
    
    // 内容宽度倍数（相对于可见宽度）
    private let contentWidthMultiplier: CGFloat = 2.5
    
    func updateData(_ data: [(time: Date, percentage: Int, isCharging: Bool)]) {
        self.chartData = data
        needsDisplay = true
    }
    
    override var isFlipped: Bool { false }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 关键：菜单窗口默认不接收 mouseMoved 事件，必须显式开启
        window?.acceptsMouseMovedEvents = true
        
        // 重新添加追踪区域确保生效
        updateTrackingAreas()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouseX = point.x
        needsDisplay = true
    }
    
    override func mouseExited(with event: NSEvent) {
        mouseX = nil
        needsDisplay = true
    }
    
    override func scrollWheel(with event: NSEvent) {
        // 传递给父视图处理滚动
        super.scrollWheel(with: event)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let padding: CGFloat = 40
        let chartRect = NSRect(
            x: padding,
            y: 25,
            width: bounds.width - padding - 15,
            height: bounds.height - 45
        )
        
        // 绘制网格和坐标轴
        drawGrid(in: chartRect, context: context)
        
        // 绘制曲线
        drawCurve(in: chartRect, context: context)
        
        // 绘制坐标轴标签
        drawAxisLabels(in: chartRect)
        
        // 绘制悬停指示线和数值
        if let mx = mouseX, mx >= chartRect.minX && mx <= chartRect.maxX {
            drawHoverIndicator(at: mx, in: chartRect, context: context)
        }
    }
    
    private func drawGrid(in rect: NSRect, context: CGContext) {
        context.setStrokeColor(NSColor.separatorColor.cgColor)
        context.setLineWidth(0.5)
        
        // 水平网格线 (25%, 50%, 75%, 100%)
        for i in 1...4 {
            let y = rect.minY + rect.height * CGFloat(i) / 4
            context.move(to: CGPoint(x: rect.minX, y: y))
            context.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        
        // 垂直网格线 (每 6 小时)
        for i in 0...8 {
            let x = rect.minX + rect.width * CGFloat(i) / 8
            context.move(to: CGPoint(x: x, y: rect.minY))
            context.addLine(to: CGPoint(x: x, y: rect.maxY))
        }
        
        context.strokePath()
        
        // 绘制边框
        context.setStrokeColor(NSColor.tertiaryLabelColor.cgColor)
        context.setLineWidth(1)
        context.stroke(rect)
    }
    
    private func drawCurve(in rect: NSRect, context: CGContext) {
        guard chartData.count > 1 else {
            // 无数据时显示提示
            let noDataText = LocalizedString("chart.no_data", comment: "")
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let size = noDataText.size(withAttributes: attrs)
            let point = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
            noDataText.draw(at: point, withAttributes: attrs)
            return
        }
        
        let now = Date()
        let hoursAgo48 = now.addingTimeInterval(-172800)
        let timeRange = now.timeIntervalSince(hoursAgo48)
        
        // 计算所有点的坐标
        var points: [(point: NSPoint, isCharging: Bool)] = []
        for dataPoint in chartData {
            let x = rect.minX + CGFloat(dataPoint.time.timeIntervalSince(hoursAgo48) / timeRange) * rect.width
            let y = rect.minY + rect.height * CGFloat(dataPoint.percentage) / 100
            points.append((NSPoint(x: x, y: y), dataPoint.isCharging))
        }
        
        guard points.count >= 2 else { return }
        
        // 绘制充电区域（绿色填充）
        var chargingRanges: [(start: Int, end: Int)] = []
        var inCharging = false
        var startIdx = 0
        
        for (i, p) in points.enumerated() {
            if p.isCharging && !inCharging {
                inCharging = true
                startIdx = i
            } else if !p.isCharging && inCharging {
                inCharging = false
                chargingRanges.append((startIdx, i))
            }
        }
        if inCharging {
            chargingRanges.append((startIdx, points.count - 1))
        }
        
        // 绘制充电区域
        for range in chargingRanges {
            if range.end > range.start {
                let chargingPath = NSBezierPath()
                let startPoint = points[range.start].point
                
                chargingPath.move(to: NSPoint(x: startPoint.x, y: rect.minY))
                
                for i in range.start...range.end {
                    chargingPath.line(to: points[i].point)
                }
                
                let endPoint = points[range.end].point
                chargingPath.line(to: NSPoint(x: endPoint.x, y: rect.minY))
                chargingPath.close()
                
                NSColor.systemGreen.withAlphaComponent(0.3).setFill()
                chargingPath.fill()
            }
        }
        
        // 绘制电量曲线（平滑贝塞尔曲线）- 始终连接所有点
        let curvePath = NSBezierPath()
        curvePath.lineWidth = 2
        
        let allPoints = points.map { $0.point }
        
        curvePath.move(to: allPoints[0])
        
        if allPoints.count == 2 {
            // 只有两个点时，直接连线
            curvePath.line(to: allPoints[1])
        } else {
            // 使用 Catmull-Rom 样条转换为贝塞尔曲线
            for i in 0..<(allPoints.count - 1) {
                let p0 = i > 0 ? allPoints[i - 1] : allPoints[0]
                let p1 = allPoints[i]
                let p2 = allPoints[i + 1]
                let p3 = i + 2 < allPoints.count ? allPoints[i + 2] : allPoints[allPoints.count - 1]
                
                // 计算控制点（Catmull-Rom 到 Bezier 转换）
                let tension: CGFloat = 0.3  // 张力系数，越小越平滑
                
                let cp1 = NSPoint(
                    x: p1.x + (p2.x - p0.x) * tension,
                    y: p1.y + (p2.y - p0.y) * tension
                )
                let cp2 = NSPoint(
                    x: p2.x - (p3.x - p1.x) * tension,
                    y: p2.y - (p3.y - p1.y) * tension
                )
                
                curvePath.curve(to: p2, controlPoint1: cp1, controlPoint2: cp2)
            }
        }
        
        NSColor.systemBlue.setStroke()
        curvePath.stroke()
    }
    
    private func drawAxisLabels(in rect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        // Y 轴标签 (0%, 25%, 50%, 75%, 100%)
        for i in 0...4 {
            let y = rect.minY + rect.height * CGFloat(i) / 4 - 5
            let text = "\(i * 25)%"
            text.draw(at: NSPoint(x: 5, y: y), withAttributes: attrs)
        }
        
        // X 轴标签 (时间)
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        // 显示 5 个时间点：48h前、36h前、24h前、12h前、现在
        let timeOffsets: [(offset: TimeInterval, label: String)] = [
            (-172800, LocalizedString("time.two_days_ago", comment: "")),
            (-129600, ""),
            (-86400, LocalizedString("time.yesterday", comment: "")),
            (-43200, ""),
            (0, LocalizedString("time.now", comment: ""))
        ]
        
        for (i, item) in timeOffsets.enumerated() {
            let x = rect.minX + rect.width * CGFloat(i) / 4
            let time = now.addingTimeInterval(item.offset)
            let timeStr = formatter.string(from: time)
            
            var displayText = timeStr
            if !item.label.isEmpty {
                displayText = item.label + "\n" + timeStr
            }
            
            let size = timeStr.size(withAttributes: attrs)
            displayText.draw(at: NSPoint(x: x - size.width / 2, y: 2), withAttributes: attrs)
        }
    }
    
    /// 绘制悬停指示线和数值
    private func drawHoverIndicator(at x: CGFloat, in rect: NSRect, context: CGContext) {
        guard chartData.count > 1 else { return }
        
        let now = Date()
        let hoursAgo48 = now.addingTimeInterval(-172800)
        let timeRange = now.timeIntervalSince(hoursAgo48)
        
        // 计算鼠标位置对应的时间
        let ratio = (x - rect.minX) / rect.width
        let hoverTime = hoursAgo48.addingTimeInterval(timeRange * Double(ratio))
        
        // 查找最近的数据点
        var closestPoint: (time: Date, percentage: Int, isCharging: Bool)? = nil
        var minDistance: TimeInterval = .infinity
        
        for point in chartData {
            let distance = abs(point.time.timeIntervalSince(hoverTime))
            if distance < minDistance {
                minDistance = distance
                closestPoint = point
            }
        }
        
        guard let point = closestPoint else { return }
        
        // 阈值检查：如果鼠标位置离最近的数据点超过 30 分钟，则不显示
        if minDistance > 1800 { return }
        
        // 绘制垂直指示线
        context.setStrokeColor(NSColor.systemOrange.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(1.5)
        context.setLineDash(phase: 0, lengths: [4, 2])
        context.move(to: CGPoint(x: x, y: rect.minY))
        context.addLine(to: CGPoint(x: x, y: rect.maxY))
        context.strokePath()
        context.setLineDash(phase: 0, lengths: [])
        
        // 计算曲线上的 Y 坐标
        let curveY = rect.minY + rect.height * CGFloat(point.percentage) / 100
        
        // 绘制交叉点圆圈
        let circleRect = NSRect(x: x - 4, y: curveY - 4, width: 8, height: 8)
        context.setFillColor(NSColor.systemOrange.cgColor)
        context.fillEllipse(in: circleRect)
        context.setStrokeColor(NSColor.white.cgColor)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: circleRect)
        
        // 绘制悬停信息框
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        let timeStr = formatter.string(from: point.time)
        let valueStr = "\(point.percentage)%"
        let chargingStr = point.isCharging ? " ⚡" : ""
        let infoText = "\(timeStr)\n\(valueStr)\(chargingStr)"
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = infoText.size(withAttributes: attrs)
        
        // 信息框位置（在指示线旁边）
        var boxX = x + 8
        if boxX + textSize.width + 12 > rect.maxX {
            boxX = x - textSize.width - 20
        }
        let boxY = curveY - textSize.height / 2 - 4
        
        let boxRect = NSRect(x: boxX, y: boxY, width: textSize.width + 12, height: textSize.height + 8)
        
        // 绘制背景
        context.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
        let boxPath = NSBezierPath(roundedRect: boxRect, xRadius: 4, yRadius: 4)
        boxPath.fill()
        
        // 绘制文本
        infoText.draw(at: NSPoint(x: boxX + 6, y: boxY + 4), withAttributes: attrs)
    }
}

/// 应用排行项视图
class AppRankingItemView: NSView {
    private let iconView: NSImageView
    private let nameLabel: NSTextField
    private let percentLabel: NSTextField
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    
    var appName: String = "" {
        didSet {
            nameLabel.stringValue = appName
            iconView.image = getAppIcon(for: appName)
        }
    }
    
    var percentage: Double = 0 {
        didSet {
            if percentage > 0 {
                percentLabel.stringValue = String(format: "%.1f%%", percentage)
            } else {
                percentLabel.stringValue = "<1%"
            }
        }
    }
    
    var isRunning: Bool = true {
        didSet {
            nameLabel.textColor = isRunning ? .labelColor : .secondaryLabelColor
            percentLabel.textColor = isRunning ? .labelColor : .secondaryLabelColor
            iconView.alphaValue = isRunning ? 1.0 : 0.5
        }
    }
    
    override init(frame: NSRect) {
        iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        
        nameLabel = NSTextField(labelWithString: "")
        nameLabel.font = NSFont.systemFont(ofSize: 13)
        nameLabel.lineBreakMode = .byTruncatingTail
        
        percentLabel = NSTextField(labelWithString: "")
        percentLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        percentLabel.alignment = .right
        
        super.init(frame: frame)
        
        addSubview(iconView)
        addSubview(nameLabel)
        addSubview(percentLabel)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        percentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentLabel.leadingAnchor, constant: -10),
            
            percentLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            percentLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            percentLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    /// 获取应用图标
    private func getAppIcon(for appName: String) -> NSImage? {
        // 1. 尝试从正在运行的应用中获取
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.localizedName == appName || $0.bundleIdentifier?.contains(appName) == true 
        }) {
            return runningApp.icon
        }
        
        // 2. 尝试从 Applications 文件夹查找
        let appPaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/System/Applications/Utilities/\(appName).app",
            NSHomeDirectory() + "/Applications/\(appName).app"
        ]
        
        for path in appPaths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }
        
        // 3. 返回通用应用图标
        return NSWorkspace.shared.icon(forFileType: "app")
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
        nameLabel.textColor = .white
        percentLabel.textColor = .white
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        layer?.backgroundColor = nil
        nameLabel.textColor = isRunning ? .labelColor : .secondaryLabelColor
        percentLabel.textColor = isRunning ? .labelColor : .secondaryLabelColor
    }
    
    // 点击回调
    var onClick: ((String, NSPoint) -> Void)?
    
    override func mouseUp(with event: NSEvent) {
        guard !appName.isEmpty else { return }
        let screenPoint = NSEvent.mouseLocation
        onClick?(appName, screenPoint)
    }
}

/// 消耗追踪器
class ConsumptionTracker {
    private(set) var startTime: Date
    private(set) var startCapacity: Int
    private(set) var startPercentage: Int
    
    init(capacity: Int, percentage: Int) {
        self.startTime = Date()
        self.startCapacity = capacity
        self.startPercentage = percentage
    }
    
    func reset(capacity: Int, percentage: Int) {
        self.startTime = Date()
        self.startCapacity = capacity
        self.startPercentage = percentage
    }
    
    func consumedCapacity(current: Int) -> Int { max(0, startCapacity - current) }
    func consumedPercentage(current: Int) -> Int { max(0, startPercentage - current) }
    var elapsedTime: TimeInterval { Date().timeIntervalSince(startTime) }
    
    var formattedElapsedTime: String {
        let elapsed = Int(elapsedTime)
        return String(format: "%d:%02d:%02d", elapsed / 3600, (elapsed % 3600) / 60, elapsed % 60)
    }
}

/// 可点击的菜单按钮视图（点击后菜单不关闭）
class ClickableMenuButtonView: NSView {
    private let label: NSTextField
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    var onClick: (() -> Void)?
    
    var text: String = "" {
        didSet { label.stringValue = text }
    }
    
    override init(frame: NSRect) {
        label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .labelColor
        super.init(frame: frame)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
        label.textColor = .white
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        layer?.backgroundColor = nil
        label.textColor = .labelColor
    }
    
    override func mouseUp(with event: NSEvent) {
        onClick?()
    }
}

/// 自定义菜单项视图（支持可选的应用图标）
class LiveMenuItemView: NSView {
    private let iconView: NSImageView
    private let label: NSTextField
    private var hasIcon: Bool = false
    private var labelLeadingConstraint: NSLayoutConstraint!
    
    var text: String = "" { 
        didSet { label.stringValue = text } 
    }
    
    /// 设置应用名称并显示图标
    func setAppInfo(name: String, barChart: String, cpuPercent: Double) {
        label.stringValue = String(format: "%@ %5.1f%% %@", barChart, cpuPercent, name)
        iconView.image = getAppIcon(for: name)
        
        if !hasIcon {
            // 首次设置图标时调整约束
            hasIcon = true
            iconView.isHidden = false
            // 切换 label 的约束：从左边缘改为图标右侧
            labelLeadingConstraint.isActive = false
            labelLeadingConstraint = label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6)
            labelLeadingConstraint.isActive = true
        }
    }
    
    override init(frame: NSRect) {
        iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.isHidden = true
        
        label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .labelColor
        super.init(frame: frame)
        
        addSubview(iconView)
        addSubview(label)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        
        // 初始 label 约束（无图标时）
        labelLeadingConstraint = label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            
            labelLeadingConstraint,
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    /// 获取应用图标
    private func getAppIcon(for appName: String) -> NSImage? {
        // 1. 尝试从正在运行的应用中获取
        if let runningApp = NSWorkspace.shared.runningApplications.first(where: { 
            $0.localizedName == appName || $0.bundleIdentifier?.contains(appName) == true 
        }) {
            return runningApp.icon
        }
        
        // 2. 尝试从 Applications 文件夹查找
        let appPaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/System/Applications/Utilities/\(appName).app",
            NSHomeDirectory() + "/Applications/\(appName).app"
        ]
        
        for path in appPaths {
            if FileManager.default.fileExists(atPath: path) {
                return NSWorkspace.shared.icon(forFile: path)
            }
        }
        
        // 3. 返回通用应用图标
        return NSWorkspace.shared.icon(forFileType: "app")
    }
}

/// 应用历史菜单项视图（支持颜色区分和右键强制退出）
class AppHistoryMenuItemView: NSView, NSMenuDelegate {
    private let label: NSTextField
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private(set) var appName: String = ""
    private(set) var isRunning: Bool = false
    var onForceQuit: ((String) -> Void)?
    
    var text: String = "" {
        didSet { label.stringValue = text }
    }
    
    func configure(text: String, appName: String, isRunning: Bool) {
        self.text = text
        self.appName = appName
        self.isRunning = isRunning
        // 运行中应用显示正常颜色，已关闭应用显示灰色
        label.textColor = isRunning ? .labelColor : .secondaryLabelColor
        
        // 只有运行中的应用才有右键菜单
        if isRunning {
            let contextMenu = NSMenu()
            contextMenu.delegate = self
            let quitItem = NSMenuItem(title: String(format: LocalizedString("menu.force_quit", comment: ""), appName), action: #selector(handleForceQuit(_:)), keyEquivalent: "")
            quitItem.target = self
            contextMenu.addItem(quitItem)
            self.menu = contextMenu
        }
    }
    
    override init(frame: NSRect) {
        label = NSTextField(labelWithString: "")
        label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textColor = .labelColor
        label.lineBreakMode = .byClipping
        label.cell?.truncatesLastVisibleLine = false
        super.init(frame: frame)
        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 500)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }
    
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.selectedContentBackgroundColor.cgColor
        label.textColor = .white
    }
    
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        layer?.backgroundColor = nil
        label.textColor = isRunning ? .labelColor : .secondaryLabelColor
    }
    
    @objc private func handleForceQuit(_ sender: NSMenuItem) {
        onForceQuit?(appName)
    }
}

/// 菜单栏控制器
class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var backgroundTimer: Timer?
    private var liveTimer: DispatchSourceTimer?
    private var tracker: ConsumptionTracker?
    private var isMenuOpen = false
    private var lastRefreshTime: Date = Date()  // 追踪刷新时间
    
    private var liveViews: [LiveMenuItemView] = []
    private var appHistoryItems: [NSMenuItem] = []
    private var currentAppsSubmenu: NSMenu!
    private var currentAppViews: [LiveMenuItemView] = []
    private var showAllCurrentApps = false
    private var showMoreButtonView: ClickableMenuButtonView!
    private var settingsMenu: NSMenu!  // 右键设置菜单
    
    // 能耗历史新 UI
    private var energyHistorySubmenu: NSMenu!
    private var batteryChartView: BatteryChartView!
    private var appRankingViews: [AppRankingItemView] = []
    private lazy var appCPUChartWindow: AppCPUChartWindow = AppCPUChartWindow()
    
    override init() {
        super.init()
        setupStatusBar()
        setupMenu()
        setupSettingsMenu()
        startBackgroundTimer()
        EnergyHistoryManager.shared.updateInBackground { [weak self] in
            self?.updateStatusBar()
        }
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // 使用原生风格的电池图标
        if let button = statusItem.button {
            button.image = createBatteryImage(percentage: 100, charging: false)
            // 设置鼠标事件处理
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(handleClick(_:))
            button.target = self
        }
    }
    
    /// 创建原生风格电池图标（缩小版）
    private func createBatteryImage(percentage: Int, charging: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 9)
        let image = NSImage(size: size, flipped: false) { rect in
            let path = NSBezierPath()
            
            // 电池外框
            let bodyRect = NSRect(x: 0, y: 0.5, width: 15, height: 8)
            path.appendRoundedRect(bodyRect, xRadius: 1.5, yRadius: 1.5)
            
            // 电池头
            let capRect = NSRect(x: 15, y: 2.5, width: 2, height: 4)
            path.appendRoundedRect(capRect, xRadius: 0.5, yRadius: 0.5)
            
            NSColor.labelColor.withAlphaComponent(0.8).setStroke()
            path.lineWidth = 1
            path.stroke()
            
            // 填充电量
            let fillWidth = max(0, CGFloat(percentage) / 100 * 11)
            let fillRect = NSRect(x: 2, y: 2.5, width: fillWidth, height: 4)
            
            if charging {
                NSColor.systemGreen.setFill()
            } else if percentage <= 20 {
                NSColor.systemRed.setFill()
            } else {
                NSColor.labelColor.withAlphaComponent(0.6).setFill()
            }
            
            NSBezierPath(roundedRect: fillRect, xRadius: 0.5, yRadius: 0.5).fill()
            
            // 充电闪电符号
            if charging {
                let bolt = NSBezierPath()
                bolt.move(to: NSPoint(x: 8.5, y: 1))
                bolt.line(to: NSPoint(x: 6, y: 4.5))
                bolt.line(to: NSPoint(x: 7.5, y: 4.5))
                bolt.line(to: NSPoint(x: 6.5, y: 8))
                bolt.line(to: NSPoint(x: 9, y: 4))
                bolt.line(to: NSPoint(x: 7.5, y: 4))
                bolt.close()
                NSColor.white.setFill()
                bolt.fill()
            }
            
            return true
        }
        
        image.isTemplate = false
        return image
    }
    
    private func setupMenu() {
        // 清理旧视图引用
        liveViews.removeAll()
        currentAppViews.removeAll()
        appRankingViews.removeAll()
        appHistoryItems.removeAll()
        
        menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        
        // 电池信息区域
        let labels = [
            LocalizedString("status.battery_info.placeholder", comment: ""),
            LocalizedString("status.power_info.placeholder", comment: ""),
            LocalizedString("status.time.remaining.placeholder", comment: ""),
            LocalizedString("status.temp_voltage.placeholder", comment: ""),
            "",
            LocalizedString("status.consumed.placeholder", comment: ""),
            LocalizedString("status.average.placeholder", comment: ""),
            "",
            LocalizedString("status.health.info.placeholder", comment: "")
        ]
        
        for text in labels {
            if text.isEmpty {
                menu.addItem(NSMenuItem.separator())
            } else {
                let view = LiveMenuItemView(frame: NSRect(x: 0, y: 0, width: 400, height: 22))
                view.text = text
                liveViews.append(view)
                let item = NSMenuItem()
                item.view = view
                menu.addItem(item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 应用能耗历史（新设计：曲线图 + 今日排行）
        let appHeader = NSMenuItem(title: LocalizedString("menu.app_energy_history", comment: ""), action: nil, keyEquivalent: "")
        energyHistorySubmenu = NSMenu()
        
        // 电池曲线图
        batteryChartView = BatteryChartView(frame: NSRect(x: 0, y: 0, width: 380, height: 150))
        let chartItem = NSMenuItem()
        chartItem.view = batteryChartView
        energyHistorySubmenu.addItem(chartItem)
        
        energyHistorySubmenu.addItem(NSMenuItem.separator())
        
        // 今日应用耗电排行标题
        let rankingHeader = NSMenuItem(title: LocalizedString("menu.today_app_ranking", comment: ""), action: nil, keyEquivalent: "")
        rankingHeader.isEnabled = false
        energyHistorySubmenu.addItem(rankingHeader)
        
        // 预创建 15 个应用排行菜单项（每个带子菜单显示 CPU 曲线）
        for _ in 0..<15 {
            let item = NSMenuItem()
            
            // 创建自定义视图
            let view = AppRankingItemView(frame: NSRect(x: 0, y: 0, width: 380, height: 26))
            appRankingViews.append(view)
            item.view = view
            item.isHidden = true
            
            // 创建子菜单（包含 CPU 曲线图）
            let submenu = NSMenu()
            let chartView = AppCPUChartView(frame: NSRect(x: 0, y: 0, width: 360, height: 180))
            let chartItem = NSMenuItem()
            chartItem.view = chartView
            submenu.addItem(chartItem)
            item.submenu = submenu
            
            energyHistorySubmenu.addItem(item)
        }
        
        // 保留旧的小时选项作为"更多"子菜单 -> 已移除，保持清爽
        /* 
        energyHistorySubmenu.addItem(NSMenuItem.separator())
        let moreHistoryItem = NSMenuItem(title: LocalizedString("menu.more_history", comment: ""), action: nil, keyEquivalent: "")
        ...
        */
        
        appHeader.submenu = energyHistorySubmenu
        menu.addItem(appHeader)
        
        // 当前活跃应用
        let currentHeader = NSMenuItem(title: LocalizedString("menu.current_active_apps", comment: ""), action: nil, keyEquivalent: "")
        currentAppsSubmenu = NSMenu()
        
        // 预创建 50 个视图槽位 (大幅增加显示数量)
        for _ in 0..<50 {
            let view = LiveMenuItemView(frame: NSRect(x: 0, y: 0, width: 420, height: 22))
            view.text = ""
            currentAppViews.append(view)
            let item = NSMenuItem()
            item.view = view
            item.isHidden = true
            currentAppsSubmenu.addItem(item)
        }
        
        // 移除"显示更多"按钮，直接展示较多数量
        /*
        currentAppsSubmenu.addItem(NSMenuItem.separator())
        showMoreButtonView = ClickableMenuButtonView(frame: NSRect(x: 0, y: 0, width: 420, height: 22))
        ...
        */
        
        currentHeader.submenu = currentAppsSubmenu
        menu.addItem(currentHeader)
        
        menu.addItem(NSMenuItem.separator())
        
        let resetItem = NSMenuItem(title: LocalizedString("menu.reset_stats", comment: ""), action: #selector(resetTracker), keyEquivalent: "r")
        resetItem.target = self
        menu.addItem(resetItem)
        // 左键菜单不再包含开机自启动和退出选项，这些移到右键菜单
    }
    
    /// 设置右键菜单（设置菜单）
    private func setupSettingsMenu() {
        settingsMenu = NSMenu()
        settingsMenu.autoenablesItems = false
        
        // 关于
        let aboutItem = NSMenuItem(title: LocalizedString("menu.about", comment: ""), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        settingsMenu.addItem(aboutItem)
        
        // 帮助 / GitHub
        let helpItem = NSMenuItem(title: LocalizedString("menu.help", comment: ""), action: #selector(openGitHub), keyEquivalent: "")
        helpItem.target = self
        settingsMenu.addItem(helpItem)
        
        // 打赏支持
        let donateItem = NSMenuItem(title: LocalizedString("menu.donate", comment: ""), action: #selector(showDonation), keyEquivalent: "")
        donateItem.target = self
        settingsMenu.addItem(donateItem)
        
        settingsMenu.addItem(NSMenuItem.separator())
        
        // (已移除) 导出能耗报告
        
        // 语言切换
        
        // 语言切换
        let languageItem = NSMenuItem(title: LocalizedString("menu.language", comment: ""), action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu()
        
        let currentLang = L10n.getCurrentLanguageSetting()
        
        // 跟随系统
        let systemItem = NSMenuItem(title: LocalizedString("menu.language.system", comment: ""), action: #selector(setLanguageSystem), keyEquivalent: "")
        systemItem.target = self
        systemItem.state = (currentLang == nil) ? .on : .off
        languageSubmenu.addItem(systemItem)
        
        languageSubmenu.addItem(NSMenuItem.separator())
        
        // 中文
        let chineseItem = NSMenuItem(title: LocalizedString("menu.language.chinese", comment: ""), action: #selector(setLanguageChinese), keyEquivalent: "")
        chineseItem.target = self
        chineseItem.state = (currentLang == "zh-Hans") ? .on : .off
        languageSubmenu.addItem(chineseItem)
        
        // English
        let englishItem = NSMenuItem(title: LocalizedString("menu.language.english", comment: ""), action: #selector(setLanguageEnglish), keyEquivalent: "")
        englishItem.target = self
        englishItem.state = (currentLang == "en") ? .on : .off
        languageSubmenu.addItem(englishItem)
        
        languageItem.submenu = languageSubmenu
        settingsMenu.addItem(languageItem)
        
        // 开机自启动选项
        let launchItem = NSMenuItem(title: LocalizedString("menu.launch_at_login", comment: ""), action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchItem.target = self
        launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        settingsMenu.addItem(launchItem)
        
        settingsMenu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: LocalizedString("menu.quit", comment: ""), action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        settingsMenu.addItem(quitItem)
    }
    
    /// 处理鼠标点击事件
    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        // 临时移除 action 以防止 performClick 导致递归调用
        statusItem.button?.action = nil
        
        if event.type == .rightMouseUp {
            // 右键点击：显示设置菜单
            statusItem.menu = settingsMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            // 左键点击：显示主菜单
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        }
        
        // 恢复 action
        statusItem.button?.action = #selector(handleClick(_:))
    }
    
    /// 显示关于对话框
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = LocalizedString("alert.about.title", comment: "")
        alert.informativeText = LocalizedString("alert.about.message", comment: "")
        alert.alertStyle = .informational
        
        // 设置应用图标
        if let icon = getAppIcon() {
            alert.icon = icon
        }
        
        alert.addButton(withTitle: LocalizedString("alert.ok", comment: ""))
        alert.runModal()
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
    
    /// 打开 GitHub 页面
    @objc private func openGitHub() {
        if let url = URL(string: "https://github.com/dxylxy/BatteryMonitor-JingDian") {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// 显示打赏信息
    /// 显示打赏/支持信息 -> 跳转到 GitHub 主页
    @objc private func showDonation() {
        // 大佬说打赏链接也追溯到主页
        openGitHub()
    }
    
    /// 导出 CSV 报告
    @objc private func exportCSV(_ sender: NSMenuItem) {
        let hours = sender.tag
        let content = EnergyHistoryManager.shared.exportToCSV(hours: hours)
        
        let savePanel = NSSavePanel()
        savePanel.title = LocalizedString("save_panel.csv.title", comment: "")
        savePanel.nameFieldStringValue = String(format: LocalizedString("save_panel.csv.name", comment: ""), hours)
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.canCreateDirectories = true
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                showExportSuccess(url: url)
            } catch {
                showExportError(error: error)
            }
        }
    }
    
    /// 导出 JSON 报告
    @objc private func exportJSON(_ sender: NSMenuItem) {
        let hours = sender.tag
        let content = EnergyHistoryManager.shared.exportToJSON(hours: hours)
        
        let savePanel = NSSavePanel()
        savePanel.title = LocalizedString("save_panel.json.title", comment: "")
        savePanel.nameFieldStringValue = String(format: LocalizedString("save_panel.json.name", comment: ""), hours)
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                showExportSuccess(url: url)
            } catch {
                showExportError(error: error)
            }
        }
    }
    
    private func showExportSuccess(url: URL) {
        let alert = NSAlert()
        alert.messageText = LocalizedString("alert.export.success", comment: "")
        alert.informativeText = String(format: LocalizedString("alert.export.saved", comment: ""), url.path)
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizedString("alert.show_in_finder", comment: ""))
        alert.addButton(withTitle: LocalizedString("alert.ok", comment: ""))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
        }
    }
    
    private func showExportError(error: Error) {
        let alert = NSAlert()
        alert.messageText = LocalizedString("alert.export.fail", comment: "")
        alert.informativeText = String(format: LocalizedString("alert.export.error", comment: ""), error.localizedDescription)
        alert.alertStyle = .critical
        alert.addButton(withTitle: LocalizedString("alert.ok", comment: ""))
        alert.runModal()
    }
    
    // MARK: - NSMenuDelegate
    
    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
        showAllCurrentApps = false
        updateLiveContent()
        updateBatteryChart()
        updateAppRanking()
        updateAppSubmenus()
        startLiveTimer()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        stopLiveTimer()
    }
    
    // MARK: - Timers
    
    private func startBackgroundTimer() {
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            EnergyHistoryManager.shared.updateInBackground {
                self?.updateStatusBar()
            }
        }
        backgroundTimer?.tolerance = 10
        RunLoop.current.add(backgroundTimer!, forMode: .common)
    }
    
    private func startLiveTimer() {
        let queue = DispatchQueue(label: "live.timer", qos: .userInteractive)
        liveTimer = DispatchSource.makeTimerSource(queue: queue)
        liveTimer?.schedule(deadline: .now(), repeating: .seconds(1))
        liveTimer?.setEventHandler { [weak self] in
            EnergyHistoryManager.shared.quickUpdateCurrentApps()
            DispatchQueue.main.async {
                self?.updateLiveContent()
                self?.updateCurrentAppsLive()
            }
        }
        liveTimer?.resume()
    }
    
    private func stopLiveTimer() {
        liveTimer?.cancel()
        liveTimer = nil
    }
    
    // MARK: - Updates
    
    private func updateStatusBar() {
        guard let info = BatteryInfo.current() else {
            statusItem.button?.title = " --"
            return
        }
        
        if tracker == nil {
            tracker = ConsumptionTracker(capacity: info.currentCapacity, percentage: info.percentage)
        }
        
        if info.isCharging && info.percentage >= 100 {
            tracker?.reset(capacity: info.currentCapacity, percentage: info.percentage)
        }
        
        if let button = statusItem.button {
            button.image = createBatteryImage(percentage: info.percentage, charging: info.isCharging)
        }
    }
    
    private func updateLiveContent() {
        guard let info = BatteryInfo.current(), liveViews.count >= 7 else { return }
        
        if tracker == nil {
            tracker = ConsumptionTracker(capacity: info.currentCapacity, percentage: info.percentage)
        }
        
        // 更新刷新时间
        lastRefreshTime = Date()
        
        liveViews[0].text = String(format: LocalizedString("status.battery_info", comment: ""), info.currentCapacity, info.maxCapacity, info.percentage)
        
        // 显示功率和充电状态（附带刷新指示）
        let refreshIndicator = "⟳"  // 刷新指示器
        let powerStatus: String
        if info.isCharging {
            powerStatus = String(format: LocalizedString("status.charging", comment: ""), info.powerWatts, abs(info.amperage), refreshIndicator)
        } else if info.isPluggedIn {
            powerStatus = String(format: LocalizedString("status.charged", comment: ""), info.powerWatts, info.amperage, refreshIndicator)
        } else {
            powerStatus = String(format: LocalizedString("status.discharging", comment: ""), info.powerWatts, info.amperage, refreshIndicator)
        }
        liveViews[1].text = powerStatus
        
        // 剩余时间预估
        let remainingTimeText: String
        if info.isCharging {
            if info.timeToFull > 0 {
                let hours = info.timeToFull / 60
                let minutes = info.timeToFull % 60
                if hours > 0 {
                    remainingTimeText = String(format: LocalizedString("time.charge_full_hm", comment: ""), hours, minutes)
                } else {
                    remainingTimeText = String(format: LocalizedString("time.charge_full_m", comment: ""), minutes)
                }
            } else if info.percentage >= 100 {
                remainingTimeText = LocalizedString("time.battery_full", comment: "")
            } else {
                remainingTimeText = LocalizedString("time.calculating_charge", comment: "")
            }
        } else if info.isPluggedIn {
            remainingTimeText = LocalizedString("time.full_ac", comment: "")
        } else {
            // 放电状态：显示剩余使用时间
            if info.timeToEmpty > 0 {
                let hours = info.timeToEmpty / 60
                let minutes = info.timeToEmpty % 60
                if hours > 0 {
                    remainingTimeText = String(format: LocalizedString("time.remaining_hm", comment: ""), hours, minutes)
                } else {
                    remainingTimeText = String(format: LocalizedString("time.remaining_m", comment: ""), minutes)
                }
            } else if abs(info.amperage) > 0 {
                // 根据当前放电速率计算
                let hoursRemaining = Double(info.currentCapacity) / Double(abs(info.amperage))
                if hoursRemaining > 0 && hoursRemaining < 100 {
                    let hours = Int(hoursRemaining)
                    let minutes = Int((hoursRemaining - Double(hours)) * 60)
                    if hours > 0 {
                        remainingTimeText = String(format: LocalizedString("time.remaining_approx_hm", comment: ""), hours, minutes)
                    } else {
                        remainingTimeText = String(format: LocalizedString("time.remaining_approx_m", comment: ""), minutes)
                    }
                } else {
                    remainingTimeText = LocalizedString("time.calculating_remaining", comment: "")
                }
            } else {
                remainingTimeText = LocalizedString("time.calculating_remaining", comment: "")
            }
        }
        liveViews[2].text = remainingTimeText
        
        liveViews[3].text = String(format: LocalizedString("status.temp_voltage", comment: ""), info.temperature, Double(info.voltage) / 1000.0)
        
        if let tracker = tracker {
            let consumedMah = tracker.consumedCapacity(current: info.currentCapacity)
            let consumedPct = tracker.consumedPercentage(current: info.percentage)
            liveViews[4].text = String(format: LocalizedString("status.consumed", comment: ""), consumedMah, consumedPct, tracker.formattedElapsedTime)
            
            let hoursElapsed = tracker.elapsedTime / 3600
            let mahPerHour = hoursElapsed > 0.01 ? Int(Double(consumedMah) / hoursElapsed) : 0
            liveViews[5].text = String(format: LocalizedString("status.average", comment: ""), mahPerHour)
        }
        
        liveViews[6].text = String(format: LocalizedString("status.health", comment: ""), info.healthPercentage, info.cycleCount, info.designCapacity)
        
        if let button = statusItem.button {
            button.image = createBatteryImage(percentage: info.percentage, charging: info.isCharging)
        }
    }
    
    private func updateCurrentAppsLive() {
        let apps = EnergyHistoryManager.shared.getCachedCurrentApps()
        let topApps = apps.filter { $0.cpuPercent > 0 }
        let maxCPU = EnergyHistoryManager.shared.getMaxCPU()
        
        // 默认显示 15 个，展开后显示最多 50 个
        let displayCount = showAllCurrentApps ? min(50, topApps.count) : min(15, topApps.count)
        
        for (i, view) in currentAppViews.enumerated() {
            let menuItem = currentAppsSubmenu.items[i]
            
            if i < displayCount && i < topApps.count {
                let app = topApps[i]
                let bar = makeBarChart(value: app.cpuPercent, maxValue: maxCPU)
                view.setAppInfo(name: app.name, barChart: bar, cpuPercent: app.cpuPercent)
                menuItem.isHidden = false
            } else {
                menuItem.isHidden = true
            }
        }
        
        // 注意: showMoreButtonView 已移除，现在默认展示 50 个应用
    }
    
    /// 显示应用 CPU 曲线弹窗
    private func showAppCPUChart(for appName: String, at point: NSPoint) {
        appCPUChartWindow.showForApp(name: appName, near: point)
    }
    
    /// 更新电池曲线图
    private func updateBatteryChart() {
        let chartData = EnergyHistoryManager.shared.getBatteryChartData(hours: 48)
        batteryChartView.updateData(chartData)
    }
    
    /// 更新今日应用耗电排行
    private func updateAppRanking() {
        let apps = EnergyHistoryManager.shared.getTodayTopApps(count: 15)
        
        for (i, view) in appRankingViews.enumerated() {
            // 获取包含该视图的菜单项（跳过标题和图表项）
            let menuItemIndex = i + 3  // 图表项 + 分隔线 + 标题
            guard menuItemIndex < energyHistorySubmenu.items.count else { continue }
            let menuItem = energyHistorySubmenu.items[menuItemIndex]
            
            if i < apps.count {
                let app = apps[i]
                view.appName = app.name
                view.percentage = app.percentEstimate
                view.isRunning = app.isRunning
                menuItem.isHidden = false
                
                // 更新子菜单中的能耗贡献曲线图
                if let submenu = menuItem.submenu,
                   let chartItem = submenu.items.first,
                   let chartView = chartItem.view as? AppCPUChartView {
                    let history = EnergyHistoryManager.shared.getAppEnergyContributionHistory(appName: app.name, hours: 36)
                    chartView.updateData(history, appName: app.name)
                }
            } else {
                menuItem.isHidden = true
            }
        }
    }
    
    private func updateAppSubmenus() {
        for item in appHistoryItems {
            let hours = item.tag
            guard let submenu = item.submenu else { continue }
            submenu.removeAllItems()
            
            let drain = EnergyHistoryManager.shared.getBatteryDrain(hours: hours)
            let history = EnergyHistoryManager.shared.getTopApps(hours: hours, count: 15)
            
            if history.isEmpty {
                let emptyItem = NSMenuItem(title: LocalizedString("menu.no_data", comment: ""), action: nil, keyEquivalent: "")
                emptyItem.isEnabled = false
                submenu.addItem(emptyItem)
            } else {
                let drainItem = NSMenuItem(title: String(format: LocalizedString("menu.total_drain", comment: ""), drain.mah, drain.percent), action: nil, keyEquivalent: "")
                drainItem.isEnabled = false
                submenu.addItem(drainItem)
                submenu.addItem(NSMenuItem.separator())
                
                let maxMah = history.first?.mahEstimate ?? 1
                let maxCpuShare = history.first?.cpuShare ?? 1  // 动态最大值
                
                for app in history {
                    let appItem = createAppMenuItem(app: app, maxMah: maxMah, maxCpuShare: maxCpuShare)
                    submenu.addItem(appItem)
                }
                
                // 添加"显示更多"选项
                let allApps = EnergyHistoryManager.shared.getTopApps(hours: hours, count: 30)
                if allApps.count > 15 {
                    submenu.addItem(NSMenuItem.separator())
                    let moreItem = NSMenuItem(title: LocalizedString("menu.show_more_apps", comment: ""), action: nil, keyEquivalent: "")
                    let moreSubmenu = NSMenu()
                    
                    for app in allApps.dropFirst(15) {
                        let appItem = createAppMenuItem(app: app, maxMah: maxMah, maxCpuShare: maxCpuShare)
                        moreSubmenu.addItem(appItem)
                    }
                    
                    moreItem.submenu = moreSubmenu
                    submenu.addItem(moreItem)
                }
            }
        }
    }
    
    /// 创建应用菜单项（带子菜单显示完整名称和操作）
    private func createAppMenuItem(app: (name: String, cpuShare: Double, mahEstimate: Double, percentEstimate: Double, isRunning: Bool), maxMah: Double, maxCpuShare: Double) -> NSMenuItem {
        let status = app.isRunning ? " [" + LocalizedString("app.running", comment: "") + "]" : ""
        
        // 使用动态最大值绘制柱状图，类似当前活跃应用的样式
        let bar = makeBarChart(value: app.cpuShare, maxValue: max(1, maxCpuShare))
        
        // 截断显示名称以适应菜单
        let displayName = app.name.count > 25 ? String(app.name.prefix(22)) + "..." : app.name
        let title = String(format: "%@ %.0fmAh (%.1f%%) %@%@",
                           bar, app.mahEstimate, app.percentEstimate, displayName, status)
        
        let appItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        
        // 设置文字颜色：运行中为黑色，已关闭为灰色
        if !app.isRunning {
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.menuFont(ofSize: 0)
            ]
            appItem.attributedTitle = NSAttributedString(string: title, attributes: attrs)
        }
        
        // 创建子菜单显示完整名称和操作
        let actionSubmenu = NSMenu()
        
        // 显示完整应用名称
        let fullNameItem = NSMenuItem(title: "📱 \(app.name)", action: nil, keyEquivalent: "")
        fullNameItem.isEnabled = false
        actionSubmenu.addItem(fullNameItem)
        
        actionSubmenu.addItem(NSMenuItem.separator())
        
        // 在访达中显示（始终可用）
        let showInFinderItem = NSMenuItem(title: LocalizedString("alert.show_in_finder", comment: ""), action: #selector(showAppInFinder(_:)), keyEquivalent: "")
        showInFinderItem.target = self
        showInFinderItem.representedObject = app.name
        actionSubmenu.addItem(showInFinderItem)
        
        // 强制退出（仅运行中可用）
        if app.isRunning {
            let forceQuitItem = NSMenuItem(title: LocalizedString("menu.force_quit_short", comment: ""), action: #selector(forceQuitAppFromMenu(_:)), keyEquivalent: "")
            forceQuitItem.target = self
            forceQuitItem.representedObject = app.name
            actionSubmenu.addItem(forceQuitItem)
        }
        
        appItem.submenu = actionSubmenu
        return appItem
    }
    
    /// 在访达中显示应用
    @objc private func showAppInFinder(_ sender: NSMenuItem) {
        guard let appName = sender.representedObject as? String else { return }
        
        // 尝试多种路径查找应用
        let possiblePaths = [
            "/Applications/\(appName).app",
            "/System/Applications/\(appName).app",
            "/System/Library/CoreServices/\(appName).app",
            "/Library/Application Support/\(appName)",
            NSHomeDirectory() + "/Applications/\(appName).app"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
                return
            }
        }
        
        // 如果找不到，尝试使用 mdfind 查找
        let task = Process()
        task.launchPath = "/usr/bin/mdfind"
        task.arguments = ["kMDItemKind == 'Application' && kMDItemDisplayName == '\(appName)'"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let firstPath = output.components(separatedBy: "\n").first,
               !firstPath.isEmpty {
                NSWorkspace.shared.selectFile(firstPath, inFileViewerRootedAtPath: "")
                return
            }
        } catch {}
        
        // 找不到应用
        let alert = NSAlert()
        alert.messageText = LocalizedString("alert.app_not_found.title", comment: "")
        alert.informativeText = String(format: LocalizedString("alert.app_not_found.message", comment: ""), appName)
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizedString("alert.ok", comment: ""))
        alert.runModal()
    }
    
    /// 从菜单强制退出应用
    @objc private func forceQuitAppFromMenu(_ sender: NSMenuItem) {
        guard let appName = sender.representedObject as? String else { return }
        forceQuitApp(appName)
    }
    
    /// 强制退出应用
    private func forceQuitApp(_ appName: String) {
        guard let pid = EnergyHistoryManager.shared.getPidForApp(appName) else {
            // 找不到 PID，可能应用已经关闭
            let alert = NSAlert()
            alert.messageText = LocalizedString("alert.force_quit_fail.title", comment: "")
            alert.informativeText = String(format: LocalizedString("alert.force_quit_fail.message", comment: ""), appName)
            alert.alertStyle = .warning
            alert.addButton(withTitle: LocalizedString("alert.ok", comment: ""))
            alert.runModal()
            return
        }
        
        // 使用 kill 命令强制退出
        kill(Int32(pid), SIGKILL)
        
        // 刷新应用列表
        EnergyHistoryManager.shared.quickUpdateCurrentApps()
    }
    
    // MARK: - Actions
    
    private func toggleShowMoreCurrent() {
        showAllCurrentApps.toggle()
        
        // 强制立即更新所有菜单项的可见性
        let apps = EnergyHistoryManager.shared.getCachedCurrentApps()
        let topApps = apps.filter { $0.cpuPercent > 0 }
        let maxCPU = EnergyHistoryManager.shared.getMaxCPU()
        let displayCount = showAllCurrentApps ? min(50, topApps.count) : min(15, topApps.count)
        
        for (i, view) in currentAppViews.enumerated() {
            let menuItem = currentAppsSubmenu.items[i]
            
            if i < displayCount && i < topApps.count {
                let app = topApps[i]
                let bar = makeBarChart(value: app.cpuPercent, maxValue: maxCPU)
                view.setAppInfo(name: app.name, barChart: bar, cpuPercent: app.cpuPercent)
                menuItem.isHidden = false
            } else {
                menuItem.isHidden = true
            }
        }
        
        // 注意: showMoreButtonView 已移除
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        LaunchAtLogin.toggle()
        sender.state = LaunchAtLogin.isEnabled ? .on : .off
    }
    
    @objc private func resetTracker() {
        if let info = BatteryInfo.current() {
            tracker?.reset(capacity: info.currentCapacity, percentage: info.percentage)
            updateLiveContent()
        }
    }
    
    // MARK: - Language Actions
    
    @objc private func setLanguageSystem() {
        L10n.setLanguage(nil)
        rebuildAllMenus()
    }
    
    @objc private func setLanguageChinese() {
        L10n.setLanguage("zh-Hans")
        rebuildAllMenus()
    }
    
    @objc private func setLanguageEnglish() {
        L10n.setLanguage("en")
        rebuildAllMenus()
    }
    
    /// 重建所有菜单以应用新语言
    private func rebuildAllMenus() {
        // 先关闭当前菜单
        menu.cancelTracking()
        settingsMenu.cancelTracking()
        
        // 延迟重建菜单，避免在菜单打开时重建导致卡死
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 重建菜单
            self.setupMenu()
            self.setupSettingsMenu()
            
            // 更新状态栏图标
            self.updateStatusBar()
            
            // 触发数据刷新
            EnergyHistoryManager.shared.updateInBackground {
                self.updateLiveContent()
            }
        }
    }
    
    @objc private func quit() {
        // 必须同步保存，否则应用会在此操作完成前终止
        EnergyHistoryManager.shared.saveHistory(sync: true)
        backgroundTimer?.invalidate()
        liveTimer?.cancel()
        NSApplication.shared.terminate(nil)
    }
    
    deinit {
        backgroundTimer?.invalidate()
        liveTimer?.cancel()
    }
}
