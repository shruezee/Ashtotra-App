package com.shruezee.ashtotra

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.shruezee.ashtotra.ui.AppRoot
import com.shruezee.ashtotra.ui.theme.AshtotraTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val demoRoute = intent.getStringExtra("demoRoute")
        if (BuildConfig.DEBUG) {
            intent.getStringExtra("demoScript")?.let { container.settings.script.value = com.shruezee.ashtotra.data.Script.fromKey(it) }
        }
        setContent {
            AshtotraTheme {
                AppRoot(container, demoRoute = if (BuildConfig.DEBUG) demoRoute else null)
            }
        }
    }
}
