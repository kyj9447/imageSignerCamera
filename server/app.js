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

    // 복호화
    decrypted = decryptArray(deduplicated);


    // 중복제거, 복호화 완료된 배열의 길이를 확인하여 성공/실패 여부 판단
    const lenthCheck = (decrypted.length <= 4) ? true : false;

    // 시작,끝 부분 검사
    const startCheck = (decrypted[0] === "START-VALIDATION") ? true : false;
    const endCheck = (decrypted[deduplicated.length - 1] === "END-VALIDATION") ? true : false;

    // 최종 결과
    // 모두 true일 경우 Success, 하나라도 false일 경우 Fail
    const verdict = (lenthCheck && startCheck && endCheck) ? "Success" : "Fail";

    // 중복제거, 복호화 완료 결과 join
    let validation = decrypted.join('\n<br>'); // 줄바꿈을 <br>로 변경

    // html 형식 작성
    const validationResult = "<h1>Validation Result : " + verdict + "</h1>" + validation;

    res.send(validationResult);
});

function decryptArray(deduplicated) {

    // Private key를 읽음
    const privateKey = fs.readFileSync('private_key.pem', 'utf8');

    // deduplicated의 첫 번째와 마지막 요소를 제외한 모든 요소를 복호화
    deduplicated = deduplicated.map((item, index) => {
        if (index === 0 || index === deduplicated.length - 1) {
            return item;
        } else {
            try {
                let buffer = Buffer.from(item, 'base64');
                let decrypted = crypto.privateDecrypt({
                    key: privateKey,
                    padding: crypto.constants.RSA_PKCS1_PADDING
                }, buffer);
                //console.log("Decrypted : "+decrypted.toString());
                return decrypted.toString();
            }
            // 복호화 실패 시 그대로 유지
            catch (e) {
                //console.log(e);
                return item;
            }
        }
    });

    return deduplicated;
}

// APK 다운로드
app.get('/apk', async (req, res) => {
    res.download('../build/app/outputs/flutter-apk/app-release.apk', 'imageSignerCamera.apk');
});