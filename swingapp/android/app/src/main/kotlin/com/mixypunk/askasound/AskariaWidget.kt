package com.mixypunk.askasound

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import kotlinx.coroutines.*
import java.net.HttpURLConnection
import java.net.URL

class AskariaWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_PREV  = "com.mixypunk.askasound.WIDGET_PREV"
        const val ACTION_PLAY  = "com.mixypunk.askasound.WIDGET_PLAY"
        const val ACTION_NEXT  = "com.mixypunk.askasound.WIDGET_NEXT"

        // Données partagées entre Flutter et le widget (via SharedPreferences)
        const val PREFS        = "askaria_widget_prefs"
        const val KEY_TITLE    = "widget_title"
        const val KEY_ARTIST   = "widget_artist"
        const val KEY_PLAYING  = "widget_playing"
        const val KEY_ART_URL  = "widget_art_url"
        const val KEY_TOKEN    = "widget_auth_token"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, AskariaWidget::class.java))
            if (ids.isNotEmpty()) {
                val intent = Intent(context, AskariaWidget::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onUpdate(ctx: Context, mgr: AppWidgetManager, ids: IntArray) {
        ids.forEach { updateWidget(ctx, mgr, it) }
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        super.onReceive(ctx, intent)
        when (intent.action) {
            ACTION_PREV, ACTION_PLAY, ACTION_NEXT -> {
                // Transmettre l'action à Flutter via broadcast
                val flutterIntent = Intent(intent.action).apply {
                    setPackage(ctx.packageName)
                }
                ctx.sendBroadcast(flutterIntent)
            }
        }
    }

    private fun updateWidget(ctx: Context, mgr: AppWidgetManager, id: Int) {
        val prefs   = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val title   = prefs.getString(KEY_TITLE,   "Askaria") ?: "Askaria"
        val artist  = prefs.getString(KEY_ARTIST,  "Aucun titre en cours") ?: "Aucun titre"
        val playing = prefs.getBoolean(KEY_PLAYING, false)
        val artUrl  = prefs.getString(KEY_ART_URL, null)
        val token   = prefs.getString(KEY_TOKEN, null)

        val views = RemoteViews(ctx.packageName, R.layout.askaria_widget)

        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_artist, artist)

        // Icône play/pause selon l'état
        views.setImageViewResource(
            R.id.widget_play,
            if (playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
        )

        // PendingIntents pour les boutons
        views.setOnClickPendingIntent(R.id.widget_prev,  makePending(ctx, ACTION_PREV))
        views.setOnClickPendingIntent(R.id.widget_play,  makePending(ctx, ACTION_PLAY))
        views.setOnClickPendingIntent(R.id.widget_next,  makePending(ctx, ACTION_NEXT))

        // Clic sur le widget → ouvre l'app
        val openApp = Intent(ctx, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPending = PendingIntent.getActivity(
            ctx, 0, openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_artwork, openPending)
        views.setOnClickPendingIntent(R.id.widget_title,   openPending)
        views.setOnClickPendingIntent(R.id.widget_artist,  openPending)

        // Charger la pochette en arrière-plan
        if (artUrl != null) {
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    val bmp = loadBitmap(artUrl, token)
                    if (bmp != null) {
                        views.setImageViewBitmap(R.id.widget_artwork, bmp)
                        mgr.updateAppWidget(id, views)
                    }
                } catch (_: Exception) {}
            }
        }

        mgr.updateAppWidget(id, views)
    }

    private fun makePending(ctx: Context, action: String): PendingIntent {
        val intent = Intent(ctx, AskariaWidget::class.java).apply { this.action = action }
        return PendingIntent.getBroadcast(
            ctx, action.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun loadBitmap(url: String, token: String?): Bitmap? {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 6000
        conn.readTimeout    = 6000
        if (!token.isNullOrEmpty()) {
            conn.setRequestProperty("Authorization", "Bearer $token")
        }
        return try {
            conn.connect()
            if (conn.responseCode == 200)
                BitmapFactory.decodeStream(conn.inputStream)
            else null
        } finally {
            conn.disconnect()
        }
    }
}
