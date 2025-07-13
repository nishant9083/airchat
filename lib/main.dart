import 'package:airchat/services/connection_service.dart';
import 'package:airchat/widgets/call_overlay_widget.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:media_kit/media_kit.dart';
import 'models/chat_user.dart';
import 'models/chat_message.dart';
import 'theme.dart';
import 'ui/home_screen.dart';
import 'ui/settings_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'providers/connection_state_provider.dart';
import 'providers/call_state_provider.dart';
import 'services/global_banner_controller.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  JustAudioMediaKit.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ChatUserAdapter());
  Hive.registerAdapter(ChatMessageAdapter());
  // await Hive.deleteBoxFromDisk('chat_users');
  await Hive.openBox<ChatUser>('chat_users');
  var settingsBox = await Hive.openBox('settings');
  if (settingsBox.get('userId') == null) {
    settingsBox.put('userId', const Uuid().v4());
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectionStateProvider()),
        ChangeNotifierProvider(create: (_) => CallStateProvider()),
        ChangeNotifierProvider(create: (_) => GlobalBannerController()),
      ],
      child: const AirChatApp(),
    ),
  );

  // Listen for call events and update CallStateProvider
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ConnectionService.listenForCallEvents();
    final context = navigatorKey.currentContext;
    if (context != null) {
      final callProvider =
          Provider.of<CallStateProvider>(context, listen: false);
      ConnectionService.callEventsStream.listen((event) async {
        final type = event['type'];
        final from = event['from'];
        final id = event['id'];
        if (type == 'call_invite') {
          callProvider.receiveIncomingCall(from, id);
        } else if (type == 'call_accept') {
          callProvider.acceptCall();
        } else if (type == 'call_reject' || type == 'call_end') {          
          await ConnectionService.updateCallDuration(
              callProvider.currentCallUserId!,
              callProvider.callId!,
              callProvider.callState == CallState.inCall
                  ? callProvider.formattedCallDuration
                  : null,
              callProvider.callDirection!);
          callProvider.endCall();
        }
      });
    }
  });
}

class AirChatApp extends StatelessWidget {
  const AirChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AirChat',
      color: Colors.white,
      theme: AirChatTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      builder: (context, child) {
        return Consumer2<GlobalBannerController, CallStateProvider>(
          builder: (context, bannerController, callProvider, _) {
            return Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                if (!callProvider.isCallingScreenOpen &&
                    callProvider.callState != CallState.idle &&
                    callProvider.callState != CallState.ended)
                  CallOverlayWidget(navigatorKey: navigatorKey),
                Expanded(child: child ?? SizedBox.shrink()),
              ],
            );
          },
        );
      },
    );
  }
}
