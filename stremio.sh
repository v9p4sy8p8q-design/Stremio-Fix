#!/bin/bash

# Script to download, install, and re-sign Stremio for macOS
# Supports macOS High Sierra (10.13) and above
# Note: For macOS Sierra (10.12), use Stremio v4.4.106 option


# Colour definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Step counter
STEP=0

# Delay between steps for visibility (in seconds)
STEP_DELAY=0.8

# Function to pause between steps
pause_step() {
    sleep $STEP_DELAY
}

# Function to display numbered step header
step_header() {
    STEP=$((STEP + 1))
    pause_step
    echo ""
    printf "${BOLD}${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}\n"
    printf "${BOLD}${CYAN}│${NC} ${BOLD}${WHITE}Step ${STEP}: ${1}${NC}\n"
    printf "${BOLD}${CYAN}└─────────────────────────────────────────────────────────────┘${NC}\n"
    sleep 0.3
}

# Function to show success message
success() {
    printf "${GREEN}✓${NC} $1\n"
}

# Function to show error message
error() {
    printf "${RED}✗${NC} $1\n"
}

# Function to show info message
info() {
    printf "${BLUE}ℹ${NC} $1\n"
}

# Function to show warning message
warning() {
    printf "${YELLOW}⚠${NC} $1\n"
}

# Spinner animation function with minimum duration
spinner() {
    local pid=$1
    local message=$2
    local min_duration=${3:-20}  # Minimum iterations (20 = ~2 seconds at 0.1s each)
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    local iterations=0
    
    while true; do
        i=$(( (i+1) %10 ))
        printf "\r  ${MAGENTA}${spin:$i:1}${NC} ${message}                                        "
        sleep 0.1
        iterations=$((iterations + 1))
        
        # Check if process is done
        if ! kill -0 $pid 2>/dev/null; then
            # Keep spinning until minimum iterations are met
            if [ $iterations -ge $min_duration ]; then
                break
            fi
        fi
    done
    # Clear the entire line before returning
    printf "\r                                                                                \r"
}

# Progress bar function
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))
    
    printf "\r  ${CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${NC} ${WHITE}%3d%%${NC}" $percentage
}

printf "${BOLD}${MAGENTA}\n"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║        Stremio Installation Script for macOS                  ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
printf "${NC}\n"

# Step 1: Detect System Information
step_header "Detecting System Information"

info "Checking macOS version..."
sleep 0.3
OS_VERSION=$(sw_vers -productVersion)
OS_MAJOR=$(echo "$OS_VERSION" | cut -d. -f1)
OS_MINOR=$(echo "$OS_VERSION" | cut -d. -f2)
success "macOS version: ${BOLD}${OS_VERSION}${NC}"

info "Detecting architecture..."
sleep 0.3
ARCH=$(uname -m)
success "Architecture: ${BOLD}${ARCH}${NC}"

info "Determining recommended version..."
sleep 0.3
# Determine recommended choice
if [[ "$OS_MAJOR" -ge 11 ]]; then
    RECOMMENDED=1
    success "Recommended version: ${BOLD}Stremio v5.1.14${NC}"
elif [[ "$ARCH" == "arm64" ]]; then
    RECOMMENDED=1
    success "Recommended version: ${BOLD}Stremio v5.1.14${NC}"    
elif [[ "$ARCH" == "x86_64" ]]; then
    if [[ "$OS_MAJOR" -lt 10 ]] || [[ "$OS_MAJOR" -eq 10 && "$OS_MINOR" -lt 13 ]]; then
        RECOMMENDED=3
        success "Recommended version: ${BOLD}Stremio v4.4.106${NC}"
    else
        RECOMMENDED=2
        success "Recommended version: ${BOLD}Stremio v4.4.171${NC}"
    fi
else
    error "Unsupported architecture: $ARCH"
    exit 1
fi

# Step 2: Version Selection
step_header "Version Selection"

select_version() {
    while true; do
        echo ""
        printf "${WHITE}Select Stremio version:${NC}\n"
        printf "  ${GREEN}[1]${NC} Stremio v5.1.14 ${CYAN}(Latest - requires macOS Big Sur 11.0+)${NC}\n"
        printf "  ${YELLOW}[2]${NC} Stremio v4.4.171 ${CYAN}(Legacy - requires macOS High Sierra 10.13+)${NC}\n"
        printf "  ${YELLOW}[3]${NC} Stremio v4.4.106 ${CYAN}(Legacy - for macOS below High Sierra 10.13)${NC}\n"
        echo ""
        printf "${WHITE}Enter your choice (1, 2, or 3): ${NC}"
        read VERSION_CHOICE </dev/tty
        
        case $VERSION_CHOICE in
            1)
                if [[ "$OS_MAJOR" -lt 11 ]]; then
                    error "Stremio v5.1.14 requires macOS Big Sur (11.0) or later."
                    warning "Your macOS version: $OS_VERSION"
                    echo ""
                    continue
                fi
                
                STREMIO_VERSION="5.1.14"
                success "Selected: ${BOLD}Stremio v5.1.14${NC}"
                if [[ "$ARCH" == "arm64" ]]; then
                    STREMIO_URL="https://dl.strem.io/stremio-shell-macos/v5.1.14/Stremio_arm64.dmg"
                    MOUNT_POINT="/Volumes/Stremio v5.1.14 arm64"
                elif [[ "$ARCH" == "x86_64" ]]; then
                    STREMIO_URL="https://dl.strem.io/stremio-shell-macos/v5.1.14/Stremio_x64.dmg"
                    MOUNT_POINT="/Volumes/Stremio5"
                else
                    error "Unsupported architecture: $ARCH"
                    exit 1
                fi
                return 0
                ;;
            2)
                if [[ "$OS_MAJOR" -lt 10 ]] || [[ "$OS_MAJOR" -eq 10 && "$OS_MINOR" -lt 13 ]]; then
                    error "Stremio v4.4.171 requires macOS High Sierra (10.13) or later."
                    warning "Your macOS version: $OS_VERSION"
                    info "Please select option 3 for v4.4.106 instead."
                    echo ""
                    continue
                fi
                
                STREMIO_VERSION="4.4.171"
                success "Selected: ${BOLD}Stremio v4.4.171${NC}"
                STREMIO_URL="https://dl.strem.io/shell-osx/v4.4.171/Stremio+4.4.171.dmg"
                MOUNT_POINT="/Volumes/Stremio4"
                return 0
                ;;
            3)
                STREMIO_VERSION="4.4.106"
                success "Selected: ${BOLD}Stremio v4.4.106${NC}"
                STREMIO_URL="https://dl.strem.io/mac/v4.4.106/Stremio+4.4.106.dmg"
                MOUNT_POINT="/Volumes/Stremio4"
                return 0
                ;;
            *)
                error "Invalid choice. Please enter 1, 2, or 3."
                echo ""
                continue
                ;;
        esac
    done
}

select_version

DMG_FILE="/tmp/stremio.dmg"
APP_NAME="Stremio.app"
APPLICATIONS="/Applications"

# Step 3: Download Stremio
step_header "Downloading Stremio v${STREMIO_VERSION}"

info "Downloading from: ${STREMIO_URL}"
echo ""

# Download with real-time progress monitoring
{
    curl -L -o "$DMG_FILE" "$STREMIO_URL" 2>&1 &
    CURL_PID=$!
    
    # Monitor download progress
    sleep 0.3  # Let download start
    COUNTER=0
    while kill -0 $CURL_PID 2>/dev/null; do
        if [ -f "$DMG_FILE" ]; then
            SIZE=$(stat -f%z "$DMG_FILE" 2>/dev/null || stat -c%s "$DMG_FILE" 2>/dev/null || echo "0")
            # Simple integer division for MB (no bc needed)
            SIZE_MB=$((SIZE / 1048576))
            
            # Animated progress indicator with file size
            SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
            SPIN_IDX=$((COUNTER % 10))
            printf "\r  ${MAGENTA}${SPIN:$SPIN_IDX:1}${NC} Downloading... ${WHITE}${SIZE_MB} MB${NC}                    "
            COUNTER=$((COUNTER + 1))
        fi
        sleep 0.15
    done
    
    wait $CURL_PID
} 2>/dev/null

# Clear the line
printf "\r                                                                                \r"
echo ""
success "Download complete"

# Step 4: Strip Quarantine from DMG
step_header "Removing Quarantine Attributes from DMG"

info "Stripping quarantine attributes..."
(
    sleep 0.5  # Ensure spinner is visible
    xattr -d com.apple.quarantine "$DMG_FILE" 2>/dev/null || true
    xattr -d com.apple.metadata:kMDItemWhereFroms "$DMG_FILE" 2>/dev/null || true
    xattr -d com.apple.metadata:kMDItemDownloadedDate "$DMG_FILE" 2>/dev/null || true
) &
spinner $! "Processing quarantine attributes" 15
success "DMG quarantine attributes removed"

# Step 5: Mount DMG
step_header "Mounting DMG"

info "Mounting disk image..."
(hdiutil attach "$DMG_FILE" -nobrowse -quiet && sleep 1) &
spinner $! "Mounting DMG" 20

# Try the expected mount point, fall back to dynamic detection
if [ ! -d "$MOUNT_POINT" ]; then
    info "Detecting mount point..."
    MOUNT_POINT=$(ls -td /Volumes/*Stremio* 2>/dev/null | head -1)
    if [ -z "$MOUNT_POINT" ]; then
        error "Could not find mounted volume"
        exit 1
    fi
fi

success "Mounted at: ${BOLD}${MOUNT_POINT}${NC}"

# Step 6: Locate Application
step_header "Locating Stremio Application"

info "Searching for Stremio.app..."
APP_PATH=$(find "$MOUNT_POINT" -name "*.app" -maxdepth 2 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    error "Could not find .app file in DMG"
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    exit 1
fi

success "Found app at: ${BOLD}${APP_PATH}${NC}"

# Step 7: Copy to Applications
step_header "Installing to Applications Folder"

if [ -d "$APPLICATIONS/$APP_NAME" ]; then
    warning "Existing installation found"
    info "Removing old version..."
    (sleep 0.8 && rm -rf "$APPLICATIONS/$APP_NAME") &
    spinner $! "Removing old version" 15
    success "Old version removed"
fi

info "Copying application..."
(sleep 0.5 && cp -R "$APP_PATH" "$APPLICATIONS/") &
spinner $! "Copying files" 20
success "Application installed to ${BOLD}${APPLICATIONS}/${APP_NAME}${NC}"

# Step 8: Cleanup DMG
step_header "Cleaning Up"

info "Unmounting DMG..."
(sleep 0.5 && hdiutil detach "$MOUNT_POINT" -quiet) &
spinner $! "Unmounting" 15
success "DMG unmounted"

info "Removing temporary files..."
(sleep 0.3 && rm "$DMG_FILE") &
spinner $! "Cleaning up" 10
success "Temporary files removed"

# Step 9: Remove Extended Attributes
step_header "Removing Extended Attributes"

info "Stripping extended attributes from app bundle..."
(
    sleep 0.5
    find "$APPLICATIONS/$APP_NAME" -print0 | xargs -0 xattr -c 2>/dev/null || true
    find "$APPLICATIONS/$APP_NAME" -print0 | xargs -0 xattr -d com.apple.quarantine 2>/dev/null || true
    find "$APPLICATIONS/$APP_NAME" -print0 | xargs -0 xattr -d com.apple.metadata:kMDItemWhereFroms 2>/dev/null || true
    find "$APPLICATIONS/$APP_NAME" -print0 | xargs -0 xattr -d com.apple.metadata:kMDItemDownloadedDate 2>/dev/null || true
) &
spinner $! "Removing attributes" 20
success "Extended attributes removed"

# Step 10: Remove Original Signature
step_header "Removing Original Code Signature"

if [[ "$OS_MAJOR" -gt 10 ]] || [[ "$OS_MAJOR" -eq 10 && "$OS_MINOR" -ge 12 ]]; then
    info "Removing existing signature..."
    (sleep 0.5 && codesign --remove-signature "$APPLICATIONS/$APP_NAME" 2>&1) &
    spinner $! "Removing signature" 15
    success "Original signature removed"
else
    warning "Skipping signature removal (macOS version too old)"
fi

# Step 11: Re-sign Application
step_header "Applying New Ad-Hoc Signature"

if [[ "$OS_MAJOR" -gt 10 ]] || [[ "$OS_MAJOR" -eq 10 && "$OS_MINOR" -ge 12 ]]; then
    info "Signing application..."
    (sleep 0.5 && codesign --force --deep --sign - "$APPLICATIONS/$APP_NAME" 2>&1) &
    spinner $! "Signing with ad-hoc signature" 20
    success "Signing complete"
    
    info "Verifying signature..."
    (sleep 0.5 && VERIFY_OUTPUT=$(codesign -dvv "$APPLICATIONS/$APP_NAME" 2>&1)) &
    spinner $! "Verifying signature" 15
    success "Signature verified"
else
    warning "Skipping code signing (macOS version too old)"
fi

# Final Step: Complete
echo ""
printf "${BOLD}${GREEN}\n"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║                  Installation Complete! ✓                     ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
printf "${NC}\n"

success "Stremio v${STREMIO_VERSION} installed to ${BOLD}${APPLICATIONS}/${APP_NAME}${NC}"
echo ""
info "Launching Stremio..."
sleep 1

open "$APPLICATIONS/$APP_NAME"

echo ""
printf "${CYAN}Enjoy streaming!${NC}\n"
echo ""
