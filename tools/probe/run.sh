#!/usr/bin/env bash
# Builds DuoProbe against the iOS 27.1 simulator SDK, checks the SDK stamp,
# then installs and launches it on the Duo simulator, streaming its stdout.
#
# Usage: tools/probe/run.sh [log-file]
#   DEVICE=<name or UDID>   simulator to use (default: Duo-27.1)
set -euo pipefail

DEVICE="${DEVICE:-Duo-27.1}"
BUNDLE_ID="dev.geekles.duoprobe"
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/build/DuoProbe.app"
LOG="${1:-$HERE/out/probe.log}"

# Pitfall 3: a binary linked against the 27.0 SDK gets no reserved regions and
# no vertical bars. Pin SDKROOT to the simulator SDK so swiftc and the linker
# both use it, then verify the stamp below.
SDKROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)"
export SDKROOT

rm -rf "$APP"
mkdir -p "$APP" "$(dirname "$LOG")"

xcrun swiftc \
  -parse-as-library \
  -swift-version 6 \
  -target arm64-apple-ios27.1-simulator \
  -sdk "$SDKROOT" \
  -module-name DuoProbe \
  -o "$APP/DuoProbe" \
  "$HERE/DuoProbe.swift"

# UILaunchScreen is required: without it, iOS runs the app in a letterboxed
# compatibility mode and the measured sizes are wrong.
cat >"$APP/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.geekles.duoprobe</string>
  <key>CFBundleExecutable</key><string>DuoProbe</string>
  <key>CFBundleName</key><string>DuoProbe</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleSupportedPlatforms</key><array><string>iPhoneSimulator</string></array>
  <key>MinimumOSVersion</key><string>27.1</string>
  <key>LSRequiresIPhoneOS</key><true/>
  <key>UIDeviceFamily</key><array><integer>1</integer></array>
  <key>UILaunchScreen</key><dict/>
  <key>UIApplicationSceneManifest</key>
  <dict>
    <key>UIApplicationSupportsMultipleScenes</key><false/>
  </dict>
  <key>UISupportedInterfaceOrientations</key>
  <array>
    <string>UIInterfaceOrientationPortrait</string>
    <string>UIInterfaceOrientationPortraitUpsideDown</string>
    <string>UIInterfaceOrientationLandscapeLeft</string>
    <string>UIInterfaceOrientationLandscapeRight</string>
  </array>
</dict>
</plist>
PLIST

codesign --force --sign - --timestamp=none "$APP"

if ! otool -l "$APP/DuoProbe" | grep -A4 LC_BUILD_VERSION | grep -q "sdk 27.1"; then
  echo "error: DuoProbe is not stamped with sdk 27.1:" >&2
  otool -l "$APP/DuoProbe" | grep -A4 LC_BUILD_VERSION >&2
  exit 1
fi
echo "SDK stamp OK:"
otool -l "$APP/DuoProbe" | grep -A4 LC_BUILD_VERSION

xcrun simctl install "$DEVICE" "$APP"
echo "Streaming JSON lines to $LOG (Ctrl-C to stop)"
xcrun simctl launch --console-pty --terminate-running-process "$DEVICE" "$BUNDLE_ID" | tee "$LOG"
