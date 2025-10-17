import 'package:flutter/material.dart';
import 'package:anslin/main.dart';
import 'package:flutter/services.dart';

//TEST
final myPhoneNumber = 09012345678;

class SafetyCheckPageState extends State<SafetyCheckPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      setState(() {
        _charCount = _messageController.text.length;
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  //[message,  to_phone_number,  message_type,  from_phone_number,  TTL]
  Future<void> _startSendMessage(
    String message,
    String toPhoneNumber,
    String messageType,
    String myphoneNumber,
    String tll,
  ) async {
    List<String> messageList = [
      message,
      toPhoneNumber,
      messageType,
      myphoneNumber,
      tll,
    ];
    String messageData = messageList.join(';');

    try {
      final String? receivedMessage = await methodChannel.invokeMethod<String>(
        'startSendMessage',
        messageData,
      );

      if (receivedMessage != null) {
        debugPrint("受信メッセージ: $receivedMessage");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("メッセージを送信しました")),
        );

        // 例：画面に表示するリストに追加
        setState(() {
          receivedMessages.insert(0, receivedMessage);
        });
      } else {
        debugPrint("メッセージは受信されませんでした");
        ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("メッセージは受信されませんでした")));
      }
    } on PlatformException catch (e) {
      debugPrint("送信エラー: $e");
    }
  }


  void _sendMessage() {
    final phoneNumber = _phoneController.text.replaceAll('-', '');
    final message = _messageController.text;
    if ( (phoneNumber.length == 10 || phoneNumber.length == 11) &&
        _messageController.text.isNotEmpty) {
      // 実際はBluetooth経由でメッセージを送信
      _phoneController.clear();
      _messageController.clear();
      _startSendMessage(message, myPhoneNumber.toString(), "2", phoneNumber.toString(), "150");
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("有効な宛先とメッセージを入力してください")));
    }
  }

  void _showPostModal() {
    showDialog(
      context: context,
      builder: (context) {
        String postText = "";
        return AlertDialog(
          title: const Text("新しい投稿"),
          content: TextField(
            maxLength: 50,
            decoration: const InputDecoration(
              hintText: "メッセージを入力してください (50文字以内)",
            ),
            onChanged: (text) {
              postText = text;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (postText.isNotEmpty) {
                  final phoneNumber = _phoneController.text.replaceAll('-', '');
                  final message = postText;
                  if (phoneNumber.length == 10 || phoneNumber.length == 11) {
                    final result = await methodChannel.invokeMethod<String>(
                      'startSendMessage',
                      [message, myPhoneNumber.toString(), "2", phoneNumber, "150"].join(';'),
                    );
                    setState(() {
                      receivedMessages.insert(0, result ?? "メッセージを受信できませんでした");
                    });
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("有効な宛先を入力してください")),
                    );
                  }
                }
              },
              child: const Text("送信"),
            ),
          ],
        );
      },
    );
  }

List<String> receivedMessages = [];

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text("安否確認")),
    floatingActionButton: FloatingActionButton(
      onPressed: _showPostModal,
      tooltip: '新しい投稿',
      child: const Icon(Icons.add),
    ),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            "メッセージは暗号化され、中継者には見えません",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: "宛先（電話番号）",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: receivedMessages.length,
              itemBuilder: (context, index) {
                return Card(
                  child: ListTile(
                    title: Text(receivedMessages[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
}
