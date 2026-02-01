# MacBatteryMonitor (Static)

> Minimalist aesthetics, silent guardian. An **ultra‑low power battery & app energy intelligence tool** for macOS.

[![License](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black.svg)]()
[![Swift](https://img.shields.io/badge/swift-5.9-black.svg)]()

[中文](README.md) | [English](README_EN.md)

---

## 📖 Overview

**MacBatteryMonitor** is a lightweight macOS energy intelligence tool. It avoids cluttered dashboards and focuses on what matters: **how long the battery will last, what is draining it, and why**.

It compresses battery curves, app energy ranking, and insight‑oriented views into a single menu‑bar surface, ideal for commuters, developers, and power users who care about every percent.

## ✨ Highlights

### 1) Battery At‑a‑Glance
- **Real‑time Metrics**: capacity, charge/discharge power (W), amperage (mA), voltage (V), temperature.
- **48‑Hour Curve**: smooth Bezier line with charging segments highlighted.
- **Health View**: cycles, design capacity, and health percentage.
- **Time Estimates**: dynamic remaining time or time‑to‑full.

### 2) App Energy Intelligence
- **Live Ranking**: second‑level refresh for the hottest apps.
- **36‑Hour History**: persistent per‑app energy timeline.
- **Energy Contribution Curve**: contribution to total drain, not raw CPU percent.
- **Smart Gap Detection**: sleep/idle windows annotated for clean charts.

### 3) Flexible Ranking Modes
- **Today’s Total Drain**: distributes today’s battery drop across apps.
- **Last Discharge Window**: focuses only on the most recent continuous drain.
- **Menu‑side Toggle**: switch modes without closing the menu.

<p align="center">
  <img src="应用展示/2026-01-30_03-30-34.png" width="45%" />
  <img src="应用展示/2026-01-30_13-15-57.png" width="45%" />
</p>

### 4) Data That Persists
- **Auto‑Restore**: history is kept across restarts.
- **5‑Minute Backup**: safe background snapshots.
- **Export**: CSV / JSON for deeper analysis.

### 5) Ultra‑Light Experience
- **Silent Operation**: CPU avg < 0.1%, memory < 20MB.
- **Smart Refresh**: 1s when open, 60s when closed.
- **Multi‑Language**: Simplified Chinese & English.

## 🧠 Why You’ll Love It
- Instantly understand why battery drops accelerate
- Zero dashboard fatigue, zero noise
- Accurate energy insights in a single click
- Learn your Mac’s true power behavior over time

## 🛠 Technical Architecture

Built in native **Swift 5.9** without heavy dependencies for maximum efficiency.

- **User Interface**: AppKit native menu‑bar UI
- **Battery Core**: IOKit hardware sensor access
- **Process Monitoring**: system sampling + intelligent filtering
- **Data Persistence**: Codable + JSON lightweight storage

## 📥 Installation

### Method 1: Download App (Recommended)
1. Visit [Releases](https://github.com/dxylxy/MacBatteryMonitor-JingDian/releases)
2. Download the latest `静•电.dmg`
3. Drag it into `Applications`
4. Launch and enjoy

### Method 2: Build from Source
```bash
git clone https://github.com/dxylxy/MacBatteryMonitor-JingDian.git
cd MacBatteryMonitor-JingDian
./package.sh
open dist/
```

## 🖥 Usage Guide

1. **Launch**: menu‑bar icon shows battery percent  
2. **View Details**: click to open the panel  
3. **Switch Views**: energy history / active apps  
4. **Settings**: right‑click for language, launch at login, export reports  

## ⚠️ Known Limits

- Some system processes are restricted by macOS permissions
- Background refresh is limited to once per minute for low power

## ☕️ Support

If this tool helps you, consider supporting the project!

<div align="center">
  <img src="sponsers/WeChat.JPG" alt="WeChat Pay" width="200" style="margin-right: 20px;" />
  <img src="sponsers/Alipay.JPG" alt="AliPay" width="200" />
</div>

## 🤝 Contribution

We welcome contributions:
1. Fork the repo
2. Create a branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add some AmazingFeature'`)
4. Push (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.

---
Copyright © 2026 Lyon. All rights reserved.
