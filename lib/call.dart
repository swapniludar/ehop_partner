import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ehop_partner/comm/signaling.dart';
import 'package:synchronized/synchronized.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallInitiatePage extends StatefulWidget {
  final String roomId;

  const CallInitiatePage({super.key, required this.roomId});

  @override
  CallInitiatePageState createState() => CallInitiatePageState();
}

class CallInitiatePageState extends State<CallInitiatePage> {
  Signaling signaling = Signaling();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  String? roomId;
  bool callJoined = false;
  TextEditingController textEditingController = TextEditingController(text: '');
  final _lock = Lock();

  @override
  void initState() {
    _localRenderer.initialize();
    _remoteRenderer.initialize();

    _localRenderer.onFirstFrameRendered = () async {
      await _lock.synchronized(() async {
        print('Received room id $roomId in onFirstFrameRendered');
        if (callJoined) {
          print("Call already joined");
        } else {
          signaling.joinRoom(roomId!, _remoteRenderer);
          callJoined = true;
          print("Call joined");
        }
      });
    };

    _localRenderer.onResize = () async {
      await _lock.synchronized(() async {
        print('Received room id $roomId in onResize');
        if (callJoined) {
          print("Call already joined");
        } else {
          if (_localRenderer.videoWidth > 0 && _localRenderer.videoHeight > 0) {
            print("✅ First frame likely rendered (via onResize)");
            signaling.joinRoom(roomId!, _remoteRenderer);
            callJoined = true;
            print("Call joined");
          }
        }
      });
    };

    signaling.onAddRemoteStream = ((stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
    });

    super.initState();
    _initRoomIdFromWidgetAndOpenUserMedia();
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
      String callerId = message.data['callerId'];
      print('Received room id: ${roomId}');
      // signaling.openUserMedia(_localRenderer, _remoteRenderer);
      // setState(() {
      //   roomId = message.data['roomId'];
      // });
      _initRoomIdFromFCMAndOpenUserMedia(message.data['roomId']);
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

  _initRoomIdFromWidgetAndOpenUserMedia() async {
    await _lock.synchronized(() async {
      if (roomId == null && widget.roomId.isNotEmpty) {
        signaling.openUserMedia(_localRenderer, _remoteRenderer);
        setState(() {
          roomId = widget.roomId;
        });
      }
    });
  }

  _initRoomIdFromFCMAndOpenUserMedia(String roomIdFromFCM) async {
    await _lock.synchronized(() async {
      if (roomId == null && widget.roomId.isEmpty) {
        signaling.openUserMedia(_localRenderer, _remoteRenderer);
        setState(() {
          roomId = roomIdFromFCM;
        });
      }
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
        ],
      ),
    );
  }
}
