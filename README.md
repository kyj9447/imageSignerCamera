(문자열 주입 / 추출 원리 참고 : https://github.com/kyj9447/imageSignerAndValidator)
## image_signer_camera
(/lib/main.dart)

##### 특정 암호화된 문자열을 주입하는 Flutter 카메라 어플리케이션

비대칭 키 쌍 중 공개 키를 가지고 있습니다

(현재 소스에는 문자열 "Hello, World!"를 암호화 한 뒤 주입합니다.)

기기의 자이로스코프 값을 읽어 버튼 아이콘 회전, 사진 저장시 적절한 방향으로 회전하는데 사용

## imageValidator server
(/server/app.js)

#### 이미지 업로드시 주입된 문자열 확인하는 Node.js Express 서버

암호화된 문자열이 주입된 이미지 submit -> 암호화된 문자열 추출 -> 복호화하여 내용 확인

비대칭 키 쌍 중 개인 키를 가지고 있습니다

### 서버 출력 예시

##### START-VALIDATION  (시작지점 암호화 안된 문자열)

##### Hello, World! (주입된 문자열)

##### Sxu/jim2TwEV8US4tQxNuN8a/jnsFkYLsRW59g36oQ3 (암호화된 문자열의 일부(복호화 불가능)) 

###### (암호화된 문자열의 길이와 사진 픽셀 수(=길이) 차이에 의한 것이며 정상적인 출력임)

##### END-VALIDATION (끝지점 암호와 안된 문자열)

###### ------------------------------------------------

#### 정상적인 사진의 경우
<img src="https://github.com/kyj9447/imageSignerCamera/assets/122734245/d9befc59-d375-46ea-bb18-dd986df31448" width=800px>

#### 편집이 들어간 사진의 경우
<img src="https://github.com/kyj9447/imageSignerCamera/assets/122734245/039f6e18-1e58-4e71-84c8-8eec5461ea77" width=800px>

