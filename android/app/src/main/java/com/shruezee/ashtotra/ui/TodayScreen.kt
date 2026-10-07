package com.shruezee.ashtotra.ui

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.shruezee.ashtotra.AppContainer
import com.shruezee.ashtotra.data.DailyChecklist
import com.shruezee.ashtotra.data.Script
import com.shruezee.ashtotra.data.Weekday
import com.shruezee.ashtotra.ui.theme.Palette
import com.shruezee.ashtotra.ui.theme.Saffron
import com.shruezee.ashtotra.ui.theme.cardColor
import com.shruezee.ashtotra.ui.theme.pageBackground
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

private val Green = Color(0xFF34A853)

@Composable
fun TodayScreen(container: AppContainer, go: Navigator) {
    val state by container.log.state.collectAsState()
    var now by remember { mutableStateOf(LocalDateTime.now()) }
    LaunchedEffect(Unit) { while (true) { delay(60_000); now = LocalDateTime.now() } }
    val today = now.toLocalDate()
    val log = container.log
    val book = container.book

    Column(
        Modifier
            .fillMaxSize()
            .background(pageBackground())
            .verticalScroll(rememberScrollState())
            .statusBarsPadding()
            .padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(22.dp),
    ) {
        TopBar("Ashtotra") { go.settings() }

        // Greeting
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            val hello = when (now.hour) { in 4 until 12 -> "Good morning"; in 12 until 17 -> "Good afternoon"; else -> "Good evening" }
            Text("$hello 🙏", style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.SemiBold))
            Text(today.format(DateTimeFormatter.ofPattern("EEEE d MMMM")), style = MaterialTheme.typography.titleMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
            val streak = log.streak(today)
            if (log.practiced(today) || streak > 0) {
                val head = if (log.practiced(today)) "Prayed today" else "Not yet today"
                Text(if (streak > 1) "$head · $streak days in a row" else head, color = Saffron,
                    style = MaterialTheme.typography.titleSmall)
            }
        }

        // Today's practice checklist
        val checklist = remember(today) { DailyChecklist(today, book) }
        val activities = state.activities[today.toString()].orEmpty()
        val done = checklist.doneCount(activities)
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                SectionTitle("Today's practice", Modifier.weight(1f))
                Text(if (done == checklist.items.size) "All done 🙏" else "$done of ${checklist.items.size}",
                    color = if (done == checklist.items.size) Green else Saffron, style = MaterialTheme.typography.titleSmall)
            }
            Column(Modifier.background(cardColor, RoundedCornerShape(20.dp))) {
                checklist.items.forEachIndexed { i, item ->
                    ChecklistRow(item, DailyChecklist.isDone(item, activities),
                        toggle = {
                            if (DailyChecklist.isDone(item, activities)) {
                                log.unrecord(item.activity); item.alsoCounts.forEach { log.unrecord(it) }
                            } else log.record(item.activity)
                        },
                        open = {
                            when (val d = item.destination) {
                                is DailyChecklist.Destination.OpenRoutine -> go.routine(d.routine.id)
                                is DailyChecklist.Destination.OpenPrayer -> go.prayer(d.prayer.id)
                                DailyChecklist.Destination.Meditate -> go.tab(Tab.Meditate)
                            }
                        })
                    if (i < checklist.items.lastIndex) HorizontalDivider(Modifier.padding(start = 60.dp), color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
                }
            }
            Box(Modifier.fillMaxWidth().background(cardColor, RoundedCornerShape(20.dp)).clickable { go.journey() }
                .padding(14.dp).semantics(mergeDescendants = true) { contentDescription = "Your practice this week. Opens your prayer calendar." }) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("This week", style = MaterialTheme.typography.titleSmall)
                    WeekStrip(container, selected = today, onSelect = null)
                }
            }
        }

        // Today's devotion
        val devotion = Weekday.devotion(today.dayOfWeek)
        book.prayer(devotion.prayerId)?.let { prayer ->
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionTitle("Today's devotion")
                Column(
                    Modifier.fillMaxWidth().background(Palette.gradient(prayer.deity), RoundedCornerShape(24.dp))
                        .clickable { go.prayer(prayer.id) }.padding(20.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text(devotion.note, color = Color.White.copy(alpha = 0.9f), style = MaterialTheme.typography.titleSmall)
                    Text(prayer.title, color = Color.White, style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold))
                    ScriptText(prayer.nativeTitle, Script.Devanagari, color = Color.White.copy(alpha = 0.9f),
                        style = MaterialTheme.typography.titleLarge)
                    Text("🔊 Read or listen", color = Color.White, style = MaterialTheme.typography.labelLarge)
                }
                devotion.namesId?.let { container.library.collection(it) }?.let { names ->
                    NavRow("Also: 108 names of ${names.title}") { go.names(names.id) }
                }
            }
        }

        // Routines
        val current = book.routineFor(now)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionTitle("Right now")
            Column(
                Modifier.fillMaxWidth().background(cardColor, RoundedCornerShape(24.dp))
                    .border(2.dp, Saffron.copy(alpha = 0.5f), RoundedCornerShape(24.dp))
                    .clickable { go.routine(current.id) }.padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                RoutineIcon(current.symbol, Saffron, Modifier.size(32.dp))
                Text(current.title, style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold))
                Text("${current.subtitle} · ${current.prayers.size} ${if (current.prayers.size == 1) "prayer" else "prayers"}",
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            SectionTitle("Through the day", Modifier.padding(top = 6.dp))
            book.routines.filter { it.id != current.id }.chunked(2).forEach { pair ->
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    pair.forEach { routine ->
                        Column(
                            Modifier.weight(1f).heightIn(min = 120.dp).background(cardColor, RoundedCornerShape(18.dp))
                                .clickable { go.routine(routine.id) }.padding(14.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            RoutineIcon(routine.symbol, Saffron, Modifier.size(26.dp))
                            Text(routine.title, style = MaterialTheme.typography.titleMedium)
                            Text(routine.subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
        }

        // Continue chanting
        val inProgress = container.library.collections.filter { (state.position[it.id] ?: 0) > 0 }
        if (inProgress.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                SectionTitle("Continue chanting")
                inProgress.forEach { c ->
                    NavRow("${c.title}: name ${(state.position[c.id] ?: 0) + 1} of 108") { go.names(c.id) }
                }
            }
        }

        // Favourites
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            SectionTitle("Your favourites")
            val favorites = book.prayers.filter { it.id in state.favorites }
            if (favorites.isEmpty()) {
                NavRow("Tap ♡ on any prayer to keep it here", "Browse prayers") { go.tab(Tab.Prayers) }
            } else favorites.forEach { p -> NavRow(p.title) { go.prayer(p.id) } }
        }

        Text("No ads, no accounts, no tracking. Everything stays on your device.",
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.fillMaxWidth().padding(bottom = 24.dp).widthIn(max = 720.dp))
    }
}

@Composable
private fun ChecklistRow(item: DailyChecklist.Item, done: Boolean, toggle: () -> Unit, open: () -> Unit) {
    val haptics = LocalHapticFeedback.current
    Row(Modifier.fillMaxWidth().heightIn(min = 64.dp).padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = {
            if (!done) haptics.performHapticFeedback(HapticFeedbackType.Confirm)
            toggle()
        }, Modifier.semantics { contentDescription = if (done) "${item.title}, done" else "Mark ${item.title} as done" }) {
            Icon(if (done) Icons.Filled.CheckCircle else Icons.Outlined.Circle, contentDescription = null,
                tint = if (done) Green else Saffron.copy(alpha = 0.6f), modifier = Modifier.size(30.dp))
        }
        Column(Modifier.weight(1f).clickable(onClick = open).padding(vertical = 10.dp, horizontal = 6.dp)) {
            Text(item.title, style = MaterialTheme.typography.titleMedium,
                textDecoration = if (done) TextDecoration.LineThrough else null)
            Text(item.detail, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text("›", modifier = Modifier.clickable(onClick = open).padding(12.dp), color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Large title with a settings button, used on every tab. */
@Composable
fun TopBar(title: String, onSettings: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title, style = MaterialTheme.typography.headlineLarge.copy(fontWeight = FontWeight.Bold), modifier = Modifier.weight(1f))
        IconButton(onClick = onSettings) {
            Icon(Icons.Filled.Settings, contentDescription = "Settings", tint = Saffron)
        }
    }
}

/** The days of the current week as rings that fill with practice. */
@Composable
fun WeekStrip(container: AppContainer, selected: LocalDate, onSelect: ((LocalDate) -> Unit)?) {
    val state by container.log.state.collectAsState()
    val today = LocalDate.now()
    val monday = today.minusDays((today.dayOfWeek.value - 1).toLong())
    Row(Modifier.fillMaxWidth()) {
        for (offset in 0L..6L) {
            val day = monday.plusDays(offset)
            Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(day.dayOfWeek.getDisplayName(java.time.format.TextStyle.NARROW, java.util.Locale.getDefault()),
                    style = MaterialTheme.typography.labelMedium,
                    color = if (day == today) Saffron else MaterialTheme.colorScheme.onSurfaceVariant)
                DayRing(container, day, state.activities[day.toString()].orEmpty(), day == selected, showNumber = false,
                    onClick = onSelect?.let { { it(day) } })
            }
        }
    }
}
