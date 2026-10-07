package com.shruezee.ashtotra.ui

import android.app.Activity
import android.view.WindowManager
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.shruezee.ashtotra.AppContainer
import com.shruezee.ashtotra.data.NameCollection
import com.shruezee.ashtotra.data.Script
import com.shruezee.ashtotra.ui.theme.Palette
import com.shruezee.ashtotra.ui.theme.cardColor
import com.shruezee.ashtotra.ui.theme.pageBackground
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

// ---------- 108 Names tab ----------

@Composable
fun NamesScreen(container: AppContainer, go: Navigator) {
    val state by container.log.state.collectAsState()
    Column(
        Modifier.fillMaxSize().background(pageBackground()).verticalScroll(rememberScrollState())
            .statusBarsPadding().padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        TopBar("108 Names") { go.settings() }
        Text("Ashtottara Shatanamavali: chant 108 names with a mala.", style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
        container.library.collections.forEach { c ->
            val position = state.position[c.id] ?: 0
            val done = state.completions[c.id] ?: 0
            Column(
                Modifier.fillMaxWidth().background(Palette.gradient(c.color), RoundedCornerShape(24.dp))
                    .clickable { go.names(c.id) }.padding(20.dp)
                    .semantics(mergeDescendants = true) {},
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text(c.title, color = Color.White, style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold))
                ScriptText(c.nativeTitle, Script.Devanagari, color = Color.White.copy(alpha = 0.9f), style = MaterialTheme.typography.titleLarge)
                Text(c.blurb, color = Color.White.copy(alpha = 0.9f))
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text(if (position > 0) "🔖 Continue at ${position + 1}" else "108 names", color = Color.White,
                        style = MaterialTheme.typography.labelLarge)
                    if (done > 0) Text("✓ $done×", color = Color.White, style = MaterialTheme.typography.labelLarge)
                }
            }
        }
        Text("No ads, no accounts, no tracking. Everything stays on your device.", style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(bottom = 24.dp))
    }
}

// ---------- Names reader ----------

@Composable
fun NamesReaderScreen(container: AppContainer, go: Navigator, id: String) {
    val collection = container.library.collection(id) ?: return
    val state by container.log.state.collectAsState()
    val script = currentScript(container)
    val showOmNamah by container.settings.showOmNamah.state.collectAsState()
    val bookmark = state.position[collection.id] ?: 0
    val tint = Palette.textTint(collection.color)
    val list = rememberLazyListState()
    LaunchedEffect(Unit) { if (bookmark > 3) list.scrollToItem(bookmark) }

    LazyColumn(
        Modifier.fillMaxSize().background(pageBackground()).statusBarsPadding(), state = list,
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        item {
            ReaderTopBar(container, collection.title, script, shareText = collection.title + "\n\n" +
                collection.names.mapIndexed { i, n -> "${i + 1}. ${container.library.chantLine(n, script)}" }.joinToString("\n"),
                onBack = { go.back() })
            Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(bottom = 8.dp)) {
                ScriptText(collection.nativeTitle, Script.Devanagari, color = tint,
                    style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold))
                Text(collection.subtitle, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(collection.blurb)
                Button(onClick = { go.chant(collection.id, bookmark) }, Modifier.fillMaxWidth().heightIn(min = 60.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Palette.tint(collection.color)), shape = RoundedCornerShape(18.dp)) {
                    Text(if (bookmark > 0) "🙏  Continue chanting at ${bookmark + 1}" else "🙏  Begin chanting",
                        style = MaterialTheme.typography.titleMedium)
                }
                Text("Or tap any name to start from there.", style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        itemsIndexed(collection.names) { i, name ->
            Row(
                Modifier.fillMaxWidth().heightIn(min = 56.dp).background(cardColor, RoundedCornerShape(14.dp))
                    .clickable { go.chant(collection.id, i) }.padding(horizontal = 14.dp, vertical = 10.dp)
                    .semantics(mergeDescendants = true) {},
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("${i + 1}", color = tint, style = MaterialTheme.typography.titleSmall, textAlign = TextAlign.End,
                    modifier = Modifier.widthIn(min = 34.dp).padding(end = 12.dp))
                ScriptText(if (showOmNamah) container.library.chantLine(name, script) else name.text(script), script,
                    modifier = Modifier.weight(1f), style = MaterialTheme.typography.titleMedium)
                if (i == bookmark && bookmark > 0) {
                    Icon(Icons.Filled.Bookmark, contentDescription = "You stopped here", tint = tint)
                }
            }
        }
        item { Spacer(Modifier.size(24.dp)) }
    }
}

// ---------- Chant mode ----------

@Composable
fun ChantScreen(container: AppContainer, go: Navigator, id: String, start: Int) {
    val collection = container.library.collection(id) ?: return
    val script = currentScript(container)
    val hapticsOn by container.settings.haptics.state.collectAsState()
    val status by container.reciter.status.collectAsState()
    val hasVoice by container.reciter.hasVoice.collectAsState()
    var index by remember { mutableIntStateOf(start.coerceIn(0, 107)) }
    var finished by remember { mutableStateOf(false) }
    val haptics = LocalHapticFeedback.current
    val owner = "chant:${collection.id}"
    val listening = status.playing && status.owner == owner
    val spoken = remember(collection) { collection.names.map { container.library.chantLine(it, Script.Devanagari) } }
    val activity = LocalContext.current as? Activity

    fun finish() {
        container.log.complete(collection.id)
        finished = true
        if (hapticsOn) haptics.performHapticFeedback(HapticFeedbackType.Confirm)
    }
    fun move(to: Int) {
        if (to > 107) { if (listening) container.reciter.stop(); finish(); return }
        if (to < 0) return
        index = to
        container.log.setPosition(index, collection.id)
        if (hapticsOn) haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
        if (listening) container.reciter.play(spoken, index, owner)
    }

    // Follow the voice while listening.
    LaunchedEffect(status.index, listening) {
        val i = status.index
        if (listening && i != null && i != index) {
            index = i
            container.log.setPosition(i, collection.id)
            if (hapticsOn) haptics.performHapticFeedback(HapticFeedbackType.SegmentTick)
        }
    }
    var lastFinished by remember { mutableIntStateOf(status.finished) }
    LaunchedEffect(status.finished) {
        if (status.finished != lastFinished) {
            lastFinished = status.finished
            if (index == 107 && !finished) finish()
        }
    }
    DisposableEffect(Unit) {
        activity?.window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose {
            activity?.window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            if (container.reciter.isPlaying(owner)) container.reciter.stop()
        }
    }

    Box(Modifier.fillMaxSize().background(Palette.gradient(collection.color))) {
        if (finished) {
            Column(
                Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically),
            ) {
                Text("🙏", style = MaterialTheme.typography.displayLarge)
                Text("108 names offered", color = Color.White, style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold))
                Text("May ${collection.title} bless your day with peace.", color = Color.White.copy(alpha = 0.9f),
                    style = MaterialTheme.typography.titleMedium, textAlign = TextAlign.Center)
                val total = container.log.completions(collection.id)
                Text(if (total == 1) "Your first time with this list." else "You've completed this list $total times.",
                    color = Color.White.copy(alpha = 0.85f))
                Spacer(Modifier.size(24.dp))
                Button(onClick = { go.back() }, Modifier.fillMaxWidth().widthIn(max = 520.dp).heightIn(min = 64.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.3f))) {
                    Text("Done", style = MaterialTheme.typography.titleMedium)
                }
                TextButton(onClick = { index = 0; finished = false }) { Text("Chant again", color = Color.White) }
            }
            return@Box
        }
        Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = 20.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { container.log.setPosition(index, collection.id); go.back() },
                    Modifier.size(52.dp).background(Color.White.copy(alpha = 0.18f), CircleShape)) {
                    Icon(Icons.Filled.Close, contentDescription = "Close and remember my place", tint = Color.White)
                }
                Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(collection.title, color = Color.White, style = MaterialTheme.typography.titleMedium)
                    Text("${index + 1} of 108", color = Color.White.copy(alpha = 0.85f), style = MaterialTheme.typography.bodyMedium)
                }
                Spacer(Modifier.size(52.dp))
            }
            Box(
                Modifier.weight(1f).fillMaxWidth().widthIn(max = 520.dp)
                    .clickable { move(index + 1) }
                    .pointerInput(index) {
                        var total = 0f
                        detectHorizontalDragGestures(onDragEnd = {
                            if (total < -60) move(index + 1) else if (total > 60) move(index - 1)
                            total = 0f
                        }) { _, drag -> total += drag }
                    }
                    .semantics {
                        customActions = listOf(
                            CustomAccessibilityAction("Next name") { move(index + 1); true },
                            CustomAccessibilityAction("Previous name") { move(index - 1); true },
                        )
                    },
                contentAlignment = Alignment.Center,
            ) {
                BeadRing(done = index + 1, modifier = Modifier.fillMaxWidth().aspectRatio(1f))
                AnimatedContent(index, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "name") { i ->
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.padding(horizontal = 56.dp)) {
                        ScriptText(container.library.om[script.key] ?: "Om", script, color = Color.White.copy(alpha = 0.85f),
                            style = MaterialTheme.typography.displaySmall)
                        ScriptText(collection.names[i].text(script), script, color = Color.White,
                            style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold, textAlign = TextAlign.Center))
                        ScriptText(container.library.namah[script.key] ?: "namaha", script, color = Color.White.copy(alpha = 0.85f),
                            style = MaterialTheme.typography.titleLarge)
                    }
                }
            }
            if (script != Script.Simple) {
                Text(collection.names[index].simple, color = Color.White.copy(alpha = 0.8f), style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.padding(bottom = 12.dp))
            }
            Row(Modifier.fillMaxWidth().widthIn(max = 520.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                IconButton(
                    onClick = { if (listening) container.reciter.stop() else container.reciter.play(spoken, index, owner) },
                    enabled = hasVoice,
                    modifier = Modifier.size(64.dp).background(Color.White.copy(alpha = if (listening) 0.45f else 0.16f), RoundedCornerShape(20.dp)),
                ) {
                    Icon(if (listening) Icons.Filled.Pause else Icons.AutoMirrored.Filled.VolumeUp, tint = Color.White,
                        contentDescription = if (listening) "Pause listening" else "Listen and chant along")
                }
                Button(onClick = { move(index - 1) }, enabled = index > 0, modifier = Modifier.weight(1f).heightIn(min = 64.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.16f)), shape = RoundedCornerShape(20.dp)) {
                    Text("‹ Back", style = MaterialTheme.typography.titleMedium)
                }
                Button(onClick = { move(index + 1) }, modifier = Modifier.weight(1f).heightIn(min = 64.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color.White.copy(alpha = 0.32f)), shape = RoundedCornerShape(20.dp)) {
                    Text(if (index == 107) "Offer 🙏" else "Next ›", style = MaterialTheme.typography.titleMedium)
                }
            }
        }
    }
}

/** A mala of 108 beads; beads already chanted glow. */
@Composable
fun BeadRing(done: Int, modifier: Modifier = Modifier) {
    Canvas(modifier.semantics { contentDescription = "" }) {
        val radius = min(size.width, size.height) / 2 - 10.dp.toPx()
        val center = Offset(size.width / 2, size.height / 2)
        for (bead in 0 until 108) {
            val angle = bead / 108.0 * 2 * Math.PI - Math.PI / 2
            val big = bead % 27 == 0
            drawCircle(
                Color.White.copy(alpha = if (bead < done) 0.95f else 0.25f),
                radius = (if (big) 4.5f else 3f).dp.toPx(),
                center = Offset(center.x + radius * cos(angle).toFloat(), center.y + radius * sin(angle).toFloat()),
            )
        }
    }
}
