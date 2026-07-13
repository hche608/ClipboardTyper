#!/bin/zsh
set -e

# Build and package ClipboardTyper as a proper macOS .app bundle.
#
# Why manual bundle creation instead of xcodebuild:
# - No Xcode project in this repo (pure SwiftPM)
# - .app bundle structure is needed for: Info.plist (LSUIElement, CFBundleIconFile),
#   app icon display in notifications, and Accessibility permission persistence
#
# Output: ./dist/ClipboardTyper.app (ready to distribute or copy to /Applications)
# Optional: pass --install to also deploy to /Applications and relaunch.

cd "$(dirname "$0")"

APP_NAME="ClipboardTyper"
DIST_DIR="./dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
INSTALL_DIR="/Applications/${APP_NAME}.app"

# --- Build ---
echo "🔨 Building (release)..."
swift build -c release

# --- Package .app bundle ---
echo "📦 Packaging ${APP_BUNDLE}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Binary
cp .build/release/${APP_NAME} "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

# Info.plist
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

# App icon (icns for Finder/Dock, png for notifications fallback)
cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
cp AppIcon.png "${APP_BUNDLE}/Contents/Resources/AppIcon.png"

# PkgInfo (standard macOS app marker — tells Finder this is an application)
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "✅ Built: ${APP_BUNDLE}"

# --- Optional: Install to /Applications ---
if [[ "$1" == "--install" ]]; then
    echo "📦 Installing to ${INSTALL_DIR}..."
    
    # Kill running instance
    pkill -x ${APP_NAME} 2>/dev/null || true
    sleep 1
    
    # Deploy
    rm -rf "${INSTALL_DIR}"
    cp -R "${APP_BUNDLE}" "${INSTALL_DIR}"
    
    # Relaunch
    echo "🔄 Launching..."
    open "${INSTALL_DIR}"
    
    echo "✅ Installed and running from /Applications"
else
    echo ""
    echo "ℹ️  To install to /Applications and launch:"
    echo "   ./build.sh --install"
    echo ""
    echo "   Or manually:  cp -R ${APP_BUNDLE} /Applications/"
fi
