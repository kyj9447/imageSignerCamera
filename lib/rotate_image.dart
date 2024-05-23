// // compute()용 wrapper
// import 'package:camera/camera.dart';
// import 'package:flutter/services.dart';
// import 'package:image/image.dart' as img;
// import 'package:image_signer_camera/main.dart';

// Future<XFile> rotateImage(List<dynamic> args) async {
//   // 토큰을 통해 isolate 초기화
//   BackgroundIsolateBinaryMessenger.ensureInitialized(args[0]);

//   XFile image = args[1];
//   num adjustedAngle = 360 - args[2];

//   img.Image imageBytes = img.decodeImage(await image.readAsBytes())!;
//   img.Image rotatedImage = img.copyRotate(imageBytes, angle: adjustedAngle);

//   return await imageToXFile(rotatedImage);
// }
