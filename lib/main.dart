import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:camera/camera.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  MyApp({required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MyHomePage(camera: camera),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final CameraDescription camera;

  MyHomePage({required this.camera});

  @override
  _MyHomePageState createState() => _MyHomePageState(camera: camera);
}

class _MyHomePageState extends State<MyHomePage> {
  final CameraDescription camera;
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  File? selectedImage;
  String buttonText = '샤프코드 스캔';

  _MyHomePageState({required this.camera});

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      camera,
      ResolutionPreset.medium,
    );


    _initializeControllerFuture = _controller!.initialize();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<String?> callFastAPI() async {
    if (selectedImage == null) {
      return '이미지를 선택하세요.';
    }

    var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
    var imageFile = selectedImage!;
    String fileName = imageFile.path.split('/').last;

    var request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        return responseBody;
      } else {
        return 'HTTP 오류: ${response.statusCode}';
      }
    } catch (e) {
      return '오류: $e';
    }
  }

  Future<void> pickImage() async {
    try {
      var status = await Permission.storage.request();
      if (status.isGranted) {
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.image,
        );

        if (result != null) {
          setState(() {
            selectedImage = File(result.files.single.path!);
            buttonText = '샤프코드 스캔';
          });
        }
      } else if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
    }
  }

  Future<void> scanImage() async {
    try {
      if (selectedImage != null) {
        // 이미지를 스캔하는 로직을 구현
        // 이 예제에서는 이미지 스캔을 수행하지 않고, 그냥 선택한 이미지를 사용합니다.
        print('이미지 스캔 로직 구현');

        // 선택한 이미지를 서버로 업로드
        await uploadImage(selectedImage!.path);
      }
    } catch (e) {
      print('이미지 스캔 오류: $e');
    }
  }

  Future<void> takePicture() async {
    try {
      var status = await Permission.camera.request();
      if (status.isGranted) {
        final pickedFile = await ImagePicker().pickImage(
          source: ImageSource.camera,
        );

        if (pickedFile != null) {
          setState(() {
            selectedImage = File(pickedFile.path);
            buttonText = '샤프코드 스캔';
          });

          await uploadImage(selectedImage!.path);
        }
      } else if (status.isPermanentlyDenied) {
        openAppSettings();
      }
    } catch (e) {
      print('이미지 선택 오류: $e');
    }
  }

  Future<String> uploadImage(String imagePath) async {
    var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
    var imageFile = File(imagePath);

    var request = http.MultipartRequest('POST', url)
      ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

    try {
      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBody = await response.stream.bytesToString();
        return responseBody;
      } else {
        return 'HTTP 오류: ${response.statusCode}';
      }
    } catch (e) {
      return '오류: $e';
    }
  }

  String? apiResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('FastAPI 호출 예제'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 300,
              height: 440,
              child: selectedImage != null
                  ? Image.file(
                selectedImage!,
                width: 300,
                height: 440,
                fit: BoxFit.cover,
              )
                  : _initializeControllerFuture == null
                  //|| !_controller!.value.isInitialized // 이 부분이 주석처리 안되어 있으면
                  ? CircularProgressIndicator()
                  : FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.done) {
                    return AspectRatio(
                        aspectRatio: _controller!.value.previewSize!.height /
                            _controller!.value.previewSize!.width, // _controller!.value.previewSize!.aspectRatio,
                        child: CameraPreview(_controller!),
                    ); //CameraPreview(_controller!);
                  } else {
                    return Center(
                      child: Text('프리뷰 준비 중...'),
                    );
                  }
                },
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (_controller!.value.isInitialized) {
                    if (buttonText == '샤프코드 스캔') {
                      // 카메라 프리뷰 이미지를 캡처하여 selectedImage에 저장
                      final image = await _controller!.takePicture();
                      setState(() {
                        selectedImage = File(image.path);
                        buttonText = '다시 스캔하기';
                      });
                    } else {
                      // "다시 스캔하기" 버튼을 누르면 앱 초기 상태로 되돌아감
                      setState(() {
                        selectedImage = null;
                        buttonText = '샤프코드 스캔';
                      });
                    }

                    // API 호출 또는 다른 작업 수행
                    String? result = await callFastAPI();
                    setState(() {
                      apiResult = result;
                    });
                    print(result);
                  }
                } catch (e) {
                  print('이미지 캡처 오류: $e');
                }
              },
              child: Text(buttonText),
            ),
            ElevatedButton(
              onPressed: pickImage,
              child: Text('이미지 선택'),
            ),
            ElevatedButton(
              onPressed: () async {
                String? result = await callFastAPI();
                setState(() {
                  apiResult = result;
                });
                print(result);
              },
              child: Text('FastAPI 호출'),
            ),
            if (apiResult != null)
              Text(
                '반환되는 샤프코드 값: $apiResult',
                style: TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}



// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'dart:io';
// import 'package:camera/camera.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   final cameras = await availableCameras();
//   final firstCamera = cameras.first;
//
//   runApp(MyApp(camera: firstCamera));
// }
//
// class MyApp extends StatelessWidget {
//   final CameraDescription camera;
//
//   MyApp({required this.camera});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: MyHomePage(camera: camera),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   final CameraDescription camera;
//
//   MyHomePage({required this.camera});
//
//   @override
//   _MyHomePageState createState() => _MyHomePageState(camera: camera);
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   final CameraDescription camera;
//   CameraController? _controller;
//   Future<void>? _initializeControllerFuture;
//   File? selectedImage;
//   String buttonText = '샤프코드 스캔'; // 버튼 텍스트 추가
//
//   _MyHomePageState({required this.camera});
//
//   @override
//   void initState() {
//     super.initState();
//
//     _controller = CameraController(
//       camera,
//       ResolutionPreset.medium,
//     );
//
//     _initializeControllerFuture = _controller!.initialize();
//   }
//
//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }
//
//   Future<String?> callFastAPI() async {
//     if (selectedImage == null) {
//       return '이미지를 선택하세요.';
//     }
//
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//     var imageFile = selectedImage!;
//     String fileName = imageFile.path.split('/').last;
//
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
//
//     try {
//       var response = await request.send();
//
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       return '오류: $e';
//     }
//   }
//
//   Future<void> pickImage() async {
//     try {
//       var status = await Permission.storage.request();
//       if (status.isGranted) {
//         FilePickerResult? result = await FilePicker.platform.pickFiles(
//           type: FileType.image,
//         );
//
//         if (result != null) {
//           setState(() {
//             selectedImage = File(result.files.single.path!);
//             buttonText = '샤프코드 스캔'; // 버튼 텍스트 변경
//           });
//         }
//       } else if (status.isPermanentlyDenied) {
//         openAppSettings();
//       }
//     } catch (e) {
//       print('이미지 선택 오류: $e');
//     }
//   }
//
//   Future<void> scanImage() async {
//     try {
//       if (selectedImage != null) {
//         // 이미지를 스캔하는 로직을 구현
//         // 이 예제에서는 이미지 스캔을 수행하지 않고, 그냥 선택한 이미지를 사용합니다.
//         print('이미지 스캔 로직 구현');
//
//         // 선택한 이미지를 서버로 업로드
//         await uploadImage(selectedImage!.path);
//       }
//     } catch (e) {
//       print('이미지 스캔 오류: $e');
//     }
//   }
//
//   Future<void> takePicture() async {
//     try {
//       var status = await Permission.camera.request();
//       if (status.isGranted) {
//         final pickedFile = await ImagePicker().pickImage(
//           source: ImageSource.camera,
//         );
//
//         if (pickedFile != null) {
//           setState(() {
//             selectedImage = File(pickedFile.path);
//             buttonText = '샤프코드 스캔'; // 버튼 텍스트 변경
//           });
//
//           await uploadImage(selectedImage!.path);
//         }
//       } else if (status.isPermanentlyDenied) {
//         openAppSettings();
//       }
//     } catch (e) {
//       print('이미지 선택 오류: $e');
//     }
//   }
//
//   Future<String> uploadImage(String imagePath) async {
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//     var imageFile = File(imagePath);
//
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
//
//     try {
//       var response = await request.send();
//
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       return '오류: $e';
//     }
//   }
//
//   String? apiResult;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('FastAPI 호출 예제'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             Container(
//               width: 300,
//               height: 300,
//               child: selectedImage != null
//                   ? Image.file(
//                 selectedImage!,
//                 width: 300,
//                 height: 300,
//                 fit: BoxFit.cover,
//               )
//                   : _initializeControllerFuture == null
//                   ? CircularProgressIndicator()
//                   : FutureBuilder<void>(
//                 future: _initializeControllerFuture,
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState ==
//                       ConnectionState.done) {
//                     return CameraPreview(_controller!);
//                   } else {
//                     return Center(
//                       child: Text('프리뷰 준비 중...'),
//                     );
//                   }
//                 },
//               ),
//             ),
//
//             ElevatedButton(
//               onPressed: () async {
//                 try {
//                   if (_controller!.value.isInitialized) {
//                     // 카메라 프리뷰 이미지를 캡처하여 selectedImage에 저장
//                     final image = await _controller!.takePicture();
//                     setState(() {
//                       selectedImage = File(image.path);
//                       buttonText = '다시 스캔하기'; // 버튼 텍스트 변경
//                     });
//
//                     // API 호출 또는 다른 작업 수행
//                     String? result = await callFastAPI();
//                     setState(() {
//                       apiResult = result;
//                     });
//                     print(result);
//                   }
//                 } catch (e) {
//                   print('이미지 캡처 오류: $e');
//                 }
//               },
//               child: Text(buttonText), // 버튼 텍스트 동적으로 변경
//             ),
//             ElevatedButton(
//               onPressed: pickImage,
//               child: Text('이미지 선택'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 String? result = await callFastAPI();
//                 setState(() {
//                   apiResult = result;
//                 });
//                 print(result);
//               },
//               child: Text('FastAPI 호출'),
//             ),
//             if (apiResult != null)
//               Text(
//                 '반환되는 샤프코드 값: $apiResult',
//                 style: TextStyle(fontSize: 16),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }


/// 매우 근접함 상태임. 다만 아직 "샤프코드 스캔" 버튼을 처음 눌렀을 때 제대로 작동하는 듯하지만
/// 이후 다시 스캔 버튼 등이 없어서.. 프리뷰가 되지 않는 상태로 "샤프코드 스캔"을 하게 됨.
/// 스캔하자마자 API로 연결되어 샤프코드 값을 반환함. 아주 빠름. 좋음.
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'dart:io';
// import 'package:camera/camera.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   final cameras = await availableCameras();
//   final firstCamera = cameras.first;
//
//   runApp(MyApp(camera: firstCamera));
// }
//
// class MyApp extends StatelessWidget {
//   final CameraDescription camera;
//
//   MyApp({required this.camera});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: MyHomePage(camera: camera),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   final CameraDescription camera;
//
//   MyHomePage({required this.camera});
//
//   @override
//   _MyHomePageState createState() => _MyHomePageState(camera: camera);
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   final CameraDescription camera;
//   CameraController? _controller;
//   Future<void>? _initializeControllerFuture;
//   File? selectedImage;
//
//   _MyHomePageState({required this.camera});
//
//   @override
//   void initState() {
//     super.initState();
//
//     _controller = CameraController(
//       camera,
//       ResolutionPreset.medium,
//     );
//
//     _initializeControllerFuture = _controller!.initialize();
//   }
//
//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }
//
//   Future<String?> callFastAPI() async {
//     if (selectedImage == null) {
//       return '이미지를 선택하세요.';
//     }
//
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//     var imageFile = selectedImage!;
//     String fileName = imageFile.path.split('/').last;
//
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
//
//     try {
//       var response = await request.send();
//
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       return '오류: $e';
//     }
//   }
//
//   Future<void> pickImage() async {
//     try {
//       var status = await Permission.storage.request();
//       if (status.isGranted) {
//         FilePickerResult? result = await FilePicker.platform.pickFiles(
//           type: FileType.image,
//         );
//
//         if (result != null) {
//           setState(() {
//             selectedImage = File(result.files.single.path!);
//           });
//         }
//       } else if (status.isPermanentlyDenied) {
//         openAppSettings();
//       }
//     } catch (e) {
//       print('이미지 선택 오류: $e');
//     }
//   }
//
//   Future<void> scanImage() async {
//     try {
//       if (selectedImage != null) {
//         // 이미지를 스캔하는 로직을 구현
//         // 이 예제에서는 이미지 스캔을 수행하지 않고, 그냥 선택한 이미지를 사용합니다.
//         print('이미지 스캔 로직 구현');
//
//         // 선택한 이미지를 서버로 업로드
//         await uploadImage(selectedImage!.path);
//       }
//     } catch (e) {
//       print('이미지 스캔 오류: $e');
//     }
//   }
//
//   Future<void> takePicture() async {
//     try {
//       var status = await Permission.camera.request();
//       if (status.isGranted) {
//         final pickedFile = await ImagePicker().pickImage(
//           source: ImageSource.camera,
//         );
//
//         if (pickedFile != null) {
//           setState(() {
//             selectedImage = File(pickedFile.path);
//           });
//
//           await uploadImage(selectedImage!.path);
//         }
//       } else if (status.isPermanentlyDenied) {
//         openAppSettings();
//       }
//     } catch (e) {
//       print('이미지 선택 오류: $e');
//     }
//   }
//
//   Future<String> uploadImage(String imagePath) async {
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//     var imageFile = File(imagePath);
//
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
//
//     try {
//       var response = await request.send();
//
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       return '오류: $e';
//     }
//   }
//
//   String? apiResult;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('FastAPI 호출 예제'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             Container(  ///selectedImage가 null이 아닌 경우 이미지를 표시하고, null인 경우에는 프리뷰를 표시합니다. 프리뷰 준비 중인 동안에는 로딩 표시를 보여줍
//               width: 300,
//               height: 300,
//               child: selectedImage != null
//                   ? Image.file(
//                 selectedImage!,
//                 width: 300,
//                 height: 300,
//                 fit: BoxFit.cover,
//               )
//                   : _initializeControllerFuture == null
//                   ? CircularProgressIndicator()
//                   : FutureBuilder<void>(
//                 future: _initializeControllerFuture,
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.done) {
//                     return CameraPreview(_controller!);
//                   } else {
//                     return Center(
//                       child: Text('프리뷰 준비 중...'),
//                     );
//                   }
//                 },
//               ),
//             ),
//
//             ElevatedButton(
//               onPressed: () async {
//                 try {
//                   // 카메라 프리뷰 이미지를 캡처하여 selectedImage에 저장
//                   final image = await _controller!.takePicture();
//                   setState(() {
//                     selectedImage = File(image.path);
//                   });
//
//                   // API 호출 또는 다른 작업 수행
//                   String? result = await callFastAPI();
//                   setState(() {
//                     apiResult = result;
//                   });
//                   print(result);
//                 } catch (e) {
//                   print('이미지 캡처 오류: $e');
//                 }
//               },
//               child: Text('샤프코드 스캔'),
//             ),
//             ElevatedButton(
//               onPressed: pickImage,
//               child: Text('이미지 선택'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 String? result = await callFastAPI();
//                 setState(() {
//                   apiResult = result;
//                 });
//                 print(result);
//               },
//               child: Text('FastAPI 호출'),
//             ),
//             if (apiResult != null)
//               Text(
//                 '반환되는 샤프코드 값: $apiResult',
//                 style: TextStyle(fontSize: 16),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }


/// 프리뷰 화면이 있고, 이미지 선택 버튼, 카메라로 사진촬영 버튼, FasfAPI 호출 버튼이 있음
/// 여기서 카메라로 사진촬영 버튼을 누르면, 카메라 화면으로 전환하되, 촬영저장 후 프로뷰의
/// 이미지가 원래 프리뷰화면에 스캔되어 있음.. 사실 선택된 이미지는 어떤 것인지 모르겠음
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart'; // image_picker 패키지 추가
// import 'package:file_picker/file_picker.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'dart:io';
// import 'package:camera/camera.dart'; // camera 패키지 추가
//
// void main() async {
//   // 카메라 초기화
//   WidgetsFlutterBinding.ensureInitialized();
//   final cameras = await availableCameras();
//   final firstCamera = cameras.first;
//
//   runApp(MyApp(camera: firstCamera));
// }
//
// class MyApp extends StatelessWidget {
//   final CameraDescription camera; // 카메라 추가
//
//   MyApp({required this.camera});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: MyHomePage(camera: camera), // 카메라 객체 전달
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   final CameraDescription camera; // 카메라 추가
//
//   MyHomePage({required this.camera});
//
//   @override
//   _MyHomePageState createState() => _MyHomePageState(camera: camera); // 카메라 객체 전달
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   final CameraDescription camera; // 카메라 추가
//   CameraController? _controller; // 카메라 컨트롤러 추가
//   Future<void>? _initializeControllerFuture; // 카메라 초기화를 위한 변수 추가
//   File? selectedImage;
//
//   _MyHomePageState({required this.camera});
//
//   @override
//   void initState() {
//     super.initState();
//
//     // 카메라 초기화
//     _controller = CameraController(
//       camera,
//       ResolutionPreset.medium, // 해상도 설정
//     );
//
//     _initializeControllerFuture = _controller!.initialize();
//   }
//
//   @override
//   void dispose() {
//     // 카메라 컨트롤러 해제
//     _controller?.dispose();
//     super.dispose();
//   }
//
//   Future<String?> callFastAPI() async {
//     if (selectedImage == null) {
//       return '이미지를 선택하세요.';
//     }
//
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//     var imageFile = selectedImage!;
//     String fileName = imageFile.path.split('/').last;
//
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
//
//     try {
//       var response = await request.send();
//
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       return '오류: $e';
//     }
//   }
//
//   Future<void> pickImage() async {
//     try {
//       var status = await Permission.storage.request();
//       if (status.isGranted) {
//         FilePickerResult? result = await FilePicker.platform.pickFiles(
//           type: FileType.image,
//         );
//
//         if (result != null) {
//           setState(() {
//             selectedImage = File(result.files.single.path!);
//           });
//         }
//       } else if (status.isPermanentlyDenied) {
//         openAppSettings();
//       }
//     } catch (e) {
//       print('이미지 선택 오류: $e');
//     }
//   }
//
//   Future<void> takePicture() async {
//     try {
//       var status = await Permission.camera.request();
//       if (status.isGranted) {
//         final pickedFile = await ImagePicker().pickImage(
//           source: ImageSource.camera,
//         );
//
//         if (pickedFile != null) {
//           setState(() {
//             selectedImage = File(pickedFile.path);
//           });
//
//           await uploadImage(selectedImage!.path);
//         }
//       } else if (status.isPermanentlyDenied) {
//         openAppSettings();
//       }
//     } catch (e) {
//       print('이미지 선택 오류: $e');
//     }
//   }
//
//   Future<String> uploadImage(String imagePath) async {
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//     var imageFile = File(imagePath);
//
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
//
//     try {
//       var response = await request.send();
//
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       return '오류: $e';
//     }
//   }
//
//   String? apiResult;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('FastAPI 호출 예제'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             // 카메라 프리뷰 추가
//             Container(
//               width: 300,
//               height: 300,
//               child: FutureBuilder<void>(
//                 future: _initializeControllerFuture,
//                 builder: (context, snapshot) {
//                   if (snapshot.connectionState == ConnectionState.done) {
//                     return CameraPreview(_controller!);
//                   } else {
//                     return CircularProgressIndicator();
//                   }
//                 },
//               ),
//             ),
//             ElevatedButton(
//               onPressed: pickImage,
//               child: Text('이미지 선택'),
//             ),
//             ElevatedButton(
//               onPressed: takePicture,
//               child: Text('카메라로 사진 촬영'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 String? result = await callFastAPI();
//                 setState(() {
//                   apiResult = result;
//                 });
//                 print(result);
//               },
//               child: Text('FastAPI 호출'),
//             ),
//             if (apiResult != null)
//               Text(
//                 '반환되는 샤프코드 값: $apiResult',
//                 style: TextStyle(fontSize: 16),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }


/// 카메라 사진촬영 버튼이 있고 누르면 카메라로 이동 사진을 찍으면 찍은 이미지를
/// 첫화면에서 보여주고, 동시에 샤프코드를 반환
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart';
// import 'package:camera/camera.dart'; // camera 패키지 추가
// import 'dart:io';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   final cameras = await availableCameras(); // 사용 가능한 카메라 목록 가져오기
//   runApp(MyApp(cameras: cameras));
// }
//
// class MyApp extends StatelessWidget {
//   final List<CameraDescription> cameras;
//
//   MyApp({required this.cameras});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: MyHomePage(cameras: cameras),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   final List<CameraDescription> cameras;
//
//   MyHomePage({required this.cameras});
//
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   File? selectedImage;
//   late CameraController controller; // 카메라 컨트롤러 추가
//
//   @override
//   void initState() {
//     super.initState();
//     controller = CameraController(
//       widget.cameras[0], // 카메라 목록 중 첫 번째 카메라 선택
//       ResolutionPreset.medium, // 해상도 설정
//     );
//     controller.initialize().then((_) {
//       if (!mounted) {
//         return;
//       }
//       setState(() {});
//     });
//   }
//
//   @override
//   void dispose() {
//     controller.dispose();
//     super.dispose();
//   }
//
//   Future<String?> callFastAPI(File imageFile) async {
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//     String fileName = imageFile.path.split('/').last;
//
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
//
//     try {
//       var response = await request.send();
//
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       return '오류: $e';
//     }
//   }
//
//   Future<void> takePicture() async {
//     try {
//       final XFile? file = await controller.takePicture(); // 사진 촬영
//       if (file != null) {
//         setState(() {
//           selectedImage = File(file.path);
//         });
//         await uploadImage(selectedImage!);
//       }
//     } catch (e) {
//       print('이미지 선택 오류: $e');
//     }
//   }
//
//   Future<void> uploadImage(File imageFile) async {
//     String? result = await callFastAPI(imageFile);
//     setState(() {
//       apiResult = result;
//     });
//     print(result);
//   }
//
//   String? apiResult;
//
//   @override
//   Widget build(BuildContext context) {
//     if (!controller.value.isInitialized) {
//       return Center(
//         child: CircularProgressIndicator(),
//       );
//     }
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('FastAPI 호출 예제'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             if (selectedImage != null)
//               Image.file(
//                 selectedImage!,
//                 width: 200,
//                 height: 200,
//               ),
//             ElevatedButton(
//               onPressed: takePicture, // 카메라로 사진 촬영 함수 호출
//               child: Text('카메라로 사진 촬영'),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 // 다른 버튼 기능 추가
//               },
//               child: Text('다른 버튼'),
//             ),
//             if (apiResult != null)
//               Text(
//                 '반환되는 샤프코드 값: $apiResult',
//                 style: TextStyle(fontSize: 16),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

/// 아래의 버전에 카메라 실행시키고, 촬영한 이미지를 추가하는 것까지 포함된 코드.
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:image_picker/image_picker.dart'; // image_picker 패키지 추가
// import 'package:file_picker/file_picker.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'dart:io';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: MyHomePage(),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   File? selectedImage;
//
//   Future<String?> callFastAPI() async {
//     if (selectedImage == null) {
//       // 이미지를 선택하지 않았을 경우 처리
//       return '이미지를 선택하세요.';
//     }
//
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//
//     // 선택한 이미지 파일
//     var imageFile = selectedImage!;
//     String fileName = imageFile.path.split('/').last;
//
//     // 요청 보내기
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
//
//     try {
//       // 요청 보내고 응답 받기
//       var response = await request.send();
//
//       // 응답 처리
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       // 오류 처리
//       return '오류: $e';
//     }
//   }
//
//   Future<void> pickImage() async {
//     try {
//       var status = await Permission.storage.request();
//       if (status.isGranted) {
//         // 권한이 부여된 경우 이미지 선택 로직 실행
//         FilePickerResult? result = await FilePicker.platform.pickFiles(
//           type: FileType.image,
//         );
//
//         if (result != null) {
//           setState(() {
//             selectedImage = File(result.files.single.path!);
//           });
//         } else {
//           // 사용자가 이미지를 선택하지 않았을 경우 처리
//         }
//       } else if (status.isPermanentlyDenied) {
//         // 사용자가 권한을 영구적으로 거부한 경우 앱 설정 페이지로 안내
//         openAppSettings();
//       }
//     } catch (e) {
//       // 오류 처리
//       print('이미지 선택 오류: $e');
//     }
//   }
//
//   Future<void> takePicture() async {
//     try {
//       var status = await Permission.camera.request(); // 카메라 권한 요청
//       if (status.isGranted) {
//         // 권한이 부여된 경우 카메라 촬영 로직 실행
//         final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
//
//
//         if (pickedFile != null) {
//           setState(() {
//             selectedImage = File(pickedFile.path);
//           });
//
//           // 선택한 이미지를 서버로 업로드
//           await uploadImage(selectedImage!.path);
//         } else {
//           // 사용자가 이미지를 선택하지 않았을 경우 처리
//         }
//       } else if (status.isPermanentlyDenied) {
//         // 사용자가 권한을 영구적으로 거부한 경우 앱 설정 페이지로 안내
//         openAppSettings();
//       }
//     } catch (e) {
//       // 오류 처리
//       print('이미지 선택 오류: $e');
//     }
//   }
//
//   Future<String> uploadImage(String imagePath) async {
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//
//     // 선택한 이미지 파일
//     var imageFile = File(imagePath);
//     String fileName = imageFile.path.split('/').last;
//
//     // 요청 보내기
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
//
//     try {
//       // 요청 보내고 응답 받기
//       var response = await request.send();
//
//       // 응답 처리
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       // 오류 처리
//       return '오류: $e';
//     }
//   }
//
//   String? apiResult; // API 결과를 저장할 변수 추가
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('FastAPI 호출 예제'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             if (selectedImage != null)
//               Image.file(
//                 selectedImage!,
//                 width: 200,
//                 height: 200,
//               ),
//             ElevatedButton(
//               onPressed: pickImage,
//               child: Text('이미지 선택'),
//             ),
//             ElevatedButton(
//               onPressed: takePicture, // 이미지 선택 대신 카메라 촬영 함수 호출
//               child: Text('카메라로 사진 촬영'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 String? result = await callFastAPI();
//                 setState(() {
//                   apiResult = result; // API 결과를 변수에 저장
//                 });
//                 print(result);
//               },
//               child: Text('FastAPI 호출'),
//             ),
//             if (apiResult != null)
//               Text(
//                 '반환되는 샤프코드 값: $apiResult', // API 결과를 화면에 표시
//                 style: TextStyle(fontSize: 16),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }


/// 이거 실행하면, 화면에 샤프코드 이미지 선택 버튼과 API 실행 버튼 있고, 동작 후
/// 샤프코드를 반환함. 제대로 함. 23-1007
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:file_picker/file_picker.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'dart:io';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: MyHomePage(),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   File? selectedImage;
//
//   Future<void> pickImage() async {
//     try {
//       var status = await Permission.storage.request();
//       if (status.isGranted) {
//         // 권한이 부여된 경우 이미지 선택 로직 실행
//         FilePickerResult? result = await FilePicker.platform.pickFiles(
//           type: FileType.image,
//         );
//
//         if (result != null) {
//           setState(() {
//             selectedImage = File(result.files.single.path!);
//           });
//         } else {
//           // 사용자가 이미지를 선택하지 않았을 경우 처리
//         }
//       } else if (status.isPermanentlyDenied) {
//         // 사용자가 권한을 영구적으로 거부한 경우 앱 설정 페이지로 안내
//         openAppSettings();
//       }
//     } catch (e) {
//       // 오류 처리
//       print('이미지 선택 오류: $e');
//     }
//   }
//
//   Future<String?> callFastAPI() async {
//     if (selectedImage == null) {
//       // 이미지를 선택하지 않았을 경우 처리
//       return '이미지를 선택하세요.';
//     }
//
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//
//     // 선택한 이미지 파일
//     var imageFile = selectedImage!;
//     String fileName = imageFile.path.split('/').last;
//
//     // 요청 보내기
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));
//
//     try {
//       // 요청 보내고 응답 받기
//       var response = await request.send();
//
//       // 응답 처리
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       // 오류 처리
//       return '오류: $e';
//     }
//   }
//
//   String? apiResult; // API 결과를 저장할 변수 추가
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('FastAPI 호출 예제'),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: <Widget>[
//             if (selectedImage != null)
//               Image.file(
//                 selectedImage!,
//                 width: 200,
//                 height: 200,
//               ),
//             ElevatedButton(
//               onPressed: pickImage,
//               child: Text('이미지 선택'),
//             ),
//             ElevatedButton(
//               onPressed: () async {
//                 String? result = await callFastAPI();
//                 setState(() {
//                   apiResult = result; // API 결과를 변수에 저장
//                 });
//                 print(result);
//               },
//               child: Text('FastAPI 호출'),
//             ),
//             if (apiResult != null)
//               Text(
//                 '반환되는 샤프코드 값: $apiResult', // API 결과를 화면에 표시
//                 style: TextStyle(fontSize: 16),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }
//


///// 이거 실행하면 서버에 샤프코드 이미지 던지고 샤프코드 값 받아옴
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:permission_handler/permission_handler.dart';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: MyHomePage(),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   Future<String> callFastAPI() async {
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//
//     // 이미지 파일 로드
//     ByteData byteData = await PlatformAssetBundle().load('assets/shaf001.png');
//     List<int> bytes = byteData.buffer.asUint8List();
//
//     // 파일 이름 설정
//     String fileName = 'shaf001.png';
//     // 요청 보내기
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
//
//     try {
//       // 요청 보내고 응답 받기
//       var response = await request.send();
//
//       // 응답 처리
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       return '오류: $e';
//     }
//   }
//
//   Future<void> requestPermission() async {
//     final status = await Permission.storage.request();
//     if (status.isGranted) {
//       // 파일 액세스 권한이 부여된 경우 실행할 작업을 추가합니다.
//     } else if (status.isDenied) {
//       // 사용자에게 권한을 요청합니다.
//       // 권한이 거부된 경우 사용자가 권한을 부여할 때까지 기다릴 수 있습니다.
//       await openAppSettings();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('FastAPI 호출 예제'),
//       ),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () async {
//             await requestPermission(); // 파일 액세스 권한 요청 추가
//             String result = await callFastAPI();
//             print(result);
//           },
//           child: Text('FastAPI 호출'),
//         ),
//       ),
//     );
//   }
// }
//



// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:http/http.dart' as http;
// import 'package:permission_handler/permission_handler.dart';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: MyHomePage(),
//     );
//   }
// }
//
// class MyHomePage extends StatefulWidget {
//   @override
//   _MyHomePageState createState() => _MyHomePageState();
// }
//
// class _MyHomePageState extends State<MyHomePage> {
//   Future<String> callFastAPI() async {
//     var url = Uri.parse('http://shafcode.iptime.org:1210/shafcode1');
//
//     // 파일 준비
//     // File file = File('assets/shaf001.png');
//     // String fileName = file.path.split('/').last;
//     // var request = http.MultipartRequest('POST', url)
//     //   ..files.add(await http.MultipartFile.fromPath('file', file.path));
//
//     // 이미지 파일 로드
//     ByteData byteData = await PlatformAssetBundle().load('assets/shaf001.png');
//     List<int> bytes = byteData.buffer.asUint8List();
//
//     // 파일 이름 설정
//     String fileName = 'shaf001.png';
//     // 요청 보내기
//     var request = http.MultipartRequest('POST', url)
//       ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: fileName));
//
//     try {
//       // 요청 보내고 응답 받기
//       var response = await request.send();
//
//       // 응답 처리
//       if (response.statusCode == 200) {
//         var responseBody = await response.stream.bytesToString();
//         return responseBody;
//       } else {
//         return 'HTTP 오류: ${response.statusCode}';
//       }
//     } catch (e) {
//       return '오류: $e';
//     }
//   }
//
//   Future<void> requestPermission() async {
//     final status = await Permission.storage.request();
//     if (status.isGranted) {
//       // 파일 액세스 권한이 부여된 경우 실행할 작업을 추가합니다.
//     } else if (status.isDenied) {
//       // 파일 액세스 권한이 거부된 경우 사용자에게 메시지를 표시합니다.
//       // 사용자가 권한을 다시 부여하도록 안내할 수 있습니다.
//       openAppSettings();
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('FastAPI 호출 예제'),
//       ),
//       body: Center(
//         child: ElevatedButton(
//           onPressed: () async {
//             await requestPermission(); // 파일 액세스 권한 요청 추가
//             String result = await callFastAPI();
//             print(result);
//           },
//           child: Text('FastAPI 호출'),
//         ),
//       ),
//     );
//   }
// }