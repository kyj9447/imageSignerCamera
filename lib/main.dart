import 'dart:io';

import 'package:external_path/external_path.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image/image.dart';
import 'package:image_signer_camera/image_signer_and_validator.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const ImageSignerCamera());
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky,
      overlays: []);
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
}

Future<void> requestStoragePermission() async {
  var status = await Permission.storage.status;
  if (!status.isGranted) {
    status = await Permission.storage.request();
  }
}

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

class ImageSignerCamera extends StatelessWidget {
  const ImageSignerCamera({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Signer Camera',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  // void saveImage(img.Image signedImage) {
  //   List<int> png = encodePng(signedImage);
  //   File('/sdcard/output.png').writeAsBytesSync(png);
  // }

  Future<void> saveImage(img.Image signedImage) async {
    String? storagePath = await getPublicDCIMFolderPath();
    List<int> png = encodePng(signedImage);
    //final Directory directory = Directory('/storage/emulated/0/');
    final DateTime now = DateTime.now();
    final String formatted = DateFormat('yyyy-MM-dd-HH-mm').format(now);
    final String filename = '$formatted.png';
    final File file = File('$storagePath/$filename');
    file.writeAsBytesSync(png);
  }

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      cameras[0],
      ResolutionPreset.ultraHigh,
    );
    _initializeControllerFuture = _controller.initialize();
  }

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
          Expanded(
            child: Container(
              color: Colors.black,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    FloatingActionButton(
                      child: const Icon(Icons.camera),
                      onPressed: () async {
                        try {
                          await requestStoragePermission();
                          await _initializeControllerFuture;
                          final image = await _controller.takePicture();
                          // Process the captured image here
                          img.Image signedImage = await addHiddenBit(
                              image, BinaryProvider('Hello, World!\n'));
                          await saveImage(signedImage);
                        } catch (e) {
                          print(e);
                        }
                      },
                    ),
                    // Add more camera controls here
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
