package com.shruezee.ashtotra.ui

import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.shruezee.ashtotra.AppContainer
import com.shruezee.ashtotra.data.DailyChecklist
import com.shruezee.ashtotra.data.PracticeLog
import com.shruezee.ashtotra.ui.theme.Saffron
import com.shruezee.ashtotra.ui.theme.cardColor
import com.shruezee.ashtotra.ui.theme.pageBackground
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter

/** Daily prayer tracking: streak, totals, this week, a month calendar and each day's details. */
@Composable
fun JourneyScreen(container: AppContainer, go: Navigator) {
    val state by container.log.state.collectAsState()
    val log = container.log
    var month by remember { mutableStateOf(YearMonth.now()) }
    var selected by remember { mutableStateOf(LocalDate.now()) }

    Column(
        Modifier.fillMaxSize().background(pageBackground()).verticalScroll(rememberScrollState())
            .statusBarsPadding().padding(horizontal = 20.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        BackTitle("Your practice") { go.back() }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            val streak = log.streak()
            StatTile("$streak", if (streak == 1) "day streak" else "days streak", Modifier.weight(1f))
            StatTile("${state.practiceDays.size}", "days of prayer", Modifier.weight(1f))
            StatTile("${state.meditationMinutes.values.sum()}", "min meditated", Modifier.weight(1f))
            StatTile("${state.completions.values.sum()}", "108-name malas", Modifier.weight(1f))
        }
        SoftCard {
            SectionTitle("This week")
            WeekStrip(container, selected) { selected = it }
        }
        SoftCard {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = { month = month.minusMonths(1) }) {
                    Icon(Icons.Filled.ChevronLeft, contentDescription = "Previous month", tint = Saffron)
                }
                Text(month.format(DateTimeFormatter.ofPattern("MMMM yyyy")), modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold))
                IconButton(onClick = { month = month.plusMonths(1) }, enabled = month < YearMonth.now()) {
                    Icon(Icons.Filled.ChevronRight, contentDescription = "Next month", tint = Saffron)
                }
            }
            Row {
                listOf("M", "T", "W", "T", "F", "S", "S").forEach {
                    Text(it, Modifier.weight(1f), textAlign = TextAlign.Center, style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            val first = month.atDay(1)
            val cells = List(first.dayOfWeek.value - 1) { null } + (1..month.lengthOfMonth()).map { month.atDay(it) }
            cells.chunked(7).forEach { week ->
                Row(Modifier.fillMaxWidth()) {
                    week.forEach { day ->
                        Box(Modifier.weight(1f), contentAlignment = Alignment.Center) {
                            if (day != null) {
                                DayRing(container, day, state.activities[day.toString()].orEmpty(), day == selected,
                                    showNumber = true) { selected = day }
                            }
                        }
                    }
                    repeat(7 - week.size) { Spacer(Modifier.weight(1f)) }
                }
            }
        }
        DayDetail(container, selected, state.activities[selected.toString()].orEmpty(),
            state.meditationMinutes[selected.toString()] ?: 0)
        Spacer(Modifier.size(24.dp))
    }
}

@Composable
private fun DayDetail(container: AppContainer, day: LocalDate, activities: Set<String>, minutes: Int) {
    val checklist = remember(day) { DailyChecklist(day, container.book) }
    SoftCard {
        SectionTitle(if (day == LocalDate.now()) "Today" else day.format(DateTimeFormatter.ofPattern("EEEE d MMMM")))
        Text("${checklist.doneCount(activities)} of ${checklist.items.size} daily practices", color = Saffron,
            style = MaterialTheme.typography.titleSmall)
        if (activities.isEmpty()) {
            Text(if (day.isAfter(LocalDate.now())) "This day is still to come." else "Nothing recorded for this day.",
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        } else activities.sorted().forEach { Text("• ${describe(container, it, minutes)}") }
    }
}

/** Readable text for an activity string from [PracticeLog]. */
fun describe(container: AppContainer, activity: String, minutes: Int): String {
    val (kind, id) = activity.split(":", limit = 2).let { it[0] to it.getOrNull(1) }
    return when (kind) {
        "routine" -> id?.let { container.book.routine(it)?.title } ?: activity
        "prayer" -> id?.let { container.book.prayer(it)?.title } ?: activity
        "chant" -> "108 names of ${id?.let { container.library.collection(it)?.title } ?: id}"
        PracticeLog.MEDITATION -> "Meditated $minutes ${if (minutes == 1) "minute" else "minutes"}"
        else -> activity
    }
}

@Composable
fun StatTile(value: String, label: String, modifier: Modifier = Modifier) {
    Column(
        modifier.heightIn(min = 76.dp).background(cardColor, RoundedCornerShape(16.dp)).padding(8.dp)
            .semantics(mergeDescendants = true) {},
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(value, style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold))
        Text(label, style = MaterialTheme.typography.labelSmall, textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
fun DayRing(
    container: AppContainer,
    day: LocalDate,
    activities: Set<String>,
    selected: Boolean,
    showNumber: Boolean,
    onClick: (() -> Unit)?,
) {
    val checklist = remember(day) { DailyChecklist(day, container.book) }
    val progress = checklist.progress(activities)
    val future = day.isAfter(LocalDate.now())
    val ringColor = if (progress >= 1f) Color(0xFF34A853) else Saffron
    Box(
        Modifier
            .size(44.dp)
            .background(if (selected) Saffron.copy(alpha = 0.15f) else Color.Transparent, CircleShape)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .semantics {
                contentDescription = "${day.format(DateTimeFormatter.ofPattern("EEEE d MMMM"))}, " +
                    "${checklist.doneCount(activities)} of ${checklist.items.size} practices"
                this.selected = selected
            },
        contentAlignment = Alignment.Center,
    ) {
        Canvas(Modifier.size(34.dp)) {
            val stroke = 4.dp.toPx()
            val inset = stroke / 2
            val arcSize = Size(size.width - stroke, size.height - stroke)
            drawArc(Saffron.copy(alpha = if (future) 0.06f else 0.15f), 0f, 360f, false, Offset(inset, inset), arcSize, style = Stroke(stroke))
            if (progress > 0f) {
                drawArc(ringColor, -90f, 360f * progress, false, Offset(inset, inset), arcSize, style = Stroke(stroke, cap = StrokeCap.Round))
            }
        }
        if (showNumber) {
            Text("${day.dayOfMonth}", style = MaterialTheme.typography.labelMedium.copy(
                fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal))
        } else if (progress >= 1f) {
            Icon(Icons.Filled.Check, contentDescription = null, tint = ringColor, modifier = Modifier.size(14.dp))
        }
    }
}

/** Back arrow and a title, for pushed screens. */
@Composable
fun BackTitle(title: String, onBack: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        IconButton(onClick = onBack) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
        }
        Text(title, style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.SemiBold))
    }
}
