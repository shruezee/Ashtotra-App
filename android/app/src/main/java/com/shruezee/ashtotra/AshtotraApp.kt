package com.shruezee.ashtotra

import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import com.shruezee.ashtotra.audio.Reciter
import com.shruezee.ashtotra.data.KeyValueStore
import com.shruezee.ashtotra.data.Library
import com.shruezee.ashtotra.data.PracticeLog
import com.shruezee.ashtotra.data.PrayerBook
import com.shruezee.ashtotra.data.Settings

class AshtotraApp : Application() {
    lateinit var container: AppContainer
        private set

    override fun onCreate() {
        super.onCreate()
        container = AppContainer(this)
    }
}

/** Everything the screens share. Texts load lazily, off the first frame. */
class AppContainer(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("ashtotra", Context.MODE_PRIVATE)

    val library: Library by lazy { Library.parse(context.assets.open("Ashtottara.json").bufferedReader().readText()) }
    val book: PrayerBook by lazy { PrayerBook.parse(context.assets.open("Prayers.json").bufferedReader().readText()) }
    val settings = Settings(prefs)
    val log = PracticeLog(object : KeyValueStore {
        override fun getString(key: String) = prefs.getString(key, null)
        override fun putString(key: String, value: String) { prefs.edit().putString(key, value).apply() }
    })
    val reciter = Reciter(context)
}

val Context.container: AppContainer get() = (applicationContext as AshtotraApp).container
