#!/usr/bin/env bash
set -e

# 1. Compile release binary
swift build -c release

# 2. Assemble bundle structure
mkdir -p "dist/ChoreDashboard.app/Contents/MacOS"
mkdir -p "dist/ChoreDashboard.app/Contents/Resources"
cp .build/release/ChoreDashboard "dist/ChoreDashboard.app/Contents/MacOS/"

# 3. Copy icon asset into bundle
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "dist/ChoreDashboard.app/Contents/Resources/AppIcon.icns"
else
    echo "WARNING: AppIcon.icns not found in root directory."
fi

# 4. Write complete Info.plist with icon binding
cat <<EOF > "dist/ChoreDashboard.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ChoreDashboard</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.choredashboard</string>
    <key>CFBundleName</key>
    <string>ChoreDashboard</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

# 5. Invalidate macOS LaunchServices cache for the modified bundle
touch "dist/ChoreDashboard.app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "dist/ChoreDashboard.app"

open "dist/ChoreDashboard.app"