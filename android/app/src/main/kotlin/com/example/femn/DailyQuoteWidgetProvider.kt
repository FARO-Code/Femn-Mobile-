package com.example.femn

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class DailyQuoteWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_daily_quote).apply {
                val quote = widgetData.getString("quote_text", "Open App for Daily Quote")
                val author = widgetData.getString("quote_author", "")

                setTextViewText(R.id.widget_quote, quote)
                setTextViewText(R.id.widget_author, author)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
