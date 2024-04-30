## image_signer_camera
(/lib/main.dart)

특정 암호화된 문자열을 주입하는 Flutter 카메라 어플리케이션

(현재 소스에는 문자열 "Hello, World!"를 암호화 한 뒤 주입합니다.)

기기의 자이로스코프 값을 읽어 버튼 아이콘 회전, 사진 저장시 적절한 방향으로 회전하는데 사용

## imageValidator server
(/server/app.js)

암호화된 문자열이 주입된 이미지 submit -> 암호화된 문자열 추출 -> 복호화하여 내용 확인

### 서버 출력 예시

START-VALIDATION  (시작지점 암호화 안된 문자열)

Hello, World! (주입된 문자열)

Sxu/jim2TwEV8US4tQxNuN8a/jnsFkYLsRW59g36oQ3 (암호화된 문자열의 일부(복호화 불가능))

END-VALIDATION (끝지점 암호와 안된 문자열)
