import 'dart:async';

import 'package:first_app/post_model.dart';
import 'package:first_app/services/post_service.dart';

class PostController {
  List<Post> posts = List.empty();
  final PostService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  PostController(this.service);


  Future<void> markAsRead(Post post) async {
    onSyncController.add(true);
    await service.updatePost(post);
    onSyncController.add(false);
  }


  Future<List<Post>> fetchPosts() async {
    onSyncController.add(true);
    posts = await service.getPosts();
    onSyncController.add(false);
    return posts;
  }
}
