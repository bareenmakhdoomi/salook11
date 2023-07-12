import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:salook/utils/firebase.dart';
import 'package:salook/view_models/auth/posts_view_model.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:camera/camera.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:highlight_text/highlight_text.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

PostsViewModel postsViewModel = PostsViewModel();

class SpeechScreen extends StatefulWidget {
  @override
  _SpeechScreenState createState() => _SpeechScreenState();
  void speechScreenMethod() {
    print('speechScreenMethod called');
    _SpeechScreenState();
  }
}

class _SpeechScreenState extends State<SpeechScreen> {
  final Map<String, HighlightedWord> _highlights = {
    'Poet': HighlightedWord(
      onTap: () => print('Poet'),
      textStyle: const TextStyle(
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
    ),
    'Poetry': HighlightedWord(
      onTap: () => print('Poetry'),
      textStyle: const TextStyle(
        color: Colors.green,
        fontWeight: FontWeight.bold,
      ),
    ),
    'Thought': HighlightedWord(
      onTap: () => print('Thought'),
      textStyle: const TextStyle(
        color: Colors.purple,
        fontWeight: FontWeight.bold,
      ),
    ),
    'Nature': HighlightedWord(
      onTap: () => print('Nature'),
      textStyle: const TextStyle(
        color: Colors.blueAccent,
        fontWeight: FontWeight.bold,
      ),
    ),
    'Beauty': HighlightedWord(
      onTap: () => print('Beauty'),
      textStyle: const TextStyle(
        color: Colors.green,
        fontWeight: FontWeight.bold,
      ),
    ),
  };

  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = 'Start Speaking';
  double _confidence = 1.0;

  get TextToImage => null;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Speak'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AvatarGlow(
        animate: _isListening,
        glowColor: Theme.of(context).primaryColor,
        endRadius: 75.0,
        duration: const Duration(milliseconds: 2000),
        repeatPauseDuration: const Duration(milliseconds: 100),
        repeat: true,
        child: FloatingActionButton(
          onPressed: _listen,
          child: Icon(_isListening ? Icons.mic : Icons.mic_none),
        ),
      ),
      body: SingleChildScrollView(
        reverse: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(30.0, 30.0, 30.0, 150.0),
          child: TextHighlight(
            text: _text,
            words: _highlights,
            textStyle: const TextStyle(
              fontSize: 32.0,
              color: Colors.black,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => print('onStatus: $val'),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (val) => setState(() {
            _text = val.recognizedWords;
            if (val.hasConfidenceRating && val.confidence > 0) {
              _confidence = val.confidence;
            }
          }),
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      _convertTextToImageAndUpload();
    }
  }

  Future<void> _convertTextToImageAndUpload() async {
    // Generate image from text
    String imagePath = await _generateImageFromText(_text);

    if (imagePath != null) {
      // Upload the generated image to Firebase Storage
      String imageUrl = await _uploadImageToFirebase(imagePath);

      if (imageUrl != null) {
        // Add the post to Firestore
        await postsViewModel.uploadPost(imageUrl);
      } else {
        // Error uploading the image
        print('Error uploading image to Firebase Storage');
      }
    } else {
      // Error generating the image
      print('Error generating image');
    }

    // Navigate back
    Navigator.pop(context);
  }

  Future<String> _uploadImageToFirebase(String imagePath) async {
    try {
      final id = firebaseAuth.currentUser!.uid;
      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('user_posts/$id/${DateTime.now().toString()}.jpg');
      final uploadTask = storageRef.putFile(File(imagePath));
      final snapshot = await uploadTask.whenComplete(() {});

      // Get the download URL of the uploaded image
      final imageUrl = await snapshot.ref.getDownloadURL();
      return imageUrl;
    } catch (e) {
      print('Error uploading image to Firebase Storage: $e');
      return '';
    }
  }

  Future<String> _generateImageFromText(String text) async {
    try {
      final image = await TextToImage.generate(
        text,
        fontSize: 24,
        textColor: Colors.black,
        backgroundColor: Colors.white,
        width: 800,
        height: 600,
      );

      final tempDir = await getTemporaryDirectory();
      final imagePath = '${tempDir.path}/text_image.png';
      final file = File(imagePath);
      await file.writeAsBytes(image);

      return imagePath;
    } catch (e) {
      print('Error generating image from text: $e');
      return '';
    }
  }
}

class CustomResultScreen extends ChangeNotifier {
  CameraController? _cameraController;
  double _confidence = 0.0;

  late PostsViewModel viewModel;

  get mediaUrl => null;

  String get imagePath => '';

  Future<String> scanImage(BuildContext context) async {
    if (_cameraController == null) return '0';

    final navigator = Navigator.of(context);
    String ocr = "";

    try {
      final pictureFile = await _cameraController!.takePicture();

      final file = File(pictureFile.path);

      final inputImage = InputImage.fromFile(file);
      var textRecognizer = GoogleMlKit.vision.textRecognizer();
      final recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();

      await navigator.push(
        MaterialPageRoute(
          builder: (BuildContext context) =>
              ResultScreen(text: recognizedText.text),
        ),
      );

      ocr += recognizedText.text;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred when scanning text'),
        ),
      );
    }

    return ocr;
  }

  void buildTextField(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String commentData = '';

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Type Your Post'),
              content: Container(
                width: double.maxFinite,
                child: TextField(
                  maxLines: null,
                  onChanged: (value) {
                    commentData = value;
                  },
                  decoration: InputDecoration(
                    hintText: 'Start Writing',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: Text(
                    'UPLOAD',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    // Handle the post creation with the commentData
                    print('Post created: $commentData');
                    String imageUrl = await _uploadImageToFirebase(commentData);

                    if (imageUrl != null) {
                      await postsViewModel.uploadPost(imageUrl);
                    } else {
                      print('Error uploading image to Firebase Storage');
                    }

                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> _uploadImageToFirebase(String text) async {
    try {
      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('images/${DateTime.now().millisecondsSinceEpoch}.png');

      final uploadTask = storageRef.putFile(File(imagePath));
      final snapshot = await uploadTask.whenComplete(() {});

      // Get the download URL of the uploaded image
      final imageUrl = await snapshot.ref.getDownloadURL();

      return imageUrl;
    } catch (e) {
      print('Error uploading image to Firebase Storage: $e');
      return '';
    }
  }
}

class ResultScreen extends StatefulWidget {
  final String text;

  ResultScreen({required this.text});

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with WidgetsBindingObserver {
  late Future<void> _future;
  CameraController? _cameraController;
  bool _isPermissionGranted = false;

  get mediaUrl => null;

  get viewModel => null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    _future = _requestCameraPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    _stopCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed &&
        _cameraController != null &&
        _cameraController!.value.isInitialized) {
      _startCamera();
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    _isPermissionGranted = status == PermissionStatus.granted;
  }

  void _startCamera() async {
    if (_cameraController != null) {
      await _cameraController!.initialize();
      setState(() {});
    }
  }

  void _stopCamera() {
    if (_cameraController != null) {
      _cameraController?.dispose();
    }
  }

  void _initCameraController(List<CameraDescription> cameras) {
    if (_cameraController != null) {
      return;
    }

    // Select the first rear camera.
    CameraDescription? camera;
    for (var i = 0; i < cameras.length; i++) {
      final CameraDescription current = cameras[i];
      if (current.lensDirection == CameraLensDirection.back) {
        camera = current;
        break;
      }
    }

    if (camera != null) {
      _cameraController = CameraController(
        camera,
        ResolutionPreset.max,
        enableAudio: false,
      );

      _startCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
      ),
      body: Container(
        padding: const EdgeInsets.all(30.0),
        child: Text(widget.text),
      ),
    );
  }
}
