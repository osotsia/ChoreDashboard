# 1. Compile release binary
swift build -c release

# 2. Assemble bundle structure
mkdir -p "dist/ChoreDashboard.app/Contents/MacOS"
mkdir -p "dist/ChoreDashboard.app/Contents/Resources"
cp .build/release/ChoreDashboard "dist/ChoreDashboard.app/Contents/MacOS/"

# 3. Write minimal Info.plist
cat <<EOF > "dist/ChoreDashboard.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ChoreDashboard</string>
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

open "dist/ChoreDashboard.app"