import 'package:cloud_firestore/cloud_firestore.dart';

class UserPost {
  String? caption;
  String? imageUrl;
  String? postId;
  String? userId;
  Timestamp? timestamp;


  UserPost({
    this.caption,
    this.imageUrl,
    this.postId,
    this.userId,
    this.timestamp,
  });
  UserPost.fromJson(Map<String, dynamic> json) {
    caption = json['caption'];
    imageUrl = json['imageUrl'];
    userId = json['userId'];
    postId = json['postId'];
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['caption'] = this.caption;
    data['imageUrl'] = this.imageUrl;
    data['postId'] = this.postId;
    data['userId'] = this.userId;
    data['timestamp'] = this.timestamp;
    return data;
  }
}
