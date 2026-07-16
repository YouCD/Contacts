#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

APK_DIR="$PROJECT_DIR/app/build/outputs/apk/core/release"
UNSIGNED_APK="$APK_DIR/contacts-*-core-release-unsigned.apk"
SIGNED_APK="/tmp/contacts-core-signed.apk"

PLATFORM_KEY="/home/ycd/self_data/source_code/jist/build/security/platform.pk8"
PLATFORM_CERT="/home/ycd/self_data/source_code/jist/build/security/platform.x509.pem"
APKSIGNER="/home/ycd/Android/Sdk/build-tools/37.0.0/apksigner"

echo "=== 1. Build coreRelease ==="
cd "$PROJECT_DIR"
GRADLE_OPTS="-Xmx12g" ./gradlew :app:assembleCoreRelease --no-daemon -Dorg.gradle.jvmargs="-Xmx12g"

echo ""
echo "=== 2. Sign with platform certificate ==="
UNSIGNED_FILE=$(ls $UNSIGNED_APK 2>/dev/null | head -1)
if [ -z "$UNSIGNED_FILE" ]; then
    echo "Error: unsigned APK not found: $UNSIGNED_APK"
    exit 1
fi
echo "Signing: $UNSIGNED_FILE"
"$APKSIGNER" sign --key "$PLATFORM_KEY" --cert "$PLATFORM_CERT" --out "$SIGNED_APK" "$UNSIGNED_FILE"
"$APKSIGNER" verify "$SIGNED_APK"
rm -f "$SIGNED_APK.idsig" 2>/dev/null

echo ""
echo "=== 3. Push to device ==="
adb root 2>/dev/null
adb remount 2>/dev/null
adb push "$SIGNED_APK" /system/app/org.fossify.contacts/org.fossify.contacts.apk
adb shell chmod 644 /system/app/org.fossify.contacts/org.fossify.contacts.apk

echo ""
echo "=== 4. Install & restart ==="
adb shell pm install -r /system/app/org.fossify.contacts/org.fossify.contacts.apk
adb shell am force-stop org.fossify.contacts
adb shell am start -n org.fossify.contacts/.activities.SplashActivity

echo ""
echo "=== Done ==="
rm -f "$SIGNED_APK"
