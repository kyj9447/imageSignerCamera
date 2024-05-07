const express = require("express");
const path = require("path");
const multer = require("multer");
const https = require("https");
const crypto = require("crypto");
const fs = require("fs");
const { validateImage } = require("./imageValidator");

const app = express();

// HTTPS 서버 옵션
const options = {
  cert: fs.readFileSync("SSL/cert1.pem", "utf8"),
  key: fs.readFileSync("SSL/privkey1.pem", "utf8"),
  ca: fs.readFileSync("SSL/chain1.pem", "utf8"),
};

// HTTPS 서버 생성
const httpsServer = https.createServer(options, app);

// 서버 리스닝 (446)
const port = process.env.PORT || 446;
httpsServer.listen(port, () => {
  console.log("Server is running on port " + port);
});

app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "index.html"));
});

// 파일 업로드를 위한 multer 설정
const storage = multer.diskStorage({
  destination: (req, file, callBack) => {
    callBack(null, "uploads/");
  },
  filename: (req, file, callBack) => {
    callBack(null, file.originalname);
  },
});

// 파일 업로드 미들웨어
const upload = multer({ storage });

// 파일 업로드 처리
app.post("/upload", upload.single("image"), async (req, res) => {
  // 이미지 업로드한 경로
  const imagePath = req.file.path;

  // 이미지 문자열 추출
  const extracted = await validateImage(imagePath);

  // 이미지 삭제 (추출이 끝나면 삭제)
  fs.unlinkSync(imagePath);

  // 줄바꿈 기준으로 split한 배열
  const extractedArray = extracted.split("\n");

  // 중복 제거
  const deduplicated = [];
  for (let i = 0; i < extractedArray.length; i++) {
    if (i === 0 || extractedArray[i] !== extractedArray[i - 1]) {
      deduplicated.push(extractedArray[i]);
    }
  }

  // 정상적인 deduplicated의 구조
  // [0] = START-VALIDATION
  // [1] = 복호화 대상
  // [2] = 복호화 대상(일부)
  // [3] = END-VALIDATION

  // 복호화
  const decrypted = decryptArray(deduplicated);

  // 복호화된 배열 길이
  const arrayLength = decrypted.length;

  // 1. 중복제거, 복호화 완료된 배열의 길이를 확인하여 성공/실패 여부 판단
  // 정상적인 경우, deduplicated의 길이는 3 또는 4임
  const lenthCheck = arrayLength == 3 || arrayLength == 4 ? true : false;

  // 2. 시작,끝 부분 검사
  const startCheck = decrypted[0] === "START-VALIDATION" ? true : false;
  const endCheck = decrypted[arrayLength - 1] === "END-VALIDATION" ? true : false;

  // 3. 시작, 끝 부분이 암호화 -> 복호화 되지 않은경우
  // 복호화 하지 않은 START-VALIDATION, END-VALIDATION이 deduplicated에 있으면 false
  const startIsCrypted = deduplicated[0] === "START-VALIDATION" ? false : true;
  const endIsCrypted = deduplicated[arrayLength - 1] === "END-VALIDATION" ? false : true;

  // 4. 두번째 요소 복호화 여부 확인 (==로 끝나면 암호화된 문자열임)
  const isDecrypted = !decrypted[1].endsWith("==");

  // 최종 결과
  // 모두 true일 경우 Success, 하나라도 false일 경우 Fail
  const verdict =
    lenthCheck && startCheck && endCheck && isDecrypted && startIsCrypted && endIsCrypted ? "Success" : "Fail";

  // 중복제거, 복호화 완료 결과 join
  //const validation = decrypted.join('<br>'); // 줄바꿈을 <br>로 변경

  // html 형식 작성
  const validationResult =
    "<h1>Validation Result : " +
    verdict +
    "</h1>" +
    decrypted.join("<br>") +
    "<h4>(복호화 전 중복제거된 DATA)</h4>" +
    deduplicated.join("<br>");

  res.send(validationResult);
});

// 배열 복호화 (처음, 끝 요소 포함)
function decryptArray(deduplicated) {
  // Private key를 읽음
  const privateKey = fs.readFileSync("private_key.pem", "utf8");

  // deduplicated의 첫 번째와 마지막 요소를 제외한 모든 요소를 복호화
  const decrypted = deduplicated.map(
    (item, index) => {
      // if (index === 0 || index === deduplicated.length - 1) {
      //     return item;
      // } else {
      // base64 디코딩 후 복호화 시도 (손상된 문자열은 복호화 실패함)
      try {
        let buffer = Buffer.from(item, "base64");
        let decrypted = crypto.privateDecrypt(
          {
            key: privateKey,
            padding: crypto.constants.RSA_PKCS1_PADDING,
          },
          buffer
        );
        //console.log("Decrypted : "+decrypted.toString());
        return decrypted.toString();
      } catch (e) {
        // 복호화 실패 시 그대로 유지
        console.log(e);
        return item;
      }
    }
    //}
  );

  return decrypted;
}

// APK 다운로드
app.get("/apk", async (req, res) => {
  const filePath = "../build/app/outputs/flutter-apk/app-release.apk";
  if (fs.existsSync(filePath)) {
    res.download(filePath, "imageSignerCamera.apk");
  } else {
    res.status(404).send("File not found");
  }
});
