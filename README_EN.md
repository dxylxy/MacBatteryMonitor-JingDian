# 静•电 (Battery Monitor - JingDian)

> Minimalist, silent guardian. An **ultra-low power battery and application monitoring tool** for macOS that follows modern aestheticism.


[![License](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-black.svg)]()
[![Swift](https://img.shields.io/badge/swift-5.9-black.svg)]()

[English](README_EN.md) | [中文](README.md)

---

## 📖 Overview

**Battery Monitor** (JingDian) is a lightweight battery management tool designed specifically for macOS. Abandoning the complex interfaces of traditional monitoring software, it adopts a minimalist design language aimed at providing the most accurate and practical battery health and energy consumption data with minimal system resource usage.

Whether for daily office work or mobile development, it helps you grasp your Mac's power status in real-time, precisely locate "power-draining" applications, and extend battery life.

## ✨ Core Features

### 1. In-depth Battery Monitoring
- **Real-time Data**: Accurately displays current charge level, charge/discharge power (W), current (mA), voltage (V), and battery temperature.
- **Visual Curves**: Supports viewing battery level changes over the **last 48 hours**, drawn using **smooth Bézier curves**, making power drops or charging phases (highlighted in green) ease to see at a glance.
- **Health Management**: Intuitively displays battery health, cycle count, and design capacity comparison.
- **Time Remaining Estimation**: Real-time calculation of remaining usage time or time to full charge based on current power consumption.

### 2. Precise Application Energy Analysis
- **Real-time Rankings**: Updates the list of applications with the highest CPU usage every second, instantly spotting high-energy processes.
- **36-Hour History**: Automatically records application energy consumption data for the past **36 hours**.
- **Energy Contribution Percentage**: Unlike traditional CPU usage rates, we calculate the **energy contribution percentage (0-100%)**. This more accurately reflects the proportion of total system power consumption used by an application at a given moment.
- **Smart Sleep Detection**: Automatically detects system sleep or shutdown periods, identified by gray break areas in the chart.
<img width="862" height="931" alt="2026-01-30_13-15-57" src="https://github.com/user-attachments/assets/ac3650b8-5867-4a58-9d79-cade37ecd8c9" />
<img width="943" height="716" alt="2026-01-30_03-30-34" src="https://github.com/user-attachments/assets/9b562019-6892-436c-be9c-32aa519fa076" />


### 3. Persistent Data Tracking
- **Auto-Save**: Historical energy data is automatically restored after the application exits or restarts, ensuring records are never lost.
- **Scheduled Backup**: Data is automatically backed up in the background every 5 minutes to prevent accidental loss.

### 4. Extreme Performance & Experience
- **Silent Operation**: Average CPU usage **< 0.1%** and memory usage **< 20MB** when running in the background.
- **Smart Refresh**: Refreshes every second when the menu is open, and automatically enters ultra-low power mode (60 seconds/cycle) when the menu is closed.
- **Multi-language Support**: Native support for Simplified Chinese and English, following the system language or manually switchable.

## 🛠 Technical Architecture

This project is developed entirely in native **Swift 5.9**, without relying on any massive third-party libraries, ensuring the application remains lightweight and efficient.

- **User Interface**: Native macOS menu bar interface built on **AppKit**.
- **Battery Core**: Communicates directly with hardware using the underlying **IOKit** framework to obtain the most accurate battery sensor data.
- **Process Monitoring**: Retrieves process information via system-level BSD commands (`sysctl`/`ps`) and filters system daemons through smart algorithms.
- **Data Persistence**: Uses the `Codable` protocol combined with JSON serialization for lightweight file storage.

## 📥 Installation

### Method 1: Download Installer (Recommended)
1. Visit the [Releases](https://github.com/dxylxy/BatteryMonitor-JingDian/releases) page.
2. Download the latest version of `静•电.dmg`.
3. Double-click the DMG file and drag `Battery Monitor` into the `Applications` folder.
4. Launch the application.

### Method 2: Build from Source
If you are a developer or wish to compile it yourself:

```bash
# 1. Clone the repository
git clone https://github.com/dxylxy/BatteryMonitor-JingDian.git
cd BatteryMonitor-JingDian

# 2. Run the package script
./package.sh

# 3. Install
# After building, the generated DMG installer can be found in the dist/ directory
open dist/
```

## 🖥 Usage Guide

1. **Launch App**: Once started, the application will reside in the top menu bar, displaying a battery icon and percentage.
2. **View Details**: Click the menu bar icon to expand the detailed information panel.
3. **Switch Views**:
   - **App Energy History**: View energy contribution curves for each application over the past 36 hours.
   - **Current Active Apps**: View applications currently running and consuming CPU.
4. **More Settings**:
   - **Right-click** the menu bar icon to enter the settings menu.
   - You can toggle **Language**, set **Launch at Login**, or **Export Energy Reports** (CSV/JSON).

## ⚠️ Known Issues & Limitations

- **System Process Permissions**: Detailed energy data for some system-level processes (like `kernel_task`) is limited by the macOS sandbox mechanism and may not be fully accessible.
- **Refresh Rate**: To ensure low power consumption, the background refresh frequency is limited to once per minute, meaning the granularity of energy history data is at the minute level.

## ☕️ Support & Donation

If you find this tool helpful, please consider buying me a coffee! Your support is my motivation to continue maintenance.

<div align="center">
  <img src="https://github.com/user-attachments/assets/c5359452-3f0d-43ca-81fa-0fd62cb836b2" alt="WeChat Pay" width="200" style="margin-right: 20px;" />
  <img src="https://github.com/user-attachments/assets/0d375b1b-57cd-4940-89b8-33b153245657" alt="AliPay" width="200" />
</div>

## 🤝 Contribution Guide

We welcome community contributions! If you have ideas for reporting bugs via Issues or submitting Pull Requests:

1. Fork this repository.
2. Create your feature branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

## 📄 License

This project is open-source under the MIT License. See the [LICENSE](LICENSE) file for details.

---
Copyright © 2026 Lyon. All rights reserved.
