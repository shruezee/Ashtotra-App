<p align="center">
  <img src="images/app-icon.jpg" width="110" alt="Ashtotra app icon: a golden Om inside a ring of 108 beads">
</p>

<h1 align="center">Ashtotra</h1>

<p align="center"><b>Daily prayers and 108 sacred names, in your script.</b><br>
Morning-to-night prayer routines, stotras like the Hanuman Chalisa and Aditya Hrudayam, the Om Jai Jagadish Hare aarti, and the 108 names of Ganesha, Shiva, Lakshmi and Saraswati. Read in English, IAST, Devanagari, Telugu, Kannada or Gujarati, or listen read aloud.</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2017%2B%20%7C%20iPadOS-lightgrey?style=flat-square">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-SwiftUI%20%2B%20Observation-orange?style=flat-square">
  <img alt="Accessibility" src="https://img.shields.io/badge/accessibility-VoiceOver%20%7C%20Dynamic%20Type-blue?style=flat-square">
  <img alt="Privacy" src="https://img.shields.io/badge/data%20collected-none-brightgreen?style=flat-square">
</p>

<p align="center">
  🌐 <a href="https://shruezee.github.io/Ashtotra-App/">Website</a> · 🔒 <a href="https://shruezee.github.io/Ashtotra-App/privacy.html">Privacy policy</a> · 🧪 Status: submitted to the App Store (in review)
</p>

<p align="center">
  <img src="images/01-today.jpg" width="200" alt="Today screen">
  <img src="images/02-hanuman-chalisa.jpg" width="200" alt="Hanuman Chalisa in Devanagari with Listen">
  <img src="images/03-morning-prayers.jpg" width="200" alt="Morning prayers with meanings">
  <img src="images/04-chant-telugu.jpg" width="200" alt="Chant mode in Telugu">
</p>

## Version 3.0: a ground-up rewrite

Ashtotra first shipped in 2019 as a UIKit app that displayed bundled PDFs, with AdMob ads. Version 3.0 replaces all of it:

| | 2019 (v2) | 2026 (v3) |
|---|---|---|
| UI | UIKit, storyboards | SwiftUI, Observation |
| Content | 106 third-party PDFs | 23 prayers + 4 × 108 names as text, generated in 6 scripts |
| Audio | Streamed third-party recordings | Offline read-aloud with the system voice |
| Accessibility | Fixed-size PDF pages | Dynamic Type up to AX5, VoiceOver with per-script speech language, Reduce Motion |
| Privacy | AdMob + Firebase | No SDKs, no network, privacy manifest |
| Tests | One XCTest | Swift Testing suite over data integrity and progress logic |

## Features

- **Today:** a greeting, the day's traditional devotion (Monday Shiva, Tuesday Hanuman, Friday Lakshmi…), the prayer routine for this time of day, and anything you were in the middle of
- **Daily routines:** morning, before study, before meals, evening lamp, before sleep: 17 short mantras with meanings
- **Stotras and aarti:** Hanuman Chalisa, Aditya Hrudayam, Ganesha Pancharatnam, Sri Suktam, Narayana Suktam, Om Jai Jagadish Hare
- **Listen:** read aloud offline with the device's Hindi voice, line by line with highlighting and auto-scroll; three paces
- **Chant mode** for the 108 names: one name at a time inside a 108-bead mala, or hands-free with Listen
- **Six scripts:** easy English, IAST, देवनागरी, తెలుగు, ಕನ್ನಡ, ગુજરાતી, switchable anywhere
- **Make it yours:** favourites, larger reading text, share a prayer, a gentle daily reminder, a soft day streak
- **Calm design:** warm gradients per deity, dark mode, iPad layout

## Engineering highlights

| Area | How it's built |
|---|---|
| Prayers | Stotras converted from the 2019 app's texts (Vignanam romanisation → IAST), typos fixed, sandhi joined correctly in Indic scripts (गुरुर्ब्रह्मा, पूर्णमदः); daily mantras and the aarti written out by hand and transliterated |
| Read aloud | `AVSpeechSynthesizer` with the best installed `hi-IN` voice speaking the Devanagari text, an `@Observable` `Reciter` publishing the current line so any screen can highlight and follow; replaces the 2019 app's third-party audio streams |
| Reminders | One repeating `UNCalendarNotificationTrigger`, scheduled only after the user turns it on |
| Content pipeline | Names parsed from ITRANS-style romanisation → IAST → Devanagari, Telugu, Kannada and Gujarati with a deterministic transliterator. Typos corrected and every list cross-checked against a second source; Ganesha, Shiva, Lakshmi and Saraswati verified at all 108 positions |
| Data | One bundled `Ashtottara.json`, decoded into `Codable` models |
| State | `@Observable` `PracticeLog` persisted to `UserDefaults`; `@AppStorage` for settings |
| Accessibility | `AttributedString.languageIdentifier` so VoiceOver reads Devanagari in Hindi, Telugu in Telugu, etc.; named accessibility actions for next/previous; chrome capped at large sizes while the name keeps scaling |
| Screenshots | Debug-only launch arguments (`-demoRoute shiva -demoChant 11 -script telugu`) open any screen directly, so App Store screenshots are reproducible |
| Testing | **Swift Testing**: every list has 108 names, every script is filled, Indic scripts contain no stray Latin letters, progress clamps, streaks, persistence |
| Privacy | `PrivacyInfo.xcprivacy`: no tracking, no collected data, UserDefaults reason CA92.1 |

### Project structure

```
Ashtotra/
├── AshtotraApp.swift
├── Models/        Library (108 names), PrayerBook (prayers, routines, weekdays),
│                  PracticeLog, Reciter (read aloud), DailyReminder
├── Views/         Root tabs, Today, Prayers, PrayerReader, Routine,
│                  Names, Reader, Chant, Settings, Theme
└── Resources/     Ashtottara.json, Prayers.json
AshtotraTests/     Swift Testing suite
AppStore/          App Store screenshots and listing text
```

## Running it

1. Open `Ashtotra.xcodeproj` in Xcode 26 or later.
2. Select your own team under **Signing & Capabilities**.
3. Run on an iPhone or iPad simulator (iOS 17+). Run the tests with **⌘U**.

## Coming next

More 108-name lists (Hanuman, Rama, Krishna, Durga, Subrahmanya), each added only after it checks out at all 108 positions, and verse-by-verse meanings for the stotras.

## About

Designed and built by **[Shruthi](https://github.com/shruezee)**, an iOS developer in Sydney. See also [KindDose](https://github.com/shruezee/KindDose) and [MiniMingle Games](https://github.com/shruezee/MiniMingle-Games).

© 2026 ShruthiRamKum
