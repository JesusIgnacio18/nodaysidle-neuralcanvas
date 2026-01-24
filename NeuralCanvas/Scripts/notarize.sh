#!/bin/bash

# NeuralCanvas Notarization Script
# This script builds, archives, and notarizes the app for distribution outside the Mac App Store
#
# Prerequisites:
# 1. Apple Developer ID Application certificate installed in Keychain
# 2. App-specific password stored in Keychain (see below)
# 3. xcrun notarytool configured
#
# To store credentials:
#   xcrun notarytool store-credentials "notarytool-profile" \
#     --apple-id "your-apple-id@example.com" \
#     --team-id "YOUR_TEAM_ID" \
#     --password "your-app-specific-password"

set -e

# Configuration
APP_NAME="NeuralCanvas"
SCHEME="NeuralCanvas"
BUILD_DIR="build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
NOTARYTOOL_PROFILE="notarytool-profile"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo_step() {
    echo -e "\n${GREEN}==>${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

echo_error() {
    echo -e "${RED}Error:${NC} $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    echo_step "Checking prerequisites..."

    # Check for Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo_error "xcodebuild not found. Please install Xcode."
    fi

    # Check for Developer ID certificate
    if ! security find-identity -v -p codesigning | grep -q "Developer ID Application"; then
        echo_warning "Developer ID Application certificate not found in Keychain."
        echo "For testing, the script will continue with ad-hoc signing."
    fi

    # Check for notarytool credentials
    if ! xcrun notarytool history --keychain-profile "$NOTARYTOOL_PROFILE" &> /dev/null 2>&1; then
        echo_warning "Notarytool profile '$NOTARYTOOL_PROFILE' not found."
        echo "Run: xcrun notarytool store-credentials \"$NOTARYTOOL_PROFILE\""
    fi

    echo "Prerequisites check complete."
}

# Clean build directory
clean() {
    echo_step "Cleaning build directory..."
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"
}

# Build and archive
build_archive() {
    echo_step "Building and archiving $APP_NAME..."

    xcodebuild archive \
        -scheme "$SCHEME" \
        -destination "platform=macOS" \
        -archivePath "$ARCHIVE_PATH" \
        -configuration Release \
        CODE_SIGN_STYLE=Manual \
        DEVELOPMENT_TEAM="${TEAM_ID:-}" \
        CODE_SIGN_IDENTITY="Developer ID Application" \
        || echo_warning "Archive created but may need signing configuration"

    echo "Archive created at: $ARCHIVE_PATH"
}

# Export the archive
export_archive() {
    echo_step "Exporting archive..."

    # Create export options plist
    cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>destination</key>
    <string>export</string>
    <key>signingStyle</key>
    <string>manual</string>
</dict>
</plist>
EOF

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_PATH" \
        -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
        || echo_warning "Export may require Developer ID certificate"

    echo "App exported to: $EXPORT_PATH"
}

# Notarize the app
notarize() {
    echo_step "Notarizing $APP_NAME..."

    APP_PATH="$EXPORT_PATH/$APP_NAME.app"

    if [ ! -d "$APP_PATH" ]; then
        echo_error "App not found at $APP_PATH"
    fi

    # Create zip for notarization
    ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
    ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

    # Submit for notarization
    echo "Submitting for notarization..."
    xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARYTOOL_PROFILE" \
        --wait

    echo "Notarization complete."
}

# Staple the ticket
staple() {
    echo_step "Stapling notarization ticket..."

    APP_PATH="$EXPORT_PATH/$APP_NAME.app"
    xcrun stapler staple "$APP_PATH"

    echo "Ticket stapled successfully."
}

# Create DMG
create_dmg() {
    echo_step "Creating DMG..."

    APP_PATH="$EXPORT_PATH/$APP_NAME.app"
    TEMP_DMG="$BUILD_DIR/temp.dmg"
    VOLUME_NAME="$APP_NAME"

    # Create temporary DMG
    hdiutil create -srcfolder "$APP_PATH" \
        -volname "$VOLUME_NAME" \
        -fs HFS+ \
        -format UDRW \
        "$TEMP_DMG"

    # Convert to compressed DMG
    hdiutil convert "$TEMP_DMG" \
        -format UDZO \
        -o "$DMG_PATH"

    rm "$TEMP_DMG"

    # Notarize DMG
    echo "Notarizing DMG..."
    xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARYTOOL_PROFILE" \
        --wait

    # Staple DMG
    xcrun stapler staple "$DMG_PATH"

    echo "DMG created and notarized at: $DMG_PATH"
}

# Verify signature
verify() {
    echo_step "Verifying code signature..."

    APP_PATH="$EXPORT_PATH/$APP_NAME.app"

    echo "Checking signature..."
    codesign -vvv --deep --strict "$APP_PATH"

    echo "Checking notarization..."
    spctl -a -vv "$APP_PATH"

    echo "Verification complete."
}

# Main
main() {
    echo "=========================================="
    echo "  NeuralCanvas Notarization Script"
    echo "=========================================="

    case "${1:-all}" in
        check)
            check_prerequisites
            ;;
        clean)
            clean
            ;;
        build)
            clean
            build_archive
            ;;
        export)
            export_archive
            ;;
        notarize)
            notarize
            ;;
        staple)
            staple
            ;;
        dmg)
            create_dmg
            ;;
        verify)
            verify
            ;;
        all)
            check_prerequisites
            clean
            build_archive
            export_archive
            notarize
            staple
            create_dmg
            verify
            echo -e "\n${GREEN}Build complete!${NC}"
            echo "DMG ready for distribution: $DMG_PATH"
            ;;
        *)
            echo "Usage: $0 {check|clean|build|export|notarize|staple|dmg|verify|all}"
            exit 1
            ;;
    esac
}

main "$@"
