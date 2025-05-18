import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ehop_partner/call.dart';
import 'package:ehop_partner/comm/chat_signaling.dart';
import 'package:ehop_partner/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MaterialApp(home: PartnerCommunicationApp()));
}

class PartnerCommunicationApp extends StatelessWidget {
  const PartnerCommunicationApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peer to Peer Audio and Video Call',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ChatPage(),
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  Signaling signaling = Signaling();
  String? roomId;
  TextEditingController textEditingController = TextEditingController(text: '');
  bool _isBodyEnabled = false;

  String? _token = 'Fetching...';

  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];

  @override
  void initState() {
    signaling.onMessageReceived = ((msg) {
      setState(() {
        _messages.add(ChatMessage(msg, false));
      });
    });

    super.initState();
    _initFCM();
  }

  Future<void> _initFCM() async {
    QuerySnapshot<Map<String, dynamic>> querySnapshot =
        await FirebaseFirestore.instance
            .collection('partners')
            .where('emailAddress', isEqualTo: "dhanashri.udar@gmail.com")
            .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();
      if (!data.containsKey('fcmToken')) {
        FirebaseMessaging messaging = FirebaseMessaging.instance;
        String? token = await messaging.getToken();
        print('FCM Token: $token');
        await doc.reference.update({'fcmToken': token});
        print('fcmToken added to Firestore.');
      } else {
        print('fcmToken already exists.');
      }
    } else {
      print('No user found with that email address.');
    }

    // Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.data}');
      String roomId = message.data['roomId'];
      String callerId = message.data['callerId'];
      print('Received room id: ${roomId}');
      signaling.joinRoom(roomId);
      _toggleBody();
    });

    // When app is opened from a terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('App opened from terminated state: ${message.messageId}');
      }
    });

    // When app is opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('App opened from background: ${message.messageId}');
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    signaling.sendMessage(text);
    setState(() {
      _messages.add(ChatMessage(text, true));
      _controller.clear();
    });
  }

  Future<void> _call() async {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const CallInitiatePage()),
    );
  }

  void _toggleBody() {
    setState(() {
      _isBodyEnabled = !_isBodyEnabled;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Demonstrate peer to peer audio & Video all")),
      body: Column(
        children: [
          SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment:
                      msg.isSentByMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    margin: EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: msg.isSentByMe ? Colors.blue : Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(msg.msg),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(onPressed: _sendMessage, child: Text("Send")),
                ElevatedButton(onPressed: _call, child: Text("Call")),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String msg;
  final bool isSentByMe;

  ChatMessage(this.msg, this.isSentByMe);
}
