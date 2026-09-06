package com.mixypunk.askasound

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.SharedPreferences

/**
 * Reçoit les mises à jour depuis Flutter (via MethodChannel dans MainActivity)
 * et actualise le widget.
 */
class WidgetReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_UPDATE = "com.mixypunk.askasound.WIDGET_UPDATE"
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == ACTION_UPDATE) {
            val prefs: SharedPreferences =
                ctx.getSharedPreferences(AskariaWidget.PREFS, Context.MODE_PRIVATE)

            intent.getStringExtra("title")?.let      { prefs.edit().putString(AskariaWidget.KEY_TITLE,  it).apply() }
            intent.getStringExtra("artist")?.let     { prefs.edit().putString(AskariaWidget.KEY_ARTIST, it).apply() }
            intent.getStringExtra("art_url")?.let    { prefs.edit().putString(AskariaWidget.KEY_ART_URL, it).apply() }
            intent.getStringExtra("auth_token")?.let { prefs.edit().putString(AskariaWidget.KEY_TOKEN,   it).apply() }
            val playing = intent.getBooleanExtra("playing", false)
            prefs.edit().putBoolean(AskariaWidget.KEY_PLAYING, playing).apply()

            // Rafraîchir tous les widgets
            AskariaWidget.updateAll(ctx)
        }
    }
}
