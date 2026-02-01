#!/bin/bash
set -e

# 配置
APP_NAME="Static"
APP_DIR="静•电.app"
DMG_NAME="静•电.dmg"
DIST_DIR="dist"

echo "🚀 开始打包流程..."

# 1. 清理
echo "🧹 清理旧构建..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"
# 注意：不删除 .build 也可以，增量编译更快

# 2. 编译
echo "🔨 正在编译 Release 版本..."
swift build -c release

# 3. 更新应用包
echo "📦 更新应用包内容..."
# 确保目录结构存在
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# 复制二进制文件
cp .build/release/MacBatteryMonitor "$APP_DIR/Contents/MacOS/"

# 生成 PkgInfo
echo "APPL????" > "$APP_DIR/Contents/PkgInfo"

# 生成 Info.plist
cat > "$APP_DIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>zh-Hans</string>
        <string>en</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>MacBatteryMonitor</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.lyon.jingdian</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>静•电</string>
    <key>CFBundleDisplayName</key>
    <string>静•电</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>3.2.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Lyon. All rights reserved.</string>
</dict>
</plist>
EOF

# 复制图标 (如果存在)
if [ -f "AppIcon.icns" ]; then
    echo "🎨 应用图标..."
    cp AppIcon.icns "$APP_DIR/Contents/Resources/"
fi

# 复制本地化资源
if [ -d "Resources" ]; then
    echo "🌍 复制本地化资源..."
    cp -r "Resources/" "$APP_DIR/Contents/Resources/"
fi

# 简单的 Ad-hoc 签名 (避免本地运行时出现权限问题)
echo "🔏 签署应用..."
find "$APP_DIR" -name "._*" -delete
find "$APP_DIR" -name ".DS_Store" -delete
dot_clean -m "$APP_DIR" || true
xattr -cr "$APP_DIR"
codesign --force --deep --sign - "$APP_DIR"

# 4. 创建 DMG
echo "💿 创建 DMG 安装包..."
DMG_TMP="$DIST_DIR/tmp_dmg"
mkdir -p "$DMG_TMP"

# 复制 .app
cp -r "$APP_DIR" "$DMG_TMP/"

# 创建 /Applications 软链接
ln -s /Applications "$DMG_TMP/Applications"

# 生成 .dmg
# -volname: 挂载后的卷名
# -srcfolder: 源文件夹
# -ov: 覆盖已存在文件
# -format UDZO: 压缩格式
hdiutil create -volname "静•电" -srcfolder "$DMG_TMP" -ov -format UDZO "$DIST_DIR/$DMG_NAME"

# 清理临时文件
rm -rf "$DMG_TMP"

echo "✅ 打包完成!"
echo "📂 输出文件: $DIST_DIR/$DMG_NAME"
echo "👉 你可以将此 DMG 文件发布到 GitHub Releases"
