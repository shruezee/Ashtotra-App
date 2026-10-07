package com.shruezee.ashtotra.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AutoStories
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.Restaurant
import androidx.compose.material.icons.filled.WbTwilight
import androidx.compose.material.icons.outlined.Circle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.intl.LocaleList
import androidx.compose.ui.unit.dp
import com.shruezee.ashtotra.AppContainer
import com.shruezee.ashtotra.data.Script
import com.shruezee.ashtotra.ui.theme.cardColor

/** Text in a given script, tagged with its language so TalkBack reads it with a matching voice. */
@Composable
fun ScriptText(
    text: String,
    script: Script,
    modifier: Modifier = Modifier,
    style: TextStyle = MaterialTheme.typography.bodyLarge,
    color: Color = Color.Unspecified,
) {
    val annotated = script.languageTag?.let {
        AnnotatedString(text, SpanStyle(localeList = LocaleList(it)))
    } ?: AnnotatedString(text)
    Text(annotated, modifier = modifier, style = style, color = color)
}

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        modifier = modifier.semantics { heading() },
        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
    )
}

@Composable
fun SoftCard(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    highlight: Color? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier
            .fillMaxWidth()
            .background(highlight?.copy(alpha = 0.16f) ?: cardColor, shape)
            .then(if (highlight != null) Modifier.border(2.dp, highlight.copy(alpha = 0.6f), shape) else Modifier)
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
        content = content,
    )
}

/** A row that opens something, at least 52dp tall for comfortable tapping. */
@Composable
fun NavRow(title: String, subtitle: String? = null, leading: @Composable (() -> Unit)? = null, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .heightIn(min = 56.dp)
            .background(cardColor, RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (leading != null) {
            leading()
            Spacer(Modifier.width(14.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            if (subtitle != null) {
                Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Text("›", style = MaterialTheme.typography.titleLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** iOS routines name SF Symbols; map them to Material icons. */
fun routineIcon(symbol: String): ImageVector = when (symbol) {
    "sunrise.fill" -> Icons.Filled.WbTwilight
    "book.fill" -> Icons.Filled.AutoStories
    "fork.knife" -> Icons.Filled.Restaurant
    "flame.fill" -> Icons.Filled.LocalFireDepartment
    "moon.stars.fill" -> Icons.Filled.Bedtime
    else -> Icons.Outlined.Circle
}

@Composable
fun RoutineIcon(symbol: String, tint: Color, modifier: Modifier = Modifier) {
    Icon(routineIcon(symbol), contentDescription = null, tint = tint, modifier = modifier)
}

/** Current script preference, observed. */
@Composable
fun currentScript(container: AppContainer): Script {
    val script by container.settings.script.state.collectAsState()
    return script
}
