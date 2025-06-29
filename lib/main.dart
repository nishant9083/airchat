
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/chat_user.dart';
import 'models/chat_message.dart';
import 'theme.dart';
import 'ui/home_screen.dart';
import 'ui/settings_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'providers/connection_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(ChatUserAdapter());
  Hive.registerAdapter(ChatMessageAdapter());
  await Hive.openBox<ChatUser>('chat_users');
  var settingsBox = await Hive.openBox('settings');
  if (settingsBox.get('userId') == null) {
    settingsBox.put('userId', const Uuid().v4());
  }  
  runApp(
    ChangeNotifierProvider(
      create: (_) => ConnectionStateProvider(),
      child: const AirChatApp(),
    ),
  );
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
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/home': (context) => const HomeScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      );




  }
}
