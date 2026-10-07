package com.shruezee.ashtotra.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp

val Saffron = Color(0xFFE36B1A)

private val PaperLight = Color(0xFFFFF8E8)
private val PaperDeepLight = Color(0xFFFCE6CC)
private val PaperDark = Color(0xFF1C141F)
private val PaperDeepDark = Color(0xFF2B1A29)

private val LightColors = lightColorScheme(
    primary = Saffron,
    onPrimary = Color.White,
    secondary = Color(0xFFB0451A),
    background = PaperLight,
    surface = PaperLight,
    surfaceContainer = Color(0xC0FFFFFF),
    onBackground = Color(0xFF2A1A12),
    onSurface = Color(0xFF2A1A12),
    onSurfaceVariant = Color(0xFF6F5B4D),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFFFA463),
    onPrimary = Color(0xFF3A1600),
    secondary = Color(0xFFFFB07A),
    background = PaperDark,
    surface = PaperDark,
    surfaceContainer = Color(0x14FFFFFF),
    onBackground = Color(0xFFF6ECE4),
    onSurface = Color(0xFFF6ECE4),
    onSurfaceVariant = Color(0xFFC4B3A6),
)

@Composable
fun AshtotraTheme(content: @Composable () -> Unit) {
    MaterialTheme(colorScheme = if (isSystemInDarkTheme()) DarkColors else LightColors, content = content)
}

/** Warm cream by day, deep plum at night (same as iOS). */
@Composable
fun pageBackground(): Brush = if (isSystemInDarkTheme()) {
    Brush.verticalGradient(listOf(PaperDark, PaperDeepDark))
} else {
    Brush.verticalGradient(listOf(PaperLight, PaperDeepLight))
}

/** Translucent card fill on the page background. */
val cardColor: Color
    @Composable @ReadOnlyComposable get() = MaterialTheme.colorScheme.surfaceContainer

/** Each deity's pair of colours, matching the iOS palette keys. */
object Palette {
    fun colors(key: String): Pair<Color, Color> = when (key) {
        "orange" -> Color(0xFFFA8C29) to Color(0xFFCC401A)
        "indigo" -> Color(0xFF5C6BD1) to Color(0xFF292B75)
        "pink" -> Color(0xFFED668C) to Color(0xFFAD2659)
        "teal" -> Color(0xFF2E9E9E) to Color(0xFF0D5970)
        "gold" -> Color(0xFFFAB833) to Color(0xFFC76B0D)
        "blue" -> Color(0xFF4094E6) to Color(0xFF144799)
        "saffron" -> Color(0xFFFC7833) to Color(0xFFB82E1F)
        else -> Color(0xFFFA8C29) to Color(0xFFCC401A)
    }

    fun gradient(key: String): Brush = colors(key).let { (a, b) -> Brush.linearGradient(listOf(a, b)) }

    /** Fills (buttons, cards) use the deep shade. */
    fun tint(key: String) = colors(key).second

    /** Text on the page: deep shade by day, a lighter shade at night for contrast. */
    @Composable
    fun textTint(key: String): Color =
        if (isSystemInDarkTheme()) lerp(colors(key).first, Color.White, 0.3f) else colors(key).second
}
