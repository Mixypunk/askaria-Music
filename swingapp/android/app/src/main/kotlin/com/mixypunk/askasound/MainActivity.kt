package com.mixypunk.askasound

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {

    private val INSTALL_CHANNEL = "com.mixypunk.askasound/install"
    private val WIDGET_CHANNEL  = "com.mixypunk.askasound/widget"
    private val WIDGET_EVENTS   = "com.mixypunk.askasound/widget_events"

    // EventChannel pour envoyer les actions du widget vers Flutter
    private var eventSink: EventChannel.EventSink? = null

    // Receiver pour les actions boutons du widget
    private val widgetActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            when (intent.action) {
                AskariaWidget.ACTION_PREV -> eventSink?.success("prev")
                AskariaWidget.ACTION_PLAY -> eventSink?.success("play")
                AskariaWidget.ACTION_NEXT -> eventSink?.success("next")
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Canal installation APK ─────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "installApk") {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_PATH", "Chemin APK manquant", null)
                        return@setMethodCallHandler
                    }
                    try { installApk(path); result.success(true) }
                    catch (e: Exception) { result.error("INSTALL_ERROR", e.message, null) }
                } else result.notImplemented()
            }

        // ── Canal mise à jour widget ────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "updateWidget") {
                    val intent = Intent(WidgetReceiver.ACTION_UPDATE).apply {
                        setPackage(packageName)
                        putExtra("title",   call.argument<String>("title")   ?: "")
                        putExtra("artist",  call.argument<String>("artist")  ?: "")
                        putExtra("art_url", call.argument<String>("art_url") ?: "")
                        putExtra("playing", call.argument<Boolean>("playing") ?: false)
                    }
                    sendBroadcast(intent)
                    result.success(true)
                } else result.notImplemented()
            }

        // ── EventChannel — actions widget → Flutter ─────────────────────
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink) {
                    eventSink = sink
                    val filter = IntentFilter().apply {
                        addAction(AskariaWidget.ACTION_PREV)
                        addAction(AskariaWidget.ACTION_PLAY)
                        addAction(AskariaWidget.ACTION_NEXT)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        registerReceiver(widgetActionReceiver, filter, RECEIVER_NOT_EXPORTED)
                    } else {
                        registerReceiver(widgetActionReceiver, filter)
                    }
                }
                override fun onCancel(args: Any?) {
                    eventSink = null
                    try { unregisterReceiver(widgetActionReceiver) } catch (_: Exception) {}
                }
            })
    }

    override fun onDestroy() {
        super.onDestroy()
        try { unregisterReceiver(widgetActionReceiver) } catch (_: Exception) {}
    }

    private fun installApk(apkPath: String) {
        val file = File(apkPath)
        if (!file.exists()) throw Exception("Fichier introuvable : $apkPath")
        val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            FileProvider.getUriForFile(this, "${applicationContext.packageName}.fileprovider", file)
        } else Uri.fromFile(file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }
}
