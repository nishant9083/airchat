package com.example.airchat

import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val channel = "airchat/connection"
    private val eventChannel = "airchat/discoveryEvents"
    private val messageEventChannel = "airchat/messageEvents"
    private val connectionEventChannel = "airchat/connectionEvents"
    private val fileEventChannel = "airchat/fileEvents"
    private val fileProgressEventChannel = "airchat/fileTransferProgressEvents"
    private lateinit var nearbyHandler: NearbyHandler
    private var discoveryEvents: EventChannel.EventSink? = null
    private var messageEvents: EventChannel.EventSink? = null
    private var connectionEvents: EventChannel.EventSink? = null
    private var fileEvents: EventChannel.EventSink? = null
    private lateinit var myUserId: String
    private lateinit var myName: String

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        nearbyHandler = NearbyHandler(this, this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDiscovery" -> {
                    myName = call.argument<String>("name")?:"AirChatUser"
                    myUserId = call.argument<String>("userId")?: ""
                    if (myUserId.isEmpty()) {
                        result.error("INVALID_ARGUMENT", "User ID cannot be empty", null)
                        return@setMethodCallHandler
                    }
                    nearbyHandler.startDiscovery(discoveryEvents)
                    result.success(null)
                }
                "stopDiscovery" -> {
                    nearbyHandler.stopDiscovery()
                    result.success(null)
                }
                "startAdvertising" -> {
                    val endpointInfo = call.argument<String>("endpointInfo") ?: "{\"name\":\"AirChatUser\",\"userId\":\"unknown\"}"
                    nearbyHandler.startAdvertising(endpointInfo)
                    result.success(null)
                }
                "stopAdvertising" -> {
                    nearbyHandler.stopAdvertising()
                    result.success(null)
                }
                "sendMessage" -> {
                    val userId = call.argument<String>("userId")
                    val message = call.argument<String>("message")
                    if (userId != null && message != null) {
                       val id = nearbyHandler.sendMessage(userId, message)
                        result.success(id)
                    } else {
                        result.error("INVALID_ARGUMENT", "User ID and message required", null)
                    }
                }
                "testNative" -> {
                    result.success("Hello from Android Native!")
                }
                "connectToDevice" -> {
                    val userId = call.argument<String>("userId")
                    if (userId != null) {
                        nearbyHandler.connectToDevice(userId)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "User ID required", null)
                    }
                }
                "getEndpointIdForUserId" -> {
                    val userId = call.argument<String>("userId")
                    if (userId != null) {
                        val endpointId = nearbyHandler.getEndpointIdForUserId(userId)
                        result.success(endpointId)
                    } else {
                        result.error("INVALID_ARGUMENT", "User ID required", null)
                    }
                }
                "sendFile" -> {
                    val userId = call.argument<String>("userId")
                    val filePath = call.argument<String>("filePath")
                    val fileName = call.argument<String>("fileName")
                    if (userId != null && filePath != null && fileName != null) {
                       val id = nearbyHandler.sendFile(userId, filePath, fileName)
                        result.success(id)
                    } else {
                        result.error("INVALID_ARGUMENT", "userId, filePath, fileName, and mimeType required", null)
                    }
                }
                "getConnectedUsers" -> {
                    val connectedUsers = nearbyHandler.getConnectedUsers()
                    result.success(connectedUsers)
                }
                "getDiscoveredUsers" -> {
                    val discoveredUsers = nearbyHandler.getDiscoveredUsers()
                    result.success(discoveredUsers)
                }
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannel).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    discoveryEvents = events
                }
                override fun onCancel(arguments: Any?) {
                    discoveryEvents = null
                }
            }
        )
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, messageEventChannel).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    messageEvents = events
                    nearbyHandler.setMessageEventSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    messageEvents = null
                    nearbyHandler.setMessageEventSink(null)
                }
            }
        )
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, connectionEventChannel).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    connectionEvents = events
                    nearbyHandler.setConnectionEventSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    connectionEvents = null
                    nearbyHandler.setConnectionEventSink(null)
                }
            }
        )
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, fileEventChannel).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    fileEvents = events
                    nearbyHandler.setFileEventSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    fileEvents = null
                    nearbyHandler.setFileEventSink(null)
                }
            }
        )
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, fileProgressEventChannel).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    nearbyHandler.setFileTransferProgressEventSink(events)
                }
                override fun onCancel(arguments: Any?) {
                    nearbyHandler.setFileTransferProgressEventSink(null)
                }
            }
        )
    }

    fun getMyUserIdAndName(): Pair<String, String>{
        return Pair(myUserId, myName)
    }

    override fun onDestroy() {
            super.onDestroy()
            nearbyHandler.cleanup()
            Log.d("MainActivity", "Cleaning up native resources")
        }
}
