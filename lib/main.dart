import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission/permission.dart';
import 'package:stringee_flutter_plugin/stringee_flutter_plugin.dart';

import 'call.dart';

/// UserID: usercall
String token1 =
    "eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS1hFaTlVbDhxQjNHWDlqVGVCWDNjQjVGOFE3VklGQWN4LTE2MTg1NTgxOTAiLCJpc3MiOiJTS1hFaTlVbDhxQjNHWDlqVGVCWDNjQjVGOFE3VklGQWN4IiwiZXhwIjoxNjIxMTUwMTkwLCJ1c2VySWQiOiJ1c2VyY2FsbCJ9.x4r205URStDGL7YH0K72eAHbUPhdg3uZ4NovkwTLnSY";

/// UserID: userlisten
String token =
    "eyJjdHkiOiJzdHJpbmdlZS1hcGk7dj0xIiwidHlwIjoiSldUIiwiYWxnIjoiSFMyNTYifQ.eyJqdGkiOiJTS1hFaTlVbDhxQjNHWDlqVGVCWDNjQjVGOFE3VklGQWN4LTE2MTg1NTgyNTgiLCJpc3MiOiJTS1hFaTlVbDhxQjNHWDlqVGVCWDNjQjVGOFE3VklGQWN4IiwiZXhwIjoxNjIxMTUwMjU4LCJ1c2VySWQiOiJ1c2VybGlzdGVuIn0.F6DTNVYtwVAG3LZTcST2l-syMK9PpI086Ylqg-hPkHY";

StringeeClient _client = StringeeClient();
StringeeCall _call;
StringeeCall2 _call2;

FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();
bool _showIncomingCall = false;

String strUserId = "";

Future<void> _backgroundMessageHandler(RemoteMessage remoteMessage) async {
  print("Handling a background message: ${remoteMessage.data}");

  Map<dynamic, dynamic> _notiData = remoteMessage.data;
  Map<dynamic, dynamic> _data = json.decode(_notiData['data']);

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@drawable/ic_noti');
  final IOSInitializationSettings iOSSettings = IOSInitializationSettings();
  final MacOSInitializationSettings macOSSettings =
      MacOSInitializationSettings();
  final InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings, iOS: iOSSettings, macOS: macOSSettings);
  await _localNotifications
      .initialize(
    initializationSettings,
    onSelectNotification: null,
  )
      .then((value) async {
    if (value) {
      if (_data['callStatus'] == 'started') {
        /// Create channel for notification
        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'your channel id',
          'your channel name',
          'your channel description',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,

          /// Set true for show App in lockScreen
        );
        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);

        /// Show notification
        await _localNotifications.show(
          0,
          'Incoming Call',
          'from ' + _data['from']['alias'],
          platformChannelSpecifics,
        );
      } else if (_data['callStatus'] == 'ended') {
        _localNotifications.cancel(0);
      }
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid)
    Firebase.initializeApp().whenComplete(() {
      print("completed");
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
    });

  runApp(new MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(title: "OneToOneCallSample", home: new MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  String myUserId = 'Not connected...';
  bool isAppInBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _localNotifications.cancel(0);
      isAppInBackground = false;
    } else if (state == AppLifecycleState.inactive) {
      isAppInBackground = true;
    }

    if (state == AppLifecycleState.resumed && _client != null) {
      if (_client.hasConnected && _showIncomingCall && Platform.isAndroid) {
        showCallScreen(_call, _call2);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<void> initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (Platform.isAndroid) {
      requestPermissions();
    }

    /// Lắng nghe sự kiện của StringeeClient(kết nối, cuộc gọi đến...)
    _client.eventStreamController.stream.listen((event) {
      Map<dynamic, dynamic> map = event;
      switch (map['eventType']) {
        case StringeeClientEvents.didConnect:
          handleDidConnectEvent();
          break;
        case StringeeClientEvents.didDisconnect:
          handleDiddisconnectEvent();
          break;
        case StringeeClientEvents.didFailWithError:
          handleDidFailWithErrorEvent(
              map['body']['code'], map['body']['message']);
          break;
        case StringeeClientEvents.requestAccessToken:
          handleRequestAccessTokenEvent();
          break;
        case StringeeClientEvents.didReceiveCustomMessage:
          handleDidReceiveCustomMessageEvent(map['body']);
          break;
        case StringeeClientEvents.incomingCall:
          StringeeCall call = map['body'];
          handleIncomingCallEvent(call);
          break;
        case StringeeClientEvents.incomingCall2:
          StringeeCall2 call = map['body'];
          handleIncomingCall2Event(call);
          break;
        case StringeeClientEvents.didReceiveObjectChange:
          StringeeObjectChange objectChange = map['body'];
          print(objectChange.objectType.toString() +
              '\t' +
              objectChange.type.toString());
          print(objectChange.objects.toString());
          break;
        default:
          break;
      }
    });

    /// Connect
    _client.connect(token);
  }

  requestPermissions() async {
    List<PermissionName> permissionNames = [];
    permissionNames.add(PermissionName.Camera);
    permissionNames.add(PermissionName.Contacts);
    permissionNames.add(PermissionName.Microphone);
    permissionNames.add(PermissionName.Location);
    permissionNames.add(PermissionName.Storage);
    permissionNames.add(PermissionName.State);
    permissionNames.add(PermissionName.Internet);
    var permissions = await Permission.requestPermissions(permissionNames);
    permissions.forEach((permission) {});
  }

  @override
  Widget build(BuildContext context) {
    Widget topText = new Container(
      padding: EdgeInsets.only(left: 10.0, top: 10.0),
      child: new Text(
        'Connected as: $myUserId',
        style: new TextStyle(
          color: Colors.black,
          fontSize: 20.0,
        ),
      ),
    );

    return new Scaffold(
      appBar: new AppBar(
        title: new Text("OneToOneCallSample"),
        backgroundColor: Colors.indigo[600],
      ),
      body: new Stack(
        children: <Widget>[topText, new MyForm()],
      ),
    );
  }

  //region Handle Client Event
  void handleDidConnectEvent() {
    if (Platform.isAndroid) {
      Stream<String> tokenRefreshStream =
          FirebaseMessaging.instance.onTokenRefresh;
      tokenRefreshStream.listen((token) {
        _client
            .registerPush(token)
            .then((value) => print('Register push ' + value['message']));
      });
      _client
          .unregisterPush('deviceToken')
          .then((value) => print('Unregister push ' + value['message']));
      FirebaseMessaging.instance.getToken().then((token) {
        _client
            .registerPush(token)
            .then((value) => print('Register push ' + value['message']));
      });
    }

    setState(() {
      myUserId = _client.userId;
    });
  }

  void handleDiddisconnectEvent() {
    setState(() {
      myUserId = 'Not connected';
    });
  }

  void handleDidFailWithErrorEvent(int code, String message) {
    print('code: ' + code.toString() + '\nmessage: ' + message);
  }

  void handleRequestAccessTokenEvent() {
    print('Request new access token');
  }

  void handleDidReceiveCustomMessageEvent(Map<dynamic, dynamic> map) {
    print('from: ' + map['fromUserId'] + '\nmessage: ' + map['message']);
  }

  void handleIncomingCallEvent(StringeeCall call) {
    if (!isAppInBackground || !Platform.isAndroid) {
      showCallScreen(call, null);
    } else {
      _showIncomingCall = true;
      _call = call;
    }
  }

  void handleIncomingCall2Event(StringeeCall2 call) {
    if (!isAppInBackground || !Platform.isAndroid) {
      showCallScreen(null, call);
    } else {
      _showIncomingCall = true;
      _call2 = call;
    }
  }

  void showCallScreen(StringeeCall call, StringeeCall2 call2) {
    _showIncomingCall = false;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Call(
          fromUserId: call != null ? call.from : call2.from,
          toUserId: call != null ? call.to : call2.to,
          isVideoCall: call != null ? call.isVideoCall : call2.isVideoCall,
          callType: call != null
              ? StringeeObjectEventType.call
              : StringeeObjectEventType.call2,
          showIncomingUi: true,
          incomingCall2: call != null ? null : call2,
          incomingCall: call != null ? call : null,
        ),
      ),
    );
  }
//endregion
}

class MyForm extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _MyFormState();
  }
}

class _MyFormState extends State<MyForm> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return new Form(
//      key: _formKey,
      child: new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          new Container(
            padding: EdgeInsets.all(20.0),
            child: new TextField(
              onChanged: (String value) {
                _changeText(value);
              },
              decoration: InputDecoration(
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
                ),
              ),
            ),
          ),
          new Container(
            child: new Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                new Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    new Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        new Container(
                          height: 40.0,
                          width: 175.0,
                          child: new RaisedButton(
                            color: Colors.grey[300],
                            textColor: Colors.black,
                            onPressed: () {
                              _CallTapped(false, StringeeObjectEventType.call);
                            },
                            child: Text('CALL'),
                          ),
                        ),
                        new Container(
                          height: 40.0,
                          width: 175.0,
                          margin: EdgeInsets.only(top: 20.0),
                          child: new RaisedButton(
                            color: Colors.grey[300],
                            textColor: Colors.black,
                            onPressed: () {
                              _CallTapped(true, StringeeObjectEventType.call);
                            },
                            child: Text('VIDEOCALL'),
                          ),
                        ),
                      ],
                    ),
                    new Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        new Container(
                          height: 40.0,
                          width: 175.0,
                          child: new RaisedButton(
                            color: Colors.grey[300],
                            textColor: Colors.black,
                            padding: EdgeInsets.only(left: 20.0, right: 20.0),
                            onPressed: () {
                              _CallTapped(false, StringeeObjectEventType.call2);
                            },
                            child: Text('CALL2'),
                          ),
                        ),
                        new Container(
                          height: 40.0,
                          width: 175.0,
                          margin: EdgeInsets.only(top: 20.0),
                          child: new RaisedButton(
                            color: Colors.grey[300],
                            textColor: Colors.black,
                            padding: EdgeInsets.only(left: 20.0, right: 20.0),
                            onPressed: () {
                              _CallTapped(true, StringeeObjectEventType.call2);
                            },
                            child: Text('VIDEOCALL2'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _changeText(String val) {
    setState(() {
      strUserId = val;
    });
  }

  void _CallTapped(bool isVideoCall, StringeeObjectEventType callType) {
    if (strUserId.isEmpty || !_client.hasConnected) return;

    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Call(
              fromUserId: _client.userId,
              toUserId: strUserId,
              isVideoCall: isVideoCall,
              callType: callType,
              showIncomingUi: false)),
    );
  }
}
