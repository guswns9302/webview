import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'firebase_options.dart';

const String webview_url = "https://pro2.edudongne.com";

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling a background message ${message.messageId}');
}

late AndroidNotificationChannel channel;
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

// main 함수는 App 시작할 때 처음 실행 되는 함수
void main() async {
  // 앱 실행 준비가 완료될 때까지 기다림.
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  channel = const AndroidNotificationChannel(
    'funidea_fcm_channel_id', // id
    'High Importance Notifications', // title
    description:
    'This channel is used for important notifications.', // description
    importance: Importance.high,
  );

  var initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_launcher');

  var initializationSettingsIOS = const DarwinInitializationSettings(requestSoundPermission: true, requestBadgePermission: true, requestAlertPermission: true);

  flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  var initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid, iOS: initializationSettingsIOS);

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
  );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  String? token = await FirebaseMessaging.instance.getToken();

  print("token : ${token ?? 'token NULL!'}");

  runApp(const MyApp());
}

/*
 * 상태가 없는 위젯 : StatelessWidget
 * 한번 그려진 후 상태가 변경 되지 않는다.
 * --> UI를 빠르게 그린다.
 */
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Flutter Demo',
      home: MyHomePage(),
    );
  }
}

/*
 * 상태가 있는 위젯 : StatefulWidget
 * 데이터 변경에 따라 UI를 업데이트 할 수 있음
 */
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late WebViewController controller;
  late Future<String> webview_info_url;

  State<MyHomePage> createState() => _MyHomePageState();

  // State 객체가 최초 생성될 때 호출되는 메소드 (한번만 호출)
  // 초기화 하는 부분 주로 사용
  @override
  void initState() {
    super.initState();
    webview_info_url = getWebViewUrlAddInfo();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Received a message while in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        showNotification(message.notification!);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message clicked!');
    });
  }

  @override
  Widget build(BuildContext context) {
    // FutureBuilder: 비동기 처리하는 데이터를 처리한 후 위젯을 반환할 때 사용하는 위젯
    return FutureBuilder<String>(
        future: webview_info_url,
        builder: (context, snapshot) {
          print(snapshot.error);
          print(snapshot.data);
          print(snapshot.connectionState);
          if(snapshot.connectionState == ConnectionState.done){
            if (snapshot.hasData && snapshot.data != null) {
              controller = WebViewController()
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..loadRequest(Uri.parse(snapshot.data!));
              return Scaffold(
                  body: WebViewWidget(controller: controller)
              );
            }
            else{
              return const Scaffold(
                body: Center(child: Text("Error loading URL")),
              );
            }
          }
          else{
            return const Scaffold(
                body: Center(
                    child: CircularProgressIndicator()
                )
            );
          }
        }
    );
  }

  void showNotification(RemoteNotification notification) {
    flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // webview 주소를 가져오는 곳
  Future<String> getWebViewUrlAddInfo() async {
    String OS_TYPE = "";
    String OS_VERSION = "";
    String DEVICE_MODEL = "";
    String UDID = "";

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo info = await deviceInfo.androidInfo;

      OS_TYPE = "Android";
      OS_VERSION = info.version.release;
      DEVICE_MODEL = info.model;

      /*
      * UDID(Unique Device Identifier)
      * : 각 기기에 부여되는 고유한 디바이스 식별값 (앱을 삭제해도 유지)
      *
      * UUID(Universally Unique Identifier)
      * : 앱마다 가지고 있는 식별값
      */
      final SharedPreferences sp = await SharedPreferences.getInstance();
      String? uuid_sp = sp.getString("UUID");
      if(uuid_sp == null || uuid_sp == "") {
        var uuid = Uuid();
        UDID = uuid.v4();
        await sp.setString("UUID", UDID);
      } else {
        UDID = uuid_sp.toString();
      }
    }
    else if (Platform.isIOS) {
      IosDeviceInfo info = await deviceInfo.iosInfo;

      OS_TYPE = "iOS";
      OS_VERSION = info.systemVersion.toString();
      UDID = info.identifierForVendor.toString();
      DEVICE_MODEL = info.model;
    }

    print('uuid - $UDID');
    print('os version - $OS_VERSION');
    print('os_kind - $OS_TYPE');
    print('deviceModel=$DEVICE_MODEL');

    // 주소 return 해주는 부분
    return '$webview_url';
  }
}
