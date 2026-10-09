package com.siraj.daur

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

// Daur home-screen widgets (design: design/widgets.html). The Flutter app writes the values
// (lib/widget_sync.dart); the track and lane are drawn here (TrackArt) so a background tap on
// "+ Glass" or "Log" redraws everything without opening the app.

private fun Context.openApp() = HomeWidgetLaunchIntent.getActivity(this, MainActivity::class.java)
private fun Context.action(name: String) = HomeWidgetBackgroundIntent.getBroadcast(this, Uri.parse("daur://$name"))
/** " · 6-DAY STREAK" once there is one: the streak grows on the home screen too. */
private fun streakText(data: SharedPreferences): String =
    data.num("streak").let { if (it > 0) " · $it-DAY STREAK" else "" }

private fun SharedPreferences.num(key: String, def: Int = 0): Int =
    runCatching { getInt(key, def) }.getOrElse { runCatching { getLong(key, def.toLong()).toInt() }.getOrDefault(def) }
private fun SharedPreferences.str(key: String, def: String = "") = getString(key, null) ?: def
private fun Context.px(dp: Int) = (dp * resources.displayMetrics.density).toInt()

/** Today (medium): the track with metres, lap, next meal, kcal. */
class DaurWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val track = TrackArt.track(context, data.num("meters"), context.px(170), centre = "${data.num("meters") / 100}/4")
        ids.forEach { id ->
            manager.updateAppWidget(id, RemoteViews(context.packageName, R.layout.daur_widget).apply {
                setOnClickPendingIntent(R.id.widget_root, context.openApp())
                setImageViewBitmap(R.id.widget_track, track)
                setTextViewText(R.id.widget_lap, "DAY ${data.num("lap_n", 1)} OF 84${streakText(data)}")
                setTextViewText(R.id.widget_next, data.str("next_name", "Open Daur"))
                setTextViewText(R.id.widget_when, data.str("next_when"))
                setProgressBar(R.id.widget_bar, 100, data.num("kcal_pct"), false)
                setTextViewText(R.id.widget_kcal, data.str("kcal_text"))
            })
        }
    }
}

/** Today (large): the whole lap; legs 1–4 painted as they're run; on day 84 the cut closes. */
class DaurLargeWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val meters = data.num("meters")
        val finish = data.num("finish") == 1
        val track = TrackArt.track(context, meters, context.px(330), numerals = true,
            centre = if (finish) "84/84" else "${meters / 100}/4", sub = if (finish) "DAYS" else "MEALS")
        val legIds = listOf(
            Triple(R.id.leg1_n, R.id.leg1_name, R.id.leg1_sub), Triple(R.id.leg2_n, R.id.leg2_name, R.id.leg2_sub),
            Triple(R.id.leg3_n, R.id.leg3_name, R.id.leg3_sub), Triple(R.id.leg4_n, R.id.leg4_name, R.id.leg4_sub),
        )
        ids.forEach { id ->
            manager.updateAppWidget(id, RemoteViews(context.packageName, R.layout.daur_widget_large).apply {
                setOnClickPendingIntent(R.id.widget_root, context.openApp())
                setImageViewBitmap(R.id.large_track, track)
                setTextViewText(R.id.large_lap, "DAY ${data.num("lap_n", 1)} OF 84${streakText(data)}")
                setTextViewText(R.id.large_date, data.str("date"))
                legIds.forEachIndexed { i, (n, name, sub) ->
                    val state = data.str("leg${i + 1}_state", "todo")
                    setTextColor(n, when (state) { "done" -> TrackArt.INK; "next" -> TrackArt.RUNNER; else -> TrackArt.INK2 })
                    setTextViewText(name, data.str("leg${i + 1}_name"))
                    setTextViewText(sub, data.str("leg${i + 1}_sub"))
                }
            })
        }
    }
}

class DaurWaterWidget : HomeWidgetProvider() {
    private val glasses = intArrayOf(
        R.id.glass0, R.id.glass1, R.id.glass2, R.id.glass3, R.id.glass4, R.id.glass5, R.id.glass6,
        R.id.glass7, R.id.glass8, R.id.glass9, R.id.glass10, R.id.glass11, R.id.glass12, R.id.glass13,
    )

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val g = data.num("water_glasses")
        val full = g >= data.num("water_goal", 14)
        val slots = data.num("water_slots", g) // personal goal mapped onto the 14 glasses
        ids.forEach { id ->
            manager.updateAppWidget(id, RemoteViews(context.packageName, R.layout.daur_widget_water).apply {
                setOnClickPendingIntent(R.id.widget_root, context.openApp())
                setOnClickPendingIntent(R.id.water_btn, context.action("water"))
                setTextViewText(R.id.water_big, if (g % 4 == 0) "${g / 4}" else "${g / 4.0}")
                setTextViewText(R.id.water_sub, data.getString("water_goal_text", null) ?: "of 3.5 L")
                setViewVisibility(R.id.water_sub, if (full) View.GONE else View.VISIBLE)
                setViewVisibility(R.id.water_btn, if (full) View.GONE else View.VISIBLE)
                glasses.forEachIndexed { i, v ->
                    setImageViewResource(v, when { i < slots -> R.drawable.glass_full; i == slots && !full -> R.drawable.glass_next; else -> R.drawable.glass_empty })
                }
            })
        }
    }
}

class DaurWalkWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val steps = data.num("walk_steps")
        val target = data.num("walk_target", 7000).coerceAtLeast(1000)
        val lane = TrackArt.straight(context, steps, target, context.px(150))
        ids.forEach { id ->
            manager.updateAppWidget(id, RemoteViews(context.packageName, R.layout.daur_widget_walk).apply {
                setOnClickPendingIntent(R.id.widget_root, context.openApp())
                setTextViewText(R.id.walk_big, "%,d".format(steps))
                setTextViewText(R.id.walk_sub, data.str("walk_sub", "steps"))
                setImageViewBitmap(R.id.walk_lane, lane)
            })
        }
    }
}

/** Next meal: full size, or a slim 4×1 on Android 12+ when the launcher gives it one row. */
class DaurMealWidget : HomeWidgetProvider() {
    private fun build(context: Context, data: SharedPreferences, layout: Int, full: Boolean) =
        RemoteViews(context.packageName, layout).apply {
            val done = data.num("meal_done") == 1
            val btn = data.str("meal_btn", "Log")
            setOnClickPendingIntent(R.id.widget_root, context.openApp())
            setOnClickPendingIntent(R.id.meal_btn, if (btn == "Open") context.openApp() else context.action("meal"))
            setTextViewText(R.id.meal_num, "${data.num("meal_num", 100) / 100}/4")
            setTextColor(R.id.meal_num, if (done) TrackArt.INK else TrackArt.RUNNER)
            setTextViewText(R.id.meal_title, data.str("meal_title", "Open Daur"))
            setTextViewText(R.id.meal_sub, data.str("meal_sub"))
            setTextViewText(R.id.meal_btn, btn)
            setViewVisibility(R.id.meal_btn, if (done) View.GONE else View.VISIBLE)
            if (full) {
                setTextColor(R.id.meal_m, if (done) TrackArt.INK else TrackArt.RUNNER)
                setTextViewText(R.id.meal_lap, "DAY ${data.num("lap_n", 1)}${streakText(data)}")
                setTextViewText(R.id.meal_when, data.str("meal_when"))
                setViewVisibility(R.id.meal_legs, if (done) View.GONE else View.VISIBLE)
                setViewVisibility(R.id.meal_cap, if (done) View.VISIBLE else View.GONE)
                setTextViewText(R.id.meal_cap, "● ${data.str("meal_cap")}")
                val leg = data.num("meal_num", 100) / 100
                listOf(R.id.mleg1, R.id.mleg2, R.id.mleg3, R.id.mleg4).forEachIndexed { i, v ->
                    setImageViewResource(v, when { i + 1 < leg -> R.drawable.leg_done; i + 1 == leg -> R.drawable.leg_next; else -> R.drawable.leg_todo })
                }
            }
        }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        ids.forEach { id ->
            val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                RemoteViews(mapOf(
                    SizeF(250f, 60f) to build(context, data, R.layout.daur_widget_meal_slim, full = false),
                    SizeF(250f, 130f) to build(context, data, R.layout.daur_widget_meal, full = true),
                ))
            } else build(context, data, R.layout.daur_widget_meal, full = true)
            manager.updateAppWidget(id, views)
        }
    }
}
