# TOMO 📖

### Your manga. Your library. Your way.

TOMO is a native Android manga reader designed to make discovering, organizing, and reading manga feel simple.

Browse the WeebCentral catalog, build your personal library, keep track of what you've read, and jump straight back into your current chapter — all from one clean Android app.

**No WebView. No clutter. Just manga.**

---

## ✨ Why TOMO?

Manga shouldn't feel like you're navigating a website from 2012.

TOMO brings the catalog and content you already want into an interface designed specifically for reading on Android.

### 🔎 Discover

Search through the WeebCentral catalog and find your next read.

Use advanced filters to narrow things down by:

* Genre & tags
* Series type
* Status
* Popularity
* Subscribers
* Latest updates
* Official translation
* Anime adaptation
* Adult content

And when the first results aren't enough, just **Load More**.

### 📚 Build your library

Found something worth reading?

Add it to TOMO.

Your library stays on your device, giving you a personal collection of the manga you actually care about.

### ▶️ Pick up where you left off

TOMO keeps track of your reading progress so you don't have to remember where you stopped.

Open your library and continue reading from where you left off.

### 📖 Just read

The reader is built around one thing:

**reading.**

Pages are displayed one at a time with simple navigation controls, while TOMO keeps your chapter and page progress saved locally.

No unnecessary controls.

No distracting interface.

Just the page you're reading.

---

## 🎨 Designed for reading

TOMO uses a dark, minimal interface with a pink accent to keep the focus where it belongs: on the manga.

Every part of the interface is designed to stay out of the way.

---

## 🚀 Features

|     | Feature                     |
| --- | --------------------------- |
| 🔎  | WeebCentral catalog search  |
| 🎛️ | Advanced search filters     |
| 📚  | Personal manga library      |
| ▶️  | Continue Reading            |
| 📖  | Page-based manga reader     |
| 💾  | Persistent reading progress |
| 📑  | Chapter tracking            |
| ⚡   | Image preloading & caching  |
| 📱  | Native Android interface    |
| 🌙  | Dark-focused UI             |
| 🎨  | TOMO visual identity        |

---

## 📱 Get TOMO

### Requirements

* Android device
* Android 8.0+ recommended
* Internet connection for manga discovery and reading

### Download

> 🚧 **TOMO is currently in active development.**
>
> Release downloads will be published here when a public release build is available.

---

## 🧭 TOMO 1.4

* Visual refresh (same logo + pink)
* Settings from Home and Library
* Library grid / list toggle
* Continue ordered by last opened

## 🧭 TOMO 1.3

* Request queue + retry on HTTP 429
* Disk cache for search, series, chapter lists and page URLs
* Background update check waits and goes one series at a time
* Continue reading pauses that background check
* Backup / restore from Settings (Library tab)
* Offline chapter download from the series page

## 🧭 TOMO 1.2

This tree is the 1.2 refactor. It keeps your local library keys (`tomo_library`, `tomo_read_*`, `tomo_page_*`, `tomo_last_*`) so existing installs can migrate without losing progress.

What changed in 1.2:

* One WeebCentral client + shared HTML parsers
* Search now sends `included_status` and `included_type`
* Tags / authors / description parsing is less brittle
* Shared `LibraryStore` so Home and Library stay in sync
* Reader tap zones, swipe, hide-able UI, and webtoon mode
* Image requests send the WeebCentral referer
* MIT license

## 🛠️ Build it yourself

If you want to run TOMO directly from source:

```bash
git clone https://github.com/atanmontes/tomo-apk.git
cd tomo-apk
flutter pub get
flutter run
```

To create a release APK:

```bash
flutter build apk --release
```

Your APK will be generated at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

## 🧩 Built with

TOMO is powered by:

* **Flutter**
* **Dart**
* **WeebCentral**
* **HTTP & HTML parsing**
* **Shared Preferences**

The app communicates with the available WeebCentral catalog/content endpoints and presents them through a native Android interface.

---

## 🗺️ What's next?

TOMO is still evolving.

Some of the things planned for the future include:

* ❤️ Favorites & likes
* 🕘 Reading history
* 🔔 Subscriptions
* 📊 Better library organization
* ⭐ Recommendations
* 👤 Account/session support
* ☁️ Reading synchronization
* 🎨 More reader customization
* ⚡ Further performance improvements

The goal isn't to make TOMO the most complicated manga app.

It's to make it the one you actually want to open.

---

## ⚠️ Disclaimer

TOMO does not host manga content.

It provides a native interface for accessing catalog and reading content from its external source.

Please respect the terms of the services you use and the copyright laws applicable in your region.

---

## ❤️ TOMO

**Discover something new.
Save what you love.
Continue where you left off.**

### **TOMO — Manga, without the clutter.**
