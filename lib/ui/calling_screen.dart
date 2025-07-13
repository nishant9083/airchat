// 📞 Modern Glassmorphic Calling Screen with Animated Avatar & Floating Controls
import 'dart:io';

import 'package:airchat/models/chat_user.dart';
import 'package:airchat/services/calling_service.dart';
import 'package:airchat/services/connection_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_state_provider.dart';
import 'dart:async';

class CallScreen extends StatefulWidget {
  final ChatUser user;

  const CallScreen({super.key, required this.user});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  final LanCallService _callService = LanCallService();
  late AnimationController _avatarPulseController;
  late Animation<double> _avatarPulse;
  Timer? _uiTimer;
  bool _wasInCall = false;
  bool _isMuted = false;
  bool _isSpeaker = false;
  StreamSubscription? _callEventSub;

  @override
  void initState() {
    super.initState();

    _avatarPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _avatarPulse = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _avatarPulseController, curve: Curves.easeInOut),
    );

    _callEventSub = ConnectionService.callEventsStream.listen((event) async {
      if (event['type'] == 'call_end' || event['type'] == 'call_reject') {
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _avatarPulseController.dispose();
    _callEventSub?.cancel();
    super.dispose();
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds % 60)}';
  }

  Future<void> _acceptCall(CallStateProvider callProvider) async {
    callProvider.acceptCall();
    await ConnectionService.sendCallAccept(widget.user.id);
  }

  Future<void> _rejectCall(CallStateProvider callProvider) async {
    await ConnectionService.updateCallDuration(
        callProvider.currentCallUserId!,
        callProvider.callId!,
        callProvider.callState == CallState.inCall?callProvider.formattedCallDuration:null,
        callProvider.callDirection!);
    callProvider.endCall();
    await ConnectionService.sendCallReject(widget.user.id);
    await _callService.endCall();
    // if (mounted) Navigator.of(context).pop();
  }

  Future<void> _endCall(CallStateProvider callProvider) async {
    await ConnectionService.updateCallDuration(
        callProvider.currentCallUserId!,
        callProvider.callId!,
        callProvider.callState == CallState.inCall?callProvider.formattedCallDuration:null,
        callProvider.callDirection!);
    callProvider.endCall();
    await ConnectionService.sendCallEnd(widget.user.id, callProvider.callId!);
    await _callService.endCall();
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
        return Colors.grey[900]!;
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
        return 'Connecting...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.user.name;
    final callProvider = Provider.of<CallStateProvider>(context);
    final callState = callProvider.callState;
    if (callState == CallState.idle) {
      Future.microtask(() {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return SizedBox.shrink();
    }
    final inCall = callState == CallState.inCall;
    // final isOutgoing = callState == CallState.calling;
    final isIncoming = callState == CallState.ringing;
    final callStartTime = callProvider.callStartTime;
    Duration callDuration = Duration.zero;
    if (inCall && callStartTime != null) {
      callDuration = DateTime.now().difference(callStartTime);
    }

    // Start/stop UI timer on call state change
    if (inCall && !_wasInCall) {
      _startUiTimer();
      _wasInCall = true;
    } else if (!inCall && _wasInCall) {
      _uiTimer?.cancel();
      _wasInCall = false;
    }

    final Color bgColor = _getBgColor(callState);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Glassmorphic background overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      bgColor.withValues(alpha: 0.95),
                      bgColor.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () {
                        Navigator.of(context).pop();
                        callProvider.setCallingScreen(false);
                      },
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 1),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _getStatusIcon(callState),
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 20,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _getStatusText(callState),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 2),
                  ],
                ),
              ),
            ),
            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated avatar with glass ring
                  AnimatedBuilder(
                    animation: _avatarPulse,
                    builder: (context, child) {
                      return Container(
                        width: 140 * _avatarPulse.value,
                        height: 140 * _avatarPulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.10),
                              bgColor.withValues(alpha: 0.35),
                              Colors.white.withValues(alpha: 0.10),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: bgColor.withValues(alpha: 0.18),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : "?",
                        style: TextStyle(
                          color: bgColor,
                          fontSize: 44,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _getStatusText(callState),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (inCall && callStartTime != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _formatDuration(callDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                  const SizedBox(height: 44),
                  // In-call actions (mute/speaker)
                  if (inCall) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GlassActionButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                          label: _isMuted ? 'Unmute' : 'Mute',
                          onTap: () {
                            setState(() {
                              _isMuted = !_isMuted;
                              _callService.setMuted(_isMuted);
                            });
                          },
                          isActive: _isMuted,
                        ),
                        const SizedBox(width: 28),
                        _GlassActionButton(
                          icon: _isSpeaker ? Icons.volume_up : Icons.hearing,
                          color: Colors.white,
                          label: _isSpeaker ? 'Speaker On' : 'Speaker Off',
                          onTap: () async {
                            if (!Platform.isWindows || !Platform.isLinux) {
                              await _callService.setSpeakerMode(!_isSpeaker);
                            }
                            setState(() {
                              _isSpeaker = !_isSpeaker;
                            });
                          },
                          isActive: _isSpeaker,
                        ),
                      ],
                    ),
                    const SizedBox(height: 44),
                  ],
                  // Action buttons
                  if (isIncoming) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _GlassActionButton(
                          icon: Icons.call_end,
                          color: Colors.red[700]!,
                          label: 'Reject',
                          onTap: () async {
                            await _rejectCall(callProvider);
                          },
                        ),
                        const SizedBox(width: 32),
                        _GlassActionButton(
                          icon: Icons.call,
                          color: Colors.green[600]!,
                          label: 'Accept',
                          onTap: () async {
                            await _acceptCall(callProvider);
                          },
                        ),
                      ],
                    ),
                  ] else ...[
                    _GlassActionButton(
                      icon: Icons.call_end,
                      color: Colors.red[700]!,
                      label: 'End',
                      onTap: () async {
                        await _endCall(callProvider);
                        // if (context.mounted) Navigator.of(context).pop();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _GlassActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isActive ? 0.28 : 0.16),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: color.withValues(alpha: 0.45),
            width: 1.6,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 32,
            semanticLabel: label,
          ),
        ),
      ),
    );
  }
}
