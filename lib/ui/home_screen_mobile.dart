import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../models/chat_user.dart';

import '../services/connection_service.dart';
import '../providers/connection_state_provider.dart';
import '../widgets/exit_popup.dart';
import 'chat_screen.dart';



class HomeScreenMobile extends StatefulWidget {
  final String? error;
  final dynamic tabController;
  final Box<ChatUser> userBox;
  final bool isAppActive;
  final dynamic searchController;
  final bool isChatTab;
  final dynamic startDiscovery;
  final dynamic stopDiscovery;

  const HomeScreenMobile({
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

  @override
  State<HomeScreenMobile> createState() => _HomeScreenMobile();
}

class _HomeScreenMobile extends State<HomeScreenMobile> {
  bool _isSearching = false;
  String _searchQuery = '';

  void _onUserTap(ChatUser user, ConnectionStateProvider connProvider) async {
    connProvider.setInChatUserId(user.id);
    await ConnectionService.connectToDevice(user.id);
    if (mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ChatScreen(userId: user.id),
      ));
    }
    connProvider.setInChatUserId(null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, _) async {
          if (didPop) {
            return;
          }
          if (_isSearching) {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
              widget.searchController.clear();
            });
            return;
          }
          final bool shouldPop = await showExitDialog(context) ?? false;
          if (context.mounted && shouldPop) {
            // Navigator.of(context).popUntil((route)=>false);
            // if (Platform.isAndroid || Platform.isIOS) {
            SystemNavigator.pop();
            // }
          }
        },
        child: Consumer<ConnectionStateProvider>(
          builder: (context, connProvider, _) {
            return Scaffold(
              backgroundColor: Colors.grey[50],
              body: NestedScrollView(
                physics: const NeverScrollableScrollPhysics(),
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  // Custom App Bar
                  SliverAppBar(
                    expandedHeight: 140,
                    collapsedHeight: 70,
                    floating: true,
                    pinned: true,
                    backgroundColor: Colors.indigoAccent,
                    elevation: 0,
                    title: _isSearching
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 0, vertical: 0),
                            margin: const EdgeInsets.only(top: 8, bottom: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.arrow_back_rounded,
                                      color: Colors.indigoAccent, size: 26),
                                  onPressed: () {
                                    setState(() {
                                      _isSearching = false;
                                      _searchQuery = '';
                                      widget.searchController.clear();
                                    });
                                  },
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: widget.searchController,
                                    autofocus: true,
                                    cursorColor: Colors.indigoAccent,
                                    decoration: InputDecoration(
                                      fillColor: Colors.transparent,
                                      hintText:
                                          'Search for people or messages...',
                                      hintStyle: TextStyle(
                                        color: Colors.indigoAccent
                                            .withValues(alpha: 0.6),
                                        fontSize: 17,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 12, horizontal: 0),
                                    ),
                                    style: TextStyle(
                                      color: Colors.indigoAccent,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                  ),
                                ),
                                AnimatedSwitcher(
                                  duration: Duration(milliseconds: 200),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                          scale: anim, child: child),
                                  child: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          key: ValueKey('clear'),
                                          icon: Icon(Icons.close_rounded,
                                              color: Colors.indigoAccent,
                                              size: 24),
                                          onPressed: () {
                                            setState(() {
                                              _searchQuery = '';
                                              widget.searchController.clear();
                                            });
                                          },
                                        )
                                      : SizedBox(width: 48), // keep layout
                                ),
                              ],
                            ),
                          )
                        : Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Container(
                              margin: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.07),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/icon/icon.png',
                                      width: 32,
                                      height: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'AirChat',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Connect. Chat. Share.',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  if (widget.isChatTab)
                                    IconButton(
                                      icon: Icon(Icons.search_rounded,
                                          color: Colors.white, size: 26),
                                      onPressed: () {
                                        setState(() {
                                          _isSearching = true;
                                        });
                                      },
                                      tooltip: 'Search',
                                    ),
                                  IconButton(
                                    icon: Icon(Icons.settings_rounded,
                                        color: Colors.white, size: 26),
                                    onPressed: () => Navigator.of(context)
                                        .pushNamed('/settings'),
                                    tooltip: 'Settings',
                                  ),
                                ],
                              ),
                            ),
                          ),
                    flexibleSpace: FlexibleSpaceBar(
                      collapseMode: CollapseMode.pin,
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                        ),
                        child: SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 60),
                                // Custom Tab Bar
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: TabBar(
                                    controller: widget.tabController,
                                    indicator: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    indicatorSize: TabBarIndicatorSize.tab,
                                    labelColor: colorScheme.primary,
                                    unselectedLabelColor: Colors.white,
                                    labelStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    dividerColor: Colors.transparent,
                                    tabs: const [
                                      Tab(text: 'CHATS'),
                                      Tab(text: 'STATUS'),
                                      Tab(text: 'CALLS'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Content
                  // SliverFillRemaining(
                  //   child:
                  // ),
                ],
                body: TabBarView(
                  controller: widget.tabController,
                  children: [
                    // CHATS TAB
                    _buildChatsTab(connProvider, colorScheme),
                    // STATUS TAB
                    _buildStatusTab(colorScheme),
                    // CALLS TAB
                    _buildCallsTab(colorScheme),
                  ],
                ),
              ),
              floatingActionButton:
                  _buildFloatingActionButton(connProvider, colorScheme),
            );
          },
        ));
  }

  Widget _buildChatsTab(
      ConnectionStateProvider connProvider, ColorScheme colorScheme) {
    return ValueListenableBuilder(
      valueListenable: widget.userBox.listenable(),
      builder: (context, Box<ChatUser> box, _) {
        final users = box.values
            .where((user) =>
                _searchQuery.isEmpty ||
                user.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList()
          ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));

        final discoveredNotInHive = connProvider.discovered.entries
            .where((e) =>
                box.get(e.key) == null &&
                (_searchQuery.isEmpty ||
                    e.value.toLowerCase().contains(_searchQuery.toLowerCase())))
            .toList();

        if (widget.error != null) {
          return _buildErrorState(widget.error!, colorScheme);
        }

        if (users.isEmpty && discoveredNotInHive.isEmpty) {
          return _buildEmptyState(colorScheme);
        }

        final int totalCount = (discoveredNotInHive.length + users.length);

        return ListView.builder(
          physics: users.length + discoveredNotInHive.length <= 5
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          itemCount: totalCount,
          itemBuilder: (context, idx) {
            if (idx < discoveredNotInHive.length) {
              return _buildDiscoveredUserTile(
                  discoveredNotInHive[idx], connProvider, colorScheme);
            } else {
              return _buildChatTile(users[idx - discoveredNotInHive.length],
                  connProvider, colorScheme);
            }
          },
        );
      },
    );
  }

  Widget _buildDiscoveredUserTile(MapEntry<String, String> entry,
      ConnectionStateProvider connProvider, ColorScheme colorScheme) {
    final userId = entry.key;
    final name = entry.value;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.primary, colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Available',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Tap to start chat',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () async {
          widget.userBox.put(
            userId,
            ChatUser(
              id: userId,
              name: name,
              lastSeen: DateTime.now(),
              messages: [],
            ),
          );
          await Future.delayed(const Duration(milliseconds: 100));
          _onUserTap(widget.userBox.get(userId)!, connProvider);
        },
      ),
    );
  }

  Widget _buildChatTile(ChatUser user, ConnectionStateProvider connProvider,
      ColorScheme colorScheme) {
    String statusText;
    Color statusColor;
    Color statusBgColor;

    final isConnected =
        connProvider.connectedPeers.any((p) => p.userId == user.id);
    if (isConnected) {
      statusText = 'Connected';
      statusColor = Colors.green;
      statusBgColor = Colors.green.withValues(alpha: .1);
    } else if (connProvider.discovered.containsKey(user.id)) {
      statusText = 'Available';
      statusColor = Colors.blue;
      statusBgColor = Colors.blue.withValues(alpha: .1);
    } else {
      statusText = 'Offline';
      statusColor = Colors.grey;
      statusBgColor = Colors.grey.withValues(alpha: .1);
    }

    int unreadCount = user.messages.where((m) => !m.isMe && !m.isRead).length;
    String lastMsg = user.messages.isNotEmpty ? user.messages.last.text : '';
    String msgType = user.messages.isNotEmpty ? user.messages.last.type : '';
    String lastTime = user.messages.isNotEmpty
        ? _formatTime(user.messages.last.timestamp)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onLongPress: () => _showDeleteDialog(user),
        leading: Stack(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withValues(alpha: .7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (lastTime.isNotEmpty)
              Text(
                lastTime,
                style: TextStyle(
                  color: unreadCount > 0 ? Colors.green : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      if (msgType == 'image')
                        const Icon(Icons.image, color: Colors.grey, size: 16)
                      else if (msgType == 'audio')
                        const Icon(
                          Icons.music_note,
                          color: Colors.grey,
                          size: 16,
                        )
                      else if (msgType == 'video')
                        const Icon(Icons.video_camera_back,
                            color: Colors.grey, size: 16)
                      else if (msgType == 'file')
                        const Icon(Icons.file_present,
                            color: Colors.grey, size: 16)
                      else if (msgType == 'text')
                        Expanded(
                          child: Text(
                            lastMsg.isNotEmpty ? lastMsg : statusText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? Colors.black87
                                  : Colors.grey,
                              fontSize: 13,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      if (msgType != 'text' && msgType.isNotEmpty)
                        const SizedBox(width: 4),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _onUserTap(user, connProvider),
      ),
    );
  }

  Widget _buildStatusTab(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Status Feature',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Coming soon!',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallsTab(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.call,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Voice & Video Calls',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Coming soon!',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, ColorScheme colorScheme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Chats Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the discover button to find nearby devices',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton(
      ConnectionStateProvider connProvider, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: connProvider.discovering
              ? [Colors.red, Colors.red.shade700]
              : [colorScheme.primary, colorScheme.secondary],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (connProvider.discovering ? Colors.red : colorScheme.primary)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: 'home-screen',
        onPressed: connProvider.discovering
            ? widget.stopDiscovery
            : () => widget.startDiscovery(connProvider),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Icon(
          connProvider.discovering
              ? Icons.stop_rounded
              : Icons.wifi_tethering_outlined,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(ChatUser user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (now.difference(dt).inDays == 0) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else if (now.difference(dt).inDays == 1) {
      return 'Yesterday';
    } else {
      return "${dt.day}/${dt.month}/${dt.year}";
    }
  }
}
