#!/usr/bin/env bash
set -euo pipefail

# -----------------------
# 설정
# -----------------------
DOMAIN="kyj9447.kr"                              # Let’s Encrypt 도메인 이름
SRC_BASE="/etc/letsencrypt/live"                 # 원본 심볼릭 링크 경로
SRC_DIR="${SRC_BASE}/${DOMAIN}"                  # 실제 심볼릭 링크 경로
DEST_DIR="$(pwd)/server/SSL"                            # 현재 작업 폴더 내 SSL
NODE_USER="kyj9447"                              # Node.js를 실행할 사용자 계정
CERT_FNAME="cert.pem"
KEY_FNAME="privkey.pem"

# -----------------------
# 유틸리티
# -----------------------
info()  { printf "\e[1;34m[INFO]\e[0m %s\n" "$*"; }
error() { printf "\e[1;31m[ERROR]\e[0m %s\n" "$*"; exit 1; }

# -----------------------
# 체크
# -----------------------
info "도메인: ${DOMAIN}"
info "원본 경로: ${SRC_DIR}"
info "복사 경로: ${DEST_DIR}"

[ ! -d "${SRC_DIR}" ] && error "원본 디렉토리 없음: ${SRC_DIR}"
[ ! -e "${SRC_DIR}/${CERT_FNAME}" ] && error "원본 인증서 없음: ${SRC_DIR}/${CERT_FNAME}"
[ ! -e "${SRC_DIR}/${KEY_FNAME}" ]  && error "원본 개인키 없음: ${SRC_DIR}/${KEY_FNAME}"

# SSL 디렉토리 생성
mkdir -p "${DEST_DIR}"

# -----------------------
# 복사 (심볼릭 링크가 가리키는 실제 파일)
# -----------------------
info "인증서 파일 복사 (심볼릭 링크 따라 실제 파일)..."
sudo cp -L "${SRC_DIR}/${CERT_FNAME}" "${DEST_DIR}/${CERT_FNAME}"
sudo cp -L "${SRC_DIR}/${KEY_FNAME}"  "${DEST_DIR}/${KEY_FNAME}"

# -----------------------
# 소유자 및 권한 설정
# -----------------------
info "소유자: ${NODE_USER}, privkey.pem 권한: 600, cert.pem 권한: 644"
sudo chown "${NODE_USER}:${NODE_USER}" "${DEST_DIR}/${CERT_FNAME}" "${DEST_DIR}/${KEY_FNAME}"
sudo chmod 600 "${DEST_DIR}/${KEY_FNAME}"
sudo chmod 644 "${DEST_DIR}/${CERT_FNAME}"

info "복사 완료. 현재 SSL 디렉토리 내용:"
ls -l "${DEST_DIR}"
