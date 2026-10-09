package com.siraj.daur

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RectF
import android.graphics.Typeface

/**
 * The running track, drawn natively so widgets update even when a button runs in the background
 * (Flutter can't render images there). Geometry matches lib/track.dart and design/widgets.html:
 * a 402×250 viewBox, lane running counter-clockwise from the start line on the home straight.
 */
object TrackArt {
    const val TARTAN = 0xFFAD3B26.toInt()
    const val INFIELD = 0xFF98321F.toInt()
    const val INK = 0xFFFFF8F3.toInt()
    const val INK2 = 0xFFFFD9CC.toInt()
    const val RUNNER = 0xFFFFD23F.toInt()
    private const val LANE = 0x80FFF8F3.toInt()
    private const val FAINT = 0x38FFF8F3

    private fun font(ctx: Context): Typeface =
        runCatching { ctx.resources.getFont(R.font.unbounded_black) }.getOrDefault(Typeface.DEFAULT_BOLD)

    private fun lanePath(): Path = Path().apply {
        // M267 215 A90 90 0 0 0 267 35 L135 35 A90 90 0 0 0 135 215 Z
        moveTo(267f, 215f)
        arcTo(RectF(177f, 35f, 357f, 215f), 90f, -180f, false)
        lineTo(135f, 35f)
        arcTo(RectF(45f, 35f, 225f, 215f), 270f, -180f, false)
        close()
    }

    /**
     * The oval at [meters] (0–400). With [numerals], stencilled leg numbers 1–4 sit outside the lane:
     * run legs ink, the current leg yellow, the rest faded ink-2. [centre] is drawn in the infield.
     */
    fun track(ctx: Context, meters: Int, widthPx: Int, numerals: Boolean = false, centre: String? = null, sub: String? = null): Bitmap {
        val pad = if (numerals) 46f else 10f
        val vbW = 402f + 2 * pad - 32f
        val vbH = 250f + 2 * pad - 12f
        val scale = widthPx / vbW
        val bmp = Bitmap.createBitmap(widthPx, (vbH * scale).toInt(), Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        c.scale(scale, scale)
        c.translate(pad - 16f, pad - 6f)

        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = 3.3f; color = LANE }
        for ((x, y, w, h) in listOf(floatArrayOf(24f, 14f, 354f, 222f), floatArrayOf(38f, 28f, 326f, 194f), floatArrayOf(52f, 42f, 298f, 166f))) {
            c.drawRoundRect(RectF(x, y, x + w, y + h), h / 2, h / 2, stroke)
        }
        val infield = RectF(66f, 56f, 336f, 194f)
        c.drawRoundRect(infield, 69f, 69f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = INFIELD })
        c.drawRoundRect(infield, 69f, 69f, stroke)
        c.drawLine(267f, 194f, 267f, 236f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = INK; strokeWidth = 5f })

        val lane = lanePath()
        val pm = PathMeasure(lane, true)
        val len = pm.length
        val m = meters.coerceIn(0, 400)
        if (m > 0) {
            val done = Path()
            pm.getSegment(0f, len * m / 400f, done, true)
            c.drawPath(done, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE; strokeWidth = 13f; strokeCap = Paint.Cap.ROUND; color = INK
            })
        }
        val pos = FloatArray(2)
        for (d in listOf(100, 200, 300)) {
            pm.getPosTan(len * d / 400f, pos, null)
            c.drawCircle(pos[0], pos[1], 9f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = if (d <= m) INK else TARTAN })
            c.drawCircle(pos[0], pos[1], 9f, Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = 4f; color = INK })
        }
        if (numerals) {
            val tp = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = font(ctx); textSize = 26f; textAlign = Paint.Align.CENTER }
            for ((d, n) in listOf(50 to "1", 150 to "2", 250 to "3", 350 to "4")) {
                pm.getPosTan(len * d / 400f, pos, null)
                val dx = pos[0] - 201f; val dy = pos[1] - 125f; val k = Math.hypot(dx.toDouble(), dy.toDouble()).toFloat()
                tp.color = when { d < m -> INK; d - 100 < m -> RUNNER; else -> INK2 }
                tp.alpha = if (d < m || d - 100 < m) 255 else 140
                c.drawText(n, pos[0] + dx / k * 58f, pos[1] + dy / k * 46f + 9f, tp)
            }
        }
        pm.getPosTan(len * (m % 400) / 400f, pos, null)
        c.drawCircle(pos[0], pos[1], 25f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = TARTAN })
        c.drawCircle(pos[0], pos[1], 21f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = RUNNER })

        if (centre != null) {
            val big = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = font(ctx); textSize = 52f; color = INK; textAlign = Paint.Align.CENTER }
            c.drawText(centre, 201f, if (sub == null) 145f else 135f, big)
            if (sub != null) {
                val small = Paint(Paint.ANTI_ALIAS_FLAG).apply { typeface = font(ctx); textSize = 15f; color = INK2; textAlign = Paint.Align.CENTER; letterSpacing = 0.08f }
                c.drawText(sub, 201f, 165f, small)
            }
        }
        return bmp
    }

    /** The home straight for Walk: a tick every 1,000 steps, the runner at [steps]. */
    fun straight(ctx: Context, steps: Int, target: Int, widthPx: Int): Bitmap {
        val h = (widthPx * 30f / 170f).toInt()
        val bmp = Bitmap.createBitmap(widthPx, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val s = widthPx / 170f
        c.scale(s, s)
        val lane = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = LANE; strokeWidth = 1f }
        c.drawLine(0f, 2f, 170f, 2f, lane)
        c.drawLine(0f, 28f, 170f, 28f, lane)
        fun x(v: Int) = 10f + (v.toFloat() / target).coerceIn(0f, 1f) * 150f
        var k = 1000
        while (k <= target) {
            c.drawLine(x(k), 6f, x(k), if (k % 4000 == 0) 24f else 11f,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeWidth = 1.6f; color = if (k <= steps) INK else FAINT })
            k += 1000
        }
        c.drawLine(x(0), 15f, x(steps), 15f, Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeWidth = 4f; strokeCap = Paint.Cap.ROUND; color = INK })
        c.drawCircle(x(steps), 15f, 9.5f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = TARTAN })
        c.drawCircle(x(steps), 15f, 8f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = RUNNER })
        return bmp
    }
}
