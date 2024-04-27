import 'dart:io';

import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_signer_camera/image_signer_and_validator.dart';
import 'package:image_signer_camera/save_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
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

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  File? _latestImage;
  bool _isLoading = false;
  int _runningTasks = 0;
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
  Future<void> takeAndSignPicture() async {
    setState(() {
      _runningTasks++;
    });
    await _initializeControllerFuture;
    final image = await _controller.takePicture();

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

          // 2. 버튼
          Expanded(
            child: Container(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    // 1. 갤러리 버튼
                    FloatingActionButton(
                      onPressed: null,
                      child: _runningTasks > 0
                          ? Center(
                              child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                CircularProgressIndicator(),
                                _runningTasks > 1
                                    ? Text('$_runningTasks')
                                    : Container(),
                              ],
                            ))
                          : _latestImage != null
                              ? Image.file(_latestImage!)
                              : const Icon(Icons.browse_gallery_rounded),
                    ),
                    // 2. 촬영 버튼
                    const Padding(padding: EdgeInsets.all(20)),
                    FloatingActionButton(
                      onPressed: takeAndSignPicture,
                      child: const Icon(Icons.camera),
                    ),
                    // 3. 카메라 전환 버튼
                    const Padding(padding: EdgeInsets.all(20)),
                    FloatingActionButton(
                      onPressed: switchCamera,
                      child: const Icon(Icons.switch_camera),
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
