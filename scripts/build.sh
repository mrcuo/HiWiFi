#!/bin/bash
# ============================================================
# HiWiFi (WiFi借一下) — Build Script
# 
# Usage:
#   chmod +x scripts/build.sh
#   ./scripts/build.sh            # Debug build
#   ./scripts/build.sh --release  # Release build + archive
#   ./scripts/build.sh --dmg      # Release build + create DMG
# ============================================================

set -euo pipefail

# ---------- Colors & Helpers ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

info()    { echo -e "${BLUE}[ℹ]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[⚠]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step()    { echo -e "\n${PURPLE}${BOLD}==>${NC}${BOLD} $1${NC}"; }

# ---------- Configuration ----------
PROJECT_NAME="HiWiFi"
SCHEME="HiWiFi"
PROJECT_FILE="${PROJECT_NAME}.xcodeproj"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
APP_PATH="${BUILD_DIR}/${PROJECT_NAME}.app"
DMG_PATH="dist/${PROJECT_NAME}.dmg"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse arguments
BUILD_RELEASE=false
CREATE_DMG=false

for arg in "$@"; do
    case $arg in
        --release) BUILD_RELEASE=true ;;
        --dmg)     BUILD_RELEASE=true; CREATE_DMG=true ;;
        --help|-h)
            echo -e "${CYAN}${BOLD}WiFi借一下 (HiWiFi) Build Script${NC}"
            echo ""
            echo "Usage:"
            echo "  ./scripts/build.sh              Debug build"
            echo "  ./scripts/build.sh --release    Release build + archive"
            echo "  ./scripts/build.sh --dmg        Release build + DMG installer"
            echo "  ./scripts/build.sh --help       Show this help"
            exit 0
            ;;
        *) warn "Unknown argument: $arg" ;;
    esac
done

# ---------- Banner ----------
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║        WiFi借一下  (HiWiFi)          ║"
echo "  ║          Build System v1.0           ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

cd "$PROJECT_ROOT"

# ============================================================
# Step 1: Check Prerequisites
# ============================================================
step "Step 1/5 — Checking prerequisites"

# Check Xcode
HAS_XCODE=true
if ! xcodebuild -version &>/dev/null; then
    HAS_XCODE=false
    warn "Full Xcode not found (or command line tools are active). Falling back to standalone swiftc compiler."
else
    XCODE_VERSION=$(xcodebuild -version | head -1)
    success "Xcode found: ${XCODE_VERSION}"
fi

if [ "$HAS_XCODE" = true ]; then
    # Check / Install XcodeGen
    if ! command -v xcodegen &>/dev/null; then
        warn "XcodeGen not found. Attempting to install via Homebrew..."

        if ! command -v brew &>/dev/null; then
            error "Homebrew not found. Install from https://brew.sh and try again."
        fi

        info "Installing XcodeGen..."
        brew install xcodegen
        
        if ! command -v xcodegen &>/dev/null; then
            error "XcodeGen installation failed. Please install manually: brew install xcodegen"
        fi
        success "XcodeGen installed successfully."
    else
        XCODEGEN_VERSION=$(xcodegen --version 2>/dev/null || echo "unknown")
        success "XcodeGen found: ${XCODEGEN_VERSION}"
    fi
else
    # Verify swiftc is available
    if ! command -v swiftc &>/dev/null; then
        error "swiftc not found. Please install Xcode Command Line Tools."
    fi
    success "swiftc found: $(swiftc --version | head -1)"
fi

# ============================================================
# Step 2: Generate Xcode Project
# ============================================================
if [ "$HAS_XCODE" = true ]; then
    step "Step 2/5 — Generating Xcode project"

    if [ ! -f "project.yml" ]; then
        error "project.yml not found in ${PROJECT_ROOT}. Cannot generate Xcode project."
    fi

    info "Running xcodegen generate..."
    xcodegen generate
    success "Xcode project generated: ${PROJECT_FILE}"
else
    step "Step 2/5 — Standalone build mode: skipping Xcode project generation"
fi

# ============================================================
# Step 3: Clean Build
# ============================================================
step "Step 3/5 — Cleaning previous builds"

if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
    info "Removed previous build directory."
fi
mkdir -p "$BUILD_DIR"

if [ "$HAS_XCODE" = true ]; then
    xcodebuild -project "$PROJECT_FILE" \
        -scheme "$SCHEME" \
        clean \
        2>&1 | tail -3
    success "Clean completed."
else
    success "Clean completed (directory reset)."
fi

# ============================================================
# Step 4: Build
# ============================================================
if [ "$HAS_XCODE" = true ]; then
    if [ "$BUILD_RELEASE" = true ]; then
        step "Step 4/5 — Building Release & Archiving with xcodebuild"

        xcodebuild -project "$PROJECT_FILE" \
            -scheme "$SCHEME" \
            -configuration Release \
            -archivePath "$ARCHIVE_PATH" \
            archive \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGNING_ALLOWED=NO \
            2>&1 | tail -5

        if [ -d "$ARCHIVE_PATH" ]; then
            success "Archive created: ${ARCHIVE_PATH}"
        else
            error "Archive failed. Check build errors above."
        fi

        # Export .app from archive
        if [ -d "${ARCHIVE_PATH}/Products/Applications/${PROJECT_NAME}.app" ]; then
            cp -R "${ARCHIVE_PATH}/Products/Applications/${PROJECT_NAME}.app" "$APP_PATH"
            success "App bundle exported: ${APP_PATH}"
        else
            # Try alternative export
            info "Attempting xcodebuild export..."
            xcodebuild -project "$PROJECT_FILE" \
                -scheme "$SCHEME" \
                -configuration Release \
                -derivedDataPath "${BUILD_DIR}/DerivedData" \
                build \
                CODE_SIGN_IDENTITY="-" \
                CODE_SIGNING_ALLOWED=NO \
                2>&1 | tail -5

            BUILT_APP=$(find "${BUILD_DIR}/DerivedData" -name "${PROJECT_NAME}.app" -type d 2>/dev/null | head -1)
            if [ -n "$BUILT_APP" ]; then
                cp -R "$BUILT_APP" "$APP_PATH"
                success "App bundle exported: ${APP_PATH}"
            else
                warn "Could not locate .app bundle. Check build output."
            fi
        fi
    else
        step "Step 4/5 — Building Debug with xcodebuild"

        xcodebuild -project "$PROJECT_FILE" \
            -scheme "$SCHEME" \
            -configuration Debug \
            -derivedDataPath "${BUILD_DIR}/DerivedData" \
            build \
            CODE_SIGN_IDENTITY="-" \
            CODE_SIGNING_ALLOWED=NO \
            2>&1 | tail -5

        BUILT_APP=$(find "${BUILD_DIR}/DerivedData" -name "${PROJECT_NAME}.app" -type d 2>/dev/null | head -1)
        if [ -n "$BUILT_APP" ]; then
            cp -R "$BUILT_APP" "$APP_PATH"
            success "Debug build succeeded: ${APP_PATH}"
        else
            warn "Build may have succeeded but .app not found in expected location."
        fi
    fi
else
    # Standalone Build using swiftc
    BUILD_CONFIG_NAME="Debug"
    SWIFTC_FLAGS=""
    if [ "$BUILD_RELEASE" = true ]; then
        step "Step 4/5 — Building Release Standalone App with swiftc"
        BUILD_CONFIG_NAME="Release"
        SWIFTC_FLAGS="-O"
    else
        step "Step 4/5 — Building Debug Standalone App with swiftc"
    fi

    # Create bundle directory structure
    mkdir -p "${APP_PATH}/Contents/MacOS"
    mkdir -p "${APP_PATH}/Contents/Resources"

    # Find all Swift source files
    SWIFT_SOURCES=$(find HiWiFi -name "*.swift")

    info "Compiling Swift source files..."
    swiftc -o "${APP_PATH}/Contents/MacOS/HiWiFi" \
        -sdk "$(xcrun --show-sdk-path)" \
        $SWIFTC_FLAGS \
        $SWIFT_SOURCES

    success "Binary compiled: ${APP_PATH}/Contents/MacOS/HiWiFi"

    # Copy Info.plist and customize placeholders using plutil
    info "Preparing Info.plist..."
    cp HiWiFi/Info.plist "${APP_PATH}/Contents/Info.plist"
    plutil -replace CFBundleIdentifier -string "com.cuostudio.HiWiFi" "${APP_PATH}/Contents/Info.plist"
    plutil -replace CFBundleVersion -string "1" "${APP_PATH}/Contents/Info.plist"
    plutil -replace CFBundleShortVersionString -string "1.0.0" "${APP_PATH}/Contents/Info.plist"
    plutil -replace CFBundleExecutable -string "HiWiFi" "${APP_PATH}/Contents/Info.plist"
    plutil -replace LSMinimumSystemVersion -string "14.0" "${APP_PATH}/Contents/Info.plist"

    # Copy resource files (dictionary and icon)
    info "Copying resource files..."
    if [ -f "HiWiFi/Resources/passwords_default.txt" ]; then
        cp "HiWiFi/Resources/passwords_default.txt" "${APP_PATH}/Contents/Resources/"
    fi
    if [ -f "HiWiFi/Resources/AppIcon.icns" ]; then
        cp "HiWiFi/Resources/AppIcon.icns" "${APP_PATH}/Contents/Resources/"
        success "Resources (including app icon) copied."
    else
        success "Resources copied."
    fi

    # Ad-hoc codesign with entitlements
    info "Signing app bundle..."
    codesign -f -s - --entitlements HiWiFi/HiWiFi.entitlements "${APP_PATH}/Contents/MacOS/HiWiFi"
    success "App bundle signed successfully."
fi

# ============================================================
# Step 5: Create DMG (optional)
# ============================================================
if [ "$CREATE_DMG" = true ]; then
    step "Step 5/5 — Creating DMG installer"

    if [ ! -d "$APP_PATH" ]; then
        error "Cannot create DMG: ${APP_PATH} not found."
    fi

    mkdir -p dist

    # Clean up previous DMG
    [ -f "$DMG_PATH" ] && rm -f "$DMG_PATH"

    # Create temporary DMG directory
    DMG_STAGING="${BUILD_DIR}/dmg_staging"
    rm -rf "$DMG_STAGING"
    mkdir -p "$DMG_STAGING"

    cp -R "$APP_PATH" "$DMG_STAGING/"
    ln -s /Applications "$DMG_STAGING/Applications"

    info "Creating DMG image..."
    hdiutil create \
        -volname "$PROJECT_NAME" \
        -srcfolder "$DMG_STAGING" \
        -ov \
        -format UDZO \
        "$DMG_PATH" \
        2>&1 | tail -3

    rm -rf "$DMG_STAGING"

    if [ -f "$DMG_PATH" ]; then
        DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
        success "DMG created: ${DMG_PATH} (${DMG_SIZE})"
    else
        error "DMG creation failed."
    fi
else
    step "Step 5/5 — Skipping DMG (use --dmg to create)"
    info "Run with --dmg flag to create a distributable DMG installer."
fi

# ============================================================
# Summary
# ============================================================
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✓ Build completed successfully!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${CYAN}Project:${NC}  ${PROJECT_NAME}"
echo -e "  ${CYAN}Config:${NC}   $([ "$BUILD_RELEASE" = true ] && echo "Release" || echo "Debug")"
echo -e "  ${CYAN}Method:${NC}   $([ "$HAS_XCODE" = true ] && echo "xcodebuild" || echo "swiftc standalone")"
[ -d "$APP_PATH" ] && echo -e "  ${CYAN}App:${NC}      ${APP_PATH}"
[ -f "$DMG_PATH" ] && echo -e "  ${CYAN}DMG:${NC}      ${DMG_PATH}"
echo ""
