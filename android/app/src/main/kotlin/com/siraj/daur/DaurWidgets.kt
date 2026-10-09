package com.siraj.daur

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

// Daur home-screen widgets, to the same design as the iPhone ones. The Flutter app writes the
// values (lib/widget_sync.dart); each face is drawn natively (WidgetFace) so a background tap on
// "+ Glass" or "Log" redraws everything without opening the app.

private fun Context.openApp() = HomeWidgetLaunchIntent.getActivity(this, MainActivity::class.java)
private fun Context.action(name: String) = HomeWidgetBackgroundIntent.getBroadcast(this, Uri.parse("daur://$name"))

/** One drawn face per widget, redrawn on every data push and when the widget is resized. */
abstract class DaurFaceWidget(private val layout: Int, private val kind: String, private val def: Pair<Float, Float>) :
    HomeWidgetProvider() {
    abstract fun face(context: Context, w: Float, h: Float, data: SharedPreferences): android.graphics.Bitmap
    open fun extras(context: Context, views: RemoteViews, data: SharedPreferences, h: Float) {}
    open fun layoutFor(h: Float) = layout

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        ids.forEach { id ->
            val (w, h) = WidgetFace.sizeDp(manager, id, def)
            manager.updateAppWidget(id, RemoteViews(context.packageName, layoutFor(h)).apply {
                setOnClickPendingIntent(R.id.widget_root, context.openApp())
                setImageViewBitmap(R.id.widget_face, face(context, w, h, data))
                setContentDescription(R.id.widget_face, WidgetFace.describe(kind, data))
                extras(context, this, data, h)
            })
        }
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        onUpdate(context, manager, intArrayOf(id), HomeWidgetPlugin.getData(context))
    }
}

/** Today (medium): the track with n/4, the day, next meal, kcal. */
class DaurWidgetProvider : DaurFaceWidget(R.layout.daur_widget, "today", 320f to 150f) {
    override fun face(context: Context, w: Float, h: Float, data: SharedPreferences) = WidgetFace.today(context, w, h, data)
}

/** Today (large): the whole lap; legs 1–4 painted as they're run; on day 84 the cut closes. */
class DaurLargeWidget : DaurFaceWidget(R.layout.daur_widget_large, "today", 320f to 340f) {
    override fun face(context: Context, w: Float, h: Float, data: SharedPreferences) = WidgetFace.large(context, w, h, data)
}

class DaurWaterWidget : DaurFaceWidget(R.layout.daur_widget_water, "water", 160f to 160f) {
    override fun face(context: Context, w: Float, h: Float, data: SharedPreferences) = WidgetFace.water(context, w, h, data)
    override fun extras(context: Context, views: RemoteViews, data: SharedPreferences, h: Float) {
        val full = data.getIntSafe("water_glasses") >= data.getIntSafe("water_goal", 14)
        views.setOnClickPendingIntent(R.id.water_btn, context.action("water"))
        views.setViewVisibility(R.id.water_btn, if (full) View.GONE else View.VISIBLE)
    }
}

class DaurWalkWidget : DaurFaceWidget(R.layout.daur_widget_walk, "walk", 160f to 160f) {
    override fun face(context: Context, w: Float, h: Float, data: SharedPreferences) = WidgetFace.walk(context, w, h, data)
}

/** Next meal: full size, or a slim one-row version when the launcher gives it a single row. */
class DaurMealWidget : DaurFaceWidget(R.layout.daur_widget_meal, "meal", 320f to 150f) {
    private fun slim(h: Float) = h < 100f
    override fun layoutFor(h: Float) = if (slim(h)) R.layout.daur_widget_meal_slim else R.layout.daur_widget_meal
    override fun face(context: Context, w: Float, h: Float, data: SharedPreferences) = WidgetFace.meal(context, w, h, data, slim(h))
    override fun extras(context: Context, views: RemoteViews, data: SharedPreferences, h: Float) {
        val done = data.getIntSafe("meal_done") == 1
        val btn = data.getString("meal_btn", null) ?: "Log"
        views.setOnClickPendingIntent(R.id.meal_btn, if (btn == "Open") context.openApp() else context.action("meal"))
        views.setViewVisibility(R.id.meal_btn, if (done) View.GONE else View.VISIBLE)
    }
}

private fun SharedPreferences.getIntSafe(key: String, def: Int = 0): Int =
    runCatching { getInt(key, def) }.getOrElse { runCatching { getLong(key, def.toLong()).toInt() }.getOrDefault(def) }
