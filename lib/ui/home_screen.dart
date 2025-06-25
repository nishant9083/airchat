import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../services/connection_service.dart';
import '../providers/connection_state_provider.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  StreamSubscription? _deviceStream;
  StreamSubscription? _connectionSub;
  StreamSubscription? _messageSubscription;
  String? _error;
  bool _inChat = false;
  late TabController _tabController;
  Box<ChatUser> get _userBox => Hive.box<ChatUser>('chat_users');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final connProvider = Provider.of<ConnectionStateProvider>(context, listen: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connProvider = Provider.of<ConnectionStateProvider>(context, listen: false);
      _startDiscovery(connProvider);
      _startAdvertising(connProvider);
    });
    _deviceStream = ConnectionService.discoveredDevicesStream.listen((event) {
      if (event['type'] == 'found') {
        connProvider.setDiscovered(event['id'], event['name'] ?? 'Unknown');
      } else if (event['type'] == 'lost') {
        connProvider.removeDiscovered(event['id']);
      }
    }, onError: (e) {
      setState(() {
        _error = e.toString();
      });
    });
    _connectionSub = ConnectionService.connectionEventsStream.listen((event) {
      final userId = event['id'] as String;
      if (event['type'] == 'connected') {
        connProvider.setConnected(userId);
      } else if (event['type'] == 'connecting') {
        connProvider.setConnecting(userId);
      } else if (event['type'] == 'disconnected') {
        connProvider.setDisconnected(userId);
      }
    });
    _messageSubscription = ConnectionService.messageEventsStream.listen((event) {
      final userId = event['from'] as String;
      final box = _userBox;
      var user = box.get(userId);
      connProvider.setConnected(userId);
      if (user == null) {
        user = ChatUser(
          id: userId,
          name: event['name'] ?? 'Unknown',
          lastSeen: DateTime.now(),
          messages: [],
        );
        box.put(userId, user);
      }
      print(connProvider.inChatUserId);
      final msg = ChatMessage(
        senderId: userId,
        text: event['message'] ?? '',
        timestamp: DateTime.now(),
        isMe: false,
        isRead: connProvider.inChatUserId == userId,
      );
      user.messages.add(msg);
      user.lastSeen = DateTime.now();
      user.save();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _deviceStream?.cancel();
    _connectionSub?.cancel();
    _messageSubscription?.cancel();
    ConnectionService.stopDiscovery();
    ConnectionService.stopAdvertising();
    super.dispose();
  }

  Future<void> _startDiscovery(ConnectionStateProvider connProvider) async {
    setState(() {
      _error = null;
      connProvider.setDiscovering(true);
    });
    try {
      if(connProvider.discovering) {
        await ConnectionService.stopDiscovery();
      }
      await ConnectionService.startDiscovery();
    } catch (e) {
      setState(() {
        _error = e.toString();
        connProvider.setDiscovering(false);
      });
    }
  }

  Future<void> _startAdvertising(ConnectionStateProvider connProvider) async {
    setState(() {
      _error = null;
      connProvider.setAdvertising(true);
    });
    try {
      await ConnectionService.startAdvertising();
    } catch (e) {
      setState(() {
        _error = e.toString();
        connProvider.setAdvertising(false);
      });
    }
  }

  void _onUserTap(ChatUser user, ConnectionStateProvider connProvider) async {
    if (connProvider.discovered.containsKey(user.id) && !connProvider.connected.contains(user.id)) {
      try {
        connProvider.setConnecting(user.id);
        ConnectionService.connectToDevice(user.id);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
        connProvider.setDisconnected(user.id);
      }
    }
    connProvider.setInChatUserId(user.id);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChatScreen(userId: user.id),
    ));
    connProvider.setInChatUserId(null);
  }

  void _stopDiscovery() {
    final connProvider = Provider.of<ConnectionStateProvider>(context, listen: false);
    connProvider.setDiscovering(false);
    ConnectionService.stopDiscovery();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectionStateProvider>(
      builder: (context, connProvider, _) {
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child:
                  // CircleAvatar(
                  //   backgroundColor: Colors.grey[300],
                  //   child: const Icon(Icons.person, color: Colors.white),
                  // ),
                const Text('AirChat', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: 'Search',
                onPressed: () {}, // Placeholder for search
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'settings') {
                    Navigator.of(context).pushNamed('/settings');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'settings', child: Text('Settings')),
                ],
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.secondary,
              labelColor: Theme.of(context).colorScheme.onPrimary,
              tabs: const [
                Tab(text: 'CHATS'),
                Tab(text: 'STATUS'),
                Tab(text: 'CALLS'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // CHATS TAB
              ValueListenableBuilder(
                valueListenable: _userBox.listenable(),
                builder: (context, Box<ChatUser> box, _) {
                  final users = box.values.toList()
                    ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
                  final discoveredNotInHive = connProvider.discovered.entries
                      .where((e) => box.get(e.key) == null)
                      .toList();
                  if (_error != null) {
                    return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));
                  }
                  if (users.isEmpty && discoveredNotInHive.isEmpty) {
                    return const Center(child: Text('No chats yet. Tap the chat button to discover!'));
                  }
                  final int totalCount = (List.from(discoveredNotInHive).length + List.from(users).length).toInt();
                  return ListView.separated(
                    itemCount: totalCount,
                    separatorBuilder: (context, idx) => const Divider(height: 0),
                    itemBuilder: (context, idx) {
                      if (idx < discoveredNotInHive.length) {
                        // Discovered users not in Hive
                        final entry = discoveredNotInHive[idx];
                        final userId = entry.key;
                        final name = entry.value;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue,
                            child: Text(name.isNotEmpty ? name[0] : '?', style: const TextStyle(color: Colors.white)),
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Tap to start chat'),
                          onTap: () async {
                            _userBox.put(userId, ChatUser(
                              id: userId,
                              name: name,
                              lastSeen: DateTime.now(),
                              messages: [],
                            ));
                            await Future.delayed(const Duration(milliseconds: 100));
                            _onUserTap(_userBox.get(userId)!, connProvider);
                          },
                        );
                      } else {
                        final user = users[idx - discoveredNotInHive.length];
                        String statusText;
                        Color statusColor;
                        if (connProvider.connected.contains(user.id)) {
                          statusText = 'Connected';
                          statusColor = Colors.green;
                        } else if (connProvider.connecting.contains(user.id)) {
                          statusText = 'Connecting...';
                          statusColor = Colors.orange;
                        } else if (connProvider.discovered.containsKey(user.id)) {
                          statusText = 'Available';
                          statusColor = Colors.blue;
                        } else {
                          statusText = 'Not Available';
                          statusColor = Colors.grey;
                        }
                        int unreadCount = user.messages.where((m) => !m.isMe && !m.isRead).length;
                        String lastMsg = user.messages.isNotEmpty ? user.messages.last.text : '';
                        String lastTime = user.messages.isNotEmpty ? _formatTime(user.messages.last.timestamp) : '';
                        return ListTile(
                          onLongPress: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Delete Chat'),
                                content: Text('Delete chat with ${user.name}?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await user.delete();
                            }
                          },
                          leading: Stack(
                            children: [
                              CircleAvatar(
                                backgroundColor: statusColor,
                                child: Text(user.name.isNotEmpty ? user.name[0] : '?', style: const TextStyle(color: Colors.white)),
                              ),
                              if (unreadCount > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$unreadCount',
                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              if (lastTime.isNotEmpty)
                                Text(lastTime, style: TextStyle(color: unreadCount > 0 ? Colors.green : Colors.grey, fontSize: 12)),
                            ],
                          ),
                          subtitle: Text(
                            lastMsg.isNotEmpty ? lastMsg : statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _onUserTap(user, connProvider),
                        );
                      }
                    },
                  );
                },
              ),
              // STATUS TAB (placeholder)
              const Center(child: Text('Status feature coming soon!')),
              // CALLS TAB (placeholder)
              const Center(child: Text('Calls feature coming soon!')),
            ],
          ),
          floatingActionButton: !connProvider.discovering? FloatingActionButton(
            onPressed: ()=>_startDiscovery(connProvider),
            tooltip: 'Discover Devices',
            child: const Icon(Icons.wifi_tethering_outlined),
          ):
              FloatingActionButton(onPressed: _stopDiscovery,
              tooltip: 'Stop Discovery',
              backgroundColor: Colors.red,
              child: const Icon(Icons.stop_rounded)
              )
          ,
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      // Today: show HH:mm
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else if (now.difference(dt).inDays == 1) {
      return 'Yesterday';
    } else {
      return "${dt.day}/${dt.month}/${dt.year}";
    }
  }
} 