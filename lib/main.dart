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

/// 전역 변수 (필요 시 클래스로 캡슐화 고려)
List<CameraDescription> cameras = [];
int cameraIndex = 0;
BinaryProvider cryptedBinary = BinaryProvider('', '', '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 사용 가능한 카메라와 권한 요청
  cameras = await availableCameras();
  await _requestPermissions();

  // 암호화 텍스트 초기화
  await _initializeCryptedBinary();

  // 화면 방향을 세로로 고정
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // 전체화면 모드 활성화 후 앱 실행
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );
  runApp(const ImageSignerCamera());
}

/// 카메라 및 저장소 권한 요청
Future<void> _requestPermissions() async {
  if (!await Permission.camera.isGranted) {
    await Permission.camera.request();
  }
  if (!await Permission.storage.isGranted) {
    await Permission.storage.request();
  }
}

/// 암호화된 텍스트 초기화
Future<void> _initializeCryptedBinary() async {
  final results = await Future.wait([
    stringCryptor('START-VALIDATION'),
    stringCryptor('Hello, World!'),
    stringCryptor('END-VALIDATION'),
  ]);
  cryptedBinary = BinaryProvider(
    '${results[0]}\n',
    '${results[1]}\n',
    '\n${results[2]}',
  );
}

/// DCIM 폴더 경로 가져오기 (없으면 임시 경로 사용)
Future<String> getPublicDCIMFolderPath() async {
  String dcimDirPath = await ExternalPath.getExternalStoragePublicDirectory(
    ExternalPath.DIRECTORY_DCIM,
  );
  final dir = Directory(dcimDirPath);
  if (!await dir.exists()) {
    dcimDirPath = (await getExternalStorageDirectory())!.path;
  }
  return dcimDirPath;
}

/// 메인 위젯
class ImageSignerCamera extends StatelessWidget {
  const ImageSignerCamera({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Signer Camera',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CameraScreen(),
    );
  }
}

/// 카메라 화면 위젯
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  File? _latestImage;
  int _runningTasks = 0;

  // TextField 컨트롤러
  final TextEditingController _textController = TextEditingController();

  // RootIsolateToken은 compute()에 전달할 때 필요함
  final RootIsolateToken rootIsolateToken = RootIsolateToken.instance!;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initCamera();
    _loadLatestImage();
  }

  Future<void> _initCamera() async {
    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.max,
      enableAudio: false,
    );

    // 컨트롤러 초기화
    await _controller.initialize();

    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// 최신 이미지 로드 (저장소 내 imageSigner 폴더)
  Future<void> _loadLatestImage() async {
    final storagePath = await getPublicDCIMFolderPath();
    final directory = Directory('$storagePath/imageSigner');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final files = directory.listSync();
    if (files.isNotEmpty) {
      files.sort(
        (a, b) => b.statSync().changed.compareTo(a.statSync().changed),
      );
    }
    setState(() {
      // 실제 파일(File)만 필터링
      _latestImage =
          files.isNotEmpty && files.first is File ? files.first as File : null;
    });
  }

  /// 사진 촬영 후 이미지 처리 및 저장 (각도는 radian 단위)
  Future<void> takeAndSignPicture(double adjustedAngle) async {
    setState(() => _runningTasks++);
    await _initializeControllerFuture;
    try {
      final xFileImage = await _controller.takePicture();
      // radian을 각도로 변환 (정수값)
      final int adjustedAngleDegrees = (adjustedAngle * 180 / pi).toInt();
      final filePath = await compute(processImageWrapper, [
        xFileImage,
        adjustedAngleDegrees,
        cryptedBinary,
        rootIsolateToken,
      ]);
      await _loadLatestImage();
      MediaScanner.loadMedia(path: filePath);
    } catch (e) {
      debugPrint('Error taking picture: $e');
    } finally {
      setState(() => _runningTasks--);
    }
  }

  /// 카메라 전환
  Future<void> _switchCamera() async {
    cameraIndex = (cameraIndex + 1) % cameras.length;
    _controller = CameraController(
      cameras[cameraIndex],
      ResolutionPreset.max,
      enableAudio: false,
    );
    await _controller.initialize();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(cameras[cameraIndex].toString()),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  /// 사용자 입력 텍스트를 암호화하여 cryptedBinary 업데이트
  Future<void> _updateCryptedBinary(String input) async {
    final results = await Future.wait([
      stringCryptor('START-VALIDATION'),
      stringCryptor(input),
      stringCryptor('END-VALIDATION'),
    ]);
    setState(() {
      cryptedBinary = BinaryProvider(
        '${results[0]}\n',
        '${results[1]}\n',
        '\n${results[2]}',
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Text submitted: $input')));
    _textController.clear();
  }

  /// 각도(°)에 따른 회전 값 계산
  double _calculateAdjustedAngle(double angleInDegrees) {
    if (angleInDegrees > 135 && angleInDegrees <= 225) {
      return 0;
    } else if (angleInDegrees > 225 && angleInDegrees <= 315) {
      return pi / 2;
    } else if (angleInDegrees > 315 || angleInDegrees <= 45) {
      return pi;
    } else if (angleInDegrees > 45 && angleInDegrees <= 135) {
      return 3 * pi / 2;
    }
    return 0;
  }

  /// AccelerometerEvent를 기반으로 회전할 각도 계산
  double _getAdjustedAngle(AccelerometerEvent? event) {
    if (event == null) return 0;
    final angle = atan2(event.x, event.y);
    final angleInDegrees = angle * 180 / pi + 180;
    return _calculateAdjustedAngle(angleInDegrees);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          // 카메라 프리뷰가 남은 공간 모두 사용
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Transform.rotate(
                    angle: pi * 1 / 2, // 90도 회전
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller.value.previewSize!.height,
                        height: _controller.value.previewSize!.width,
                        child: CameraPreview(_controller),
                      ),
                    ),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          // 하단 패널: 텍스트 입력 필드와 버튼 영역
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 텍스트 입력 필드
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    labelText: 'Enter text to encrypt',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed:
                          () => _updateCryptedBinary(_textController.text),
                    ),
                  ),
                ),
              ),
              // 버튼 영역: 영역 크기를 2배로 늘리고 버튼 간격을 균일하게 배치
              StreamBuilder<AccelerometerEvent>(
                stream: accelerometerEvents,
                builder: (context, snapshot) {
                  final adjustedAngle = _getAdjustedAngle(snapshot.data);
                  return Container(
                    height: 120, // 기존의 2배 크기로 영역 높이를 지정 (원하는 값으로 조정 가능)
                    color: Colors.black,
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        // 갤러리 버튼
                        Transform.rotate(
                          angle: adjustedAngle,
                          child: FloatingActionButton(
                            onPressed: () {},
                            child:
                                _runningTasks > 0
                                    ? Stack(
                                      alignment: Alignment.center,
                                      children: <Widget>[
                                        const CircularProgressIndicator(),
                                        if (_runningTasks > 1)
                                          Text('$_runningTasks'),
                                      ],
                                    )
                                    : _latestImage != null
                                    ? Image.file(_latestImage!)
                                    : const Icon(Icons.browse_gallery_rounded),
                          ),
                        ),
                        // 사진 촬영 버튼
                        Transform.rotate(
                          angle: adjustedAngle,
                          child: FloatingActionButton(
                            onPressed: () => takeAndSignPicture(adjustedAngle),
                            child: const Icon(Icons.camera),
                          ),
                        ),
                        // 카메라 전환 버튼
                        Transform.rotate(
                          angle: adjustedAngle,
                          child: FloatingActionButton(
                            onPressed: _switchCamera,
                            child: const Icon(Icons.switch_camera),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
