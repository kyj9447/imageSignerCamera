const express = require('express');
const path = require('path');
const multer = require('multer');
const crypto = require('crypto');
const fs = require('fs');
const { validateImage } = require('./imageValidator');

const app = express();

app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'index.html'));
});

app.listen(3000, () => {
    console.log('Server is running on http://localhost:3000');
});

// 파일 업로드를 위한 multer 설정
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        cb(null, file.originalname);
    }
});

// 파일 업로드 미들웨어
const upload = multer({ storage });

// 파일 업로드 처리
app.post('/upload', upload.single('image'), async (req, res) => {
    // 이미지 업로드한 경로
    const imagePath = req.file.path;

    // 이미지 문자열 추출
    const extracted = await validateImage(imagePath);

    // 이미지 삭제 (추출이 끝나면 삭제)
    fs.unlinkSync(imagePath);

    // 줄바꿈 기준으로 split한 배열
    const extractedArray = extracted.split("\n")

    // 중복 제거
    let deduplicated = [];
    for (let i = 0; i < extractedArray.length; i++) {
        if (i === 0 || extractedArray[i] !== extractedArray[i - 1]) {
            deduplicated.push(extractedArray[i]);
        }
    }

    // deduplicated의 구조
    // [0] = START-VALIDATION
    // [1] = 복호화 대상
    // [2] = 복호화 대상(일부)
    // [3] = END-VALIDATION

    // 복호화 대상
    const decryptionTarget = deduplicated[1];
    //console.log("decryptionTarget : " + decryptionTarget);

    // Private key를 읽어옵니다.
    const privateKey = fs.readFileSync('private_key.pem', 'utf8');

    // deduplicated의 두 번째 요소를 복호화합니다.
    let buffer = Buffer.from(deduplicated[1], 'base64');
    let decrypted = crypto.privateDecrypt({
        key: privateKey,
        padding: crypto.constants.RSA_PKCS1_PADDING
    }, buffer);

    // 복호화된 문자열로 교체합니다.
    deduplicated[1] = decrypted.toString();

    // 중복제거, 복호화 완료 결과
    let validation = deduplicated.join('\n');

    res.send(validation);
});