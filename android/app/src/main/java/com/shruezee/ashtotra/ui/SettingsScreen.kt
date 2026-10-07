package com.shruezee.ashtotra.ui

import android.Manifest
import android.app.TimePickerDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import com.shruezee.ashtotra.AppContainer
import com.shruezee.ashtotra.data.Script
import com.shruezee.ashtotra.reminder.DailyReminder
import com.shruezee.ashtotra.ui.theme.Saffron
import com.shruezee.ashtotra.ui.theme.pageBackground

@Composable
fun SettingsScreen(container: AppContainer, go: Navigator) {
    val s = container.settings
    val context = LocalContext.current
    val script by s.script.state.collectAsState()
    val showOmNamah by s.showOmNamah.state.collectAsState()
    val haptics by s.haptics.state.collectAsState()
    val reminderOn by s.reminderOn.state.collectAsState()
    val reminderMinutes by s.reminderMinutes.state.collectAsState()
    val hasVoice by container.reciter.hasVoice.collectAsState()
    var denied by remember { mutableStateOf(false) }

    fun enableReminder() {
        s.reminderOn.value = true
        DailyReminder.schedule(context, s.reminderMinutes.value)
    }
    val notifications = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        denied = !granted
        if (granted) enableReminder() else s.reminderOn.value = false
    }

    Column(
        Modifier.fillMaxSize().background(pageBackground()).verticalScroll(rememberScrollState())
            .statusBarsPadding().padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        BackTitle("Settings") { go.back() }

        SoftCard {
            SectionTitle("Read the names in")
            Script.entries.forEach { option ->
                Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable { s.script.value = option },
                    verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        ScriptText(option.label, option, style = MaterialTheme.typography.titleMedium)
                        Text(option.detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (option == script) Icon(Icons.Filled.CheckCircle, contentDescription = "Selected", tint = Saffron)
                }
            }
            val sample = container.library.collections[0].names[0]
            ScriptText("Example: " + container.library.chantLine(sample, script), script,
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        SoftCard {
            SectionTitle("Reading")
            ToggleRow("Show “Om … namaha” on every name", showOmNamah) { s.showOmNamah.value = it }
            ToggleRow("Gentle vibration while chanting", haptics) { s.haptics.value = it }
            Text("Text follows your phone's font size. In any prayer you can also make it larger from the reading menu.",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        SoftCard {
            SectionTitle("Reminder")
            ToggleRow("Daily prayer reminder", reminderOn) { on ->
                if (!on) { s.reminderOn.value = false; DailyReminder.cancel(context) }
                else if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(context,
                        Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                    notifications.launch(Manifest.permission.POST_NOTIFICATIONS)
                } else enableReminder()
            }
            if (reminderOn) {
                val time = "%d:%02d %s".format(((reminderMinutes / 60 + 11) % 12) + 1, reminderMinutes % 60,
                    if (reminderMinutes / 60 < 12) "am" else "pm")
                TextButton(onClick = {
                    TimePickerDialog(context, { _, h, m ->
                        s.reminderMinutes.value = h * 60 + m
                        DailyReminder.schedule(context, h * 60 + m)
                    }, reminderMinutes / 60, reminderMinutes % 60, false).show()
                }) { Text("Remind me at $time", color = Saffron, style = MaterialTheme.typography.titleMedium) }
            }
            if (denied) {
                Text("Notifications are turned off for Ashtotra. You can allow them in your phone's Settings.",
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Text("One gentle notification a day. Nothing else.", style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        SoftCard {
            SectionTitle("Read aloud")
            if (hasVoice) {
                Text("Tap Listen on any prayer, or Listen in chant mode, to hear it read aloud with your phone's Hindi voice. It works offline.")
            } else {
                Text("To hear prayers read aloud, install a Hindi voice: Settings › Accessibility › Text-to-speech › Speech Services by Google › Install voice data › Hindi.")
                TextButton(onClick = {
                    runCatching { context.startActivity(Intent("com.android.settings.TTS_SETTINGS")) }
                }) { Text("Open text-to-speech settings", color = Saffron) }
            }
        }

        SoftCard {
            SectionTitle("About")
            Text("The prayers and 108 names are traditional texts, carefully checked against more than one source. If you spot a mistake, please let us know.")
            TextButton(onClick = {
                context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:shruthianthropic@gmail.com?subject=Ashtotra%20correction")))
            }) { Text("✉  Suggest a correction", color = Saffron) }
            TextButton(onClick = {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://shruezee.github.io/Ashtotra-App/privacy.html")))
            }) { Text("🔒  Privacy policy", color = Saffron) }
            Text("No ads, no accounts, no tracking. Your progress stays on this device.",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text("© 2026 Shruezee Studio", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Spacer(Modifier.size(24.dp))
    }
}

@Composable
private fun ToggleRow(label: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable { onChange(!checked) }, verticalAlignment = Alignment.CenterVertically) {
        Text(label, Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
        Spacer(Modifier.width(12.dp))
        Switch(checked, onChange)
    }
}
