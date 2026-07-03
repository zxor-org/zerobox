package org.zxor.zerobox

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class MainActivity : FlutterActivity() {
    @Volatile
    private var sppSocket: BluetoothSocket? = null
    private var readThread: Thread? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb")
    private val sendLock = Object()
    private val sendExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "zerobox/classic_spp",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> connect(call, result)
                "send" -> send(call, result)
                "disconnect" -> {
                    disconnect()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "zerobox/classic_spp/events",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        requestBluetoothPermissionsIfNeeded()
    }

    @SuppressLint("MissingPermission")
    private fun connect(call: MethodCall, result: MethodChannel.Result) {
        val addr = call.argument<String>("addr")
        if (addr.isNullOrBlank()) {
            result.error("INVALID_ARGUMENT", "addr is required", null)
            return
        }
        if (!hasBluetoothConnectPermission()) {
            requestBluetoothPermissionsIfNeeded()
            result.error("MISSING_PERMISSION", "Bluetooth permission is required", null)
            return
        }

        Thread {
            try {
                disconnect()
                val adapter = BluetoothAdapter.getDefaultAdapter()
                    ?: throw IOException("BluetoothAdapter is unavailable")
                val device = adapter.getRemoteDevice(addr)

                if (adapter.isDiscovering) adapter.cancelDiscovery()
                ensureBonded(device)

                val connected = tryChannel(device, 5)
                    ?: tryChannel(device, 1)
                    ?: trySdpUuid(device)
                    ?: throw IOException("No SPP channel/UUID available")

                sppSocket = connected.socket
                startReadThread()
                mainHandler.post {
                    result.success(mapOf("channel" to connected.channel))
                }
            } catch (e: Exception) {
                disconnect()
                mainHandler.post {
                    result.error("CONNECT_FAILED", e.message ?: e.toString(), null)
                }
            }
        }.start()
    }

    private fun send(call: MethodCall, result: MethodChannel.Result) {
        val data = call.argument<ByteArray>("data")
        if (data == null) {
            result.error("INVALID_ARGUMENT", "data is required", null)
            return
        }
        val socket = sppSocket
        if (socket == null || !socket.isConnected) {
            result.error("NOT_CONNECTED", "SPP socket is not connected", null)
            return
        }

        sendExecutor.execute {
            try {
                val out = socket.outputStream
                synchronized(sendLock) {
                    var offset = 0
                    while (offset < data.size) {
                        val length = minOf(512, data.size - offset)
                        out.write(data, offset, length)
                        offset += length
                    }
                    out.flush()
                }
                mainHandler.post { result.success(null) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("SEND_FAILED", e.message ?: e.toString(), null)
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun ensureBonded(device: BluetoothDevice) {
        if (device.bondState == BluetoothDevice.BOND_BONDED) return
        val latch = CountDownLatch(1)
        val error = AtomicReference<Exception?>()
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return
                val changed = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(
                        BluetoothDevice.EXTRA_DEVICE,
                        BluetoothDevice::class.java,
                    )
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                if (changed?.address != device.address) return
                when (changed.bondState) {
                    BluetoothDevice.BOND_BONDED -> latch.countDown()
                    BluetoothDevice.BOND_NONE -> {
                        error.set(IOException("Bonding failed"))
                        latch.countDown()
                    }
                }
            }
        }

        registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))
        try {
            if (!device.createBond()) {
                throw IOException("createBond() failed")
            }
            if (!latch.await(15, TimeUnit.SECONDS)) {
                throw IOException("Bonding timed out")
            }
            error.get()?.let { throw it }
        } finally {
            try {
                unregisterReceiver(receiver)
            } catch (_: IllegalArgumentException) {
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun tryChannel(device: BluetoothDevice, channel: Int): ConnectedSocket? {
        val methods = listOf("createInsecureRfcommSocket", "createRfcommSocket")
        for (name in methods) {
            val socket = runCatching {
                val method = device.javaClass.getMethod(name, Int::class.javaPrimitiveType)
                method.invoke(device, channel) as BluetoothSocket
            }.getOrNull() ?: continue
            if (connectSocket(socket, 3_000)) return ConnectedSocket(socket, channel)
        }
        return null
    }

    @SuppressLint("MissingPermission")
    private fun trySdpUuid(device: BluetoothDevice): ConnectedSocket? {
        if (!device.fetchUuidsWithSdp()) {
            return null
        }
        repeat(20) {
            device.uuids
                ?.firstOrNull { it.uuid.toString().startsWith("00001101", ignoreCase = true) }
                ?.let { parcel ->
                    runCatching {
                        val socket = device.createInsecureRfcommSocketToServiceRecord(parcel.uuid)
                        if (connectSocket(socket, 6_000)) {
                            return ConnectedSocket(socket, -1)
                        }
                    }
                    runCatching {
                        val socket = device.createRfcommSocketToServiceRecord(parcel.uuid)
                        if (connectSocket(socket, 6_000)) {
                            return ConnectedSocket(socket, -1)
                        }
                    }
                }
            Thread.sleep(100)
        }
        return null
    }

    private fun connectSocket(socket: BluetoothSocket, timeoutMs: Long): Boolean {
        val latch = CountDownLatch(1)
        val connected = AtomicReference(false)
        val connector = Thread {
            try {
                socket.connect()
                connected.set(true)
            } catch (_: IOException) {
            } finally {
                latch.countDown()
            }
        }
        connector.start()
        if (!latch.await(timeoutMs, TimeUnit.MILLISECONDS) || !connected.get()) {
            try {
                socket.close()
            } catch (_: IOException) {
            }
            return false
        }
        return true
    }

    private fun startReadThread() {
        val socket = sppSocket ?: return
        val thread = Thread {
            val buffer = ByteArray(1024)
            try {
                val input = socket.inputStream
                while (!Thread.currentThread().isInterrupted) {
                    val length = input.read(buffer)
                    if (length <= 0) break
                    val packet = buffer.copyOf(length)
                    mainHandler.post { eventSink?.success(packet) }
                }
            } catch (e: IOException) {
                mainHandler.post { eventSink?.error("READ_FAILED", e.message, null) }
            } finally {
                if (readThread == Thread.currentThread()) {
                    disconnect()
                }
            }
        }.also { it.start() }
        readThread = thread
    }

    private fun disconnect() {
        val thread = readThread
        readThread = null
        if (thread != null && thread != Thread.currentThread()) {
            thread.interrupt()
        }
        try {
            sppSocket?.close()
        } catch (_: IOException) {
        }
        sppSocket = null
    }

    private fun hasBluetoothConnectPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestBluetoothPermissionsIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        val missing = listOf(
            Manifest.permission.BLUETOOTH_SCAN,
            Manifest.permission.BLUETOOTH_CONNECT,
        ).filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isNotEmpty()) {
            requestPermissions(missing.toTypedArray(), 0x5A10)
        }
    }

    private data class ConnectedSocket(
        val socket: BluetoothSocket,
        val channel: Int,
    )

    override fun onDestroy() {
        sendExecutor.shutdownNow()
        super.onDestroy()
    }
}
