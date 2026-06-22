# 🐊 Patchi-Wani

**A tap game for young children — catch the crocodile before it disappears!**

Tap the crocodile as it appears on screen. The game runs for 60 seconds and is designed to be picked up and played in short sessions.

**[▶ ブラウザでプレイ](https://togakyo.github.io/patchi-wani/)**

---

## Screenshots

<!-- Replace with actual screenshots when available -->
```
[Start screen]     [Game screen]      [Block editor]      [Result screen]
  🐊               🎯               🟪🟩🟨              🏆
  Patchi-Wani!     ━━ 12 pts ━━     Customize rules      Well done!
  Catch me!        42 sec left       with blocks          15 points
```

---

## Features

- **60-second sessions** — short enough to hold a young child's attention
- **Auto difficulty scaling** — target shrinks as score increases
- **Scratch-style block editor** — children can customize game rules by dragging blocks
- **Replaceable sound effects** — swap in a parent's recorded voice
- **High-contrast color scheme** — dark background `#0D1117`, vivid red target `#FF3B30`

---

## Architecture

```
Flutter (FE)  ←─ dart:ffi ─→  Rust Engine (BE)
     │                               │
     └── Scratch Block Editor        └── GameRule JSON
         Blocks → JSON → Rust            Game loop · scoring · difficulty
```

| Layer | Tech | Role |
|-------|------|------|
| Frontend | Flutter (Dart) | UI, touch input, block editor |
| Bridge | `dart:ffi` | C ABI calls between Flutter and Rust |
| Backend | Rust | Game loop, score management, difficulty scaling |
| Data | JSON / SQLite | Rule config, play log |

---

## Requirements

| Tool | Min version | Purpose |
|------|-------------|---------|
| Rust | 1.77+ | Game engine (BE) |
| Flutter | 3.22+ | UI (FE) |
| Android Studio | Latest | Android build & emulator |
| Xcode | 15+ | iOS build (macOS only) |
| Android NDK | r25c+ | Rust → Android cross-compilation |

---

## Quick start

```bash
git clone https://github.com/<your-username>/patchi-wani.git
cd patchi-wani

# 1. Install dependencies (first time only, ~15–30 min)
chmod +x setup.sh && ./setup.sh

# 2. Verify the Rust engine
cd patchi_wani_engine && cargo test && cd ..

# 3. Run the Flutter app on a simulator
cd patchi_wani_flutter && flutter run
```

For full build instructions (Android APK, iOS) see **[SETUP.md](./SETUP.md)**.

### UI development in Chrome (no Rust build required)

A pure-Dart stub replaces the Rust engine on web, so you can iterate on the UI without a simulator or device:

```bash
cd patchi_wani_flutter
flutter run -d chrome
```

> Game logic runs as a Dart simulation — scoring, difficulty, and target size all work, but behaviour may differ slightly from the native Rust engine.

---

## Repository layout

```
patchi-wani/
├── patchi_wani_engine/       # 🦀 Rust game engine
│   ├── Cargo.toml
│   └── src/lib.rs            # C ABI exports + game logic + unit tests
│
├── patchi_wani_flutter/      # 🐦 Flutter app
│   ├── lib/
│   │   ├── game/             # FFI bridge, game controller
│   │   ├── scratch/          # Block definitions, JSON conversion
│   │   └── screens/          # Game screen, block editor screen
│   └── assets/
│       ├── audio/            # Sound files (place .mp3 files here)
│       └── images/           # Character images (place files here)
│
├── setup.sh                  # Environment setup script
├── build_all.sh              # One-command build script
├── SETUP.md                  # Detailed build instructions
├── CONTRIBUTING.md           # Contribution guide
└── LICENSE                   # MIT License
```

---

## Customization

### Change the target character

Edit the emoji in `patchi_wani_flutter/lib/screens/game_screen.dart`, inside the `_Target` widget:

```dart
// Before
child: Text('🐊', style: TextStyle(fontSize: size * 0.44)),

// After (example: dinosaur)
child: Text('🦖', style: TextStyle(fontSize: size * 0.44)),
```

To use an image file instead, place it in `assets/images/` and switch to `Image.asset()`.

### Replace sound effects with a parent's voice

1. Record a short clip (e.g. "Great job!") and save it as `assets/audio/hit.mp3`
2. Record a longer clip for the end of game and save as `assets/audio/fanfare.mp3`
3. Update the `// CUSTOMIZE` section in `game_screen.dart`:

```dart
final player = AudioPlayer();
await player.play(AssetSource('audio/hit.mp3'));
```

### Customize game rules with blocks

Tap **"⚙ ルールをかえる"** on the start screen to open the block editor. Drag and drop blocks to change game duration, difficulty thresholds, and target sizes.

---

## Roadmap

- [ ] **Tracking mode** — target moves across the screen
- [ ] **Figure-ground mode** — noisy background makes the target harder to spot
- [ ] **Play log** — chart daily scores (SQLite already wired up)
- [ ] **CI** — GitHub Actions for Android/iOS builds

---

## Contributing

Bug reports and feature requests are welcome via [Issues](https://github.com/<your-username>/patchi-wani/issues).
Pull requests are also welcome — see [CONTRIBUTING.md](./CONTRIBUTING.md).

---

## License

[MIT License](./LICENSE)

---

## License

This is a personal hobby project — feel free to use and adapt it.
