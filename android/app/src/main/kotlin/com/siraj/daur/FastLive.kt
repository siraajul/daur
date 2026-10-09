package com.siraj.daur

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The fast as a live notification while it runs (started from Fasting in the app).
 * Android 16+: a Live Update. Its bar is cut into the fast's stages (yellow marks where each
 * starts) and it gets a status-bar chip with the hours. Older Android: a plain progress bar.
 * The clock ticks by itself (chronometer); an alarm redraws the bar and stage every 15 minutes
 * and at each stage, so it stays right with the app closed. Started and stopped from Dart
 * (lib/live.dart, channel "daur/fast"); the stage names come from there too.
 */
object FastLive {
    private const val ID = 4401
    private const val CHANNEL = "fast_live"
    private const val PREFS = "daur_fast_live"
    private val shades = longArrayOf(0xFFE8A598, 0xFFD9775F, 0xFFC4553D, 0xFFAD3B26, 0xFF7A2414)

    fun show(ctx: Context, from: Long, goalHours: Int, hours: List<Int>, names: List<String>) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong("from", from).putInt("goal", goalHours)
            .putString("hours", hours.joinToString(",")).putString("names", names.joinToString("|"))
            .apply()
        post(ctx)
    }

    fun cancel(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        ctx.getSystemService(NotificationManager::class.java).cancel(ID)
        ctx.getSystemService(AlarmManager::class.java).cancel(tick(ctx))
    }

    /** Draws the notification from the saved fast, then books the next redraw. */
    fun post(ctx: Context) {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val from = p.getLong("from", 0L)
        if (from == 0L) return
        val goal = p.getInt("goal", 16)
        val hours = p.getString("hours", "")!!.split(",").mapNotNull { it.toIntOrNull() }
        val names = p.getString("names", "")!!.split("|")
        val now = System.currentTimeMillis()
        val min = ((now - from) / 60000).toInt().coerceAtLeast(0)
        val goalMin = goal * 60
        val stage = hours.indexOfLast { min >= it * 60 }.coerceAtLeast(0)
        val done = min >= goalMin
        val at = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(from + goalMin * 60000L))

        val nm = ctx.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Fasting timer", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "The fast you are on, live, while it runs"
                    setShowBadge(false)
                },
            )
        }
        val open = PendingIntent.getActivity(
            ctx, 0,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val b = Notification.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_daur)
            .setLargeIcon(Icon.createWithResource(ctx, R.drawable.notif_fasting))
            .setColor(0xFFAD3B26.toInt())
            .setContentTitle("Fasting · ${names.getOrElse(stage) { "" }}")
            .setContentText(
                if (done) "Goal done · ${goal}h · end it in Daur"
                else "${(goalMin - min) / 60}h ${"%02d".format((goalMin - min) % 60)}m to go · goal at $at",
            )
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setWhen(from)
            .setUsesChronometer(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(open)

        if (Build.VERSION.SDK_INT >= 36) {
            // the bar in stages: one segment per stage up to the goal, a yellow mark where each starts
            val starts = hours.filter { it < goal }
            val segments = starts.mapIndexed { i, h ->
                val end = if (i + 1 < starts.size) starts[i + 1] else goal
                Notification.ProgressStyle.Segment((end - h) * 60).setColor(shades[i % shades.size].toInt())
            }
            val points = starts.drop(1).map { Notification.ProgressStyle.Point(it * 60).setColor(0xFFFFD23F.toInt()) }
            b.setStyle(
                Notification.ProgressStyle()
                    .setStyledByProgress(true)
                    .setProgressSegments(segments)
                    .setProgressPoints(points)
                    .setProgress(min.coerceAtMost(goalMin))
                    .setProgressTrackerIcon(Icon.createWithResource(ctx, R.drawable.ic_stat_daur)),
            )
            b.setShortCriticalText("${min / 60}h") // the status-bar chip
            b.setRequestPromotedOngoing(true) // ask to be a Live Update
        } else {
            b.setProgress(goalMin, min.coerceAtMost(goalMin), false)
        }
        nm.notify(ID, b.build())

        // redraw in 15 minutes, or at the next stage / the goal if that comes sooner
        val nextMarks = (hours.map { it * 60 } + goalMin).filter { it > min }
        val next = (listOf(min + 15) + nextMarks).min()
        ctx.getSystemService(AlarmManager::class.java)
            .setAndAllowWhileIdle(AlarmManager.RTC, from + next * 60000L, tick(ctx))
    }

    private fun tick(ctx: Context) = PendingIntent.getBroadcast(
        ctx, ID, Intent(ctx, FastLiveReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}

/** The 15-minute / next-stage redraw booked by [FastLive.post]. */
class FastLiveReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) = FastLive.post(ctx)
}
