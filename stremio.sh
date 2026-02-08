#!/bin/bash

# Script to download, install, and re-sign Stremio for macOS
# This helps bypass macOS Gatekeeper restrictions

echo "=== Stremio Installation Script for macOS ==="

# Detect architecture
ARCH=$(uname -m)
echo "Detected architecture: $ARCH"

# Variables
if [[ "$ARCH" == "arm64" ]]; then
    STREMIO_URL="https://dl.strem.io/stremio-shell-macos/v5.1.12/Stremio_arm64.dmg"
    MOUNT_POINT="/Volumes/Stremio v5.1.12 arm64"
    echo "Using Apple Silicon (ARM64) version"
elif [[ "$ARCH" == "x86_64" ]]; then
    STREMIO_URL="https://dl.strem.io/stremio-shell-macos/v5.1.12/Stremio_x64.dmg"
    MOUNT_POINT="/Volumes/Stremio v5.1.12 x64"
    echo "Using Intel (x64) version"
else
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
fi

DMG_FILE="/tmp/stremio.dmg"
APP_NAME="Stremio.app"
APPLICATIONS="/Applications"

# Download Stremio
echo "Downloading Stremio..."
curl -L -o "$DMG_FILE" "$STREMIO_URL"

# Mount the DMG
echo "Mounting DMG..."
hdiutil attach "$DMG_FILE" -nobrowse -quiet

# Wait for mount
sleep 2

echo "Mount point: $MOUNT_POINT"

# Find the .app file
echo "Looking for Stremio.app..."
APP_PATH=$(find "$MOUNT_POINT" -name "*.app" -maxdepth 2 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: Could not find .app file in DMG"
    echo "Contents of mount point:"
    ls -la "$MOUNT_POINT"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    exit 1
fi

echo "Found app at: $APP_PATH"

# Copy to Applications
echo "Copying to Applications folder..."
if [ -d "$APPLICATIONS/$APP_NAME" ]; then
    echo "Removing existing Stremio installation..."
     rm -rf "$APPLICATIONS/$APP_NAME"
fi

cp -R "$APP_PATH" "$APPLICATIONS/"

# Unmount DMG
echo "Unmounting DMG..."
hdiutil detach "$MOUNT_POINT" -quiet

# Remove downloaded DMG
echo "Removing DMG file..."
rm "$DMG_FILE"

# Remove quarantine attribute
echo "Removing quarantine flag..."
 xattr -c -r "$APPLICATIONS/$APP_NAME" 2>&1
echo "Quarantine removal completed"

# Remove existing signatures
echo "Removing original signatures..."
 codesign --remove-signature "$APPLICATIONS/$APP_NAME" 2>&1
echo "Signature removal completed"

# Re-sign the app
echo "Adding new ad-hoc signature..."
 codesign --force --deep --sign - "$APPLICATIONS/$APP_NAME" 2>&1
echo "Signing completed"

# Verify the signature
echo ""
echo "Verifying signature..."
codesign -d -v -v "$APPLICATIONS/$APP_NAME" 2>&1

echo ""
echo "=== Installation Complete ==="
echo "Stremio has been installed to $APPLICATIONS/$APP_NAME"
echo "The app has been re-signed and quarantine flags removed."
echo ""
echo "Testing if app can be opened..."
open "$APPLICATIONS/$APP_NAME"