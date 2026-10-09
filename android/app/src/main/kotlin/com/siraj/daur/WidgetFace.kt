package com.siraj.daur

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.text.TextPaint
import android.text.TextUtils
import com.siraj.daur.TrackArt.INK
import com.siraj.daur.TrackArt.INK2
import com.siraj.daur.TrackArt.RUNNER

/**
 * Each widget's face drawn as one image, at the widget's real size, to the same design as the
 * iPhone widgets (ios/DaurWidget/DaurWidget.swift). Launchers ignore an app's own fonts in widget
 * layouts, so drawn text is the only way to get Daur's heavy display numerals on Android; the
 * buttons (+, Log) stay real views on top. Coordinates are in dp; the canvas is scaled to pixels.
 */
object WidgetFace {
    private const val ON_RUNNER = 0xFF3A1208.toInt()
    private const val PAD = 16f

    /** The widget's size in dp (portrait: min width × max height), or [def] before the launcher says. */
    fun sizeDp(manager: AppWidgetManager, id: Int, def: Pair<Float, Float>): Pair<Float, Float> {
        val o = manager.getAppWidgetOptions(id)
        val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
        return if (w > 0 && h > 0) w.toFloat() to h.toFloat() else def
    }

    private class Face(val ctx: Context, val w: Float, val h: Float, density: Float = ctx.resources.displayMetrics.density) {
        val bmp: Bitmap = Bitmap.createBitmap((w * density).toInt().coerceAtLeast(1), (h * density).toInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp).apply { scale(density, density) }
        val x: Typeface = runCatching { ctx.resources.getFont(R.font.unbounded_black) }.getOrDefault(Typeface.DEFAULT_BOLD)
        val medium: Typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        val bold: Typeface = Typeface.create("sans-serif", Typeface.BOLD)

        fun paint(face: Typeface, size: Float, color: Int, spacing: Float = 0f) = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            typeface = face; textSize = size; this.color = color; letterSpacing = spacing
        }

        /** Text with its top at [top]; shrinks to fit [maxW] (down to 70%), then ellipsizes. Returns its bottom. */
        fun text(s: String, left: Float, top: Float, p: TextPaint, maxW: Float = w - left - PAD, right: Boolean = false): Float {
            val min = p.textSize * .7f
            while (p.measureText(s) > maxW && p.textSize > min) p.textSize -= .5f
            val t = TextUtils.ellipsize(s, p, maxW, TextUtils.TruncateAt.END).toString()
            val fm = p.fontMetrics
            val xPos = if (right) left - p.measureText(t) else left
            c.drawText(t, xPos, top - fm.ascent, p)
            return top - fm.ascent + fm.descent
        }

        fun fill(color: Int) = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        fun stroke(color: Int, width: Float) = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = width; this.color = color }

        fun track(meters: Int, box: RectF, numerals: Boolean = false, centre: String? = null, sub: String? = null) {
            val d = c.matrix.mapRadius(1f) // px per dp
            val art = TrackArt.track(ctx, meters, (box.width() * d).toInt(), numerals, centre, sub)
            // fit inside the box (the art keeps its own aspect ratio)
            val scale = minOf(box.width() / (art.width / d), box.height() / (art.height / d))
            val aw = art.width / d * scale; val ah = art.height / d * scale
            val dst = RectF(box.centerX() - aw / 2, box.centerY() - ah / 2, box.centerX() + aw / 2, box.centerY() + ah / 2)
            c.drawBitmap(art, null, dst, Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        }

        /** A thin rounded progress bar: ink over faint ink. */
        fun bar(left: Float, top: Float, width: Float, frac: Float) {
            val r = RectF(left, top, left + width, top + 5f)
            c.drawRoundRect(r, 2.5f, 2.5f, fill(0x38FFF8F3))
            if (frac > 0) c.drawRoundRect(RectF(left, top, left + width * frac.coerceIn(0f, 1f), top + 5f), 2.5f, 2.5f, fill(INK))
        }

        /** The yellow pill (Log) or disc (+): drawn here, the tappable view sits on top at the same spot. */
        fun pill(label: String, right: Float, bottom: Float, width: Float = 72f) {
            val r = RectF(right - width, bottom - 40f, right, bottom)
            c.drawRoundRect(r, 20f, 20f, fill(RUNNER))
            val p = paint(bold, 15f, ON_RUNNER).apply { textAlign = Paint.Align.CENTER }
            c.drawText(label, r.centerX(), r.centerY() - (p.fontMetrics.ascent + p.fontMetrics.descent) / 2, p)
        }

        fun plus(right: Float, bottom: Float) {
            c.drawCircle(right - 20f, bottom - 20f, 20f, fill(RUNNER))
            val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = ON_RUNNER; strokeWidth = 3f; strokeCap = Paint.Cap.ROUND }
            c.drawLine(right - 27f, bottom - 20f, right - 13f, bottom - 20f, p)
            c.drawLine(right - 20f, bottom - 27f, right - 20f, bottom - 13f, p)
        }
    }

    private fun SharedPreferences.num(key: String, def: Int = 0): Int =
        runCatching { getInt(key, def) }.getOrElse { runCatching { getLong(key, def.toLong()).toInt() }.getOrDefault(def) }
    private fun SharedPreferences.str(key: String, def: String = "") = getString(key, null) ?: def
    private fun lapLine(d: SharedPreferences, of84: Boolean = true): String {
        val s = d.num("streak")
        return "DAY ${d.num("lap_n", 1)}${if (of84) " OF 84" else ""}${if (s > 0) " · $s-DAY STREAK" else ""}"
    }

    /** Today, medium: the track with n/4 on the left; the day, the next meal and kcal on the right. */
    fun today(ctx: Context, w: Float, h: Float, d: SharedPreferences): Bitmap {
        val f = Face(ctx, w, h)
        val meters = d.num("meters")
        val half = (w - 2 * PAD - 12f) / 2
        f.track(meters, RectF(PAD, PAD, PAD + half, h - PAD), centre = "${meters / 100}/4")
        val left = PAD + half + 12f
        f.text(lapLine(d, of84 = false), left, PAD, f.paint(f.x, 10f, INK2, .06f))
        var y = h - PAD
        y -= 15f
        f.text(d.str("kcal_text"), left, y, f.paint(f.medium, 12f, if (d.num("burn_over") == 1) RUNNER else INK2))
        y -= 13f
        f.bar(left, y, w - left - PAD, d.num("kcal_pct") / 100f)
        y -= 24f
        f.text(d.str("next_when"), left, y, f.paint(f.medium, 13f, INK))
        y -= 26f
        f.text(d.str("next_name", "Open Daur"), left, y, f.paint(f.x, 19f, INK))
        return f.bmp
    }

    /** Today, large: the whole lap with leg numbers, the day and date on top, the four meals under it. */
    fun large(ctx: Context, w: Float, h: Float, d: SharedPreferences): Bitmap {
        val f = Face(ctx, w, h)
        val meters = d.num("meters")
        val finish = d.num("finish") == 1
        f.text(lapLine(d), PAD, PAD, f.paint(f.x, 11f, INK2, .06f), maxW = w * .62f)
        f.text(d.str("date"), w - PAD, PAD, f.paint(f.x, 11f, INK2), maxW = w * .3f, right = true)
        val gridH = 92f
        f.track(
            meters, RectF(PAD, PAD + 20f, w - PAD, h - PAD - gridH - 6f), numerals = true,
            centre = if (finish) "84/84" else "${meters / 100}/4", sub = if (finish) "DAYS" else "MEALS",
        )
        val colW = (w - 2 * PAD - 14f) / 2
        for (i in 0 until 4) {
            val left = PAD + (i % 2) * (colW + 14f)
            val top = h - PAD - gridH + (i / 2) * 48f
            val state = d.str("leg${i + 1}_state", "todo")
            f.text("${i + 1}", left, top + 4f, f.paint(f.x, 24f, when (state) { "done" -> INK; "next" -> RUNNER; else -> INK2 }))
            val b = f.text(d.str("leg${i + 1}_name"), left + 34f, top, f.paint(f.bold, 15f, INK), maxW = colW - 34f)
            f.text(d.str("leg${i + 1}_sub"), left + 34f, b + 1f, f.paint(f.medium, 12f, INK2), maxW = colW - 34f)
        }
        return f.bmp
    }

    /** Water: litres big, 14 glasses in two rows, + glass (the button view sits on the drawn disc). */
    fun water(ctx: Context, w: Float, h: Float, d: SharedPreferences): Bitmap {
        val f = Face(ctx, w, h)
        val g = d.num("water_glasses")
        val full = g >= d.num("water_goal", 14)
        val slots = d.num("water_slots", g)
        var y = f.text("Water", PAD, PAD, f.paint(f.medium, 13f, INK2))
        val big = f.paint(f.x, 34f, INK)
        val litres = if (g % 4 == 0) "${g / 4}" else "${g / 4.0}"
        val by = f.text(litres, PAD, y + 4f, big)
        f.text("L", PAD + big.measureText(litres) + 4f, y + 4f + (big.textSize - 15f) * .8f, f.paint(f.x, 15f, INK))
        if (!full) f.text(d.str("water_goal_text", "of 3.5 L"), PAD, by + 2f, f.paint(f.medium, 12f, INK2))
        // glasses: 2 rows of 7, full = ink, the next one ringed yellow, the rest outlined
        val right = if (full) w - PAD else w - PAD - 48f
        val gap = 3f
        val gw = (right - PAD - 6 * gap) / 7
        for (i in 0 until 14) {
            val col = i % 7; val row = i / 7
            val top = h - PAD - 38f + row * 21f
            val r = RectF(PAD + col * (gw + gap), top, PAD + col * (gw + gap) + gw, top + 17f)
            when {
                i < slots -> f.c.drawRoundRect(r, 4f, 4f, f.fill(INK))
                i == slots && !full -> f.c.drawRoundRect(r.apply { inset(1f, 1f) }, 4f, 4f, f.stroke(RUNNER, 2f))
                else -> f.c.drawRoundRect(r.apply { inset(.75f, .75f) }, 4f, 4f, f.stroke(0x80FFF8F3.toInt(), 1.5f))
            }
        }
        if (!full) f.plus(w - PAD, h - PAD)
        return f.bmp
    }

    /** Walk: steps big, the line under it, and the home straight with the runner. */
    fun walk(ctx: Context, w: Float, h: Float, d: SharedPreferences): Bitmap {
        val f = Face(ctx, w, h)
        val has = d.contains("walk_steps")
        val steps = d.num("walk_steps")
        val target = d.num("walk_target", 7000).coerceAtLeast(1000)
        var y = f.text("Walk", PAD, PAD, f.paint(f.medium, 13f, INK2))
        y = f.text(if (has) "%,d".format(steps) else "–", PAD, y + 4f, f.paint(f.x, 32f, INK))
        f.text(d.str("walk_sub", "steps"), PAD, y + 2f, f.paint(f.medium, 12f, INK2))
        val dpx = f.c.matrix.mapRadius(1f)
        val lane = TrackArt.straight(ctx, steps, target, ((w - 2 * PAD) * dpx).toInt())
        val lh = lane.height / dpx
        f.c.drawBitmap(lane, null, RectF(PAD, h - PAD - lh, w - PAD, h - PAD), Paint(Paint.FILTER_BITMAP_FLAG))
        return f.bmp
    }

    /** Next meal: n/4 big in yellow, the four-leg strip, the meal and Log (or a slim one-row version). */
    fun meal(ctx: Context, w: Float, h: Float, d: SharedPreferences, slim: Boolean): Bitmap {
        val f = Face(ctx, w, h)
        val done = d.num("meal_done") == 1
        val leg = d.num("meal_num", 100) / 100
        val btn = d.str("meal_btn", "Log")
        val numColor = if (done) INK else RUNNER
        if (slim) {
            val mid = h / 2
            val n = f.paint(f.x, 30f, numColor)
            f.text("$leg/4", PAD, mid - 17f, n)
            val left = PAD + 92f
            val maxW = w - left - PAD - (if (done) 0f else 84f)
            val b = f.text(d.str("meal_title", "Open Daur"), left, mid - 19f, f.paint(f.x, 16f, INK), maxW)
            f.text(d.str("meal_sub"), left, b + 2f, f.paint(f.medium, 13f, INK2), maxW)
            if (!done) f.pill(btn, w - PAD, mid + 20f)
            return f.bmp
        }
        val n = f.paint(f.x, 52f, numColor)
        // the display font's descent is deep: lay out from the numeral's baseline, not its box
        val nb = f.text("$leg/4", PAD, PAD - 6f, n, maxW = w * .55f) - n.fontMetrics.descent
        val m = f.paint(f.x, 18f, numColor)
        f.text("m", PAD + n.measureText("$leg/4") + 3f, nb + m.fontMetrics.ascent, m)
        f.text(lapLine(d, of84 = false), w - PAD, PAD, f.paint(f.x, 11f, INK2, .06f), maxW = w * .4f, right = true)
        f.text(d.str("meal_when"), w - PAD, PAD + 17f, f.paint(f.medium, 13f, INK2), maxW = w * .4f, right = true)
        if (done) {
            f.c.drawCircle(PAD + 4f, nb + 12f, 4f, f.fill(RUNNER))
            f.text(d.str("meal_cap"), PAD + 14f, nb + 4f, f.paint(f.bold, 13f, INK))
        } else {
            val sw = (150f - 3 * 4f) / 4
            for (i in 1..4) {
                val r = RectF(PAD + (i - 1) * (sw + 4f), nb + 6f, PAD + (i - 1) * (sw + 4f) + sw, nb + 13f)
                when {
                    i < leg -> f.c.drawRoundRect(r, 4f, 4f, f.fill(INK))
                    i == leg -> f.c.drawRoundRect(r.apply { inset(1f, 1f) }, 4f, 4f, f.stroke(RUNNER, 2f))
                    else -> f.c.drawRoundRect(r, 4f, 4f, f.fill(0x38FFF8F3))
                }
            }
        }
        val maxW = w - 2 * PAD - (if (done) 0f else 84f)
        f.text(d.str("meal_sub"), PAD, h - PAD - 16f, f.paint(f.medium, 13f, INK2), maxW)
        f.text(d.str("meal_title", "Open Daur"), PAD, h - PAD - 44f, f.paint(f.x, 20f, INK), maxW)
        if (!done) f.pill(btn, w - PAD, h - PAD)
        return f.bmp
    }

    /** Spoken by TalkBack in place of the drawn face. */
    fun describe(kind: String, d: SharedPreferences): String = when (kind) {
        "water" -> "Water: ${d.num("water_glasses")} glasses ${d.str("water_goal_text")}"
        "walk" -> "Walk: ${d.num("walk_steps")} steps, ${d.str("walk_sub")}"
        "meal" -> "Meal ${d.num("meal_num", 100) / 100} of 4: ${d.str("meal_title")}, ${d.str("meal_sub")}"
        else -> "Day ${d.num("lap_n", 1)}: ${d.num("meters") / 100} of 4 meals. Next: ${d.str("next_name")} ${d.str("next_when")}. ${d.str("kcal_text")}"
    }
}
