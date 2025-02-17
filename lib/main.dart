import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:imagesignercamera/image_signer.dart';
import 'package:imagesignercamera/process_image.dart';
import 'package:imagesignercamera/string_cryptor.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

List<CameraDescription> cameras = [];
int cameraIndex = 0;
BinaryProvider cryptedBinary = BinaryProvider('', '', '');
// BinaryProvider noncryptedBinary = BinaryProvider('', '', '');

// main
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  await requestPermissions();

  //암호화 텍스트 제공
  List<String> results = await Future.wait([
    stringCryptor('START-VALIDATION'),
    stringCryptor('Hello, World!'),
    stringCryptor('END-VALIDATION'),
  ]);

  cryptedBinary =
      BinaryProvider('${results[0]}\n', '${results[1]}\n', '\n${results[2]}');

  // // 테스트용 비암호화 텍스트
  // BinaryProvider noncryptedBinary = BinaryProvider('START-VALIDATION\n', 'Hello, World!\n', '\nEND-VALIDATION');

  runApp(const ImageSignerCamera());
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
      overlays: []);
}

// 권한 요청
Future<void> requestPermissions() async {
  var status = await Permission.camera.status;
  if (!status.isGranted) {
    status = await Permission.camera.request();
  }

  var storageStatus = await Permission.storage.status;
  if (!storageStatus.isGranted) {
    storageStatus = await Permission.storage.request();
  }
}

// // 저장소 미디어스캔 실행
// void medaiScan(String path) {
//   if (Platform.isAndroid) {
//     // 미디어 스캔 실행
//     AndroidIntent intent = AndroidIntent(
//       action: 'android.intent.action.MEDIA_SCANNER_SCAN_FILE',
//       data: Uri.file(path).toString(),
//       package: 'com.android.gallery3d',
//     );
//     intent.launch();
//   }
// }

// DCIM 폴더 경로 가져오기 (Scoped Storage)
Future<String> getPublicDCIMFolderPath() async {
  String? dcimDirPath;

  dcimDirPath = await ExternalPath.getExternalStoragePublicDirectory(
      ExternalPath.DIRECTORY_DCIM);
  Directory dir = Directory(dcimDirPath);

  if (!dir.existsSync()) {
    dcimDirPath = (await getExternalStorageDirectory())!.path;
  }

  return dcimDirPath;
}

// // Image -> XFile
// Future<XFile> imageToXFile(img.Image image) async {
//   // 이미지를 바이트 배열로 변환
//   List<int> imageBytes = img.encodePng(image);

//   // 바이트 배열을 파일로 저장
//   Directory tempDir = await getTemporaryDirectory();
//   File tempFile = File('${tempDir.path}/temp.png');
//   await tempFile.writeAsBytes(imageBytes);

//   // 파일의 경로를 사용하여 XFile 객체를 생성
//   XFile xfile = XFile(tempFile.path);

//   return xfile;
// }

// // XFile -> Image
// Future<img.Image> xFileToImage(XFile xfile) async {
//   // 파일을 바이트 배열로 읽기
//   Uint8List imageBytes = await File(xfile.path).readAsBytes();

//   // 바이트 배열을 이미지로 변환
//   img.Image image = img.decodeImage(imageBytes)!;

//   return image;
// }

// 메인 위젯
class ImageSignerCamera extends StatelessWidget {
  const ImageSignerCamera({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Signer Camera',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      // 주 화면
      home: const CameraScreen(),
    );
  }
}

// 카메라 화면 위젯
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

// 카메라 화면 State
class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  // 마지막으로 찍은 사진
  File? _latestImage;

  // 실행 중인 작업 수
  int _runningTasks = 0;

  // 루트 isolate 토큰
  RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;

  // TextEditingController to manage text input
  final TextEditingController _textController = TextEditingController();

  Future<void> _loadLatestImage() async {
    String? storagePath = await getPublicDCIMFolderPath();
    var directory = Directory('$storagePath/imageSigner');
    // 디렉토리가 없으면 생성
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    var files = directory.listSync();
    files.sort((a, b) => b
        .statSync()
        .changed
        .toString()
        .compareTo(a.statSync().changed.toString()));
    setState(() {
      _latestImage = files.isEmpty ? null : files.first as File?;
    });
  }

  // 사진 촬영
  Future<void> takeAndSignPicture(double adjusted90AngleRadian) async {
    setState(() {
      _runningTasks++;
    });
    await _initializeControllerFuture;
    XFile xFileImage = await _controller.takePicture();

    // 라디안을 각도로 변환
    int adjusted90Angle = adjusted90AngleRadian * 180 ~/ pi;

    // 이미지 처리 함수 실행
    String filePath = await compute(processImageWrapper,
        [xFileImage, adjusted90Angle, cryptedBinary, rootIsolateToken]);

    await _loadLatestImage();

    setState(() {
      _runningTasks--;
    });

    // 미디어 스캔 실행
    //medaiScan(filePath);
    MediaScanner.loadMedia(path: filePath);
  }

  // 카메라 전환
  void switchCamera() async {
    cameraIndex += 1;
    if (cameraIndex > cameras.length - 1) {
      cameraIndex = 0;
    }

    _controller = CameraController(cameras[cameraIndex], ResolutionPreset.max,
        enableAudio: false);

    await _controller.initialize();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        cameras[cameraIndex].toString(),
      ),
      duration: const Duration(milliseconds: 1000),
    ));
  }

  // Update cryptedBinary with user input
  Future<void> _updateCryptedBinary(String input) async {
    List<String> results = await Future.wait([
      stringCryptor('START-VALIDATION'),
      stringCryptor(input),
      stringCryptor('END-VALIDATION'),
    ]);

    setState(() {
      cryptedBinary =
          BinaryProvider('${results[0]}\n', '${results[1]}\n', '\n${results[2]}');
    });

    // Show a SnackBar to notify the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Text submitted: $input')),
    );

    // Clear the input field
    _textController.clear();
  }

  // 카메라 초기화
  @override
  void initState() {
    super.initState();

    // // 가속도계 이벤트 구독
    // accelerometerSubscription =
    //     accelerometerEventStream().listen((AccelerometerEvent event) {
    //   setState(() {
    //     accelerometerEvent = event;
    //   });
    // });

    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.max,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
    _loadLatestImage();
  }

  // // 카메라 해제
  // @override
  // void dispose() {
  //   // // 가속도계 이벤트 구독 취소
  //   // accelerometerSubscription?.cancel();

  //   _controller.dispose();
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          // 1. 카메라 화면
          FutureBuilder<void>(
            future: _initializeControllerFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Transform.scale(
                    scale: 1,
                    child: CameraPreview(_controller),
                  ),
                );
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),

          // 2. 텍스트 입력 필드
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _textController,
              decoration: InputDecoration(
                labelText: 'Enter text to encrypt',
                suffixIcon: IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    _updateCryptedBinary(_textController.text);
                  },
                ),
              ),
            ),
          ),

          // 3. 버튼들
          StreamBuilder<AccelerometerEvent>(
            stream: accelerometerEventStream(),
            builder: (BuildContext context,
                AsyncSnapshot<AccelerometerEvent> snapshot) {
              double angle = 0;
              double adjustedAngle = 0;
              double angleInDegrees = 0;

              // 각도 계산
              if (snapshot.hasData) {
                angle = atan2(snapshot.data!.x, snapshot.data!.y);
                angleInDegrees = angle * 180 / pi + 180;
                adjustedAngle = 0;
                if (225 >= angleInDegrees && angleInDegrees > 135) {
                  adjustedAngle = 0;
                } else if (315 >= angleInDegrees && angleInDegrees > 225) {
                  adjustedAngle = pi / 2;
                } else if (45 >= angleInDegrees || angleInDegrees > 315) {
                  adjustedAngle = pi;
                } else if (135 >= angleInDegrees && angleInDegrees > 45) {
                  adjustedAngle = 3 * pi / 2;
                }
              }
              return Expanded(
                child: Container(
                  color: Colors.black,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        // 2-1. 갤러리 버튼
                        Transform.rotate(
                          angle: adjustedAngle,
                          child: FloatingActionButton(
                            onPressed: null,
                            child: _runningTasks > 0
                                ? Center(
                                    child: Stack(
                                    alignment: Alignment.center,
                                    children: <Widget>[
                                      const CircularProgressIndicator(),
                                      _runningTasks > 1
                                          ? Text('$_runningTasks')
                                          : Container(),
                                    ],
                                  ))
                                : _latestImage != null
                                    ? Image.file(_latestImage!)
                                    : const Icon(Icons.browse_gallery_rounded),
                          ),
                        ),

                        // 2-2. 사진 찍기 버튼
                        const Padding(padding: EdgeInsets.all(20)),
                        Transform.rotate(
                          angle: adjustedAngle,
                          child: FloatingActionButton(
                            onPressed: () => takeAndSignPicture(adjustedAngle),
                            child: const Icon(Icons.camera),
                          ),
                        ),

                        // 2-3. 카메라 전환 버튼
                        const Padding(padding: EdgeInsets.all(20)),
                        Transform.rotate(
                          angle: adjustedAngle,
                          child: FloatingActionButton(
                            onPressed: switchCamera,
                            child: const Icon(Icons.switch_camera),
                          ),
                        ),

                        //// 2-4. 각도 표시 (임시)
                        //const Padding(padding: EdgeInsets.all(20)),
                        //Transform.rotate(
                        //  angle: 0,
                        //  child: Text(
                        //    angleInDegrees.toStringAsFixed(4),
                        //    style: const TextStyle(color: Colors.white),
                        //  ),
                        //),
                      ],
                    ),
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }
}
