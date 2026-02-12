#!/bin/bash

# Script to download, install, and re-sign Stremio for macOS
# Supports macOS High Sierra (10.13) and above

echo "=== Stremio Installation Script for macOS ==="

# Check macOS version
OS_VERSION=$(sw_vers -productVersion)
OS_MAJOR=$(echo "$OS_VERSION" | cut -d. -f1)
OS_MINOR=$(echo "$OS_VERSION" | cut -d. -f2)

if [[ "$OS_MAJOR" -lt 10 ]] || [[ "$OS_MAJOR" -eq 10 && "$OS_MINOR" -lt 13 ]]; then
    echo "Error: macOS High Sierra (10.13) or later is required."
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)

# Display system information in dashed boxes
echo ""
echo "------------------------------------"
echo "  macOS Version: $OS_VERSION"
echo "  Architecture:  $ARCH"
echo "------------------------------------"
echo ""

# Version selection
echo "Select Stremio version:"
echo "  [1] Stremio v5.1.14 (Latest)"
echo "  [2] Stremio v4.4.171 (Legacy)"
echo ""

# Add recommendation for ARM users
if [[ "$ARCH" == "arm64" ]]; then
    echo "⚠️  Recommendation: Option [1] is recommended for Apple Silicon Macs"
    echo ""
fi

read -p "Enter your choice (1 or 2): " VERSION_CHOICE </dev/tty

case $VERSION_CHOICE in
    1)
        STREMIO_VERSION="5.1.14"
        echo "Selected: Stremio v5.1.14"
        if [[ "$ARCH" == "arm64" ]]; then
            STREMIO_URL="https://dl.strem.io/stremio-shell-macos/v5.1.14/Stremio_arm64.dmg"
            MOUNT_POINT="/Volumes/Stremiov5arm"
        elif [[ "$ARCH" == "x86_64" ]]; then
            STREMIO_URL="https://dl.strem.io/stremio-shell-macos/v5.1.14/Stremio_x64.dmg"
            MOUNT_POINT="/Volumes/Stremiov5x86"
        else
            echo "Error: Unsupported architecture: $ARCH"
            exit 1
        fi
        ;;
    2)
        STREMIO_VERSION="4.4.171"
        echo "Selected: Stremio v4.4.171"
        STREMIO_URL="https://dl.strem.io/shell-osx/v4.4.171/Stremio+4.4.171.dmg"
        MOUNT_POINT="/Volumes/Stremio4"
        ;;
    *)
        echo "Error: Invalid choice."
        exit 1
        ;;
esac

DMG_FILE="/tmp/stremio.dmg"
APP_NAME="Stremio.app"
APPLICATIONS="/Applications"

# Download Stremio
echo ""
echo "Downloading Stremio v${STREMIO_VERSION}..."
curl -L -o "$DMG_FILE" "$STREMIO_URL"

# Strip quarantine from DMG immediately after download
# Using individual -d calls for compatibility with High Sierra's xattr
echo "Stripping quarantine attributes from DMG..."
xattr -d com.apple.quarantine "$DMG_FILE" 2>/dev/null || true
xattr -d com.apple.metadata:kMDItemWhereFroms "$DMG_FILE" 2>/dev/null || true
xattr -d com.apple.metadata:kMDItemDownloadedDate "$DMG_FILE" 2>/dev/null || true
echo "DMG quarantine attributes removed"

# Mount the DMG
echo "Mounting DMG..."
hdiutil attach "$DMG_FILE" -nobrowse -quiet
sleep 2

# Try the expected mount point, fall back to dynamic detection
if [ ! -d "$MOUNT_POINT" ]; then
    echo "Expected mount point not found, detecting automatically..."
    MOUNT_POINT=$(ls -td /Volumes/*Stremio* 2>/dev/null | head -1)
    if [ -z "$MOUNT_POINT" ]; then
        echo "Error: Could not find mounted volume"
        exit 1
    fi
fi

echo "Mounted at: $MOUNT_POINT"

# Find the .app file
echo "Looking for Stremio.app..."
APP_PATH=$(find "$MOUNT_POINT" -name "*.app" -maxdepth 2 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find .app file in DMG"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    exit 1
fi

echo "Found app at: $APP_PATH"

# Copy to Applications
echo "Copying to Applications folder..."
if [ -d "$APPLICATIONS/$APP_NAME" ]; then
    echo "Removing existing installation..."
    rm -rf "$APPLICATIONS/$APP_NAME"
fi

cp -R "$APP_PATH" "$APPLICATIONS/"
echo "Application copied"

# Unmount DMG
echo "Unmounting DMG..."
hdiutil detach "$MOUNT_POINT" -quiet

# Remove downloaded DMG
echo "Removing DMG file..."
rm "$DMG_FILE"

# Strip all extended attributes from the app bundle
# Using find + xattr loop for broader compatibility instead of xattr -r
echo "Stripping all extended attributes from app bundle..."
find "$APPLICATIONS/$APP_NAME" -print0 | xargs -0 xattr -c 2>/dev/null || true
find "$APPLICATIONS/$APP_NAME" -print0 | xargs -0 xattr -d com.apple.quarantine 2>/dev/null || true
find "$APPLICATIONS/$APP_NAME" -print0 | xargs -0 xattr -d com.apple.metadata:kMDItemWhereFroms 2>/dev/null || true
find "$APPLICATIONS/$APP_NAME" -print0 | xargs -0 xattr -d com.apple.metadata:kMDItemDownloadedDate 2>/dev/null || true
echo "Extended attributes removed"

# Remove existing signature
# --remove-signature was added in macOS 10.12 so safe for High Sierra+
echo "Removing original code signature..."
codesign --remove-signature "$APPLICATIONS/$APP_NAME" 2>&1 || true
echo "Original signature removed"

# Re-sign with ad-hoc signature
# -f/--force and --deep are supported on High Sierra+
echo "Applying new ad-hoc signature..."
codesign --force --deep --sign - "$APPLICATIONS/$APP_NAME" 2>&1
echo "Signing complete"

# Verify the signature
echo "Verifying signature..."
codesign -dvv "$APPLICATIONS/$APP_NAME" 2>&1

echo ""
echo "=== Installation Complete ==="
echo "Stremio v${STREMIO_VERSION} installed to $APPLICATIONS/$APP_NAME"
echo ""
echo "Launching Stremio..."
open "$APPLICATIONS/$APP_NAME"
