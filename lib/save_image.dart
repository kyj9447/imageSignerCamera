import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_signer_camera/main.dart';
import 'package:intl/intl.dart';

// compute()용 wrapper
Future<String> saveImageWrapper(List<dynamic> args) async {
  // 토큰을 통해 isolate 초기화
  BackgroundIsolateBinaryMessenger.ensureInitialized(args[0]);

  img.Image image = args[1];
  return saveImage(image);
}

// 이미지 저장
Future<String> saveImage(img.Image signedImage) async {
  String? storagePath = await getPublicDCIMFolderPath();
  List<int> png = img.encodePng(signedImage);
  final DateTime now = DateTime.now();
  final String formatted = DateFormat('yyyy-MM-dd-HH-mm').format(now);
  final directory = Directory('$storagePath/imageSigner');
  if (!await directory.exists()) {
    await directory.create(recursive: true);
  }

  // 이미지 파일명 중복 시 (1), (2) ... 순서로 파일명 변경
  String filename = '$formatted.png';
  int counter = 1;
  while (await File('${directory.path}/$filename').exists()) {
    filename = '$formatted(${counter++}).png';
  }

  final File file = File('${directory.path}/$filename');
  await file.writeAsBytes(png);

  return file.path;
}
