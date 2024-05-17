import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:front/screen/login.dart';
import 'package:front/screen/post_list.dart';
import 'package:http/http.dart' as http;
import 'package:front/screen/detail_page.dart';
import 'package:get/get.dart';
import 'package:front/model/post.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // 게시물 모델 임포트

// 업데이트랑 삭제 부분 구현 하고 + 아이디값 적용해서 url관리
// 댓글 부분
void main() async {
  await dotenv.load(fileName: ".env");
  runApp(PostDetailPage());
}

class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key});

  @override
  PostDetailPageState createState() => PostDetailPageState();
}

class PostDetailPageState extends State<PostDetailPage> {
  final storage = FlutterSecureStorage();
  String title = "";
  String content = "";
  String username = "";
  String tokenUsername = "";
  List<Map<String, dynamic>> comments = [];

  bool isAuthorVerified(String username, String tokenUsername) {
    // username과 tokenUsername을 비교하여 일치 여부를 확인하고 true 또는 false 반환
    return username == tokenUsername;
  }

  @override
  void initState() {
    super.initState();
    decodeToken();
    fetchPostData(); // initState에서 데이터 가져오기
  }

  Future<void> decodeToken() async {
    String? token = await storage.read(key: 'accessToken');
    Map<String, dynamic> decodedToken = JwtDecoder.decode(token!);
    tokenUsername = decodedToken['username'];
  }

  Future<void> fetchPostData() async {
    String postId = Get.arguments;
    String serverUri = dotenv.env['SERVER_URI']!;
    String postEndpoint = dotenv.env['POST_ENDPOINT']!;
    final response =
        await http.get(Uri.parse('$serverUri$postEndpoint/$postId'));
    if (response.statusCode == 200) {
      // 서버에서 데이터를 성공적으로 받았을 때
      print("success");
      final Map<String, dynamic> data =
          json.decode(utf8.decode(response.bodyBytes));
      setState(() {
        title = data['title'];
        content = data['content'];
        username = data['author']['username'];
        comments = List<Map<String, dynamic>>.from(data['commentDTOList']);
      });
    } else {
      print("fail");
      // 서버로부터 데이터를 받지 못했을 때
      throw Exception('Failed to load post data');
    }
  }

  Future<void> deletePost(String postId) async {
    String? token = await storage.read(key: 'accessToken');
    String serverUri = dotenv.env['SERVER_URI']!;
    String deleteEndpoint = dotenv.env['POST_DELETE_ENDPOINT']!;
    String postId = Get.arguments;

    Map<String, String> headers = {
      'Authorization': '$token', // 토큰 값 추가
    };

    try {
      String deleteUrl = "$serverUri$deleteEndpoint/$postId";

      // HTTP DELETE 요청 보내기
      var response = await http.delete(
        Uri.parse(deleteUrl),
        headers: headers,
      );

      if (response.statusCode == 200) {
        // 삭제 성공 시
        print("게시물 삭제 성공");
        // 이전 화면으로 이동 또는 다른 작업 수행
        Get.off(PostList());
      } else {
        print(postId);
        print(response.statusCode);
        // 삭제 실패 시
        print("게시물 삭제 실패");
        // 실패 메시지를 표시하거나 사용자에게 알림
      }
    } catch (e) {
      print("오류 발생: $e");
      // 오류 처리
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DetailPage',
      home: Scaffold(
        appBar: AppBar(
          title: null,
          leading: IconButton(
            // 왼쪽에 뒤로가기 아이콘 추가
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Get.off(PostList());
              // GET.off 써서 뒤로가기
            },
          ),
          actions: [
            if (isAuthorVerified(username, tokenUsername)) // 저자 확인 함수 호출
              IconButton(
                icon: Icon(Icons.edit),
                onPressed: () {
                  String postId = Get.arguments;
                  print(postId);
                  // 게시물 수정 페이지로 이동
                  Get.to(() => EditPostPage(
                      title: title, content: content, postId: postId));
                },
              ),
            if (isAuthorVerified(username, tokenUsername)) // 저자 확인 함수 호출
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  String postId = Get.arguments;
                  deletePost(postId);
                },
              ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Text(
                content,
                style: TextStyle(fontSize: 18),
              ),
              Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (_, index) {
                    return ListTile(
                      title: Text(
                        comments[index]['author']['username'],
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54),
                      ),
                      subtitle: Text(
                        comments[index]['comment'],
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditPostPage extends StatefulWidget {
  final String title; // 원래 제목
  final String content; // 원래 내용
  final String postId; // id

  EditPostPage({
    Key? key,
    required this.title,
    required this.content,
    required this.postId,
  }) : super(key: key);

  @override
  _EditPostPageState createState() => _EditPostPageState();
}

class _EditPostPageState extends State<EditPostPage> {
  late TextEditingController _posttitleController;
  late TextEditingController _postcontentController;
  String _selectedCategory = 'FREE';

  @override
  void initState() {
    super.initState();
    _posttitleController = TextEditingController(text: widget.title);
    _postcontentController = TextEditingController(text: widget.content);
  }

  @override
  void dispose() {
    _posttitleController.dispose();
    _postcontentController.dispose();
    super.dispose();
  }

  void updatePost(BuildContext context) async {
    print("포스트 아이디");
    print(widget.postId);
    final storage = FlutterSecureStorage();
    String serverUri = dotenv.env['SERVER_URI']!;
    String postUpdateEndpoint =
        dotenv.env['POST_UPDATE_ENDPOINT']!; // 업데이트할 게시물의 URL
    String updateUrl = "$serverUri$postUpdateEndpoint/${widget.postId}";
    String category = _selectedCategory;

    String? token = await storage.read(key: 'accessToken');
    Map<String, String> headers = {
      'Authorization': '$token', // 토큰 값 추가
    };

    String newTitle = _posttitleController.text;
    String newContent = _postcontentController.text;

    try {
      final response = await http.put(
        Uri.parse(updateUrl),
        headers: headers,
        body: {
          'title': newTitle,
          'content': newContent,
          'category': category,
        },
      );

      if (response.statusCode == 200) {
        // 게시물 업데이트가 성공한 경우
        print('게시물이 성공적으로 업데이트되었습니다.');
        Get.off(PostDetailPage(), arguments: widget.postId.toString());
      } else {
        // 게시물 업데이트가 실패한 경우
        print('게시물 업데이트 실패: ${response.statusCode}');
        // 실패 메시지를 사용자에게 보여줄 수 있습니다.
        // 예를 들어 Get 패키지를 사용하여 에러 다이얼로그를 표시할 수 있습니다.
      }
    } catch (e) {
      // 예외 발생 시 처리
      print('게시물 업데이트 중 에러 발생: $e');
      // 예외 처리 로직을 추가할 수 있습니다.
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // 다른 곳을 탭하면 포커스 해제
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('게시물 수정'),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              Get.back();
            },
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.send),
              onPressed: () {
                updatePost(context);
              },
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _posttitleController,
                decoration: InputDecoration(
                  labelText: '제목',
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w300,
                    color: Colors.blue.shade200,
                  ),
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue.shade200),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue.shade200),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile(
                      title: Text('자유게시판'),
                      value: 'FREE',
                      groupValue: _selectedCategory,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                          print(_selectedCategory);
                        });
                      },
                      activeColor: Colors.blue.shade200,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile(
                      title: Text('계획게시판'),
                      value: 'PLAN',
                      groupValue: _selectedCategory,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategory = value!;
                          print(_selectedCategory);
                        });
                      },
                      activeColor: Colors.blue.shade200,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.0),
              TextFormField(
                controller: _postcontentController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: '내용',
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w300,
                    color: Colors.blue.shade200,
                  ),
                  border: InputBorder.none,
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
