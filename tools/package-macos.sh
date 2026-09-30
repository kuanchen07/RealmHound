#!/usr/bin/env bash
# ==============================================================================
# RealmHound macOS App Bundle & DMG Packaging Script
# ==============================================================================
# Builds RealmHound for macOS and packages it into:
#   1. RealmHound.app (macOS application bundle)
#   2. RealmHound-<version>-<arch>.dmg (Drag-and-drop installer DMG)
#
# Requirements:
#   - macOS with Xcode Command Line Tools
#   - Rust stable toolchain
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
REALMHOUND_DIR="$REPO_ROOT/realmhound"

# Determine target architecture
ARCH="$(uname -m)"
TARGET="${1:-""}"

if [ -z "$TARGET" ]; then
    if [ "$ARCH" = "arm64" ]; then
        TARGET="aarch64-apple-darwin"
    else
        TARGET="x86_64-apple-darwin"
    fi
fi

echo "==> Packaging RealmHound for target: $TARGET"

# Extract version from Cargo.toml
VERSION=$(grep -m 1 '^version = ' "$REALMHOUND_DIR/Cargo.toml" | cut -d '"' -f 2)
if [ -z "$VERSION" ]; then
    echo "Error: Could not extract version from $REALMHOUND_DIR/Cargo.toml"
    exit 1
fi
echo "==> Building RealmHound v$VERSION ($TARGET)..."

# Build release binary
cd "$REALMHOUND_DIR"
cargo build --release --target "$TARGET" -p RealmHound

if [ -f "$REALMHOUND_DIR/target/$TARGET/release/RealmHound" ]; then
    BINARY_PATH="$REALMHOUND_DIR/target/$TARGET/release/RealmHound"
elif [ -f "$REALMHOUND_DIR/target/release/RealmHound" ]; then
    BINARY_PATH="$REALMHOUND_DIR/target/release/RealmHound"
else
    echo "Error: Compiled binary not found at $REALMHOUND_DIR/target/$TARGET/release/RealmHound"
    exit 1
fi

DIST_DIR="$REPO_ROOT/dist"
APP_NAME="RealmHound.app"
APP_DIR="$DIST_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> Creating macOS App Bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy binary
cp "$BINARY_PATH" "$MACOS_DIR/RealmHound"
chmod +x "$MACOS_DIR/RealmHound"

# Copy assets
ASSETS_SRC="$REALMHOUND_DIR/crates/realmhound/assets"
if [ -d "$ASSETS_SRC" ]; then
    echo "==> Bundling assets..."
    mkdir -p "$RESOURCES_DIR/assets"
    cp -R "$ASSETS_SRC"/* "$RESOURCES_DIR/assets/"
fi

# Generate Info.plist
echo "==> Writing Info.plist..."
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>RealmHound</string>
    <key>CFBundleDisplayName</key>
    <string>RealmHound</string>
    <key>CFBundleIdentifier</key>
    <string>com.pillarzz.realmhound</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>CFBundleExecutable</key>
    <string>RealmHound</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 Lovens &amp; Pillar. MIT License.</string>
</dict>
</plist>
EOF

# Create AppIcon.icns if iconset tools are available
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICNS_FILE="$RESOURCES_DIR/AppIcon.icns"

if command -v iconutil >/dev/null 2>&1 && [ -f "$ASSETS_SRC/icon.ico" ]; then
    echo "==> Generating AppIcon.icns..."
    mkdir -p "$ICONSET_DIR"
    # Convert from png or ico using sips or python if available
    python3 -c "
from PIL import Image
import os
try:
    img = Image.open('$ASSETS_SRC/icon.ico')
    sizes = [16, 32, 64, 128, 256, 512]
    for s in sizes:
        img.resize((s, s), Image.LANCZOS).save(f'$ICONSET_DIR/icon_{s}x{s}.png')
        img.resize((s*2, s*2), Image.LANCZOS).save(f'$ICONSET_DIR/icon_{s}x{s}@2x.png')
except Exception as e:
    print('Notice: Could not auto-generate iconset with PIL:', e)
" 2>/dev/null || true

    if [ -f "$ICONSET_DIR/icon_512x512.png" ]; then
        iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE" || true
    fi
    rm -rf "$ICONSET_DIR"
fi

echo "==> RealmHound.app successfully assembled at: $APP_DIR"

# Build DMG
DMG_NAME="RealmHound-$VERSION-$ARCH.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
DMG_STAGE="$DIST_DIR/dmg_staging"

if command -v hdiutil >/dev/null 2>&1; then
    echo "==> Packaging into DMG: $DMG_PATH..."
    rm -rf "$DMG_STAGE" "$DMG_PATH"
    mkdir -p "$DMG_STAGE"

    cp -R "$APP_DIR" "$DMG_STAGE/"
    ln -s /Applications "$DMG_STAGE/Applications"

    hdiutil create \
        -volname "RealmHound" \
        -srcfolder "$DMG_STAGE" \
        -ov \
        -format UDZO \
        "$DMG_PATH"

    rm -rf "$DMG_STAGE"
    echo "==> Successfully created DMG at: $DMG_PATH"
else
    echo "Notice: hdiutil not found; skipping DMG creation (App bundle is ready)."
fi

echo "==> All macOS packaging steps completed successfully!"
