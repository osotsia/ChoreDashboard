#!/usr/bin/env bash
set -e

SOURCE_SVG="images/icon.svg"
ICONSET_DIR="AppIcon.iconset"

mkdir -p "$ICONSET_DIR"

# 1. Rasterize SVG cleanly to 1024x1024 PNG using native AppKit (Zero white border artifact)
swift - <<EOF
import AppKit

let url = URL(fileURLWithPath: "$SOURCE_SVG")
guard let image = NSImage(contentsOf: url) else { exit(1) }
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
rep.size = NSSize(width: 1024, height: 1024)

NSGraphicsContext.saveGraphicsState()
let ctx = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current = ctx
image.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()

let pngData = rep.representation(using: .png, properties: [:])!
try pngData.write(to: URL(fileURLWithPath: "master_1024.png"))
EOF

# 2. Generate standard iconset sizes
sips -z 16 16     master_1024.png --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
sips -z 32 32     master_1024.png --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
sips -z 32 32     master_1024.png --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
sips -z 64 64     master_1024.png --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
sips -z 128 128   master_1024.png --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
sips -z 256 256   master_1024.png --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
sips -z 256 256   master_1024.png --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
sips -z 512 512   master_1024.png --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
sips -z 512 512   master_1024.png --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
sips -z 1024 1024 master_1024.png --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

# 3. Compile iconset into final Apple ICNS
iconutil -c icns "$ICONSET_DIR" -o "AppIcon.icns"

# 4. Clean up temporary files
rm -rf "$ICONSET_DIR" master_1024.png

echo "Successfully generated clean AppIcon.icns."