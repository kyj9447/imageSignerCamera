(문자열 주입 / 추출 원리 참고 : https://github.com/kyj9447/imageSignerAndValidator)
## 1.image_signer_camera
(/lib/main.dart)

#### 이미지에 특정 암호화된 문자열을 주입하는 Flutter 카메라 어플리케이션

Key Pair 중 공개 키를 가지고 있습니다.

(현재 소스에는 문자열 "Hello, World!"를 암호화 한 뒤 주입합니다.)

<sup>+ 기기의 자이로스코프 값을 읽어 버튼 아이콘 회전, 사진 저장시 적절한 방향으로 회전하는데 사용</sup>

<br><img src="https://github.com/kyj9447/imageSignerCamera/assets/122734245/8b7bc658-5864-4cfe-8a56-24f757cf11ec" width=600px><br>

##### flutter 앱 빌드
```sh
flutter clean
flutter pub get
flutter build apk
```

---

## 2.imageValidator server
(/server/app.js)

#### 이미지 업로드시 주입된 문자열 확인해 표시해주는 Node.js Express 서버

Key Pair 중 개인 키를 가지고 있습니다.

암호화된 문자열이 주입된 이미지 submit -> 암호화된 문자열 추출 -> 복호화하여 내용 확인

<sup>+ 서버에 빌드된 .apk 파일을 다운로드 받을 수 있는 링크 제공.</sup>

<br><img src="https://github.com/kyj9447/imageSignerCamera/assets/122734245/097da77e-5ae7-4e81-859c-06ef72c3a6b6" width=400px><br>

##### server 실행법
```sh
cd server
npm install
node app.js
```

### 서버 출력 예시

START-VALIDATION  (시작지점 문자열 - 복호화됨)

Hello, World! (주입된 문자열 - 복호화됨)

Sxu/jim2TwEV8US4tQxNuN8a/jnsFkYLsRW59g36oQ3 (암호화된 문자열의 일부(복호화 불가능)) 

<sup> (암호화된 문자열의 길이와 사진 픽셀 수(=길이) 차이에 의한 것이며 정상적인 출력임) </sup>

END-VALIDATION (끝지점 문자열 - 복호화됨)

---

#### 정상적인 사진의 경우
<br><img src="https://github.com/kyj9447/imageSignerCamera/assets/122734245/d9befc59-d375-46ea-bb18-dd986df31448" width=800px><br>

#### 편집이 들어간 사진의 경우
(=이미지를 잘라낸 경우 or 이미지의 일부 픽셀을 조금이라도 수정한 경우)

<br><img src="https://github.com/kyj9447/imageSignerCamera/assets/122734245/039f6e18-1e58-4e71-84c8-8eec5461ea77" width=800px><br>

