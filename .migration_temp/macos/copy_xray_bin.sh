#!/bin/bash
# Copy xray-core binaries to macOS app bundle

# Directory where the built app resides
APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app"
XRAY_BIN_DIR="${APP_BUNDLE}/Contents/Resources/xray-bin"

# Source directory (project root assets)
SRC_DIR="${PROJECT_DIR}/../assets/bin"

echo "Copying xray binaries to $XRAY_BIN_DIR"

# Create destination directory
mkdir -p "$XRAY_BIN_DIR"

# Copy architecture-specific xray binaries
cp -f "$SRC_DIR/xray-darwin-amd64" "$XRAY_BIN_DIR/" 2>/dev/null || echo "Warning: xray-darwin-amd64 not found"
cp -f "$SRC_DIR/xray-darwin-arm64" "$XRAY_BIN_DIR/" 2>/dev/null || echo "Warning: xray-darwin-arm64 not found"

# Copy geodata files
cp -f "$SRC_DIR/geoip.dat" "$XRAY_BIN_DIR/" 2>/dev/null || echo "Warning: geoip.dat not found"
cp -f "$SRC_DIR/geosite.dat" "$XRAY_BIN_DIR/" 2>/dev/null || echo "Warning: geosite.dat not found"

# Make binaries executable
chmod +x "$XRAY_BIN_DIR/xray-darwin-amd64" 2>/dev/null
chmod +x "$XRAY_BIN_DIR/xray-darwin-arm64" 2>/dev/null

echo "Xray binaries copied successfully"
