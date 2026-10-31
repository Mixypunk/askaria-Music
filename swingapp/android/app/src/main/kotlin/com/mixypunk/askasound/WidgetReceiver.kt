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
        const val ACTION_CLEAR  = "com.mixypunk.askasound.WIDGET_CLEAR"
    }

    override fun onReceive(ctx: Context, intent: Intent) {
        val prefs: SharedPreferences =
            ctx.getSharedPreferences(AskariaWidget.PREFS, Context.MODE_PRIVATE)

        when (intent.action) {
            ACTION_UPDATE -> {
                intent.getStringExtra("title")?.let   { prefs.edit().putString(AskariaWidget.KEY_TITLE,  it).apply() }
                intent.getStringExtra("artist")?.let  { prefs.edit().putString(AskariaWidget.KEY_ARTIST, it).apply() }
                intent.getStringExtra("art_url")?.let { prefs.edit().putString(AskariaWidget.KEY_ART_URL, it).apply() }
                val playing = intent.getBooleanExtra("playing", false)
                prefs.edit().putBoolean(AskariaWidget.KEY_PLAYING, playing).apply()
                // Supprimer tout ancien jeton résiduel
                prefs.edit().remove("token").apply()

                // Rafraîchir tous les widgets
                AskariaWidget.updateAll(ctx)
            }
            ACTION_CLEAR -> {
                prefs.edit().clear().apply()
                AskariaWidget.updateAll(ctx)
            }
        }
    }
}
