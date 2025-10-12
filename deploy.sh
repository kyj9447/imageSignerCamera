#!/bin/bash

# Flutter 프로젝트 경로
FLUTTER_PROJECT_DIR="/home/kyj9447/FTP/WorkSpace/kyj9447/Flutter/imageSignerCamera"
# Node.js 프로젝트 경로
NODE_PROJECT_DIR="/home/kyj9447/FTP/WorkSpace/kyj9447/Flutter/imageSignerCamera/server"
# 최종 배포 폴더
TARGET_DIR="/home/kyj9447/server/imageSignerCamera"

# 배포 폴더 생성
mkdir -p "$TARGET_DIR"

# --- 1. Flutter APK 빌드 ---
echo "Flutter APK 빌드 중..."
cd "$FLUTTER_PROJECT_DIR" || exit
flutter clean
flutter pub get
flutter build apk --release

# --- 2. Node.js pkg 빌드 ---
echo "Node.js pkg 빌드 중..."
cd "$NODE_PROJECT_DIR" || exit
npm install
npm run package

# --- 3. 결과물 복사 ---
if [ -d "$NODE_PROJECT_DIR" ]; then
    echo "결과물 복사 중..."
    cp "$NODE_PROJECT_DIR/imageSignerServer" "$TARGET_DIR/"
    cp "$NODE_PROJECT_DIR/index.html" "$TARGET_DIR/"
    cp "$NODE_PROJECT_DIR/private_key.pem" "$TARGET_DIR/"
    cp "$NODE_PROJECT_DIR/app-release.apk" "$TARGET_DIR/"
    cp -r "$NODE_PROJECT_DIR/SSL" "$TARGET_DIR/"
else
    echo "복사 실패: $NODE_PROJECT_DIR"
fi

echo "배포 파일 복사 완료: $TARGET_DIR"
