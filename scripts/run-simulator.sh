#!/bin/bash
set -euo pipefail

# TeamPicker - iOS 시뮬레이터 빌드 & 실행 스크립트
# Usage: ./scripts/run-simulator.sh [device-name]
# Example: ./scripts/run-simulator.sh "iPhone 17 Pro"

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/TeamPicker.xcodeproj"
SCHEME="TeamPicker"
DERIVED_DATA=$(mktemp -d "${TMPDIR:-/tmp}/TeamPickerBuild.XXXXXX")
BUNDLE_ID="com.reno.TeamPicker"
export DEVICE_NAME="${1:-iPhone 17 Pro}"

cleanup() {
  rm -rf "$DERIVED_DATA"
}
trap cleanup EXIT

# 1. 사용 가능한 시뮬레이터 찾기
echo "🔍 시뮬레이터 검색: $DEVICE_NAME"
DEVICE_ID=$(xcrun simctl list devices available -j \
  | python3 -c "
import json, sys, os
device_name = os.environ['DEVICE_NAME']
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['name'] == device_name and d['isAvailable']:
            print(d['udid'])
            sys.exit(0)
sys.exit(1)
" 2>/dev/null) || {
  echo "❌ '$DEVICE_NAME' 시뮬레이터를 찾을 수 없습니다."
  echo "사용 가능한 기기:"
  xcrun simctl list devices available | grep -E "iPhone|iPad" | head -10
  exit 1
}
echo "✅ 발견: $DEVICE_NAME ($DEVICE_ID)"

# 2. 시뮬레이터 부팅
export DEVICE_ID
STATE=$(xcrun simctl list devices -j | python3 -c "
import json, sys, os
device_id = os.environ['DEVICE_ID']
data = json.load(sys.stdin)
for runtime, devices in data['devices'].items():
    for d in devices:
        if d['udid'] == device_id:
            print(d['state'])
            sys.exit(0)
")

if [ "$STATE" != "Booted" ]; then
  echo "🚀 시뮬레이터 부팅 중..."
  xcrun simctl boot "$DEVICE_ID"
fi

# 3. Simulator.app 열기
open -a Simulator

# 4. 빌드
echo "🔨 빌드 중..."
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  -quiet 2>&1

if [ $? -eq 0 ]; then
  echo "✅ 빌드 성공"
else
  echo "❌ 빌드 실패"
  exit 1
fi

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/TeamPicker.app"

# 5. 기존 앱 종료 (실행 중이면)
xcrun simctl terminate "$DEVICE_ID" "$BUNDLE_ID" 2>/dev/null || true

# 6. 설치
echo "📦 앱 설치 중..."
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

# 7. 실행
echo "▶️  앱 실행 중..."
xcrun simctl launch "$DEVICE_ID" "$BUNDLE_ID"

echo "🎉 완료! 시뮬레이터에서 TeamPicker가 실행 중입니다."
