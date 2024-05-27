import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_signer_camera/image_signer.dart';
import 'package:image_signer_camera/save_image.dart';
import 'package:media_scanner/media_scanner.dart';

//DateTime startTime = DateTime.now();

// compute()용 wrapper
Future<String> processImageWrapper(List<dynamic> args) async {
  //[image, rotateDegree, BinaryProvider, rootIsolateToken]

  //print("processImageWrapper 시작");

  // 3. 토큰을 통해 isolate 초기화
  RootIsolateToken rootIsolateToken = args[3];
  BackgroundIsolateBinaryMessenger.ensureInitialized(rootIsolateToken);

  // 1. 이미지
  XFile xFileImage = args[0];

  // 2. 회전 각도
  num rotateDegree = 360 - args[1];
  if (rotateDegree == 360) {
    rotateDegree = 0;
  }

  //print("회전각도 : $rotateDegree");

  // 3. 암호화 텍스트
  BinaryProvider cryptedBinary = args[2];

  //String startString = cryptedBinary.startString;
  //String endString = cryptedBinary.endString;
  //print("Start String : $startString");
  //print("End String : $endString");

  //print('Execution time: ${DateTime.now().difference(startTime).inMilliseconds} ms');

  // 4. 이미지 처리 함수 실행

  // 0. 이미지 읽기
  img.Image? imageBytes = img.decodeImage(await xFileImage.readAsBytes());
  //print('이미지 읽기 : ${DateTime.now().difference(startTime).inMilliseconds} ms');

  // 1. 이미지 회전
  //print("회전각도 : $rotateDegree");
  img.Image rotatedImage = img.copyRotate(imageBytes!, angle: rotateDegree);
  //print('이미지 회전 : ${DateTime.now().difference(startTime).inMilliseconds} ms');

  // 2-2. 이미지에 텍스트 숨기기
  img.Image signedImage = await addHiddenBit(rotatedImage, cryptedBinary);
  //print('텍스트 주입 : ${DateTime.now().difference(startTime).inMilliseconds} ms');

  // 3. 이미지 저장
  String filePath = await saveImage(signedImage);
  //print('이미지 저장 : ${DateTime.now().difference(startTime).inMilliseconds} ms');

  return filePath;
}
