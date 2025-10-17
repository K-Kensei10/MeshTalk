import 'package:flutter/material.dart';
import 'package:anslin/main.dart';
import 'package:flutter/services.dart';

//TEST
final myPhoneNumber = 09012345678;

class SafetyCheckPageState extends State<SafetyCheckPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  static const methodChannel = MethodChannel('anslin.flutter.dev/contact');
  List<String> receivedMessages = [];


  Future<void> _startCatchMessage() async {
    try {
      final String? rawMessage = await methodChannel.invokeMethod<String>('startCatchMessage');
      if (rawMessage != null && rawMessage.isNotEmpty) {
        final parts = rawMessage.split(';');
        if (parts.length >= 5) {
          final formatted = "電話番号：${parts[3]}, メッセージ：${parts[0]}";
          setState(() {
            receivedMessages.insert(0, "$formatted\n(${DateTime.now()})");
          });
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("メッセージを受信しました")),
          );
        } else {
          debugPrint("メッセージ形式が不正: $rawMessage");
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("メッセージは受信されませんでした")),
        );
      }
    } on PlatformException catch (e) {
      debugPrint("受信エラー: $e");
    }
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

  void _showPostModal() {
    final TextEditingController _modalPhoneController = TextEditingController();
    final TextEditingController _modalMessageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("新しい投稿"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _modalPhoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "宛先（電話番号）",
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modalMessageController,
                maxLength: 50,
                decoration: const InputDecoration(
                  hintText: "メッセージを入力してください (50文字以内)",
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("キャンセル"),
            ),
            ElevatedButton(
              onPressed: () async {
                final phoneNumber = _modalPhoneController.text.replaceAll('-', '');
                final message = _modalMessageController.text;
                if ((phoneNumber.length == 10 || phoneNumber.length == 11) && message.isNotEmpty) {
                  Navigator.of(context).pop(); // ✅ 先に閉じる

                  await methodChannel.invokeMethod<String>(
                    'startSendMessage',
                    [message, myPhoneNumber.toString(), "2", phoneNumber, "150"].join(';'),
                  );

                  _startCatchMessage(); // ✅ 送信後に受信処理
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("有効な宛先とメッセージを入力してください")),
                  );
                }
              },
              child: const Text("送信"),
            ),
          ],
        );
      },
    );
  }


@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("安否確認"),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: "スキャン",
            onPressed: _startCatchMessage,
          ),
        ],
      ),
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
            Expanded(
              child: receivedMessages.isEmpty
                  ? const Center(child: Text("まだメッセージは受信されていません"))
                  : ListView.builder(
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

