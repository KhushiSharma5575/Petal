package com.petal.petal

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import java.util.Locale

/**
 * Home-screen widget: today's open tasks (up to 3) and water, with a
 * "+ glass" button.
 *
 * The app pushes a snapshot of today's data here (channel "petal/widget",
 * see MainActivity) whenever it changes. "+ glass" can't write to Petal's
 * database directly, so it counts "pending" glasses; the app adds them to
 * today's water the next time it opens. Everything stays on the phone.
 */
class PetalWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, render(context))
        scheduleMidnightRefresh(context)
    }

    override fun onDisabled(context: Context) {
        alarmManager(context)?.cancel(midnightIntent(context))
    }

    companion object {
        const val CHANNEL = "petal/widget"
        private const val PREFS = "petal_widget"

        private fun prefs(context: Context) =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

        private fun today() = LocalDate.now().toString() // "2026-11-16"

        /** Stores what the app sent: date, tasks, openCount, water, waterGoal. */
        fun saveSnapshot(context: Context, data: Map<*, *>) {
            val tasks = (data["tasks"] as? List<*>)?.joinToString("\n") { "• $it" } ?: ""
            prefs(context).edit()
                .putString("date", data["date"] as? String ?: "")
                .putString("tasks", tasks)
                .putInt("openCount", (data["openCount"] as? Number)?.toInt() ?: 0)
                .putInt("water", (data["water"] as? Number)?.toInt() ?: 0)
                .putInt("waterGoal", (data["waterGoal"] as? Number)?.toInt() ?: 8)
                .apply()
        }

        /** Earlier days' taps, kept as "2026-11-20:3;2026-11-19:1". */
        private fun parseOlder(s: String?): MutableMap<String, Int> {
            val out = linkedMapOf<String, Int>()
            for (part in (s ?: "").split(';')) {
                val bits = part.split(':')
                val n = bits.getOrNull(1)?.toIntOrNull() ?: continue
                if (bits[0].isNotEmpty() && n > 0) out[bits[0]] = (out[bits[0]] ?: 0) + n
            }
            return out
        }

        /**
         * Every day's pending "+ glass" taps, as a list of {date, count},
         * then clears them. Taps from several days are all kept.
         */
        fun takePendingGlasses(context: Context): List<Map<String, Any>> {
            val p = prefs(context)
            val all = parseOlder(p.getString("olderPending", null))
            val date = p.getString("pendingDate", null)
            val count = p.getInt("pendingGlasses", 0)
            if (date != null && count > 0) all[date] = (all[date] ?: 0) + count
            p.edit().remove("pendingDate").remove("pendingGlasses").remove("olderPending").apply()
            return all.map { (d, n) -> mapOf("date" to d, "count" to n) }
        }

        fun addPendingGlass(context: Context) {
            val p = prefs(context)
            val today = today()
            val edit = p.edit()
            val oldDate = p.getString("pendingDate", null)
            val oldCount = p.getInt("pendingGlasses", 0)
            if (oldDate != null && oldDate != today && oldCount > 0) {
                // A new day: keep yesterday's taps instead of overwriting them.
                val older = parseOlder(p.getString("olderPending", null))
                older[oldDate] = (older[oldDate] ?: 0) + oldCount
                edit.putString("olderPending", older.entries.joinToString(";") { "${it.key}:${it.value}" })
                    .remove("pendingGlasses")
            }
            val pending = if (oldDate == today) oldCount else 0
            val logged = if (p.getString("date", "") == today) p.getInt("water", 0) else 0
            val goal = p.getInt("waterGoal", 8)
            if (logged + pending >= goal) {
                edit.apply() // still save the moved-over taps
                return // goal reached, like the app
            }
            edit.putString("pendingDate", today).putInt("pendingGlasses", pending + 1).apply()
        }

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PetalWidget::class.java))
            if (ids.isEmpty()) return
            val views = render(context)
            for (id in ids) manager.updateAppWidget(id, views)
            scheduleMidnightRefresh(context)
        }

        private fun alarmManager(context: Context) =
            context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager

        /** Re-runs onUpdate, so a new day never shows yesterday's tasks. */
        private fun midnightIntent(context: Context): PendingIntent {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PetalWidget::class.java))
            val intent = Intent(context, PetalWidget::class.java)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            return PendingIntent.getBroadcast(
                context, 7, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /**
         * One inexact alarm just after the next midnight (no exact-alarm
         * permission needed, little battery use). It re-arms itself.
         */
        fun scheduleMidnightRefresh(context: Context) {
            val am = alarmManager(context) ?: return
            val at = LocalDate.now().plusDays(1).atTime(LocalTime.of(0, 1))
                .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
            am.set(AlarmManager.RTC, at, midnightIntent(context))
        }

        private fun render(context: Context): RemoteViews {
            val p = prefs(context)
            val today = today()
            val fresh = p.getString("date", "") == today
            val openCount = if (fresh) p.getInt("openCount", 0) else 0
            val tasksText = when {
                !fresh -> "Open Petal to see today's tasks"
                openCount == 0 -> "Nothing due today"
                else -> {
                    val shown = p.getString("tasks", "") ?: ""
                    val shownCount = shown.lines().count { it.isNotBlank() }
                    if (openCount > shownCount) "$shown\n+${openCount - shownCount} more" else shown
                }
            }
            val pending = if (p.getString("pendingDate", "") == today) p.getInt("pendingGlasses", 0) else 0
            val water = (if (fresh) p.getInt("water", 0) else 0) + pending
            val goal = p.getInt("waterGoal", 8)
            // Locale.US so it's always "1.1", never "1,1".
            val litres = String.format(Locale.US, "%.1f", water * 0.375).removeSuffix(".0")

            return RemoteViews(context.packageName, R.layout.petal_widget).apply {
                setTextViewText(R.id.widget_tasks, tasksText)
                setTextViewText(R.id.widget_water, "Water $water/$goal · $litres L")
                setContentDescription(
                    R.id.widget_add_glass,
                    context.getString(R.string.widget_add_glass_description),
                )

                val open = Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                setOnClickPendingIntent(
                    R.id.widget_root,
                    PendingIntent.getActivity(
                        context, 0, open,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )

                val add = Intent(context, PetalWidgetActions::class.java)
                    .setAction(PetalWidgetActions.ACTION_ADD_GLASS)
                setOnClickPendingIntent(
                    R.id.widget_add_glass,
                    PendingIntent.getBroadcast(
                        context, 1, add,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }
        }
    }
}

/**
 * Handles the "+ glass" tap. Not exported, so other apps can't send it.
 */
class PetalWidgetActions : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_ADD_GLASS) return
        PetalWidget.addPendingGlass(context)
        PetalWidget.refreshAll(context)
    }

    companion object {
        const val ACTION_ADD_GLASS = "com.petal.petal.ADD_GLASS"
    }
}
