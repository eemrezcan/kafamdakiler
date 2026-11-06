package com.eemrezcan.kafamdakiler

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

// The one-button home screen widget. A tap opens MainActivity with the same extra the quick_actions plugin puts on
// an app shortcut ("some unique action key" = "yakala"), so the Dart side handles it exactly like the "Yakala"
// shortcut, on cold and warm start (lib/data/services/paylasim_kaynagi.dart). No data is shown, so no updates.
class YakalaWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val intent = Intent(context, MainActivity::class.java)
            .putExtra(QUICK_ACTIONS_EXTRA, YAKALA_TURU)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val dokunma = PendingIntent.getActivity(
            context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val gorunum = RemoteViews(context.packageName, R.layout.widget_yakala)
        gorunum.setOnClickPendingIntent(R.id.widget_kok, dokunma)
        appWidgetManager.updateAppWidget(appWidgetIds, gorunum)
    }

    private companion object {
        // Private constant of the quick_actions_android plugin; keep in step with it (see README, "Mobile app").
        const val QUICK_ACTIONS_EXTRA = "some unique action key"
        const val YAKALA_TURU = "yakala"
    }
}
