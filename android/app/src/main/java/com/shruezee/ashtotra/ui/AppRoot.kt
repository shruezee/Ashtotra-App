package com.shruezee.ashtotra.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Spa
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.outlined.DataUsage
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.shruezee.ashtotra.AppContainer
import com.shruezee.ashtotra.ui.theme.Saffron
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

enum class Tab(val route: String, val label: String, val icon: ImageVector) {
    Today("today", "Today", Icons.Filled.WbSunny),
    Prayers("prayers", "Prayers", Icons.Filled.MenuBook),
    Meditate("meditate", "Meditate", Icons.Filled.Spa),
    Names("names", "108 Names", Icons.Outlined.DataUsage),
}

/** Opens a screen from anywhere. */
class Navigator(private val nav: NavHostController) {
    fun prayer(id: String) = nav.navigate("prayer/$id")
    fun routine(id: String) = nav.navigate("routine/$id")
    fun names(id: String) = nav.navigate("names/$id")
    fun chant(id: String, start: Int) = nav.navigate("chant/$id/$start")
    fun journey() = nav.navigate("journey")
    fun settings() = nav.navigate("settings")
    fun meditation() = nav.navigate("session")
    fun back() = nav.popBackStack()
    fun tab(tab: Tab) = nav.navigate(tab.route) {
        popUpTo(nav.graph.findStartDestination().id) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}

@Composable
fun AppRoot(container: AppContainer, demoRoute: String? = null) {
    val nav = rememberNavController()
    val go = remember(nav) { Navigator(nav) }
    var showSplash by rememberSaveable { mutableStateOf(demoRoute == null) }

    LaunchedEffect(Unit) {
        // Load the texts while the splash is showing.
        withContext(Dispatchers.Default) {
            container.library.collections.size
            container.book.prayers.size
        }
        if (showSplash) {
            delay(1800)
            showSplash = false
        }
        demoRoute?.let { openDemoRoute(it, go, container) }
    }

    val entry by nav.currentBackStackEntryAsState()
    val route = entry?.destination?.route
    val onTab = Tab.entries.any { it.route == route }

    Box {
        Scaffold(
            bottomBar = {
                if (onTab) {
                    NavigationBar(containerColor = MaterialTheme.colorScheme.background) {
                        Tab.entries.forEach { tab ->
                            NavigationBarItem(
                                selected = route == tab.route,
                                onClick = { go.tab(tab) },
                                icon = { Icon(tab.icon, contentDescription = null) },
                                label = { Text(tab.label) },
                                colors = NavigationBarItemDefaults.colors(
                                    selectedIconColor = Saffron,
                                    selectedTextColor = Saffron,
                                    indicatorColor = Saffron.copy(alpha = 0.16f),
                                ),
                            )
                        }
                    }
                }
            },
        ) { padding ->
            NavHost(nav, startDestination = Tab.Today.route, modifier = Modifier.padding(bottom = padding.calculateBottomPadding())) {
                composable(Tab.Today.route) { TodayScreen(container, go) }
                composable(Tab.Prayers.route) { PrayersScreen(container, go) }
                composable(Tab.Meditate.route) { MeditateScreen(container, go) }
                composable(Tab.Names.route) { NamesScreen(container, go) }
                composable("prayer/{id}") { PrayerReaderScreen(container, go, it.arguments?.getString("id").orEmpty()) }
                composable("routine/{id}") { RoutineScreen(container, go, it.arguments?.getString("id").orEmpty()) }
                composable("names/{id}") { NamesReaderScreen(container, go, it.arguments?.getString("id").orEmpty()) }
                composable("chant/{id}/{start}") {
                    ChantScreen(container, go, it.arguments?.getString("id").orEmpty(),
                        it.arguments?.getString("start")?.toIntOrNull() ?: 0)
                }
                composable("journey") { JourneyScreen(container, go) }
                composable("settings") { SettingsScreen(container, go) }
                composable("session") { MeditationSessionScreen(container, go) }
            }
        }
        AnimatedVisibility(visible = showSplash, exit = fadeOut()) {
            SplashScreen()
        }
    }
}

/** Debug hooks for screenshots, e.g. `adb shell am start -e demoRoute prayer:hanuman-chalisa`. */
private fun openDemoRoute(route: String, go: Navigator, container: AppContainer) {
    val (kind, id) = route.split(":", limit = 2).let { it[0] to it.getOrNull(1) }
    if (route.contains("seed")) seedDemoHistory(container)
    when (kind) {
        "tab" -> Tab.entries.firstOrNull { it.route == id }?.let(go::tab)
        "prayer" -> id?.let { go.tab(Tab.Prayers); go.prayer(it) }
        "routine" -> id?.let(go::routine)
        "names" -> id?.let { go.tab(Tab.Names); go.names(it) }
        "chant" -> id?.split("@")?.let { go.chant(it[0], it.getOrNull(1)?.toIntOrNull() ?: 0) }
        "journey" -> go.journey()
        "settings" -> go.settings()
        "meditate" -> { go.tab(Tab.Meditate); if (id == "session") go.meditation() }
    }
}

/** A believable fortnight of practice for screenshots. */
private fun seedDemoHistory(container: AppContainer) {
    val log = container.log
    val today = java.time.LocalDate.now()
    for (offset in 1L..16L) {
        if (offset == 9L) continue
        val day = today.minusDays(offset)
        val devotion = com.shruezee.ashtotra.data.Weekday.devotion(day.dayOfWeek)
        log.record("routine:morning", day)
        if (offset % 3 != 0L) log.record("prayer:${devotion.prayerId}", day)
        if (offset % 4 != 1L) log.addMeditation(listOf(2, 5, 2, 10)[(offset % 4).toInt()], day)
        if (offset % 2 == 0L) log.record("routine:evening", day)
    }
    log.record("routine:morning")
    log.addMeditation(2)
    log.setPosition(41, "shiva")
}
