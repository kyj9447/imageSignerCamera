import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_signer_camera/image_signer_and_validator.dart';
import 'package:image_signer_camera/rotate_image.dart';
import 'package:image_signer_camera/save_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

List<CameraDescription> cameras = [];
int cameraIndex = 0;

// main
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  await requestStoragePermission();
  runApp(const ImageSignerCamera());
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
      overlays: []);
}

// 저장소 권한 요청
Future<void> requestStoragePermission() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    status = await Permission.storage.request();
  }
}

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

// Image -> XFile
Future<XFile> imageToXFile(img.Image image) async {
  // 이미지를 바이트 배열로 변환
  List<int> imageBytes = img.encodePng(image);

  // 바이트 배열을 파일로 저장
  Directory tempDir = await getTemporaryDirectory();
  File tempFile = File('${tempDir.path}/temp.png');
  await tempFile.writeAsBytes(imageBytes);

  // 파일의 경로를 사용하여 XFile 객체를 생성
  XFile xfile = XFile(tempFile.path);

  return xfile;
}

// XFile -> Image
Future<img.Image> xFileToImage(XFile xfile) async {
  // 파일을 바이트 배열로 읽기
  Uint8List imageBytes = await File(xfile.path).readAsBytes();

  // 바이트 배열을 이미지로 변환
  img.Image image = img.decodeImage(imageBytes)!;

  return image;
}

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

  // 가속도계 이벤트 저장
  AccelerometerEvent? accelerometerEvent;
  StreamSubscription? accelerometerSubscription;

  // 루트 isolate 토큰
  RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;

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
  Future<void> takeAndSignPicture(double adjustedAngleRadian) async {
    setState(() {
      _runningTasks++;
    });
    await _initializeControllerFuture;
    var image = await _controller.takePicture();

    // 라디안을 각도로 변환
    int adjustedAngle = adjustedAngleRadian * 180 ~/ pi;
    adjustedAngle += 180; // !180도 회전!

    // 이미지 회전 (compute 사용)
    image =
        await compute(rotateImage, [rootIsolateToken, image, adjustedAngle]);

    processImage(image).then((_) {
      setState(() {
        _runningTasks--;
      });
    });

    setState(() {
      _latestImage = File(image.path);
    });
  }

  Future<void> processImage(XFile image) async {
    // 이미지에 텍스트 숨기기 (compute 사용)
    img.Image signedImage = await compute(addHiddenBitWrapper,
        [rootIsolateToken, image, BinaryProvider('Hello, World!\n')]);

    // 이미지 저장 (compute 사용)
    await compute(saveImageWrapper, [rootIsolateToken, signedImage]);
  }

  // 카메라 전환
  void switchCamera() async {
    cameraIndex += 1;
    if (cameraIndex > cameras.length - 1) {
      cameraIndex = 0;
    }

    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.ultraHigh,
    );

    await _controller.initialize();
    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        cameras[cameraIndex].toString(),
      ),
      duration: const Duration(milliseconds: 1000),
    ));
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
      ResolutionPreset.ultraHigh,
    );
    _initializeControllerFuture = _controller.initialize();
    _loadLatestImage();
  }

  // 카메라 해제
  @override
  void dispose() {
    // // 가속도계 이벤트 구독 취소
    // accelerometerSubscription?.cancel();

    _controller.dispose();
    super.dispose();
  }

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

          // 2. 버튼들
          StreamBuilder<AccelerometerEvent>(
            stream: accelerometerEventStream(),
            builder: (BuildContext context,
                AsyncSnapshot<AccelerometerEvent> snapshot) {
              double adjustedAngle = 0;

              // 각도 계산
              if (snapshot.hasData) {
                double angle = atan2(snapshot.data!.y, snapshot.data!.x);
                double angleInDegrees = angle * 180 / pi;
                adjustedAngle = 0;
                if (angleInDegrees >= 315 || angleInDegrees < 45) {
                  adjustedAngle = pi / 2;
                } else if (angleInDegrees >= 45 && angleInDegrees < 135) {
                  adjustedAngle = 0;
                } else if (angleInDegrees >= 135 && angleInDegrees < 225) {
                  adjustedAngle = 3 * pi / 2;
                } else if (angleInDegrees >= 225 && angleInDegrees < 315) {
                  adjustedAngle = pi;
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
                        )
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
