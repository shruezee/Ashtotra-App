package com.shruezee.ashtotra.ui

import android.app.Activity
import android.content.Intent
import android.provider.OpenableColumns
import android.view.WindowManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shruezee.ashtotra.AppContainer
import com.shruezee.ashtotra.audio.BreathHaptics
import com.shruezee.ashtotra.audio.DroneSynth
import com.shruezee.ashtotra.audio.SongPlayer
import com.shruezee.ashtotra.data.BreathPattern
import com.shruezee.ashtotra.data.MeditationLength
import com.shruezee.ashtotra.data.MeditationSound
import com.shruezee.ashtotra.ui.theme.Saffron
import com.shruezee.ashtotra.ui.theme.pageBackground
import kotlinx.coroutines.delay
import java.time.LocalDate
import kotlin.math.cos
import kotlin.math.roundToInt

// ---------- Setup ----------

@Composable
fun MeditateScreen(container: AppContainer, go: Navigator) {
    val s = container.settings
    val minutes by s.meditationLength.state.collectAsState()
    val sound by s.meditationSound.state.collectAsState()
    val patternId by s.breathPattern.state.collectAsState()
    val hapticsOn by s.breathHaptics.state.collectAsState()
    val songTitle by s.songTitle.state.collectAsState()
    val songUri by s.songUri.state.collectAsState()
    val state by container.log.state.collectAsState()
    val context = LocalContext.current
    val haptics = remember { BreathHaptics(context) }

    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            runCatching { context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION) }
            val name = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) it.getString(0) else null
            } ?: "My song"
            s.songUri.value = uri.toString()
            s.songTitle.value = name.substringBeforeLast('.')
            s.meditationSound.value = MeditationSound.MySong
        }
    }

    Column(
        Modifier.fillMaxSize().background(pageBackground()).verticalScroll(rememberScrollState())
            .statusBarsPadding().padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        TopBar("Meditate") { go.settings() }
        Text("Sit comfortably, gently close your eyes, and let your breath slow down.",
            style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)

        SoftCard {
            SectionTitle("Length")
            Row(verticalAlignment = Alignment.CenterVertically) {
                RoundButton(Icons.Filled.Remove, "One minute less", minutes > MeditationLength.range.first) {
                    s.meditationLength.value = minutes - 1
                }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("$minutes", fontSize = 56.sp, fontWeight = FontWeight.Bold)
                    Text(if (minutes == 1) "minute" else "minutes", color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                RoundButton(Icons.Filled.Add, "One minute more", minutes < MeditationLength.range.last) {
                    s.meditationLength.value = minutes + 1
                }
            }
            Slider(minutes.toFloat(), { s.meditationLength.value = it.roundToInt() },
                valueRange = 1f..20f, steps = 18, colors = SliderDefaults.colors(thumbColor = Saffron, activeTrackColor = Saffron,
                    activeTickColor = Color.Transparent, inactiveTickColor = Color.Transparent,
                    inactiveTrackColor = Saffron.copy(alpha = 0.18f)))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(2, 5, 10, 20).forEach { preset ->
                    FilterChip(selected = minutes == preset, onClick = { s.meditationLength.value = preset },
                        label = { Text("$preset min") }, modifier = Modifier.weight(1f),
                        colors = FilterChipDefaults.filterChipColors(selectedContainerColor = Saffron.copy(alpha = 0.18f),
                            selectedLabelColor = Saffron))
                }
            }
        }

        SoftCard {
            SectionTitle("Sound")
            MeditationSound.entries.forEach { option ->
                Row(
                    Modifier.fillMaxWidth().heightIn(min = 52.dp).clickable {
                        if (option == MeditationSound.MySong && songUri.isBlank()) picker.launch(arrayOf("audio/*", "video/mp4"))
                        else s.meditationSound.value = option
                    },
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(option.title, style = MaterialTheme.typography.titleMedium)
                        if (option == MeditationSound.MySong) {
                            Text(songTitle.ifBlank { "Choose an MP3 or MP4 from your phone" },
                                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    if (sound == option) Icon(Icons.Filled.CheckCircle, contentDescription = "Selected", tint = Saffron)
                }
            }
            if (sound == MeditationSound.MySong || songUri.isNotBlank()) {
                TextButton(onClick = { picker.launch(arrayOf("audio/*", "video/mp4")) }) {
                    Text(if (songUri.isBlank()) "Choose song" else "Change song", color = Saffron)
                }
            }
        }

        SoftCard {
            SectionTitle("Breath guide")
            SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                BreathPattern.all.forEachIndexed { i, p ->
                    SegmentedButton(selected = patternId == p.id, onClick = { s.breathPattern.value = p.id },
                        shape = SegmentedButtonDefaults.itemShape(i, BreathPattern.all.size)) { Text(p.name) }
                }
            }
            Text(BreathPattern.named(patternId).summary + " seconds", color = MaterialTheme.colorScheme.onSurfaceVariant)
            if (haptics.isSupported) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Haptic breath", style = MaterialTheme.typography.titleMedium)
                        Text("Feel a gentle vibration rise as you breathe in and fade as you breathe out, so you can keep your eyes closed.",
                            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    Spacer(Modifier.width(12.dp))
                    Switch(hapticsOn, { s.breathHaptics.value = it })
                }
            }
        }

        Button(onClick = { go.meditation() }, Modifier.fillMaxWidth().heightIn(min = 64.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Saffron), shape = RoundedCornerShape(20.dp)) {
            Text("🍃  Begin $minutes-minute meditation", style = MaterialTheme.typography.titleMedium)
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            StatTile("${state.meditationMinutes[LocalDate.now().toString()] ?: 0}", "min today", Modifier.weight(1f))
            StatTile("${state.meditationMinutes.values.sum()}", "min in total", Modifier.weight(1f))
            val streak = container.log.streak()
            StatTile("$streak", if (streak == 1) "day streak" else "days streak", Modifier.weight(1f))
        }
        Spacer(Modifier.size(16.dp))
    }
}

@Composable
private fun RoundButton(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, enabled: Boolean, onClick: () -> Unit) {
    IconButton(onClick = onClick, enabled = enabled,
        modifier = Modifier.size(60.dp).background(Saffron.copy(alpha = 0.15f), CircleShape)) {
        Icon(icon, contentDescription = label, tint = Saffron)
    }
}

// ---------- Session ----------

@Composable
fun MeditationSessionScreen(container: AppContainer, go: Navigator) {
    val s = container.settings
    val minutes = remember { s.meditationLength.value }
    val sound = remember { s.meditationSound.value }
    val pattern = remember { BreathPattern.named(s.breathPattern.value) }
    val context = LocalContext.current
    val breath = remember { BreathHaptics(context) }
    val useHaptics = remember { s.breathHaptics.value && breath.isSupported }
    val synth = remember { DroneSynth() }
    val song = remember { SongPlayer(context) }
    val total = minutes * 60.0

    var elapsedMs by remember { mutableLongStateOf(0L) }
    var paused by remember { mutableStateOf(false) }
    var finished by remember { mutableStateOf(false) }
    var songMissing by remember { mutableStateOf(false) }
    var lastPhase by remember { mutableStateOf<BreathPattern.Phase?>(null) }

    fun finish(early: Boolean) {
        if (finished) return
        val sat = (minOf(elapsedMs / 1000.0, total) / 60).roundToInt()
        if (!early || sat >= 1) container.log.addMeditation(maxOf(1, sat), LocalDate.now())
        if (early && sat < 1) { go.back(); return }
        synth.fadeOut(); song.stop(); synth.ringBell()
        if (useHaptics) breath.success()
        finished = true
    }

    DisposableEffect(Unit) {
        (context as? Activity)?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        when (sound) {
            MeditationSound.Tanpura -> synth.start(DroneSynth.Kind.Tanpura)
            MeditationSound.Bowl -> synth.start(DroneSynth.Kind.Bowl)
            MeditationSound.Silence -> synth.start(DroneSynth.Kind.None)
            MeditationSound.MySong -> { synth.start(DroneSynth.Kind.None); songMissing = !song.play(s.songUri.value) }
        }
        onDispose {
            (context as? Activity)?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            breath.stop(); song.stop(); synth.stop()
        }
    }

    // Clock: drives the circle, the haptic phases and the end of the session.
    LaunchedEffect(paused, finished) {
        if (paused || finished) return@LaunchedEffect
        var last = withFrameMillis { it }
        while (true) {
            val now = withFrameMillis { it }
            elapsedMs += now - last
            last = now
            val t = elapsedMs / 1000.0
            if (t >= total) { finish(early = false); break }
            val phase = pattern.phaseAt(t).first
            if (phase != lastPhase) {
                lastPhase = phase
                if (useHaptics) breath.play(phase, pattern.length(phase))
            }
        }
    }

    val bg = Brush.verticalGradient(listOf(Color(0xFF1A1433), Color(0xFF4D1F38)))
    Box(Modifier.fillMaxSize().background(bg).statusBarsPadding().navigationBarsPadding()) {
        if (finished) {
            val sat = maxOf(1, (minOf(elapsedMs / 1000.0, total) / 60).roundToInt())
            Column(Modifier.fillMaxSize().padding(24.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically)) {
                Text("🙏", fontSize = 80.sp)
                Text("Namaste", color = Color.White, style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold))
                Text("You sat in stillness for $sat ${if (sat == 1) "minute" else "minutes"}.", color = Color.White.copy(alpha = 0.9f),
                    style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
                Text("Take a moment before you open your eyes.", color = Color.White.copy(alpha = 0.7f))
                Spacer(Modifier.size(24.dp))
                Button(onClick = { go.back() }, Modifier.fillMaxWidth().widthIn(max = 520.dp).heightIn(min = 64.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.2f))) {
                    Text("Done", style = MaterialTheme.typography.titleMedium)
                }
            }
            return@Box
        }

        val t = elapsedMs / 1000.0
        val (phase, progress) = pattern.phaseAt(t)
        fun ease(x: Double) = (0.5 - 0.5 * cos(Math.PI * x)).toFloat()
        val scale = when (phase) {
            BreathPattern.Phase.Inhale -> 0.55f + 0.45f * ease(progress)
            BreathPattern.Phase.Hold -> 1f
            BreathPattern.Phase.Exhale -> 1f - 0.45f * ease(progress)
            BreathPattern.Phase.Rest -> 0.55f
        }
        val remaining = maxOf(0.0, total - t).toInt()
        val intro by animateFloatAsState(if (t < 7) 1f else 0f, tween(2500), label = "intro")

        Column(Modifier.fillMaxSize().padding(horizontal = 24.dp, vertical = 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Row(Modifier.fillMaxWidth()) {
                Text("%d:%02d".format(remaining / 60, remaining % 60), color = Color.White.copy(alpha = 0.7f),
                    style = MaterialTheme.typography.titleMedium,
                    modifier = Modifier.semantics { contentDescription = "${remaining / 60} minutes ${remaining % 60} seconds left" })
                Spacer(Modifier.weight(1f))
                if (songMissing) Text("Song unavailable", color = Color.White.copy(alpha = 0.7f), style = MaterialTheme.typography.bodySmall)
            }
            Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                Box(Modifier.size(320.dp).scale(scale)
                    .background(Brush.radialGradient(listOf(Color(0xE6FFB859), Color(0x40F26B33))), CircleShape))
                Box(Modifier.size(320.dp).border(2.dp, Color.White.copy(alpha = 0.25f), CircleShape))
                Text(phase.label, color = Color.White, style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.SemiBold),
                    modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite })
            }
            Column(Modifier.alpha(intro).padding(bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Gently close your eyes", color = Color.White, style = MaterialTheme.typography.headlineSmall)
                Text(if (useHaptics) "Follow the gentle vibration: it rises as you breathe in and fades as you breathe out."
                     else "Breathe slowly with the circle.",
                    color = Color.White.copy(alpha = 0.8f), textAlign = TextAlign.Center)
            }
            Row(Modifier.fillMaxWidth().widthIn(max = 520.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                Button(onClick = { paused = !paused; lastPhase = null; if (paused) breath.stop() },
                    Modifier.weight(1f).heightIn(min = 60.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.14f)), shape = RoundedCornerShape(20.dp)) {
                    Text(if (paused) "▶ Resume" else "❚❚ Pause", style = MaterialTheme.typography.titleMedium)
                }
                Button(onClick = { finish(early = true) }, Modifier.weight(1f).heightIn(min = 60.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.08f)), shape = RoundedCornerShape(20.dp)) {
                    Text("■ End", style = MaterialTheme.typography.titleMedium)
                }
            }
        }
    }
}
