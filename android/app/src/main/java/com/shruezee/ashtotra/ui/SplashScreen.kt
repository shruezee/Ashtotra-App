package com.shruezee.ashtotra.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.colorResource
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.shruezee.ashtotra.R
import com.shruezee.ashtotra.ui.theme.Saffron
import kotlinx.coroutines.delay

/**
 * Picks up where the system splash leaves off (same colour, icon in the centre), then adds
 * the name, a loading message and the copyright line.
 */
@Composable
fun SplashScreen() {
    val messages = listOf("Lighting the lamp…", "Preparing your prayers…", "Taking a calm breath…")
    var shown by remember { mutableStateOf(false) }
    var index by remember { mutableIntStateOf(0) }
    val glow by animateFloatAsState(if (shown) 1f else 0f, tween(900), label = "glow")

    LaunchedEffect(Unit) {
        shown = true
        for (i in 1 until messages.size) {
            delay(650)
            index = i
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(colorResource(R.color.paper))
            .semantics(mergeDescendants = true) {
                contentDescription = "Ashtotra. ${messages[index]} Copyright 2026 Shruezee Studio."
            },
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .size(380.dp)
                .scale(0.85f + 0.23f * glow)
                .alpha(glow)
                .background(Brush.radialGradient(listOf(Saffron.copy(alpha = 0.28f), Color.Transparent)), CircleShape),
        )
        Box(
            Modifier
                .size(120.dp)
                .shadow((18 * glow).dp, RoundedCornerShape(28.dp), spotColor = Saffron)
                .clip(RoundedCornerShape(28.dp))
                .background(Brush.radialGradient(listOf(Color(0xFFFFB347), Color(0xFFED6B1F), Color(0xFF8C1A29)))),
        ) {
            Image(painterResource(R.mipmap.ic_launcher_foreground), contentDescription = null,
                modifier = Modifier.fillMaxSize().scale(1.5f))
        }
        Column(
            Modifier.offset(y = 120.dp).alpha(glow),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("Ashtotra", style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold))
            AnimatedContent(index, transitionSpec = { fadeIn() togetherWith fadeOut() }, label = "message") {
                Text(messages[it], style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Spacer(Modifier.height(2.dp))
            CircularProgressIndicator(Modifier.size(22.dp), color = Saffron, strokeWidth = 2.dp)
        }
        Text(
            "© 2026 Shruezee Studio",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(bottom = 16.dp).alpha(glow),
        )
    }
}
