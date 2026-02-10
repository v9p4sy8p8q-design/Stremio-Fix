#!/bin/bash

# Script to download, install, and re-sign Stremio for macOS
# This helps bypass macOS Gatekeeper restrictions

echo "=== Stremio Installation Script for macOS ==="

# Detect architecture
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

# Version selection
echo ""
echo "Select Stremio version:"
echo "  [1] Stremio v5.1.12 (Latest)"
echo "  [2] Stremio v4.4.171 (Legacy)"
echo ""
read -p "Enter your choice (1 or 2): " VERSION_CHOICE

case $VERSION_CHOICE in
    1)
        STREMIO_VERSION="5.1.12"
        echo "Selected: Stremio v5.1.12"
        if [[ "$ARCH" == "arm64" ]]; then
            STREMIO_URL="https://dl.strem.io/stremio-shell-macos/v5.1.12/Stremio_arm64.dmg"
            MOUNT_POINT="/Volumes/Stremio v5.1.12 arm64"
        elif [[ "$ARCH" == "x86_64" ]]; then
            STREMIO_URL="https://dl.strem.io/stremio-shell-macos/v5.1.12/Stremio_x64.dmg"
            MOUNT_POINT="/Volumes/Stremio v5.1.12 x64"
        else
            echo "Error: Unsupported architecture: $ARCH"
            exit 1
        fi
        ;;
    2)
        STREMIO_VERSION="4.4.171"
        echo "Selected: Stremio v4.4.171"
        STREMIO_URL="https://dl.strem.io/shell-osx/v4.4.171/Stremio+4.4.171.dmg"
        MOUNT_POINT="/Volumes/Stremio 4.4.171"
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
echo "Stripping quarantine attributes from DMG..."
xattr -d com.apple.quarantine "$DMG_FILE" 2>/dev/null || true
xattr -d com.apple.metadata:kMDItemWhereFroms "$DMG_FILE" 2>/dev/null || true
xattr -d com.apple.metadata:kMDItemDownloadedDate "$DMG_FILE" 2>/dev/null || true
xattr -r -d com.apple.quarantine "$DMG_FILE" 2>/dev/null || true
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
echo "Stripping all extended attributes from app bundle..."
 xattr -c -r "$APPLICATIONS/$APP_NAME" 2>/dev/null || true
 xattr -d -r com.apple.quarantine "$APPLICATIONS/$APP_NAME" 2>/dev/null || true
 xattr -d -r com.apple.metadata:kMDItemWhereFroms "$APPLICATIONS/$APP_NAME" 2>/dev/null || true
 xattr -d -r com.apple.metadata:kMDItemDownloadedDate "$APPLICATIONS/$APP_NAME" 2>/dev/null || true
echo "Extended attributes removed"

# Remove existing signature
echo "Removing original code signature..."
codesign --remove-signature "$APPLICATIONS/$APP_NAME" 2>&1
echo "Original signature removed"

# Re-sign the app
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