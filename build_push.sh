#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 脚本就在仓库根目录，PROJECT_DIR 即 SCRIPT_DIR 本身
PROJECT_DIR="$SCRIPT_DIR"

# 变基后 flavor 为 foss/gplay，产物名随 versionCode 变化
APK_DIR="$SCRIPT_DIR/app/build/outputs/apk/foss/release"
UNSIGNED_APK="$APK_DIR/contacts-*-foss-release-unsigned.apk"
SIGNED_APK="/tmp/contacts-foss-signed.apk"

PLATFORM_KEY="/home/ycd/self_data/source_code/jist/build/security/platform.pk8"
PLATFORM_CERT="/home/ycd/self_data/source_code/jist/build/security/platform.x509.pem"
APKSIGNER="/home/ycd/Android/Sdk/build-tools/37.0.0/apksigner"

echo "=== 1. Build fossRelease ==="
cd "$PROJECT_DIR"
GRADLE_OPTS="-Xmx12g" ./gradlew :app:assembleFossRelease --no-daemon -Dorg.gradle.jvmargs="-Xmx12g"

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
adb wait-for-device
if ! adb devices | grep -qE "^\S+\s+device$"; then
    echo "Error: no device in 'device' state"
    exit 1
fi
adb root 2>/dev/null || true
adb remount 2>/dev/null || true
adb shell mkdir -p /system/app/org.fossify.contacts
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
