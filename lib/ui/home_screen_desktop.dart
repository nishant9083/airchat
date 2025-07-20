import 'dart:io';

import 'package:airchat/services/connection_service.dart';
import 'package:airchat/ui/desktop_settings.dart';
import 'package:airchat/utility/video_viewer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/chat_user.dart';
import '../models/chat_message.dart';
import '../providers/connection_state_provider.dart';
import 'package:airchat/providers/call_state_provider.dart';

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
    final theme = Theme.of(context);
    return Consumer<CallStateProvider>(
      builder: (context, callProvider, _) {
        return Consumer<ConnectionStateProvider>(
          builder: (context, connProvider, _) {
            return ValueListenableBuilder(
              valueListenable: widget.userBox.listenable(),
              builder: (context, Box<ChatUser> box, _) {
                final users = box.values
                    .where((user) =>
                        _searchQuery.isEmpty ||
                        user.name
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                    .toList()
                  ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
                final discoveredNotInHive = connProvider.discovered.entries
                    .where((e) =>
                        box.get(e.key) == null &&
                        (_searchQuery.isEmpty ||
                            e.value
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase())))
                    .toList();
                final sidebarList = [
                  ...discoveredNotInHive.map((e) =>
                      {'type': 'discovered', 'id': e.key, 'name': e.value}),
                  ...users.map((u) => {
                        'type': 'chat',
                        'id': u.id,
                        'name': u.name,
                        'msgType': u.messages.isNotEmpty
                            ? u.messages[u.messages.length - 1].type
                            : '',
                        'lstMsg': u.messages.isNotEmpty
                            ? u.messages[u.messages.length - 1].text
                            : ''
                      }),
                ];

                final List<ChatMessage> messages = selectedUser?.messages ?? [];

                // Modern, glassy, and more visually appealing UI
                return Scaffold(
                  backgroundColor: colorScheme.surface,
                  body: Row(
                    children: [
                      // Sidebar
                      Container(
                        width: 320,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withValues(alpha: 0.04),
                              blurRadius: 16,
                              offset: const Offset(2, 0),
                            ),
                          ],
                          // backgroundBlendMode: BlendMode.multiply,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.asset(
                                      'assets/icon/icon.png',
                                      width: 44,
                                      height: 44,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    'AirChat',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                      shadows: [
                                        Shadow(
                                          color: colorScheme.primary
                                              .withValues(alpha: 0.15),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: Icon(Icons.settings,
                                        color: Colors.white),
                                    tooltip: 'Settings',
                                    onPressed: () {
                                      Navigator.of(context).push(
                                          MaterialPageRoute(
                                              builder: (builder) =>
                                                  DesktopSettingsPage()));
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search chats...',
                                  hintStyle: TextStyle(
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.5)),
                                  filled: true,
                                  fillColor: colorScheme.surface,
                                  prefixIcon: Icon(Icons.search,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.5)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 0),
                                ),
                                style: TextStyle(color: colorScheme.onSurface),
                                onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            Expanded(
                              child: ScrollConfiguration(
                                behavior: _NoGlowScrollBehavior(),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 8),
                                  itemCount: sidebarList.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 6),
                                  itemBuilder: (context, idx) {
                                    final item = sidebarList[idx];
                                    final selected =
                                        item['id'] == selectedUserId;
                                    final isDiscovered =
                                        item['type'] == 'discovered';
                                    final isOnline = connProvider.discovered
                                        .containsKey(item['id']);
                                    final isConnected =
                                        connProvider.connectedPeers.any((p) =>
                                            p.userId == (item['id'] as String));
                                    final unreadCount = !isDiscovered &&
                                            item['id'] != null &&
                                            (item['id'] as String).isNotEmpty &&
                                            box.containsKey(
                                                item['id'] as String) &&
                                            box.get(item['id'] as String) !=
                                                null
                                        ? box
                                            .get(item['id'] as String)!
                                            .messages
                                            .where((m) => !m.isMe && !m.isRead)
                                            .length
                                        : 0;

                                    String msgType = item['type'] == 'chat'
                                        ? item['msgType']!
                                        : '';
                                    return _SidebarItemModern(
                                      item: item,
                                      selected: selected,
                                      isDiscovered: isDiscovered,
                                      isOnline: isOnline,
                                      isConnected: isConnected,
                                      unreadCount: unreadCount,
                                      msgType: msgType,
                                      box: box,
                                      idx: idx,
                                      onTap: () async {
                                        setState(() {
                                          selectedUserId = item['id'];
                                          selectedUser =
                                              box.get(selectedUserId!);
                                          selectedChatIndex = idx;
                                          if (selectedUser != null) {
                                            _onUserTap(
                                                selectedUser!, connProvider);
                                          } else {
                                            widget.userBox.put(
                                              selectedUserId,
                                              ChatUser(
                                                id: selectedUserId!,
                                                name: item['name']!,
                                                lastSeen: DateTime.now(),
                                                messages: [],
                                              ),
                                            );
                                            _onUserTap(
                                                widget.userBox
                                                    .get(selectedUserId)!,
                                                connProvider);
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
                            ),
                            Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: connProvider.discovering
                                        ? Colors.redAccent
                                        : colorScheme.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  icon: Icon(
                                    connProvider.discovering
                                        ? Icons.stop
                                        : Icons.wifi_tethering_rounded,
                                    color: colorScheme.onPrimary,
                                  ),
                                  label: Text(
                                    connProvider.discovering
                                        ? 'Stop Discovering'
                                        : 'Discover Devices',
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                  onPressed: () {
                                    if (connProvider.discovering) {
                                      widget.stopDiscovery();
                                    } else {
                                      widget.startDiscovery(connProvider);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Main chat area
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: selectedUser == null
                              ? _NoChatSelectedModern()
                              : DesktopChatSection(
                                  key: ValueKey(selectedUserId),
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
                      ),
                      // Right panel (user info/status)
                      if (selectedUser != null && showUserInfo)
                        Container(
                          width: 340,
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            border: Border(
                              left: BorderSide(
                                  color: colorScheme.outline
                                      .withValues(alpha: 0.13),
                                  width: 1.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.shadow.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(-2, 0),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 18),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundColor: colorScheme.primary
                                              .withValues(alpha: 0.12),
                                          child: Text(
                                            selectedUser!.name.isNotEmpty
                                                ? selectedUser!.name[0]
                                                : '?',
                                            style: TextStyle(
                                              fontSize: 28,
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                selectedUser!.name,
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Last seen: ${_formatLastSeen(selectedUser!.lastSeen)}',
                                                style: theme.textTheme.bodySmall
                                                    ?.copyWith(
                                                  color: colorScheme.onSurface
                                                      .withValues(alpha: 0.6),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
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
                                        final mediaMessages = selectedUser!
                                            .messages
                                            .where((m) =>
                                                m.type == 'image' ||
                                                m.type == 'video')
                                            .toList()
                                          ..sort((a, b) => b.timestamp
                                              .compareTo(a.timestamp));
                                        if (mediaMessages.isEmpty) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            child: Text(
                                              'No media yet.',
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                      color: colorScheme
                                                          .onSurface
                                                          .withValues(
                                                              alpha: 0.6),
                                                      fontSize: 14),
                                            ),
                                          );
                                        }
                                        return SizedBox(
                                            height: 220,
                                            child: GridView.builder(
                                              itemCount: mediaMessages.length,
                                              gridDelegate:
                                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: 3,
                                                mainAxisSpacing: 8,
                                                crossAxisSpacing: 8,
                                                childAspectRatio: 1,
                                              ),
                                              itemBuilder: (context, idx) {
                                                final msg = mediaMessages[idx];
                                                if (msg.type == 'image' &&
                                                    msg.filePath != null) {
                                                  return GestureDetector(
                                                    onTap: () {
                                                      // Open full screen image viewer
                                                    },
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      child: Image.file(
                                                        File(msg.filePath!),
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (c, e, s) =>
                                                                Container(
                                                          color: colorScheme
                                                              .surface,
                                                          child: Icon(
                                                              Icons
                                                                  .broken_image,
                                                              color: colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                      alpha:
                                                                          0.4)),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                } else if (msg.type ==
                                                        'video' &&
                                                    msg.filePath != null) {
                                                  return GestureDetector(
                                                    onTap: () {
                                                      // Open video viewer
                                                    },
                                                    child: Stack(
                                                      children: [
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(10),
                                                          child:
                                                              VideoThumbnailWidget(
                                                                  filePath: msg
                                                                      .filePath!),
                                                        ),
                                                        Center(
                                                          child: Icon(
                                                              Icons
                                                                  .play_circle_fill,
                                                              color: colorScheme
                                                                  .onSurface
                                                                  .withValues(
                                                                      alpha:
                                                                          0.7),
                                                              size: 32),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            ));
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    // Files List
                                    Builder(
                                      builder: (context) {
                                        final fileMessages = selectedUser!
                                            .messages
                                            .where((m) => m.type == 'file')
                                            .toList()
                                          ..sort((a, b) => b.timestamp
                                              .compareTo(a.timestamp));
                                        if (fileMessages.isEmpty) {
                                          return const SizedBox.shrink();
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
                                              height: 120,
                                              child: ListView.builder(
                                                itemCount: fileMessages.length,
                                                itemBuilder: (context, idx) {
                                                  final msg = fileMessages[idx];
                                                  return ListTile(
                                                    leading: Icon(
                                                        Icons.insert_drive_file,
                                                        color: colorScheme
                                                            .primary),
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
                                                    contentPadding:
                                                        EdgeInsets.zero,
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
      },
    );
  }
}

String _formatLastSeen(DateTime lastSeen) {
  final now = DateTime.now();
  final diff = now.difference(lastSeen);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  return '${lastSeen.year}/${lastSeen.month}/${lastSeen.day}';
}

class _SidebarItemModern extends StatefulWidget {
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

  const _SidebarItemModern({
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
  State<_SidebarItemModern> createState() => _SidebarItemModernState();
}

class _SidebarItemModernState extends State<_SidebarItemModern> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final box = widget.box;
    final msgType = widget.msgType;
    final isDiscovered = widget.isDiscovered;
    final isOnline = widget.isOnline;
    final isConnected = widget.isConnected;
    final unreadCount = widget.unreadCount;

    Color avatarColor;
    if (isConnected) {
      avatarColor = Colors.greenAccent.shade400;
    } else if (isOnline) {
      avatarColor = Colors.blueAccent.shade200;
    } else if (isDiscovered) {
      avatarColor = Colors.orangeAccent.shade200;
    } else {
      avatarColor = Colors.grey.shade400;
    }

    return MouseRegion(
      onHover: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      // hitTestBehavior: HitTestBehavior.translucent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.selected
              ? Colors.white.withValues(alpha: 0.13)
              : isHovered
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: widget.selected
              ? [
                  BoxShadow(
                    color: Colors.blueAccent.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        backgroundColor: avatarColor,
                        radius: 22,
                        child: Text(
                          item['name']!.isNotEmpty ? item['name']![0] : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isConnected)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.greenAccent.shade400,
                                width: 2,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.check,
                                  size: 9, color: Colors.green),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name']!,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: widget.selected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 17,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (msgType == 'image')
                          Row(
                            children: const [
                              Icon(Icons.image,
                                  color: Colors.white70, size: 16),
                              SizedBox(width: 4),
                              Text('Photo',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          )
                        else if (msgType == 'audio')
                          Row(
                            children: const [
                              Icon(Icons.music_note,
                                  color: Colors.white70, size: 16),
                              SizedBox(width: 4),
                              Text('Audio',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          )
                        else if (msgType == 'video')
                          Row(
                            children: const [
                              Icon(Icons.videocam_rounded,
                                  color: Colors.white70, size: 16),
                              SizedBox(width: 4),
                              Text('Video',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          )
                        else if (msgType == 'file')
                          Row(
                            children: const [
                              Icon(Icons.file_present,
                                  color: Colors.white70, size: 16),
                              SizedBox(width: 4),
                              Text('File',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          )
                        else if (msgType == 'call')
                          Row(
                            children: const [
                              Icon(Icons.call, color: Colors.white70, size: 16),
                              SizedBox(width: 4),
                              Text('Call',
                                  style: TextStyle(
                                      color: Colors.white70, fontSize: 13)),
                            ],
                          )
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
                  if (unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$unreadCount',
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
                      child: PopupMenuButton<String>(
                        icon:
                            const Icon(Icons.more_vert, color: Colors.white70),
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
                                Icon(Icons.delete,
                                    color: Colors.redAccent, size: 20),
                                SizedBox(width: 8),
                                Text('Delete Chat'),
                              ],
                            ),
                          ),
                        ],
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoChatSelectedModern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 64.0),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surface.withValues(alpha: 0.92)
                : colorScheme.surface.withValues(alpha: 0.95),
            border: Border.all(
                color: colorScheme.onSurface.withValues(alpha: 0.08),
                width: 1.5),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.18)
                    : colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: isDark ? 32 : 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_rounded,
                size: 90,
                color: colorScheme.secondary,
              ),
              const SizedBox(height: 32),
              Text(
                'Welcome to AirChat Desktop',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: isDark ? colorScheme.onSurface : colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Select a conversation from the sidebar or start a new chat to begin messaging.\n\nYou can also discover nearby devices to chat with!',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                  color: isDark
                      ? colorScheme.onSurface.withValues(alpha: 0.85)
                      : colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 32),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                color: colorScheme.secondary,
                size: 36,
              ),
              const SizedBox(height: 8),
              Text(
                'Pick a user on the left',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: colorScheme.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  // @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}
