import 'package:first_app/controller/post_controller.dart';
import 'package:first_app/post_model.dart';
import 'package:first_app/services/post_service.dart';
import 'package:flutter/material.dart';
 
class PostPage extends StatefulWidget {
  const PostPage({super.key});
 
  @override
  State<PostPage> createState() => _PostPageState();
}
 
class _PostPageState extends State<PostPage> {
  List<Post> posts = List.empty();
  bool isLoading = false;
  PostController controller = PostController(PostFirebaseService());
 
  initState() {
    super.initState();
    controller.onSync.listen((bool syncState) {
      setState(() {
        isLoading = syncState;
      });
    });
  }
 
  void _getPosts() async {
    var newPosts = await controller.fetchPosts();
    setState(() {
      posts = newPosts;
    });
  }
 
  Widget get body => isLoading
    ? CircularProgressIndicator()
    : ListView.builder(
      itemCount: posts.isNotEmpty ? posts.length : 1,
      itemBuilder: (context, index) {
        if (posts.isNotEmpty) {
          return CheckboxListTile(
            title: Text(posts[index].title),
            value: posts[index].isRead,
            onChanged: (value) {
              setState(() => posts[index].isRead = value!);
              controller.markAsRead(posts[index]);
            }
          );
        }
 
        return Center(
          child: Text('Press to fetch posts'),
        );
      }
    );
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:  AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Post Page'),
      ),
      body:  Center(
        child: body,
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: _getPosts,
      )
    );
  }
}
 