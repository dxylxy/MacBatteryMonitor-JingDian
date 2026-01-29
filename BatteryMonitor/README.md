# 静•电 (Battery Monitor - JingDian)

> 极致简约，静默守护。一款遵循现代审美主义的 macOS 菜单栏电池监控应用。

[![License](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black.svg)]()
[![Swift](https://img.shields.io/badge/swift-5.9-black.svg)]()

[English](README_EN.md) | [中文](README.md)

---

## 📖 应用概述

**静•电** (Battery Monitor) 是一款专为 macOS 设计的轻量级电池管理工具。它摒弃了传统监控软件繁杂的界面，采用极简主义设计语言，旨在以最低的系统资源占用，提供最精准、实用的电池健康与能耗数据。

无论是日常办公还是移动开发，它都能帮你实时掌握 Mac 的电力状况，精准定位"偷电"应用，延长电池续航寿命。

## ✨ 核心功能

### 1. 深度电池监控
- **实时数据**：精准显示当前电量、充电/放电功率 (W)、电流 (mA)、电压 (V) 及电池温度。
- **健康管理**：直观展示电池健康度、循环次数及设计容量对比。
- **剩余时间预估**：基于当前功耗实时计算剩余使用时间或充电所需时间。

### 2. 应用能耗分析
- **实时排行榜**：秒级刷新当前 CPU 占用最高的应用列表，立即发现高能耗进程。
- **历史回溯**：自动记录过去 48 小时的应用能耗数据。
- **能耗占比**：可视化展示各应用在选定时间段内的耗电比例（%）和估算耗电量（mAh）。

### 3. 持久化数据追踪
- **自动保存**：应用退出或重启后，历史能耗数据自动恢复，记录永不丢失。
- **定时备份**：后台每 5 分钟自动备份数据，防止意外丢失。

### 4. 极致性能与体验
- **静默运行**：后台运行时 CPU 占用平均 < 0.1%，内存占用 < 20MB。
- **智能刷新**：菜单展开时每秒刷新，菜单关闭后自动进入低功耗模式（60秒/次）。
- **多语言支持**：原生支持简体中文与英文，可跟随系统或手动切换。

## 🛠 技术架构

本项目完全使用 **Swift 5.9** 原生开发，不依赖任何庞大的第三方库，确保了应用的轻量与高效。

- **User Interface**: 基于 **AppKit** 构建的原生 macOS 菜单栏界面。
- **Battery Core**: 使用底层 **IOKit** 框架直接与硬件通信，获取最准确的电池传感器数据。
- **Process Monitoring**: 通过系统级 BSD 命令 (`sysctl`/`ps`) 获取进程信息，并经过智能算法过滤系统守护进程。
- **Data Persistence**: 采用 `Codable` 协议结合 JSON 序列化，实现轻量级文件存储。

## 📥 安装与配置

### 方式一：下载安装包 (推荐)
1. 访问 [Releases](https://github.com/dxylxy/BatteryMonitor-JingDian/releases) 页面。
2. 下载最新版本的 `静•电.dmg`。
3. 双击打开 DMG 文件，将 `静•电` 拖入 `Applications` 文件夹。
4. 启动应用即可。

### 方式二：从源码构建
如果您是开发者或希望自行编译：

```bash
# 1. 克隆仓库
git clone https://github.com/dxylxy/BatteryMonitor-JingDian.git
cd BatteryMonitor-JingDian

# 2. 执行打包脚本
./package.sh

# 3. 安装
# 构建完成后，在 dist/ 目录下可以找到生成的 DMG 安装包
open dist/
```

## 🖥 使用操作说明

1. **启动应用**：应用启动后会常驻顶部菜单栏，显示电池图标及电量百分比。
2. **查看详情**：点击菜单栏图标，展开详细信息面板。
3. **切换视图**：
   - **应用能耗历史**：查看过去 1/4/12/24/48 小时的能耗统计。
   - **当前活跃应用**：查看当前正在运行并占用 CPU 的应用。
4. **更多设置**：
   - **右键点击**菜单栏图标，进入设置菜单。
   - 可进行**语言切换**、**开机自启动**设置、或**导出能耗报告** (CSV/JSON)。

## ⚠️ 已知问题与限制

- **系统进程权限**：部分系统级进程（如 `kernel_task`）的详细能耗数据受限于 macOS 沙盒机制，可能无法完全获取。
- **刷新率**：为了保证低功耗，后台刷新频率限制为 1 分钟一次，这意味着能耗历史数据的粒度为分钟级。

## 🤝 贡献指南

我们非常欢迎社区贡献！如果您有通过 Issue 报告 Bug 或提交 Pull Request 的想法：

1. Fork 本仓库。
2. 创建您的特性分支 (`git checkout -b feature/AmazingFeature`)。
3. 提交您的更改 (`git commit -m 'Add some AmazingFeature'`)。
4. 推送到分支 (`git push origin feature/AmazingFeature`)。
5. 打开一个 Pull Request。

## 📄 许可证

本项目基于 MIT 许可证开源。详情请参阅 [LICENSE](LICENSE) 文件。

---
Copyright © 2026 Lyon. All rights reserved.
