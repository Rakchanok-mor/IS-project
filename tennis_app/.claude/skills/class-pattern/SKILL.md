---
name: class-pattern
description: Coding conventions for tennis_app, based on the IS767 Flutter course patterns (model / service / controller / page + Provider). Use whenever creating or editing any Dart file in lib/ — pages, models, services, controllers, components — or adding a new feature/screen to this app.
---

# IS767 Class Pattern (tennis_app)

โปรเจคนี้ต้องเขียนตามแบบที่อาจารย์สอนในวิชา IS767 (ตัวอย่างต้นฉบับ: `first_app` ของอาจารย์)
ต่างจากในห้องแค่ **ใช้ Supabase แทน Firebase** — โครงสร้างคลาสเหมือนเดิมทุกอย่าง

ตัวอย่างโค้ดต้นฉบับของอาจารย์อยู่ที่ `examples/teacher/` ในโฟลเดอร์ skill นี้
ตัวอย่างที่แปลงเป็น Supabase แล้วในโปรเจค: `lib/models/listing_model.dart`,
`lib/services/listing_service.dart`, `lib/controller/listing_controller.dart`,
`lib/pages/12_myListingsPage.dart`

## โครงสร้างโฟลเดอร์ (lecture 04 Refactoring + lecture 10: models / services / controllers / UI)

| โฟลเดอร์ | ใส่อะไร | ชื่อไฟล์ |
|---|---|---|
| `lib/models/` | data class + `fromJson`, และ `ChangeNotifier` สำหรับ app state | `xxx_model.dart` |
| `lib/services/` | `abstract class XxxService` + `XxxSupabaseService implements XxxService` — ที่เดียวที่คุยกับ Supabase | `xxx_service.dart` |
| `lib/controller/` | `XxxController` ตัวกลางระหว่างหน้าจอกับ service + `onSync` stream | `xxx_controller.dart` |
| `lib/pages/` | หน้าจอ (Scaffold) | `NN_camelCasePage.dart` เลขเรียงต่อจากเลขสุดท้าย, `99_blankpage.dart` = แม่แบบ |
| `lib/components/` | widget ที่ใช้ซ้ำ | `snake_case.dart` |

import แบบ package เสมอ: `import 'package:tennis_app/...';`

## 0. Widget พื้นฐาน (lecture 02)

- ไม่มี state เปลี่ยน → `StatelessWidget`; มีข้อมูลที่เปลี่ยนระหว่างใช้งาน (ฟอร์ม, ตัวเลือก, list ที่โหลด) → `StatefulWidget` + `State` class ชื่อ `_XxxState`
- constructor มี `{super.key}` และใส่ `const` ได้เมื่อทำได้ (`const XxxPage({super.key});`, `const Text('...')`, `const EdgeInsets.all(8.0)`) — อาจารย์บอก "ควรกำหนด const เสมอ" และไม่ใช้ `new`
- เปลี่ยนค่าที่ต้องวาดจอใหม่ → ใส่ใน `setState(() { ... });` เท่านั้น
- ค่าเริ่มต้น / โหลดข้อมูลครั้งแรก → `initState()` (เรียก `super.initState()` ก่อน)
- รูปในโปรเจค → วางใน `assets/images/` แล้วประกาศใน `pubspec.yaml` ใต้ `flutter: assets:` แล้วใช้ `Image.asset(...)`; รูปจากเน็ต → `Image.network(...)`; จำกัดขนาดด้วย `SizedBox` / `Container`
- จัดเรียงด้วย `Row` / `Column` + `mainAxisAlignment` / `crossAxisAlignment`

## 1. Model (lecture 10, 11)

```dart
class Post {
  String id;
  String title;
  int views;
  bool isRead;

  Post(this.id, this.title, this.views, this.isRead);   // positional constructor

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      json['id'].toString(),
      json['title'] as String,
      json['views'] as int? ?? 0,          // ค่าที่อาจไม่มี: `as T? ?? default`
      json['isRead'] as bool? ?? false,
    );
  }
}

class AllPosts {                          // คลาสห่อ list เสมอ
  final List<Post> posts;
  AllPosts(this.posts);

  factory AllPosts.fromJson(List<dynamic> json) {
    List<Post> posts;
    posts = json.map((item) => Post.fromJson(item)).toList();
    return AllPosts(posts);
  }
}
```
- ฟิลด์เสริมใส่เป็น named optional หลัง positional ได้ (ดู `Listing`)
- ค่าคงที่ของ model (สถานะ, ชื่อกีฬา) ประกาศเป็น `const String kXxx` ไว้บนไฟล์ model

## 2. Service (lecture 10, 11)

```dart
abstract class PostService {
  Future<List<Post>> getPosts();
  Future<void> updatePost(Post post);
}

class PostSupabaseService implements PostService {
  @override
  Future<List<Post>> getPosts() async {
    final data = await Supabase.instance.client.from('posts').select();
    AllPosts all = AllPosts.fromJson(data);
    return all.posts;
  }
  ...
}
```
- หน้าจอ / controller ห้ามเรียก `Supabase.instance.client.from(...)` เอง ต้องผ่าน service
- ตั้งชื่อคลาส implement ว่า `XxxSupabaseService` (แบบ `PostFirebaseService` / `PostHttpService`)

## 3. Controller (lecture 08 Stream + lecture 10)

```dart
class PostController {
  List<Post> posts = List.empty();
  final PostService service;

  StreamController<bool> onSyncController = StreamController();
  Stream<bool> get onSync => onSyncController.stream;

  PostController(this.service);

  Future<List<Post>> fetchPosts() async {
    onSyncController.add(true);
    try {
      posts = await service.getPosts();
    } finally {
      onSyncController.add(false);     // ส่วนที่โปรเจคเพิ่ม: finally กันวงโหลดค้าง
    }
    return posts;
  }

  void dispose() {
    onSyncController.close();
  }
}
```

## 4. Page (lecture 10 SeventhPage / 06_postpage)

```dart
class PostPage extends StatefulWidget {
  const PostPage({super.key});

  @override
  State<PostPage> createState() => _PostPageState();
}

class _PostPageState extends State<PostPage> {
  PostController controller = PostController(PostSupabaseService());
  StreamSubscription<bool>? _syncSubscription;
  List<Post> posts = List.empty();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _syncSubscription = controller.onSync.listen((bool syncState) {
      if (!mounted) return;
      setState(() {
        isLoading = syncState;
      });
    });
    _getPosts();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  Future<void> _getPosts() async {
    try {
      await controller.fetchPosts();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('โหลดข้อมูลไม่สำเร็จ ลองใหม่อีกครั้ง')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      posts = controller.posts;
    });
  }

  Widget get body => isLoading
      ? const CircularProgressIndicator()
      : ListView.builder(...);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('...')),
      body: Center(child: body),
    );
  }
}
```
- ข้อมูลเฉพาะหน้า (ephemeral state) → ตัวแปรใน State + `setState`
- เช็ก `if (!mounted) return;` ทุกครั้งหลัง `await` ก่อนใช้ `context` / `setState`
- แจ้งผลผู้ใช้ด้วย `ScaffoldMessenger.of(context).showSnackBar(...)` ข้อความภาษาไทย (ต้องให้ผู้ใช้ตอบได้ → ใส่ `SnackBarAction`)

### โครงหน้าจอ (lecture 03)

- ทุกหน้า = `Scaffold` ประกอบจาก `appBar`, `body`, และถ้าต้องใช้ `floatingActionButton`, `bottomNavigationBar`, `drawer`
- ปุ่มบน AppBar → `actions: [IconButton(icon: ..., tooltip: ..., onPressed: ...)]`
- หน้าที่อยู่ในแท็บของ `HomePage` ไม่ต้องมี `Scaffold` ของตัวเอง (ดู `12_myListingsPage.dart`)
- สี / ตัวอักษร: ใช้ `Theme.of(context).colorScheme...` และ `Theme.of(context).textTheme...` หรือค่าคงที่ใน `app_colors.dart`; ตั้ง theme รวมไว้ที่ `ThemeData` ใน `main.dart` ที่เดียว ไม่ตั้งสีซ้ำทุกหน้า
- ขนาดจอ → `MediaQuery.sizeOf(context)`
- list ข้อมูลที่ไม่รู้จำนวนล่วงหน้า → `ListView.builder(itemCount: ..., itemBuilder: ...)` (ไม่ใช่ `ListView(children: [...])`); ข้อมูลว่างให้แสดงข้อความแทน (แบบ `posts.isNotEmpty ? posts.length : 1` ใน 06_postpage)
- เมนูหลายคอลัมน์ → `GridView.count(crossAxisCount: 2, children: List.generate(...))`

## 5. App state ด้วย Provider (lecture 07)

```dart
class LoginModel extends ChangeNotifier {
  String _username = '';

  String get username => _username;

  set username(String value) {
    _username = value;
    notifyListeners();
  }
}
```
- ใช้เฉพาะข้อมูลที่หลายหน้าต้องใช้ร่วม (login, โหมดซื้อ/ขาย, กีฬาที่เลือก) — ดู `HomeModel`
- ลงทะเบียนใน `MultiProvider` ของ `main.dart`
- อ่านค่าครั้งเดียว / ใน callback → `context.read<T>()`; ต้องการให้ rebuild → `context.watch<T>()` หรือ `Consumer<T>`
- private field `_x` + getter/setter ที่เรียก `notifyListeners()` (มี type ชัดเจน)

## 6. Routing (lecture 06)

- ใช้ dynamic routing: `Navigator.push(context, MaterialPageRoute(builder: (context) => XxxPage(data: ...)))`
- ส่งข้อมูลเข้าหน้าใหม่ผ่าน constructor (`required this.listing`)
- รับค่ากลับ: `final result = await Navigator.push(...)` + `Navigator.pop(context, value)` (onPressed ต้องเป็น `async`)
- Navigator เป็น stack: ระวังสร้างหน้าเดียวกันซ้อนหลายชั้น — หน้าผลลัพธ์ (success) ใช้ `pushReplacement` / กลับหน้าแรกด้วย `popUntil((route) => route.isFirst)`
- เข้าแอปผ่าน `AuthGate` — ห้ามเพิ่ม MaterialApp ตัวที่สอง

## 7. Form และ Gesture (lecture 04, 05, 03_formpage)

- หน้าฟอร์มเป็น `StatefulWidget` เสมอ (ค่าที่กรอกต้องอยู่รอดตอน repaint)
- `final _formKey = GlobalKey<FormState>();` + `Form(key: _formKey, ...)` + `TextFormField` มี `decoration: InputDecoration(labelText, hintText, icon, border)`, `validator`, `onSaved`
- กดปุ่มส่ง:
  ```dart
  if (!_formKey.currentState!.validate()) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ข้อมูลไม่ถูกต้อง')),
    );
    return;
  }
  _formKey.currentState!.save();
  // ส่งข้อมูลผ่าน controller / service
  ```
- ฟังก์ชัน validate แยกเป็นเมธอด `String? _validateXxx(String fieldName, String? value, ...)` แล้วเรียก `validator: (value) => _validateXxx('ชื่อ', value, 2)`
- `onSaved` = เก็บค่าลงตัวแปรเฉย ๆ (ไม่ repaint); `onChanged` = อยากให้จอเปลี่ยนทันทีที่พิมพ์ → ต้องเรียก `setState`
- ต้องตั้งค่าเริ่มต้น / อ่านค่าเองระหว่างพิมพ์ → `TextEditingController` ประกาศเป็น field, ใส่ `controller:` ใน TextFormField และ **`dispose()` ทุกตัว** ใน `dispose()` ของ State
- แตะ / กดค้าง widget ที่ไม่ใช่ปุ่ม → ห่อด้วย `GestureDetector` (`onTap`, `onDoubleTap`, `onLongPress`) หรือ `InkWell` ถ้าอยากได้ ripple
- เลือก on/off → `SwitchListTile` / `CheckboxListTile` คู่กับตัวแปร `bool` ใน State + `setState` ใน `onChanged`
- เลือก 1 จากหลายตัว → Radio ทำเป็น component (`ChoiceCard` + `ChoiceRadio` + `ChoiceData` ใน `examples/teacher/choicecard.dart`) ใช้ `[Text(title), ...List.generate(...)]` (spread operator ตามฉบับ 05_Fix); Flutter รุ่นที่โปรเจคใช้ `groupValue`/`onChanged` บน `Radio` ถูก deprecate แล้ว ให้ห่อด้วย `RadioGroup<int>(groupValue: ..., onChanged: ..., child: ...)` ตาม "Radio API redesign" ที่อาจารย์อ้างถึง

## 7.1 Authentication (lecture 13 — ในโปรเจคใช้ Supabase Auth แทน FirebaseAuth)

| ในห้อง (FirebaseAuth) | ในโปรเจค (Supabase) |
|---|---|
| `FirebaseAuth.instance.authStateChanges()` | `Supabase.instance.client.auth.onAuthStateChange` |
| `signInWithEmailAndPassword` | `auth.signInWithPassword(email:, password:)` |
| `createUserWithEmailAndPassword` | `auth.signUp(email:, password:)` |
| `FirebaseAuth.instance.currentUser?.uid` | `auth.currentUser?.id` |
| `on FirebaseAuthException catch (e)` + `e.code` | `on AuthException catch (e)` + `e.code` |
| `signOut()` | `auth.signOut()` |

- สลับหน้าตามสถานะล็อกอินด้วย `StreamBuilder` ฟัง auth stream ใน `AuthGate` (observer pattern แบบในห้อง) — ไม่ต้อง push ไปหน้า home เองหลังล็อกอินสำเร็จ
- ครอบ sign in / sign up ด้วย `try { ... } on AuthException catch (e) { ... }` แล้วแปลง `e.code` เป็นข้อความที่ผู้ใช้อ่านเข้าใจ ด้วยเมธอดแยก (ดู `_loginErrorMessage` ใน `04_loginPage.dart`)

## 8. Component (lecture 03, 06 NameCard / choicecard)

```dart
class NameCard extends StatelessWidget {
  const NameCard({super.key, required this.data, required this.onTap});

  final NameCardData data;
  final VoidCallback onTap;
  ...
}
```
- StatelessWidget, รับข้อมูลผ่าน `required this.x`, ส่ง event กลับด้วย callback (`VoidCallback`, `ValueChanged<T>`)
- ข้อมูลหลายตัวรวมเป็นคลาส `XxxData` แบบ `const` constructor (แบบ `ChoiceData`)
- สีใช้ค่าคงที่จาก `lib/components/app_colors.dart` (`kBuyerColor`, `kSellerColor`, `kPageColor` ...) ห้ามเขียนสีใหม่กระจัดกระจาย

## 9. Async (lecture 08)

- ใช้ `async` / `await` + `try` / `catch` เป็นหลัก (ไม่ต่อ `.then()` ยาว ๆ)
- ฟังก์ชันที่ `await` ต้องประกาศ `async` และคืน `Future<T>`; อย่าลืม `await` ไม่งั้นจะได้ `Instance of Future` แทนค่า
- `Future.wait([...])` เมื่อเรียกหลายอย่างพร้อมกันที่ไม่ขึ้นต่อกัน
- เหตุการณ์ที่เกิดหลายครั้ง → `StreamController` (sink) + `.stream` + `.listen` (subscriber); มีผู้ฟังหลายตัว → `StreamController.broadcast()`; UI ที่วาดตาม stream → `StreamBuilder`

## 9.1 Supabase query (เทียบ lecture 11–12 Firestore)

| Firestore ในห้อง | Supabase ในโปรเจค |
|---|---|
| `collection('posts').get()` | `.from('posts').select()` |
| `.add(data)` / `.doc().set(data)` | `.insert(data)` (ต้องการ id กลับ → `.select().single()`) |
| `.doc(id).update({...})` | `.update({...}).eq('id', id)` |
| `.doc(id).delete()` | `.delete().eq('id', id)` |
| `.where('isRead', isEqualTo: false)` | `.eq('is_read', false)` (และ `.neq`, `.gte`, `.inFilter`, `.or(...)`) |
| `FieldValue.serverTimestamp()` | ให้ฐานข้อมูลตั้ง `default now()` หรือส่ง `DateTime.now().toUtc().toIso8601String()` |

- ทุก query อยู่ใน service class เท่านั้น ห่อด้วย `try/catch` ฝั่งหน้าจอ (หรือปล่อยให้ controller โยนต่อ)
- ตาราง / คอลัมน์ใหม่ต้องเพิ่มใน `supabase/schema.sql` ด้วย

## สไตล์ทั่วไป

- คอมเมนต์ภาษาไทย สั้น ๆ อธิบายว่า "ทำไม" เหนือคลาส / เมธอด
- ข้อความ UI ภาษาไทย
- เขียนให้อ่านง่ายระดับที่เรียนในห้อง — ไม่ใช้ package state management อื่น (Bloc, Riverpod, GetX), ไม่ใช้ code generation (json_serializable, freezed), ไม่ใช้ go_router
- เพิ่ม package ใหม่เฉพาะเมื่อจำเป็นจริง และบอกผู้ใช้ก่อน

## Checklist ก่อนส่งงาน

1. ฟีเจอร์ใหม่ครบชุด model → service (abstract + Supabase) → controller → page หรือยัง
2. หน้าจอไม่เรียก Supabase ตรง
3. มี `dispose()` ปิด subscription / controller / `TextEditingController`
4. เช็ก `mounted` หลัง `await`
5. ไฟล์หน้าใหม่ตั้งชื่อ `NN_camelCasePage.dart` เลขต่อจากเดิม
6. รัน `flutter analyze` ผ่าน
