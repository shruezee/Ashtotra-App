package com.shruezee.ashtotra.reminder

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.shruezee.ashtotra.MainActivity
import com.shruezee.ashtotra.R
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId

/** One gentle notification a day, scheduled on the device. Nothing is sent anywhere. */
object DailyReminder {
    private const val CHANNEL = "daily-prayer"
    private const val REQUEST = 108

    fun schedule(context: Context, minutesAfterMidnight: Int) {
        ensureChannel(context)
        val now = LocalDateTime.now()
        var next = LocalDateTime.of(LocalDate.now(), LocalTime.of(minutesAfterMidnight / 60, minutesAfterMidnight % 60))
        if (!next.isAfter(now)) next = next.plusDays(1)
        val millis = next.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
        // Inexact is fine for a gentle reminder and needs no special alarm permission.
        alarms(context).setInexactRepeating(AlarmManager.RTC_WAKEUP, millis, AlarmManager.INTERVAL_DAY, pending(context))
    }

    fun cancel(context: Context) = alarms(context).cancel(pending(context))

    fun title(hour: Int) = when (hour) {
        in 4 until 12 -> "Time for your morning prayers"
        in 12 until 17 -> "A moment for prayer"
        else -> "Time for your evening prayers"
    }

    internal fun notify(context: Context) {
        ensureChannel(context)
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_lamp)
            .setContentTitle(title(LocalTime.now().hour))
            .setContentText("Take a quiet minute with Ashtotra. 🙏")
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(REQUEST, notification) }
    }

    private fun ensureChannel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Daily prayer reminder", NotificationManager.IMPORTANCE_DEFAULT)
                .apply { description = "One gentle reminder a day" }
        )
    }

    private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)

    private fun pending(context: Context) = PendingIntent.getBroadcast(
        context, REQUEST, Intent(context, ReminderReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )
}

class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) = DailyReminder.notify(context)
}

/** Alarms are cleared when the phone restarts, so set the reminder again. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        val prefs = context.getSharedPreferences("ashtotra", Context.MODE_PRIVATE)
        if (prefs.getBoolean("reminderOn", false)) {
            DailyReminder.schedule(context, prefs.getInt("reminderMinutes", 6 * 60 + 30))
        }
    }
}
