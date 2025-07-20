import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:airchat/providers/call_state_provider.dart';
import 'package:airchat/utility/notification_util.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../services/connection_service.dart';
import '../providers/connection_state_provider.dart';
import '../utility/display_name_prompt.dart';
import 'home_screen_desktop.dart';
import 'home_screen_mobile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  StreamSubscription? _deviceStream;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _fileSubscription;
  String? _error;
  late TabController _tabController;
  Box<ChatUser> get _userBox => Hive.box<ChatUser>('chat_users');
  bool _isAppActive = true;

  final TextEditingController _searchController = TextEditingController();
  bool _isChatTab = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        setState(() {
          _isChatTab = true;
        });
      } else {
        setState(() {
          _isChatTab = false;
        });
      }
    });
    final connProvider =
        Provider.of<ConnectionStateProvider>(context, listen: false);
    final callProvider = Provider.of<CallStateProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await showDisplayNamePrompt(context);
      await _startDiscovery(connProvider);
      await ConnectionService.startServer();
    });
    _setupEventListeners(connProvider, callProvider);
  }

  void _setupEventListeners(
      ConnectionStateProvider connProvider, CallStateProvider callProvider) {
    _deviceStream = ConnectionService.discoveredDevicesStream.listen((event) {
      if (event['type'] == 'found') {
        connProvider.setDiscovered(event['id'], event['name'] ?? 'Unknown');
      }
      if (event['type'] == 'off') {
        connProvider.clearAll();
      }
    }, onError: (e) {
      setState(() {
        _error = e.toString();
      });
    });

    _messageSubscription =
        ConnectionService.messageEventsStream.listen((event) {
      final userId = event['from'] as String;
      final box = _userBox;
      var user = box.get(userId);
      connProvider.setDiscovered(userId, event['name'] ?? 'Unknown');
      if (user == null) {
        user = ChatUser(
          id: userId,
          name: event['name'] ?? 'Unknown',
          lastSeen: DateTime.now(),
          messages: [],
        );
        box.put(userId, user);
      }
      if (event['type'] == 'call') {
        if(event['message'] == '__CALL_INVITE__' && !_isAppActive)
        {
          NotificationUtil.showIncomingCall(id: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF, callerName: event['name']);
        }
        return;
      }
      final msg = ChatMessage(
          id: event['timestamp'],
          senderId: userId,
          text: event['message'] ?? '',
          timestamp: DateTime.now(),
          isMe: false,
          isRead: connProvider.inChatUserId == userId,
          type: 'text');
      if (event['name'] != null) {
        user.name = event['name'];
      }
      user.messages.add(msg);
      user.lastSeen = DateTime.now();
      user.save();
      if(!_isAppActive){
        NotificationUtil.showNotification(
          id: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
          title: event['name'] ?? 'New Message',
          body: event['message'] ?? '',
        );
      }
    });

    _fileSubscription = ConnectionService.fileEventsStream.listen((event) {
      final userId = event['from'] as String;
      final box = _userBox;
      var user = box.get(userId);
      connProvider.setDiscovered(userId, event['name'] ?? 'Unknown');
      if (user == null) {
        user = ChatUser(
          id: userId,
          name: event['name'] ?? 'Unknown',
          lastSeen: DateTime.now(),
          messages: [],
        );
        box.put(userId, user);
      }
      final msg = ChatMessage(
          id: event['timestamp'],
          senderId: userId,
          text: '',
          timestamp: DateTime.now(),
          isMe: false,
          isRead: connProvider.inChatUserId == userId,
          type: event['fileType'] ?? 'file',
          fileName: event['fileName'],
          filePath: event['filePath']);
      if (event['name'] != null) {
        user.name = event['name'];
      }
      user.messages.add(msg);
      user.save();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final connProvider =
        Provider.of<ConnectionStateProvider>(context, listen: false);
    switch (state) {
      case AppLifecycleState.resumed:
        setState(() {
          _isAppActive = true;
        });
        _refreshConnectionState(connProvider);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        setState(() {
          _isAppActive = false;
        });
        break;
    }
  }

  Future<void> _refreshConnectionState(
      ConnectionStateProvider connProvider) async {
    try {
      final discoveredUsers = await ConnectionService.getDiscoveredUsers();
      await ConnectionService.stopDiscovery();
      await ConnectionService.startDiscovery();
      connProvider.clearAll();
      for (final user in discoveredUsers) {
        connProvider.setDiscovered(user['id'], user['name']);
      }
    } catch (e) {
      
        log('Error refreshing connection state: $e');
      
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _deviceStream?.cancel();
    _messageSubscription?.cancel();
    _fileSubscription?.cancel();
    ConnectionService.stopDiscovery();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startDiscovery(ConnectionStateProvider connProvider) async {
    setState(() {
      _error = null;
    });
    try {
      if (connProvider.discovering) {
        await ConnectionService.stopDiscovery();
      }
      connProvider.setDiscovering(true);
      await ConnectionService.startDiscovery();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      connProvider.setDiscovering(false);
    }
  }

  void _stopDiscovery() {
    final connProvider =
        Provider.of<ConnectionStateProvider>(context, listen: false);
    connProvider.setDiscovering(false);
    ConnectionService.stopDiscovery();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return HomeScreenDesktop(
        error: _error,
        tabController: _tabController,
        userBox: _userBox,
        isAppActive: _isAppActive,
        searchController: _searchController,
        isChatTab: _isChatTab,
        startDiscovery: _startDiscovery,
        stopDiscovery: _stopDiscovery,
      );
    } else {
      return HomeScreenMobile(
        error: _error,
        tabController: _tabController,
        userBox: _userBox,
        isAppActive: _isAppActive,
        searchController: _searchController,
        isChatTab: _isChatTab,
        startDiscovery: _startDiscovery,
        stopDiscovery: _stopDiscovery,
      );
    }
  }
}
