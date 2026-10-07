package com.shruezee.ashtotra.ui

import android.content.Intent
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.filled.TextFields
import androidx.compose.material.icons.automirrored.filled.VolumeUp
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shruezee.ashtotra.AppContainer
import com.shruezee.ashtotra.data.Prayer
import com.shruezee.ashtotra.data.PrayerKind
import com.shruezee.ashtotra.data.Script
import com.shruezee.ashtotra.data.Verse
import com.shruezee.ashtotra.ui.theme.Palette
import com.shruezee.ashtotra.ui.theme.Saffron
import com.shruezee.ashtotra.ui.theme.cardColor
import com.shruezee.ashtotra.ui.theme.pageBackground

// ---------- Prayers tab ----------

@Composable
fun PrayersScreen(container: AppContainer, go: Navigator) {
    val state by container.log.state.collectAsState()
    var query by remember { mutableStateOf("") }
    val book = container.book
    fun matches(p: Prayer) = query.isBlank() || p.title.contains(query, true) || p.nativeTitle.contains(query) ||
        p.about.contains(query, true)

    LazyColumn(
        Modifier.fillMaxSize().background(pageBackground()).statusBarsPadding(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        item { TopBar("Prayers") { go.settings() } }
        item {
            OutlinedTextField(query, { query = it }, Modifier.fillMaxWidth(), singleLine = true,
                leadingIcon = { Icon(Icons.Filled.Search, contentDescription = null) },
                placeholder = { Text("Search prayers") }, shape = RoundedCornerShape(16.dp))
        }
        if (query.isBlank()) {
            val favorites = book.prayers.filter { it.id in state.favorites }
            if (favorites.isNotEmpty()) {
                item { SectionTitle("Favourites", Modifier.padding(top = 8.dp)) }
                items(favorites, key = { "fav-" + it.id }) { PrayerRow(it, true) { go.prayer(it.id) } }
            }
            item { SectionTitle("Daily routines", Modifier.padding(top = 8.dp)) }
            items(book.routines, key = { "r-" + it.id }) { r ->
                NavRow(r.title, r.subtitle, leading = { RoutineIcon(r.symbol, Saffron) }) { go.routine(r.id) }
            }
        }
        for (kind in listOf(PrayerKind.Stotra, PrayerKind.Aarti, PrayerKind.Mantra)) {
            val list = book.prayers(kind).filter(::matches)
            if (list.isNotEmpty()) {
                item(key = "h-$kind") { SectionTitle(kind.title, Modifier.padding(top = 8.dp)) }
                items(list, key = { it.id }) { PrayerRow(it, it.id in state.favorites) { go.prayer(it.id) } }
            }
        }
        if (book.prayers.none(::matches)) {
            item { Text("No prayers match “$query”.", color = MaterialTheme.colorScheme.onSurfaceVariant) }
        }
        item { Spacer(Modifier.size(16.dp)) }
    }
}

@Composable
private fun PrayerRow(prayer: Prayer, favorite: Boolean, onClick: () -> Unit) {
    NavRow(prayer.title, prayer.nativeTitle, leading = {
        Box(Modifier.size(14.dp).background(Palette.gradient(prayer.deity), CircleShape))
    }, onClick = onClick)
}

// ---------- Prayer reader ----------

@Composable
fun PrayerReaderScreen(container: AppContainer, go: Navigator, id: String) {
    val prayer = container.book.prayer(id) ?: return
    val state by container.log.state.collectAsState()
    val script = currentScript(container)
    val scale by container.settings.readerScale.state.collectAsState()
    val status by container.reciter.status.collectAsState()
    val owner = "prayer:${prayer.id}"
    val lines = remember(prayer) { prayer.verses.flatMapIndexed { v, verse -> verse.lines.map { v to it } } }
    val speakingVerse = if (status.playing && status.owner == owner) status.index?.let { lines.getOrNull(it)?.first } else null
    val list = rememberLazyListState()
    val activity = "prayer:${prayer.id}"
    val done = activity in state.activities[java.time.LocalDate.now().toString()].orEmpty()
    val tint = Palette.textTint(prayer.deity)

    LaunchedEffect(speakingVerse) { speakingVerse?.let { list.animateScrollToItem(it + 1) } }
    DisposableEffect(owner) { onDispose { if (container.reciter.isPlaying(owner)) container.reciter.stop() } }

    Box(Modifier.fillMaxSize().background(pageBackground())) {
        LazyColumn(
            Modifier.fillMaxSize().statusBarsPadding(),
            state = list,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 140.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            item {
                ReaderTopBar(container, prayer.title, script, shareText = shareText(prayer, script), onBack = { go.back() }) {
                    IconButton(onClick = { container.log.toggleFavorite(prayer.id) }) {
                        val fav = prayer.id in state.favorites
                        Icon(if (fav) Icons.Filled.Favorite else Icons.Filled.FavoriteBorder,
                            contentDescription = if (fav) "Remove from favourites" else "Add to favourites", tint = Saffron)
                    }
                }
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    ScriptText(prayer.nativeTitle, Script.Devanagari, color = tint,
                        style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold))
                    Text(prayer.about, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    prayer.meaning?.let {
                        Text(it, fontStyle = FontStyle.Italic, modifier = Modifier.fillMaxWidth()
                            .background(cardColor, RoundedCornerShape(16.dp)).padding(14.dp))
                    }
                }
            }
            itemsIndexed(prayer.verses) { i, verse ->
                VerseCard(verse, script, (21 * scale).sp, tint, highlighted = speakingVerse == i)
            }
            item {
                OutlinedButton(
                    onClick = { if (done) container.log.unrecord(activity) else container.log.record(activity) },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp),
                    shape = RoundedCornerShape(16.dp),
                ) {
                    Text(if (done) "✓ Done today" else "Mark as done today",
                        color = if (done) Color(0xFF34A853) else Palette.tint(prayer.deity),
                        style = MaterialTheme.typography.titleMedium)
                }
            }
        }
        ListenBar(container, owner, Palette.tint(prayer.deity), Modifier.align(Alignment.BottomCenter)) {
            lines.map { it.second.devanagari }
        }
    }
}

@Composable
fun VerseCard(verse: Verse, script: Script, size: androidx.compose.ui.unit.TextUnit, tint: Color, highlighted: Boolean) {
    SoftCard(highlight = if (highlighted) tint else null) {
        verse.label?.let {
            Text(it.uppercase(), color = tint, style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            verse.number?.let {
                Text("$it", color = tint, style = MaterialTheme.typography.titleSmall,
                    modifier = Modifier.width(28.dp).semantics { contentDescription = "Verse $it" })
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                verse.lines.forEach { line ->
                    ScriptText(line.text(script), script,
                        style = MaterialTheme.typography.bodyLarge.copy(fontSize = size, lineHeight = size * 1.45f))
                }
            }
        }
    }
}

/** Back, script picker, text size and share, shared by readers. */
@Composable
fun ReaderTopBar(
    container: AppContainer,
    title: String,
    script: Script,
    shareText: String,
    onBack: () -> Unit,
    extra: @Composable () -> Unit = {},
) {
    val context = LocalContext.current
    var menu by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back") }
        Text(title, style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.SemiBold), modifier = Modifier.weight(1f),
            maxLines = 1)
        extra()
        Box {
            IconButton(onClick = { menu = true }) {
                Icon(Icons.Filled.TextFields, contentDescription = "Reading options", tint = Saffron)
            }
            DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                Script.entries.forEach { option ->
                    DropdownMenuItem(
                        text = { ScriptText((if (option == script) "✓  " else "     ") + option.label, option) },
                        onClick = { container.settings.script.value = option; menu = false },
                    )
                }
                HorizontalDivider()
                DropdownMenuItem(text = { Text("Larger text") }, onClick = {
                    container.settings.readerScale.value = (container.settings.readerScale.value + 0.15f).coerceAtMost(2f)
                })
                DropdownMenuItem(text = { Text("Smaller text") }, onClick = {
                    container.settings.readerScale.value = (container.settings.readerScale.value - 0.15f).coerceAtLeast(0.7f)
                })
                HorizontalDivider()
                DropdownMenuItem(text = { Text("Share") }, onClick = {
                    menu = false
                    context.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, shareText)
                    }, null))
                })
            }
        }
    }
}

private fun shareText(prayer: Prayer, script: Script) =
    prayer.title + "\n\n" + prayer.verses.joinToString("\n\n") { v -> v.lines.joinToString("\n") { it.text(script) } } +
        "\n\nShared from Ashtotra"

/** Listen / stop with a pace choice. Uses the phone's Hindi text-to-speech voice, offline. */
@Composable
fun ListenBar(container: AppContainer, owner: String, tint: Color, modifier: Modifier = Modifier, lines: () -> List<String>) {
    val reciter = container.reciter
    val status by reciter.status.collectAsState()
    val hasVoice by reciter.hasVoice.collectAsState()
    val pace by container.settings.recitePace.state.collectAsState()
    val playing = status.playing && status.owner == owner
    var menu by remember { mutableStateOf(false) }
    val paceName = when { pace < 0.7f -> "Slow"; pace < 0.9f -> "Calm"; else -> "Normal" }

    Surface(modifier.navigationBarsPadding().padding(12.dp), shape = RoundedCornerShape(50), tonalElevation = 6.dp, shadowElevation = 6.dp) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = {
                    if (playing) reciter.stop() else { reciter.pace = pace; reciter.play(lines(), owner = owner) }
                },
                enabled = hasVoice,
                colors = ButtonDefaults.buttonColors(containerColor = tint),
                modifier = Modifier.heightIn(min = 52.dp),
            ) {
                Icon(if (playing) Icons.Filled.Stop else Icons.AutoMirrored.Filled.VolumeUp, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text(if (playing) "Stop" else "Listen", style = MaterialTheme.typography.titleMedium)
            }
            Box {
                TextButton(onClick = { menu = true }, modifier = Modifier.heightIn(min = 52.dp)
                    .semantics { contentDescription = "Reading pace: $paceName" }) { Text("🐢 $paceName") }
                DropdownMenu(menu, { menu = false }) {
                    listOf("Slow" to 0.6f, "Calm" to 0.8f, "Normal" to 1.0f).forEach { (name, value) ->
                        DropdownMenuItem(text = { Text(name) }, onClick = { container.settings.recitePace.value = value; menu = false })
                    }
                }
            }
        }
    }
}

// ---------- Routine ----------

@Composable
fun RoutineScreen(container: AppContainer, go: Navigator, id: String) {
    val routine = container.book.routine(id) ?: return
    val state by container.log.state.collectAsState()
    val script = currentScript(container)
    val scale by container.settings.readerScale.state.collectAsState()
    val status by container.reciter.status.collectAsState()
    val prayers = remember(routine) { container.book.prayersIn(routine) }
    val lines = remember(prayers) { prayers.flatMapIndexed { i, p -> p.lines.map { i to it.devanagari } } }
    val owner = "routine:${routine.id}"
    val speaking = if (status.playing && status.owner == owner) status.index?.let { lines.getOrNull(it)?.first } else null
    val list = rememberLazyListState()
    val activity = "routine:${routine.id}"
    val done = activity in state.activities[java.time.LocalDate.now().toString()].orEmpty()

    LaunchedEffect(speaking) { speaking?.let { list.animateScrollToItem(it + 1) } }
    DisposableEffect(owner) { onDispose { if (container.reciter.isPlaying(owner)) container.reciter.stop() } }

    Box(Modifier.fillMaxSize().background(pageBackground())) {
        LazyColumn(
            Modifier.fillMaxSize().statusBarsPadding(), state = list,
            contentPadding = androidx.compose.foundation.layout.PaddingValues(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 140.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            item {
                ReaderTopBar(container, routine.title, script, shareText = routine.title + "\n\n" +
                    prayers.joinToString("\n\n") { p -> p.title + "\n" + p.lines.joinToString("\n") { it.text(script) } },
                    onBack = { go.back() })
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    RoutineIcon(routine.symbol, Saffron)
                    Text(routine.subtitle, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            itemsIndexed(prayers) { i, prayer ->
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Column(Modifier.clickable { go.prayer(prayer.id) }) {
                        Text(prayer.title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.semantics { heading() })
                        Text(prayer.about, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    prayer.verses.forEach { VerseCard(it, script, (21 * scale).sp, Palette.textTint(prayer.deity), speaking == i) }
                    prayer.meaning?.let { Text(it, fontStyle = FontStyle.Italic, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                }
            }
            item {
                OutlinedButton(
                    onClick = { if (done) container.log.unrecord(activity) else container.log.record(activity) },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp), shape = RoundedCornerShape(16.dp),
                ) {
                    Text(if (done) "✓ Done today" else "Mark as done today",
                        color = if (done) Color(0xFF34A853) else Saffron, style = MaterialTheme.typography.titleMedium)
                }
            }
        }
        ListenBar(container, owner, Saffron, Modifier.align(Alignment.BottomCenter)) { lines.map { it.second } }
    }
}
