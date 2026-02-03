package com.example.femn

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PetitionWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_petition).apply {
                val title = widgetData.getString("petition_title", null)
                val current = widgetData.getInt("petition_current", 0)
                val goal = widgetData.getInt("petition_goal", 1)
                
                // Safe read for progress which might be stored as Float (old) or String (new)
                val progress: Float = try {
                    val str = widgetData.getString("petition_progress", "0.0")
                    str?.toFloatOrNull() ?: 0.0f
                } catch (e: ClassCastException) {
                    try {
                        widgetData.getFloat("petition_progress", 0.0f)
                    } catch (e2: ClassCastException) {
                        0.0f
                    }
                }
                
                if (title == null) {
                    setTextViewText(R.id.widget_title, "Tap to Select Petition")
                    setProgressBar(R.id.widget_progress_bar, 100, 0, false)
                    setTextViewText(R.id.widget_count, "-- / --")
                    setViewVisibility(R.id.widget_image_container, android.view.View.GONE)
                } else {
                    setTextViewText(R.id.widget_title, title)
                    setProgressBar(R.id.widget_progress_bar, 100, (progress * 100).toInt(), false)
                    setTextViewText(R.id.widget_count, "$current / $goal signatures")

                    val imagePath = widgetData.getString("petition_image_path", null)
                    if (imagePath != null) {
                        val file = java.io.File(imagePath)
                        if (file.exists()) {
                            try {
                                val bitmap = android.graphics.BitmapFactory.decodeFile(file.absolutePath)
                                if (bitmap != null) {
                                    setImageViewBitmap(R.id.widget_banner_image, bitmap)
                                    setViewVisibility(R.id.widget_image_container, android.view.View.VISIBLE)
                                } else {
                                    setViewVisibility(R.id.widget_image_container, android.view.View.GONE)
                                }
                            } catch (e: Exception) {
                                setViewVisibility(R.id.widget_image_container, android.view.View.GONE)
                            }
                        } else {
                            setViewVisibility(R.id.widget_image_container, android.view.View.GONE)
                        }
                    } else {
                        setViewVisibility(R.id.widget_image_container, android.view.View.GONE)
                    }
                }

                // Intent to open the app (Deep Link to Picker if unconfigured, or just open app)
                // For simplicity, we open the picker via a deep link mechanism or just open the app.
                // Since this uses HomeWidget, we can use the background intent.
                
                // Using a generic intent to open the app. 
                // In a real scenario, you'd pass a URI to deep link to the specific petition.
                // For "Tap to Select", we want to go to the Picker.
                
                // Construct an Intent which points to the flutter activity
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    // We can use a custom URI scheme to route to the picker
                    data = android.net.Uri.parse("femn://app/petition_widget_picker") 
                }
                
                val pendingIntent = PendingIntent.getActivity(
                    context, 
                    0, 
                    intent, 
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
