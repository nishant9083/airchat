import 'dart:io';

import 'package:airchat/services/connection_service.dart';
import 'package:airchat/utility/video_viewer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../providers/connection_state_provider.dart';

import 'desktop_chat_section.dart';

class HomeScreenDesktop extends StatefulWidget {
  const HomeScreenDesktop({
    super.key,
    required this.error,
    required this.tabController,
    required this.userBox,
    required this.isAppActive,
    required this.searchController,
    required this.isChatTab,
    required this.startDiscovery,
    required this.stopDiscovery,
  });

  final String? error;
  final dynamic tabController;
  final Box<ChatUser> userBox;
  final bool isAppActive;
  final dynamic searchController;
  final bool isChatTab;
  final dynamic startDiscovery;
  final dynamic stopDiscovery;

  @override
  State<HomeScreenDesktop> createState() => _HomeScreenDesktopState();
}

class _HomeScreenDesktopState extends State<HomeScreenDesktop> {
  int? selectedChatIndex;
  String? selectedUserId;
  String _searchQuery = '';
  bool showUserInfo = false;
  ChatUser? selectedUser;

  void _onUserTap(ChatUser user, ConnectionStateProvider connProvider) async {
    connProvider.setInChatUserId(user.id);
    await ConnectionService.connectToDevice(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer<ConnectionStateProvider>(
      builder: (context, connProvider, _) {
        return ValueListenableBuilder(
          valueListenable: widget.userBox.listenable(),
          builder: (context, Box<ChatUser> box, _) {
            // Filter users by search
            final users = box.values
                .where((user) =>
                    _searchQuery.isEmpty ||
                    user.name
                        .toLowerCase()
                        .contains(_searchQuery.toLowerCase()))
                .toList()
              ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
            // Discovered users not in Hive
            final discoveredNotInHive = connProvider.discovered.entries
                .where((e) =>
                    box.get(e.key) == null &&
                    (_searchQuery.isEmpty ||
                        e.value
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase())))
                .toList();
            // Sidebar list: discovered first, then chats
            final sidebarList = [
              ...discoveredNotInHive.map(
                  (e) => {'type': 'discovered', 'id': e.key, 'name': e.value}),
              ...users.map((u) => {'type': 'chat', 'id': u.id, 'name': u.name, 'msgType':u.messages.isNotEmpty? u.messages[u.messages.length-1].type:'', 'lstMsg':u.messages.isNotEmpty? u.messages[u.messages.length-1].text:''}),
            ];

            final List<ChatMessage> messages = selectedUser?.messages ?? [];            
            // UI
            return Scaffold(
              backgroundColor: colorScheme.surface,
              body: Row(
                children: [
                  // Sidebar
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colorScheme.primary, colorScheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .08),
                          blurRadius: 12,
                          offset: Offset(2, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset('assets/icon/icon.png',
                                width: 40, height: 40),
                            const SizedBox(width: 12),
                            const Text(
                              'AirChat',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search chats...',
                              hintStyle: TextStyle(color: Colors.white70),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: .12),
                              prefixIcon:
                                  Icon(Icons.search, color: Colors.white70),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 0),
                            ),
                            style: const TextStyle(color: Colors.white),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemCount: sidebarList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, idx) {
                              final item = sidebarList[idx];
                              final selected = item['id'] == selectedUserId;
                              final isDiscovered = item['type'] == 'discovered';
                              final isOnline = connProvider.discovered
                                  .containsKey(item['id']);
                              final isConnected = connProvider.connectedPeers
                                  .any((p) =>
                                      p.userId == (item['id'] as String));
                              final unreadCount = !isDiscovered &&
                                      item['id'] != null &&
                                      (item['id'] as String).isNotEmpty &&
                                      box.containsKey(item['id'] as String) &&
                                      box.get(item['id'] as String) != null
                                  ? box
                                      .get(item['id'] as String)!
                                      .messages
                                      .where((m) => !m.isMe && !m.isRead)
                                      .length
                                  : 0;

                              String msgType = item['type'] =='chat'? item['msgType']!:'';
                              return _SidebarItem(
                                item: item,
                                selected: selected,
                                isDiscovered: isDiscovered,
                                isOnline: isOnline,
                                isConnected: isConnected,
                                unreadCount: unreadCount,
                                msgType: msgType,
                                box: box,
                                idx: idx,
                                onTap: () {
                                  setState(() {
                                    selectedUserId = item['id'];
                                    selectedUser = box.get(selectedUserId!);
                                    selectedChatIndex = idx;
                                    if (selectedUser != null) {
                                      _onUserTap(selectedUser!, connProvider);
                                    }
                                  });
                                },
                                onDelete: () async {
                                  await box.delete(item['id'] as String);
                                  setState(() {
                                    if (selectedUserId == item['id']) {
                                      selectedUserId = null;
                                      selectedUser = null;
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: FloatingActionButton.extended(
                            heroTag: 'desktop-screen',
                            onPressed: () {
                              if (connProvider.discovering) {
                                widget.stopDiscovery();
                              } else {
                                widget.startDiscovery(connProvider);
                              }
                            },
                            backgroundColor: connProvider.discovering
                                ? Colors.red
                                : Colors.white,
                            icon: Icon(
                              connProvider.discovering
                                  ? Icons.stop
                                  : Icons.wifi_tethering,
                              color: connProvider.discovering
                                  ? Colors.white
                                  : colorScheme.primary,
                            ),
                            label: Text(
                              connProvider.discovering ? 'Stop' : 'Discover',
                              style: TextStyle(
                                color: connProvider.discovering
                                    ? Colors.white
                                    : colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Main chat area
                  Expanded(
                    child: selectedUser == null
                        ? Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 48.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.indigo.withValues(alpha: .08),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(32),
                                    child: Icon(
                                      Icons.forum_outlined,
                                      size: 72,
                                      color: Colors.indigoAccent
                                          .withValues(alpha: .7),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    'No Chat Selected',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo[700],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Choose a conversation from the sidebar\nor start a new chat to begin messaging.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: Colors.indigo[200],
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Select a user on the left',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.indigo[200],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : DesktopChatSection(
                            user: selectedUser!,
                            messages: messages,
                            onBack: () {
                              setState(() {
                                selectedUserId = null;
                                selectedUser = null;
                              });
                              connProvider.setInChatUserId(null);
                            },
                            onInfoToggle: () {
                              setState(() {
                                showUserInfo = !showUserInfo;
                              });
                            }),
                  ),
                  // Right panel (user info/status)
                  if (selectedUser != null && showUserInfo)
                    Container(
                      width: 320,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        border: Border(
                          left: BorderSide(
                              color: Colors.grey.withValues(alpha: .12)),
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 10,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Media, Links & Docs',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Media Grid
                                Builder(
                                  builder: (context) {
                                    final mediaMessages = selectedUser!.messages
                                        .where((m) =>
                                            m.type == 'image' ||
                                            m.type == 'video')
                                        .toList()
                                      ..sort((a, b) =>
                                          b.timestamp.compareTo(a.timestamp));
                                    if (mediaMessages.isEmpty) {
                                      return Text(
                                        'No media yet.',
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14),
                                      );
                                    }
                                    return SizedBox(
                                        height: 300,
                                        child: GridView.builder(
                                          // shrinkWrap: true,
                                          // physics: NeverScrollableScrollPhysics(),
                                          itemCount: mediaMessages.length,
                                          gridDelegate:
                                              SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            mainAxisSpacing: 6,
                                            crossAxisSpacing: 6,
                                            childAspectRatio: 1,
                                          ),
                                          itemBuilder: (context, idx) {
                                            final msg = mediaMessages[idx];
                                            if (msg.type == 'image' &&
                                                msg.filePath != null) {
                                              return GestureDetector(
                                                onTap: () {
                                                  // Open full screen image viewer
                                                  // (implement as in your mobile UI)
                                                },
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.file(
                                                    File(msg.filePath!),
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (c, e, s) =>
                                                        Container(
                                                      color: Colors.grey[300],
                                                      child: Icon(
                                                          Icons.broken_image,
                                                          color: Colors.grey),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            } else if (msg.type == 'video' &&
                                                msg.filePath != null) {
                                              return GestureDetector(
                                                onTap: () {
                                                  // Open video viewer
                                                },
                                                child: Stack(
                                                  children: [
                                                    // Show video thumbnail (implement VideoThumbnailWidget if you have it)
                                                    ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      child:
                                                          VideoThumbnailWidget(
                                                              filePath: msg
                                                                  .filePath!),
                                                    ),
                                                    Center(
                                                      child: Icon(
                                                          Icons
                                                              .play_circle_fill,
                                                          color: Colors.white70,
                                                          size: 32),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                            return SizedBox.shrink();
                                          },
                                        ));
                                  },
                                ),

                                const SizedBox(height: 18),

// Files List
                                Builder(
                                  builder: (context) {
                                    final fileMessages = selectedUser!.messages
                                        .where((m) => m.type == 'file')
                                        .toList()
                                      ..sort((a, b) =>
                                          b.timestamp.compareTo(a.timestamp));
                                    if (fileMessages.isEmpty) {
                                      return SizedBox.shrink();
                                    }
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Files',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15),
                                        ),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                          height: 180, // adjust as needed
                                          child: ListView.builder(
                                            itemCount: fileMessages.length,
                                            itemBuilder: (context, idx) {
                                              final msg = fileMessages[idx];
                                              return ListTile(
                                                leading: Icon(
                                                    Icons.insert_drive_file,
                                                    color: Colors.indigoAccent),
                                                title: Text(
                                                  msg.fileName ?? 'File',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                onTap: () {
                                                  // Open file (use OpenFile.open(msg.filePath))
                                                },
                                                dense: true,
                                                contentPadding: EdgeInsets.zero,
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool selected;
  final bool isDiscovered;
  final bool isOnline;
  final bool isConnected;
  final int unreadCount;
  final String msgType;
  final Box<ChatUser> box;
  final int idx;
  final void Function()? onTap;
  final void Function()? onDelete;

  const _SidebarItem({    
    required this.item,
    required this.selected,
    required this.isDiscovered,
    required this.isOnline,
    required this.isConnected,
    required this.unreadCount,
    required this.msgType,
    required this.box,
    required this.idx,
    this.onTap,
    this.onDelete,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final box = widget.box;
    final msgType = widget.msgType;
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: Material(
        color: widget.selected
            ? Colors.white.withValues(alpha: .12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: widget.isConnected
                      ? Colors.green
                      : widget.isOnline
                          ? Colors.blueAccent
                          : Colors.grey,
                  radius: 20,
                  child: Text(
                    item['name']!.isNotEmpty ? item['name']![0] : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['name']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (msgType == 'image')
                        const Icon(Icons.image, color: Colors.grey, size: 16)
                      else if (msgType == 'audio')
                        const Icon(Icons.music_note, color: Colors.grey, size: 16)
                      else if (msgType == 'video')
                        const Icon(Icons.video_camera_back, color: Colors.grey, size: 16)
                      else if (msgType == 'file')
                        const Icon(Icons.file_present, color: Colors.grey, size: 16)
                      else if (msgType == 'text')
                        Text(
                          box.get(item['id'] as String)!.messages.last.text,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (widget.unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${widget.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                // Hover icon button
                AnimatedOpacity(
                  opacity: isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  child: isHovered
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white70),
                          onSelected: (value) async {
                            if (value == 'delete') {
                              if (widget.onDelete != null) widget.onDelete!();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete Chat'),
                                ],
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(width: 40),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
