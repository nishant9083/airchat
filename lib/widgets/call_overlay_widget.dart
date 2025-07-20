import 'dart:io';

import 'package:airchat/services/overlay_service.dart';
import 'package:airchat/ui/calling_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/call_state_provider.dart';
import '../models/chat_user.dart';
import '../services/connection_service.dart';

class CallOverlayWidget extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const CallOverlayWidget({super.key, required this.navigatorKey});

  String _getStatusText(CallState callState) {
    switch (callState) {
      case CallState.ringing:
        return 'Incoming call...';
      case CallState.calling:
        return 'Calling...';
      case CallState.inCall:
        return 'In call';
      case CallState.ended:
        return 'Call ended';
      default:
        return '';
    }
  }

  Color _getBgColor(CallState callState) {
    switch (callState) {
      case CallState.ringing:
        return Colors.blue[700]!;
      case CallState.calling:
        return Colors.orange[700]!;
      case CallState.inCall:
        return Colors.green[700]!;
      default:
        return Colors.grey[800]!;
    }
  }

  IconData _getStatusIcon(CallState callState) {
    switch (callState) {
      case CallState.ringing:
        return Icons.phone_in_talk_rounded;
      case CallState.calling:
        return Icons.phone_forwarded_rounded;
      case CallState.inCall:
        return Icons.call_rounded;
      case CallState.ended:
        return Icons.call_end_rounded;
      default:
        return Icons.phone;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallStateProvider>(
      builder: (context, callProvider, _) {
        final String? userId = callProvider.currentCallUserId;
        final CallState callState = callProvider.callState;
        return FutureBuilder<Box<ChatUser>>(
          future: Hive.openBox<ChatUser>('chat_users'),
          builder: (context, snapshot) {
            ChatUser? user;
            if (snapshot.hasData && userId != null) {
              user = snapshot.data!.get(userId);
            }
            final Color bgColor = _getBgColor(callState);

            // Modern glassmorphic overlay with floating controls
            return Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    callProvider.setCallingScreen(true);
                    if (Platform.isAndroid || Platform.isIOS) {
                      navigatorKey.currentState?.push(
                        MaterialPageRoute(
                          builder: (_) => CallScreen(user: user!),
                        ),
                      );
                    } else {
                      DraggableOverlayService().showOverlay(user!);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: bgColor.withValues(alpha: 0.85),
                      // borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: bgColor.withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top > 0
                          ? MediaQuery.of(context).padding.top + 5
                          : 15,
                      left: 22,
                      right: 22,
                      bottom: 15,
                    ),
                    child: Row(
                      children: [
                        // Avatar with animated ring
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: SweepGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0.15),
                                    bgColor.withValues(alpha: 0.5),
                                    Colors.white.withValues(alpha: 0.15),
                                  ],
                                ),
                              ),
                            ),
                            CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 22,
                              child: Text(
                                user?.name.isNotEmpty == true
                                    ? user!.name[0]
                                    : '?',
                                style: TextStyle(
                                  color: bgColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        // Name and status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getStatusIcon(callState),
                                    color: Colors.white.withValues(alpha: 0.85),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      user?.name ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 18,
                                        letterSpacing: 0.2,
                                        decoration: TextDecoration.none,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _getStatusText(callState),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              if (callState == CallState.inCall)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2.0),
                                  child: Text(
                                    callProvider.formattedCallDuration,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Action buttons (no Tooltip to avoid Overlay error)
                        if (callState == CallState.ringing) ...[
                          _GlassActionButton(
                            icon: Icons.call,
                            color: Colors.green[600]!,
                            label: 'Accept',
                            onTap: () async {
                              callProvider.acceptCall();
                              if (Platform.isAndroid || Platform.isIOS) {
                                if (context.mounted) {
                                  navigatorKey.currentState?.push(
                                    MaterialPageRoute(
                                      builder: (_) => CallScreen(user: user!),
                                    ),
                                  );
                                }
                              } else {
                                DraggableOverlayService().showOverlay(user!);
                              }
                              await ConnectionService.sendCallAccept(user!.id);
                            },
                          ),
                          const SizedBox(width: 10),
                          _GlassActionButton(
                            icon: Icons.call_end,
                            color: Colors.red[700]!,
                            label: 'Reject',
                            onTap: () async {
                              await ConnectionService.updateCallDuration(
                                  callProvider.currentCallUserId!,
                                  callProvider.callId!,
                                  callProvider.callState == CallState.inCall
                                      ? callProvider.formattedCallDuration
                                      : null,
                                  callProvider.callDirection!);
                              callProvider.endCall();
                              await ConnectionService.sendCallReject(user!.id);
                            },
                          ),
                        ] else if (callState == CallState.calling) ...[
                          _GlassActionButton(
                            icon: Icons.call_end,
                            color: Colors.red[700]!,
                            label: 'Cancel',
                            onTap: () async {
                              await ConnectionService.updateCallDuration(
                                  callProvider.currentCallUserId!,
                                  callProvider.callId!,
                                  callProvider.callState == CallState.inCall
                                      ? callProvider.formattedCallDuration
                                      : null,
                                  callProvider.callDirection!);

                              callProvider.endCall();
                              await ConnectionService.sendCallEnd(
                                  user!.id, callProvider.callId!);
                            },
                          ),
                        ] else if (callState == CallState.inCall) ...[
                          _GlassActionButton(
                            icon: Icons.call_end,
                            color: Colors.red[700]!,
                            label: 'End',
                            onTap: () async {
                              await ConnectionService.updateCallDuration(
                                  callProvider.currentCallUserId!,
                                  callProvider.callId!,
                                  callProvider.callState == CallState.inCall
                                      ? callProvider.formattedCallDuration
                                      : null,
                                  callProvider.callDirection!);

                              callProvider.endCall();
                              await ConnectionService.sendCallEnd(
                                  user!.id, callProvider.callId!);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ));
          },
        );
      },
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _GlassActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Semantics(
            label: label,
            button: true,
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
