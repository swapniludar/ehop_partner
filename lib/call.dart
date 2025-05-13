import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ehop_partner/comm/signaling.dart';
import 'package:ehop_partner/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peer to Peer Audio and Video Call',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  MyHomePageState createState() => MyHomePageState();
}

class MyHomePageState extends State<MyHomePage> {
  Signaling signaling = Signaling();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  String? roomId;
  TextEditingController textEditingController = TextEditingController(text: '');

  String? _token = 'Fetching...';

  @override
  void initState() {
    _localRenderer.initialize();
    _remoteRenderer.initialize();

    signaling.onAddRemoteStream = ((stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
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
      print('Foreground message: ${message.notification?.title}');
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
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Demonstrate peer to peer audio & Video all")),
      body: Column(
        children: [
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  signaling.openUserMedia(_localRenderer, _remoteRenderer);
                },
                child: Text("Open camera & microphone"),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // Add roomId
                  signaling.joinRoom(
                    textEditingController.text.trim(),
                    _remoteRenderer,
                  );
                },
                child: Text("Join room"),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  signaling.hangUp(_localRenderer);
                },
                child: Text("Hangup"),
              ),
            ],
          ),
          SizedBox(height: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(child: RTCVideoView(_localRenderer, mirror: true)),
                  Expanded(child: RTCVideoView(_remoteRenderer)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Join the following Room: "),
                Flexible(
                  child: TextFormField(controller: textEditingController),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }
}
