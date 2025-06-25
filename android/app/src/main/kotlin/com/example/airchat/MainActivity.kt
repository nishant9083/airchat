package com.example.airchat

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import android.os.Bundle

class MainActivity: FlutterActivity() {
    private val CHANNEL = "airchat/connection"
    private val EVENT_CHANNEL = "airchat/discoveryEvents"
    private val MESSAGE_EVENT_CHANNEL = "airchat/messageEvents"
    private val CONNECTION_EVENT_CHANNEL = "airchat/connectionEvents"
    private lateinit var nearbyHandler: NearbyHandler
    private var discoveryEvents: EventChannel.EventSink? = null
    private var messageEvents: EventChannel.EventSink? = null
    private var connectionEvents: EventChannel.EventSink? = null
    private lateinit var myUserId: String;
    private lateinit var myName: String;

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        nearbyHandler = NearbyHandler(this, this)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
                        nearbyHandler.sendMessage(userId, message)
                        result.success(null)
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
                else -> result.notImplemented()
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    discoveryEvents = events
                }
                override fun onCancel(arguments: Any?) {
                    discoveryEvents = null
                }
            }
        )
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, MESSAGE_EVENT_CHANNEL).setStreamHandler(
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
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CONNECTION_EVENT_CHANNEL).setStreamHandler(
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
    }

    fun getMyUserIdAndName(): Pair<String, String>{
        return Pair(myUserId, myName)
    }
}
