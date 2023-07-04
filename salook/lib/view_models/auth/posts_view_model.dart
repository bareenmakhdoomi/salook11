// ignore_for_file: unused_import

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:salook/models/post.dart';
import 'package:salook/screens/mainscreen.dart';
import 'package:salook/services/post_service.dart';
import 'package:salook/services/user_service.dart';
import 'package:salook/utils/constants.dart';
import 'package:salook/utils/firebase.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;

class PostsViewModel extends ChangeNotifier {
  // Services
  UserService userService = UserService();
  PostService postService = PostService();

  // Keys
  GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Variables
  bool loading = false;
  String? username;
  File? mediaUrl;
  final picker = ImagePicker();
  String? location;
  Position? position;
  Placemark? placemark;
  String? bio;
  String? description;
  String? email;
  String? commentData;
  String? ownerId;
  String? userId;
  String? type;
  File? userDp;
  String? imgLink;
  bool edit = false;
  String? id;

  // Controllers
  TextEditingController locationTEC = TextEditingController();
  TextEditingController textEditingController = TextEditingController();

  // Speech-to-text
  stt.SpeechToText? speech;
  bool isListening = false;
  String recognizedText = '';

  // Setters
  setEdit(bool val) {
    edit = val;
    notifyListeners();
  }

  setPost(PostModel post) {
    if (post != null) {
      description = post.description;
      imgLink = post.mediaUrl;
      location = post.location;
      edit = true;
      edit = false;
      notifyListeners();
    } else {
      edit = false;
      notifyListeners();
    }
  }

  setUsername(String val) {
    print('SetName $val');
    username = val;
    notifyListeners();
  }

  setDescription(String val) {
    print('SetDescription $val');
    description = val;
    notifyListeners();
  }

  setLocation(String val) {
    print('SetCountry $val');
    location = val;
    notifyListeners();
  }

  setBio(String val) {
    print('SetBio $val');
    bio = val;
    notifyListeners();
  }

  uploadPost(String? recognizedText, String mediaUrl) async {
    if (recognizedText != null) {
      final id = firebaseAuth.currentUser!.uid;

      // Download the media file
      final response = await http.get(Uri.parse(mediaUrl));
      final bytes = response.bodyBytes;

      // Create a temporary file to store the downloaded media
      final tempDir = await path_provider.getTemporaryDirectory();
      final tempPath = path.join(tempDir.path, '${DateTime.now()}.jpg');
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(bytes);

      // Upload the file to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('user_posts/$id/${DateTime.now()}.jpg');
      final uploadTask = storageRef.putFile(tempFile);
      final snapshot = await uploadTask.whenComplete(() {});

      // Get the download URL of the image
      final imageUrl = await snapshot.ref.getDownloadURL();

      // Add the post to Firestore
      final postRef = FirebaseFirestore.instance.collection('user_posts').doc();
      await postRef.set({
        'postId': postRef.id,
        'userId': id,
        'imageUrl': imageUrl,
        'caption': recognizedText,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Delete the temporary file
      await tempFile.delete();
    }
  }

  void initSpeechToText() async {
    speech = stt.SpeechToText();
    bool isAvailable = await speech!.initialize();

    if (isAvailable) {
      isListening = speech!.isListening;
      notifyListeners();
    } else {
      throw SpeechToTextNotInitializedException();
    }
  }

  void startListening() {
    if (speech != null && !isListening) {
      speech!.listen(
        onResult: (result) {
          if (result.finalResult) {
            recognizedText = result.recognizedWords;
            notifyListeners();
            // After getting the recognized text, you can proceed to upload it as a post
            uploadPost(recognizedText, mediaUrl as String);
          }
        },
      );
      isListening = true;
      print('Started listening');
      notifyListeners();
    }
  }

  void stopListening() {
    if (speech != null && isListening) {
      speech!.stop();
      isListening = false;
      notifyListeners();
    }
  }

  // Functions
  pickImage1({bool camera = false, context}) async {
    try {
      // Set loading to true before starting image picking
      loading = true;
      notifyListeners();

      XFile? xFile = await picker.pickImage(
          source: camera ? ImageSource.camera : ImageSource.gallery);
      PickedFile? pickedFile = xFile != null ? PickedFile(xFile.path) : null;
      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile!.path,
        aspectRatioPresets: [
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio3x2,
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.ratio4x3,
          CropAspectRatioPreset.ratio16x9
        ],
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Constants.lightAccent,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            minimumAspectRatio: 1.0,
          ),
        ],
      );
      mediaUrl = File(croppedFile!.path);

      loading = false;
      notifyListeners();
    } catch (e) {
      loading = false;
      notifyListeners();
      showInSnackBar('Cancelled', context!); // Pass the context here
    }
  }

  getLocation() async {
    loading = true;
    notifyListeners();
    LocationPermission permission = await Geolocator.checkPermission();
    print(permission);
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      LocationPermission rPermission = await Geolocator.requestPermission();
      print(rPermission);
      await getLocation();
    } else {
      position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(
          position!.latitude, position!.longitude);
      placemark = placemarks[0];
      location = " ${placemarks[0].locality}, ${placemarks[0].country}";
      locationTEC.text = location!;
      print(location);
    }
    loading = false;
    notifyListeners();
  }

  Future<Uint8List?> textToImage(String text) async {
    final textStyle = ui.TextStyle(fontSize: 20.0, color: Colors.black);
    final textParagraph = ui.ParagraphBuilder(ui.ParagraphStyle(
      textAlign: TextAlign.left,
      fontSize: 20.0,
    ))
      ..pushStyle(textStyle)
      ..addText(text);
    final textParagraphBuilt = textParagraph.build();
    textParagraphBuilt.layout(ui.ParagraphConstraints(width: 300));

    final image = ui.PictureRecorder();
    final canvas = ui.Canvas(image);
    canvas.drawParagraph(textParagraphBuilt, ui.Offset(0.0, 0.0));
    final recordedImage = image.endRecording();

    final byteData = await recordedImage.toImage(
      textParagraphBuilt.width.toInt(),
      textParagraphBuilt.height.toInt(),
    );
    final pngBytes = await byteData.toByteData(format: ui.ImageByteFormat.png);
    return pngBytes?.buffer.asUint8List();
  }

  uploadPosts(String? recognizedText) async {
    if (recognizedText != null) {
      Uint8List? imageBytes = await textToImage(recognizedText);
      if (imageBytes != null) {
        final id = firebaseAuth.currentUser!.uid;
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_posts/$id/${DateTime.now().toString()}.jpg');

        final uploadTask = storageRef.putData(imageBytes);
        final snapshot = await uploadTask.whenComplete(() {});

        // Get the download URL of the image
        final imageUrl = await snapshot.ref.getDownloadURL();

        // Add the post to Firestore
        final postRef =
            FirebaseFirestore.instance.collection('user_posts').doc();
        await postRef.set({
          'postId': postRef.id,
          'userId': id,
          'imageUrl': imageUrl,
          'caption': recognizedText,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  uploadProfilePicture(BuildContext context) async {
    if (mediaUrl == null) {
      showInSnackBar('Please select an image', context);
    } else {
      try {
        loading = true;
        notifyListeners();
        await postService.uploadProfilePicture(
            mediaUrl!, firebaseAuth.currentUser!);
        loading = false;
        Navigator.of(context)
            .pushReplacement(CupertinoPageRoute(builder: (_) => TabScreen()));
        notifyListeners();
      } catch (e) {
        print(e);
        loading = false;
        showInSnackBar('Uploaded successfully!', context);
        notifyListeners();
      }
    }
  }

  resetPost() {
    mediaUrl = null;
    location = null;
    recognizedText = '';
    notifyListeners();
  }

  void buildTextField(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        String commentData = '';

        return AlertDialog(
          title: Text('Type Your Post'),
          content: Container(
            width: double.maxFinite, // Set the width of the content container
            child: TextField(
              maxLines: null, // Allow the text field to expand vertically
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
              onPressed: () {
                // Handle the post creation with the commentData
                print('Post created: $commentData');
                uploadPost(
                    commentData,
                    mediaUrl
                        as String); // Call the uploadPost function with the commentData
                Navigator.pop(context);
              },
              child: Text('Post',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            TextButton(
                onPressed: () {
                  // Handle the post creation with the commentData
                  print('Post created: $commentData');
                  Navigator.pop(context);
                },
                child: Text(
                  'Upload',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold),
                )),
          ],
        );
      },
    );
  }

  Future<void> showInSnackBar(String value, BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
