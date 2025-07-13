import 'dart:developer';

import 'package:airchat/services/calling_service.dart';
import 'package:airchat/services/connection_service.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:just_audio/just_audio.dart'; // Added for Timer

enum CallState {
  idle,
  calling,
  ringing,
  inCall,
  ended,
}

class CallStateProvider extends ChangeNotifier {
  String? currentCallUserId;
  String? callId;
  CallState callState = CallState.idle;
  DateTime? callStartTime;
  String? callDirection;
  bool isMuted = false;
  bool isCallingScreenOpen = false;
  Timer? _callTimeoutTimer; // Added for call timeout timer
  final AudioPlayer _ringtonePlayer = AudioPlayer();

  void setCallingScreen(bool state) {
    isCallingScreenOpen = state;
    notifyListeners();
  }

  void startOutgoingCall(String userId, String id) {
    isCallingScreenOpen = true;
    currentCallUserId = userId;
    callId = id;
    callDirection = 'Outgoing';
    callState = CallState.calling;
    callStartTime = DateTime.now();
    isMuted = false;
    _playCallingRingtone();
    notifyListeners();
    _callTimeoutTimer?.cancel(); // Cancel any previous timer
    _callTimeoutTimer = Timer(Duration(seconds: 60), () async {
      // If call is still not accepted, end it
      if (callState == CallState.calling) {
        await endCallDueToTimeout();
        await _stopRingtone();
      }
    });
  }

  void receiveIncomingCall(String userId, String id) {
    isCallingScreenOpen = false;
    callId = id;
    callDirection = 'Incoming';
    currentCallUserId = userId;
    callState = CallState.ringing;
    callStartTime = null;
    isMuted = false;
    _playIncomingRingtone();
    notifyListeners();
  }

  void acceptCall() {
    isCallingScreenOpen = true;
    callState = CallState.inCall;
    callStartTime = DateTime.now();
    notifyListeners();
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
    _stopRingtone();
  }

  void endCall() {
    isCallingScreenOpen = false;
    callState = CallState.ended;
    callStartTime = null;
    callDirection = null;
    notifyListeners();
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
    Future.delayed(const Duration(seconds: 2), () {
      callState = CallState.idle;
      currentCallUserId = null;
      callId = null;
      notifyListeners();
    });
    _stopRingtone();
  }

  void setMuted(bool value) {
    isMuted = value;
    notifyListeners();
  }

  void reset() {
    callState = CallState.idle;
    currentCallUserId = null;
    callId = null;
    callDirection = null;
    callStartTime = null;
    isMuted = false;
    notifyListeners();
  }

  /// Utility to get the current call duration as a [Duration] object.
  Duration get callDuration {
    if (callState == CallState.inCall && callStartTime != null) {
      return DateTime.now().difference(callStartTime!);
    }
    return Duration.zero;
  }

  /// Utility to get the call duration as a formatted string (mm:ss).
  String get formattedCallDuration {
    final duration = callDuration;
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(duration.inMinutes)}:${twoDigits(duration.inSeconds % 60)}';
  }

  Future<void> endCallDueToTimeout() async {
    // Clean up call state and resources
    await ConnectionService.updateCallDuration(
        currentCallUserId!, callId!, null, callDirection!);
    endCall();
    await ConnectionService.sendCallEnd(currentCallUserId!, callId!);
    await LanCallService().endCall();
    notifyListeners();
    // Optionally notify user
    // showSnackbar("Call not answered");
  }

  Future<void> _playCallingRingtone() async {
    try {
      await _ringtonePlayer.setAsset('assets/ringtone/calling.mp3');
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      await _ringtonePlayer.play();
    } catch (e) {
      log('Error playing ringtone: $e');
    }
  }

  Future<void> _playIncomingRingtone() async {
    try {
      await _ringtonePlayer.setAsset('assets/ringtone/incoming.mp3');
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      await _ringtonePlayer.play();
    } catch (e) {
      log('Error playing incoming ringtone: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
    } catch (e) {
      log('Error stopping ringtone: $e');
    }
  }

  @override
  void dispose() {
    _ringtonePlayer.dispose();
    super.dispose();
  }
}
