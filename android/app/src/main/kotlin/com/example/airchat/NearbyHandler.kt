package com.example.airchat

import android.content.Context
import android.util.Log
import com.google.android.gms.nearby.Nearby
import com.google.android.gms.nearby.connection.ConnectionLifecycleCallback
import com.google.android.gms.nearby.connection.ConnectionResolution
import com.google.android.gms.nearby.connection.ConnectionsClient
import com.google.android.gms.nearby.connection.PayloadCallback
import com.google.android.gms.nearby.connection.Payload
import com.google.android.gms.nearby.connection.ConnectionInfo
import com.google.android.gms.nearby.connection.PayloadTransferUpdate
import com.google.android.gms.nearby.connection.EndpointDiscoveryCallback
import com.google.android.gms.nearby.connection.Strategy
import com.google.android.gms.nearby.connection.DiscoveredEndpointInfo
import io.flutter.plugin.common.EventChannel
import com.google.android.gms.common.api.ApiException
import java.io.File

class NearbyHandler(private val mainActivity: MainActivity, val context: Context) {
    private val connectionsClient: ConnectionsClient = Nearby.getConnectionsClient(context)
    private val serviceId = "com.example.airchat.SERVICE_ID"
    private val strategy = Strategy.P2P_CLUSTER
    private var discoveryEvents: EventChannel.EventSink? = null
    private var messageEventSink: EventChannel.EventSink? = null
    private var connectionEventSink: EventChannel.EventSink? = null
    private var fileEventSink: EventChannel.EventSink? = null
    private var fileTransferProgressEvents: EventChannel.EventSink? = null
    private val connectedEndpoints = mutableSetOf<String>()
    private val endpointIdToUser: MutableMap<String, Pair<String, String>> =
        mutableMapOf() // endpointId -> (userId, name)
    private val pendingHandshake: MutableSet<String> =
        mutableSetOf() // endpointIds waiting for handshake
    private val incomingFilePayloads = mutableMapOf<Long, Pair<Payload, String>>() // payloadId -> (Payload, endpointId)
    private val incomingFileMetadata = mutableMapOf<Long, Triple<String, String, String>>() // payloadId -> (endpointId, userId, name)

    fun startDiscovery(eventSink: EventChannel.EventSink?) {
        discoveryEvents = eventSink
        Log.d("NearbyHandler", "Starting discovery...")
        try {
            connectionsClient.startDiscovery(
                serviceId,
                object : EndpointDiscoveryCallback() {
                    override fun onEndpointFound(endpointId: String, info: DiscoveredEndpointInfo) {
                        Log.d(
                            "NearbyHandler",
                            "Endpoint found: $endpointId, name: ${info.endpointName}"
                        )
                        try {
                            val json = org.json.JSONObject(info.endpointName)
                            val userId = json.optString("userId", endpointId)
                            val name = json.optString("name", "Unknown")
                            // Remove any previous endpointId for this userId to ensure uniqueness
                            endpointIdToUser.entries.removeIf { it.value.first == userId }
                            endpointIdToUser[endpointId] = Pair(userId, name)
                            if (!connectedEndpoints.contains(endpointId)) {
                            val data = mapOf("type" to "found", "id" to userId, "name" to name)
                            discoveryEvents?.success(data)
                            }
                        } catch (e: Exception) {
                            endpointIdToUser[endpointId] = Pair(endpointId, info.endpointName)
                            val data = mapOf(
                                "type" to "found",
                                "id" to endpointId,
                                "name" to info.endpointName
                            )
                            discoveryEvents?.success(data)
                        }
                    }

                    override fun onEndpointLost(endpointId: String) {
                        Log.d("NearbyHandler", "Endpoint lost: $endpointId")
                        val userId = endpointIdToUser[endpointId]?.first ?: endpointId
                        if(!connectedEndpoints.contains(endpointId)){
                        endpointIdToUser.remove(endpointId)
                        pendingHandshake.remove(endpointId)
                        val data = mapOf("type" to "lost", "id" to userId)
                        discoveryEvents?.success(data)
                        }
                    }
                },
                com.google.android.gms.nearby.connection.DiscoveryOptions.Builder()
                    .setStrategy(strategy).build()
            )
        } catch (e: ApiException) {
            Log.e("NearbyHandler", "APIException occurred: ${e.message}")
            discoveryEvents?.error("DISCOVERY_ERROR", e.message, e)
        } catch (e: Exception) {
            Log.e("NearbyHandler", "Exception occurred: ${e.message}")
            discoveryEvents?.error("DISCOVERY_ERROR", e.message, e)
        }
    }

    fun stopDiscovery() {
        Log.d("NearbyHandler", "Stopping discovery...")
        connectionsClient.stopDiscovery()
    }

    fun startAdvertising(endpointInfo: String) {
        Log.d("NearbyHandler", "Starting advertising...")
        try {
            connectionsClient.startAdvertising(
                endpointInfo,
                serviceId,
                object : ConnectionLifecycleCallback() {
                    override fun onConnectionInitiated(
                        endpointId: String,
                        connectionInfo: ConnectionInfo
                    ) {
                        Log.d("NearbyHandler", "Connection initiated (advertiser): $endpointId")
                        pendingHandshake.add(endpointId)
                        connectionsClient.acceptConnection(endpointId, object : PayloadCallback() {
                            override fun onPayloadReceived(endpointId: String, payload: Payload) {
                                Log.d("NearbyHandler", "Payload received from $endpointId (advertiser)")
                                if (payload.type == Payload.Type.FILE) {
                                    incomingFilePayloads[payload.id] = Pair(payload, endpointId)
                                    val (userId, name) = endpointIdToUser[endpointId] ?: Pair(endpointId, "Unknown")
                                    incomingFileMetadata[payload.id] = Triple(endpointId, userId, name)
                                    Log.d("NearbyHandler", "File payload registered, waiting for transfer update. PayloadId: ${payload.id}")
                                    return
                                }
                                payload.asBytes()?.let {
                                    try {
                                        val json = org.json.JSONObject(String(it))
                                        val userId = json.optString("userId", endpointId)
                                        val name = json.optString("name", "Unknown")
                                        val message = json.optString("message", "")

                                        // Expect handshake JSON as first payload
                                        if (pendingHandshake.contains(endpointId)) {
                                        endpointIdToUser[endpointId] = Pair(userId, name)
                                        pendingHandshake.remove(endpointId)
                                            connectionEventSink?.success(
                                                mapOf(
                                                    "type" to "connected",
                                                    "id" to userId,
                                                    "name" to name
                                                )
                                            )
                                        Log.d("NearbyHandler", "Handshake received: $userId, $name")
                                        }

                                        if(message.isNotEmpty()){
                                            messageEventSink?.success(
                                                mapOf(
                                                    "from" to userId,
                                                    "payloadId" to payload.id,
                                                    "name" to name,
                                                    "message" to message
                                                )
                                            )
                                        }
                                        else{
                                        connectionEventSink?.success(mapOf("type" to "connected", "id" to userId, "name" to name))
                                        }
                                    } catch (e: Exception) {
                                        Log.e(
                                            "NearbyHandler",
                                            "Failed to parse handshake: ${e.message}"
                                        )
                                    }
                                }
                            }

                            override fun onPayloadTransferUpdate(
                                endpointId: String,
                                update: PayloadTransferUpdate
                            ) {
                                Log.d("NearbyHandler", "Payload transfer update from $endpointId (advertiser): ${update.payloadId}, status: ${update.status}")
                                // Send progress to Flutter
                                fileTransferProgressEvents?.success(mapOf(
                                    "payloadId" to update.payloadId,
                                    "bytesTransferred" to update.bytesTransferred,
                                    "totalBytes" to update.totalBytes,
                                    "status" to update.status
                                ))
                                if (update.status == PayloadTransferUpdate.Status.SUCCESS) {
                                    val pair = incomingFilePayloads.remove(update.payloadId)
                                    val meta = incomingFileMetadata.remove(update.payloadId)
                                    if (pair != null && meta != null) {
                                        val (payload, _) = pair
                                        val (_, userId, name) = meta
                                        val uri = payload.asFile()?.asUri()
                                        val inputStream = uri?.let {
                                            context.contentResolver.openInputStream(it)
                                        }
                                        val file = File(context.filesDir, File(uri?.lastPathSegment ?: "received_file").name)
                                        inputStream?.use { input ->
                                            file.outputStream().use { output ->
                                                input.copyTo(output)
                                            }
                                        }
                                        if (uri != null) {
                                            fileEventSink?.success(mapOf(
                                                "payloadId" to update.payloadId,
                                                "from" to userId,
                                                "name" to name,
                                                "filePath" to file.absolutePath,
                                                "type" to when (file.extension.lowercase()) {
                                                    in listOf("jpg", "jpeg", "png", "gif", "bmp", "webp") -> "image"
                                                    in listOf("mp4", "mov", "avi", "mkv", "webm") -> "video"
                                                    else -> "file"
                                                },
                                                "fileName" to uri.lastPathSegment?.let { File(it).name }
                                            ))
                                            Log.d("NearbyHandler", "File received: ${file.absolutePath}")
                                        }
                                    }
                                }
                            }
                        })
                    }

                    override fun onConnectionResult(
                        endpointId: String,
                        result: ConnectionResolution
                    ) {
                        Log.d(
                            "NearbyHandler",
                            "Connection result (advertiser): $endpointId, status: ${result.status.statusCode}"
                        )
                        if (result.status.isSuccess) {
                            connectedEndpoints.add(endpointId)
                        } else {
                            val (userId, name) = endpointIdToUser[endpointId] ?: Pair(
                                endpointId,
                                "Unknown"
                            )
                            connectionEventSink?.success(
                                mapOf(
                                    "type" to "failed",
                                    "id" to userId,
                                    "name" to name,
                                    "status" to result.status.statusCode
                                )
                            )
                        }
                    }

                    override fun onDisconnected(endpointId: String) {
                        Log.d("NearbyHandler", "Disconnected (advertiser): $endpointId")
                        connectedEndpoints.remove(endpointId)
                        val (userId, name) = endpointIdToUser[endpointId] ?: Pair(
                            endpointId,
                            "Unknown"
                        )
                        connectionEventSink?.success(
                            mapOf(
                                "type" to "disconnected",
                                "id" to userId,
                                "name" to name
                            )
                        )
                    }
                },
                com.google.android.gms.nearby.connection.AdvertisingOptions.Builder()
                    .setStrategy(strategy).build()
            )
        } catch (e: Exception) {
            Log.e("NearbyHandler", "Error starting advertising: ${e.message}")
            connectionEventSink?.error("ADVERTISING_ERROR", e.message, e)
        }
    }

    fun stopAdvertising() {
        Log.d("NearbyHandler", "Stopping advertising...")
        try {
            connectionsClient.stopAdvertising()
        } catch (e: Exception) {
            Log.e("NearbyHandler", "Error stopping advertising: ${e.message}")
            connectionEventSink?.error("ADVERTISING_ERROR", e.message, e)
        }
    }

    fun connectToDevice(userId: String) {
        val endpointId = getEndpointIdForUserId(userId)
        if (endpointId == null) {
            Log.d("NearbyHandler", "No endpointId found for userId $userId")
            return
        }
        if (connectedEndpoints.contains(endpointId)) {
            Log.d(
                "NearbyHandler",
                "Already connected to $endpointId, not initiating duplicate connection."
            )
            connectionEventSink?.success(
                mapOf(
                    "type" to "connected",
                    "id" to userId,
                    "name" to (endpointIdToUser[endpointId]?.second
                        ?: "Unknown")
                )
            )
            return
        }
        Log.d("NearbyHandler", "Requesting connection to $endpointId for userId $userId")
        try {
            connectionsClient.requestConnection(
                endpointIdToUser[endpointId]?.second ?: "AirChatUser",
                endpointId,
                object : ConnectionLifecycleCallback() {
                    override fun onConnectionInitiated(
                        endpointId: String,
                        connectionInfo: ConnectionInfo
                    ) {
                        Log.d("NearbyHandler", "Connection initiated: $endpointId")
                        connectionsClient.acceptConnection(endpointId, object : PayloadCallback() {
                            override fun onPayloadReceived(endpointId: String, payload: Payload) {
                                Log.d("NearbyHandler", "Payload received from $endpointId")
                                if (payload.type == Payload.Type.FILE) {
                                    incomingFilePayloads[payload.id] = Pair(payload, endpointId)
                                    val (fromUserId, name) = endpointIdToUser[endpointId] ?: Pair(endpointId, "Unknown")
                                    incomingFileMetadata[payload.id] = Triple(endpointId, fromUserId, name)
                                    Log.d("NearbyHandler", "File payload registered, waiting for transfer update. PayloadId: ${payload.id}")
                                    return
                                }
                                payload.asBytes()?.let {
                                    try {
                                        val json = org.json.JSONObject(String(it))
                                        val inUserId = json.optString("userId", endpointId)
                                        val name = json.optString("name", "Unknown")
                                        val message = json.optString("message", "")
                                        messageEventSink?.success(
                                            mapOf(
                                                "from" to inUserId,
                                                "payloadId" to payload.id,
                                                "name" to name,
                                                "message" to message
                                            )
                                        )
                                    }
                                    catch (e: Exception) {
                                        Log.e("NearbyHandler", "Failed to parse payload: ${e.message}")
                                    }
                                }
                            }

                            override fun onPayloadTransferUpdate(
                                endpointId: String,
                                update: PayloadTransferUpdate
                            ) {
                                Log.d("NearbyHandler", "Payload transfer update from $endpointId: ${update.payloadId}, status: ${update.status}")
                                // Send progress to Flutter
                                fileTransferProgressEvents?.success(mapOf(
                                    "payloadId" to update.payloadId,
                                    "bytesTransferred" to update.bytesTransferred,
                                    "totalBytes" to update.totalBytes,
                                    "status" to update.status
                                ))
                                if (update.status == PayloadTransferUpdate.Status.SUCCESS) {
                                    val pair = incomingFilePayloads.remove(update.payloadId)
                                    val meta = incomingFileMetadata.remove(update.payloadId)
                                    if (pair != null && meta != null) {
                                        val (payload, _) = pair
                                        val (_, fromUserId, name) = meta
                                        val uri = payload.asFile()?.asUri()
                                        val inputStream = uri?.let {
                                            context.contentResolver.openInputStream(it)
                                        }
                                        val file = File(context.filesDir, File(uri?.lastPathSegment ?: "received_file").name)
                                        inputStream?.use { input ->
                                            file.outputStream().use { output ->
                                                input.copyTo(output)
                                            }
                                        }
                                        if (uri != null) {
                                            fileEventSink?.success(mapOf(
                                                "payloadId" to update.payloadId,
                                                "from" to fromUserId,
                                                "name" to name,
                                                "filePath" to file.absolutePath,
                                                "type" to when (file.extension.lowercase()) {
                                                    in listOf("jpg", "jpeg", "png", "gif", "bmp", "webp") -> "image"
                                                    in listOf("mp4", "mov", "avi", "mkv", "webm") -> "video"
                                                    else -> "file"
                                                },
                                                "fileName" to uri.lastPathSegment?.let { File(it).name }
                                            ))
                                            Log.d("NearbyHandler", "File received: ${file.absolutePath}")
                                        }
                                    }
                                }
                            }
                        })
                    }

                    override fun onConnectionResult(
                        endpointId: String,
                        result: ConnectionResolution
                    ) {
                        Log.d(
                            "NearbyHandler",
                            "Connection result: $endpointId, status: ${result.status.statusCode}"
                        )
                        if (result.status.isSuccess) {
                            connectedEndpoints.add(endpointId)
                            val (_, name) = endpointIdToUser[endpointId] ?: Pair(
                                endpointId,
                                "Unknown"
                            )
                            // Send handshake as first payload
                            val (myUserId, myName) = mainActivity.getMyUserIdAndName()
                            val handshake =
                                org.json.JSONObject(mapOf("userId" to myUserId, "name" to myName))
                                    .toString()
                            // Send handshake payload
                            connectionsClient.sendPayload(
                                endpointId,
                                Payload.fromBytes(handshake.toByteArray())
                            )
                            Log.d(
                                "NearbyHandler",
                                "Handshake sent to $endpointId: $handshake"
                            )
                            connectionEventSink?.success(
                                mapOf(
                                    "type" to "connected",
                                    "id" to userId,
                                    "name" to name
                                )
                            )
                        } else {
                            val (_, name) = endpointIdToUser[endpointId] ?: Pair(
                                endpointId,
                                "Unknown"
                            )
                            connectionEventSink?.success(
                                mapOf(
                                    "type" to "failed",
                                    "id" to userId,
                                    "name" to name,
                                    "status" to result.status.statusCode
                                )
                            )
                        }
                    }

                    override fun onDisconnected(endpointId: String) {
                        Log.d("NearbyHandler", "Disconnected: $endpointId")
                        connectedEndpoints.remove(endpointId)
                        val (_, name) = endpointIdToUser[endpointId] ?: Pair(
                            endpointId,
                            "Unknown"
                        )
                        connectionEventSink?.success(
                            mapOf(
                                "type" to "disconnected",
                                "id" to userId,
                                "name" to name
                            )
                        )
                    }
                }
            )
        } catch (e: Exception) {
            Log.e("NearbyHandler", "Error connecting to device: ${e.message}")
            connectionEventSink?.error("CONNECTION_ERROR", e.message, e)
        }
    }

    fun setMessageEventSink(sink: EventChannel.EventSink?) {
        messageEventSink = sink
    }

    fun setConnectionEventSink(sink: EventChannel.EventSink?) {
        connectionEventSink = sink
    }

    fun setFileEventSink(sink: EventChannel.EventSink?) {
        fileEventSink = sink
    }
    fun setFileTransferProgressEventSink(sink: EventChannel.EventSink?) {
        fileTransferProgressEvents = sink
    }


    fun sendMessage(userId: String, message: String): Long? {
        val endpointId = getEndpointIdForUserId(userId)
        if (endpointId == null) {
            Log.d("NearbyHandler", "No endpointId found for userId $userId")
            return null
        }
        val (myUserId, myName) = mainActivity.getMyUserIdAndName()
        val data =
            org.json.JSONObject(mapOf("userId" to myUserId, "name" to myName, "message" to message))
                .toString()
        val payload = Payload.fromBytes(data.toByteArray())
        connectionsClient.sendPayload(endpointId, payload)
        Log.d("NearbyHandler", "Sent message to $endpointId: $message")
        return payload.id
    }

    fun sendFile(userId: String, filePath: String, fileName: String): Long? {
        val endpointId = getEndpointIdForUserId(userId)
        if (endpointId == null) {
            Log.d("NearbyHandler", "No endpointId found for userId $userId")
            return null
        }
        val file = File(filePath)
        if (!file.exists()) {
            Log.d("NearbyHandler", "File does not exist: $filePath")
            return null
        }
        val payload = Payload.fromFile(file)
        payload.setFileName(fileName)
        connectionsClient.sendPayload(endpointId, payload)
        Log.d("NearbyHandler", "Sent file to $endpointId: $filePath")
        return payload.id
    }

    fun getEndpointIdForUserId(userId: String): String? {
        return endpointIdToUser.entries.firstOrNull { it.value.first == userId }?.key
    }

    fun getConnectedUsers(): List<Map<String, String>> {
        return connectedEndpoints.mapNotNull { endpointId ->
            val (userId, name) = endpointIdToUser[endpointId] ?: return@mapNotNull null
            mapOf("id" to userId, "name" to name)
        }
    }

    fun getDiscoveredUsers(): List<Map<String, String>> {
        return endpointIdToUser.map { (_, userInfo) ->
            val (userId, name) = userInfo
            mapOf("id" to userId, "name" to name)
        }
    }
    fun cleanup() {
        try {
            // Stop discovery and advertising
            stopDiscovery()
            stopAdvertising()

            // Disconnect from all endpoints
            val endpoints = ArrayList(connectedEndpoints)
            for (endpointId in endpoints) {
                connectionsClient.disconnectFromEndpoint(endpointId)
            }

            // Clear collections
            connectedEndpoints.clear()
            endpointIdToUser.clear()
            pendingHandshake.clear()
            incomingFilePayloads.clear()
            incomingFileMetadata.clear()

            // Reset all event sinks
            messageEventSink = null
            connectionEventSink = null
            fileEventSink = null
            fileTransferProgressEvents = null
            discoveryEvents = null
        } catch (e: Exception) {
            Log.e("NearbyHandler", "Error during cleanup: ${e.message}")
        }
    }
} 