# CLAUDE.md — Grabgold

2D-Action-RPG (Top-down, ALTTP-Tempo), **Vertical Slice**. Priorität: **Kampfgefühl**, nicht Umfang.

## Engine & Aufruf

Das Projekt wird auf **zwei Maschinen** entwickelt. Godot liegt auf **keiner** von beiden im PATH.
`$GODOT` unten steht jeweils für den passenden Aufruf der eigenen Maschine.

**Linux (Flatpak) — Godot `4.6.1.stable`**

- `GODOT="flatpak run org.godotengine.Godot"`

**Windows 11 (portable EXE) — Godot `4.6.3.stable`**

- `GODOT="$env:USERPROFILE\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"`
  (Aufruf in PowerShell mit `& $GODOT ...`)
- **Achtung, Stolperfalle:** `Godot_v4.6.3-stable_win64.exe` ist ein **Ordner**, nicht die Binary.
  Immer die `_console.exe` darin nehmen — die GUI-Variante gibt headless keine Ausgabe zurück.
- Kein Flatpak, kein `godot`-Alias. Bash-Aufrufe der `.exe` scheitern („Is a directory"),
  darum für Godot-Kommandos **PowerShell** verwenden.

**Kommandos (beide Maschinen, `$GODOT` einsetzen)**

- Editor öffnen: `$GODOT --editor --path .`
- Spiel starten: `$GODOT --path .`
- Headless-Import (CI/Validierung): `$GODOT --headless --path . --import`
- Klassen-DB dumpen bei Signatur-Zweifel: `$GODOT --headless --doctool <out>`
  — **`<out>` muss vorher existieren**, sonst „Argument supplied to --doctool must be a valid
  directory path"; Ergebnis landet in `<out>/doc/classes/*.xml` (~1063 Klassen).

**Versions-Delta 4.6.1 ↔ 4.6.3:** nur Patch-Level, keine bekannten API-Unterschiede für dieses
Projekt. Bei Signatur-Zweifeln gilt trotzdem Regel Null gegen die **lokal** gedumpte Klassen-DB.

- **Regel Null:** Methodensignaturen (`move_and_slide`, `AnimationPlayer` Call-Method-Tracks,
  Area2D-Masken) gegen die echte Klassen-DB/lokale Doku prüfen — nie aus dem Gedächtnis raten.
- **4.6-Besonderheit:** `TileMap` gibt es nicht mehr → **`TileMapLayer`** verwenden (Phase 6).

## Auflösung & Look

- **Interne Auflösung: 320×180** (provisorisch, angenommene 16×16-Tiles → 20 Tiles horizontal).
  Integer-Scaling **×6 = 1920×1080**. Dev-Fenster ×4 = 1280×720.
- Beim echten Asset-Pack **neu ableiten** (Tile-Größe inspizieren; 15–25 Tiles horizontal, muss
  ganzzahlig auf 1080p skalieren). Siehe `docs/assets-todo.md`.
- Stretch `canvas_items`, aspect `keep`, **scale_mode `integer`**. Texture-Filter **Nearest** (0).
  `snap_2d_transforms_to_pixel=true`. Kein Sub-Pixel-Movement bei Sprites (Flimmer-Gefahr).
- **Camera2D Position Smoothing bleibt AUS.** Smoothing erzeugt Sub-Pixel-Kamerapositionen und damit
  Tile-Seams — trotz gesnappter Sprites. Nachrüsten später nur mit explizit auf ganze Pixel
  gesnappter Kamera-Position.
- Renderer: **Forward+**. Y-Sort für Tiefenstaffelung (ab Phase 1/3).

## Assets (Pack)

- **Ninja Adventure Asset Pack** (Pixel-boy + AAA), **CC0** — unter
  `assets/external/Ninja Adventure - Asset Pack/`. Attribution nicht nötig, aber erwünscht
  (`docs/credits.md`).
- **Tiles: 16×16** → bestätigt interne Auflösung 320×180.
- **Spieler = NinjaGreen** (`Actor/CharacterAnimated/NinjaGreen/Separate/`), **Frame 32×32**,
  **Spalten = Richtungen** (0=down, 1=up, 2=left, 3=right), **Zeilen = Animations-Frames** (Left/Right
  ggf. zur Laufzeit tauschen). Attack = **4 Frames** → TuningStats 3/6/3.
- Gesliced zu `res://resources/player_ninja_frames.tres` (SpriteFrames, 16 Anims: idle/walk/attack/hurt
  × 4 Richtungen). **`.tres` nie von Hand** — per Godot-Tool-Skript bauen (Engine serialisiert).
- **Input-Actions** (in `project.godot`): `move_up/down/left/right` (WASD + Pfeile), `attack` (J + Space).

## Movement- und Combat-Konventionen

1. **Movement hat bewusst fast keine Beschleunigungsrampe** (ALTTP-Tempo, kein Metroidvania-
   Momentum). Vollgeschwindigkeit in **~2–3 Frames**, Stopp **nahezu instant**. Werte liegen in
   `TuningStats` (`acceleration`, `friction`). **Wer diese Werte erhöht, ändert das Spielgefühl
   grundlegend — nicht ohne Rücksprache.**
2. **Facing bei Diagonaleingabe: horizontale Richtung hat Priorität.** 4-Richtungs-Sprites; die
   Seitenansicht liest sich am besten. (Reines Hoch/Runter ohne Horizontalanteil → vertikales Facing.)
3. **Facing ist ab Attack-Startup bis Ende der Active-Frames gesperrt.** Invariante, nicht optional —
   sonst rotiert die Hitbox mitten im Schlag. Erst ab Recovery wieder frei drehbar.

## Collision-Layer-Matrix

Layer = „was bin ich", Mask = „was scanne ich". Nur **Hitbox** aktiv (`monitoring=true`);
**Hurtbox** passiv (`monitorable=true, monitoring=false`).

| Bit | Name | Nodes | Layer | Mask |
|---|---|---|---|---|
| 1 | `environment` | TileMapLayer-Kollision, Wände, Türen (solid) | 1 | — |
| 2 | `player_body` | Player `CharacterBody2D` | 2 | 1 |
| 3 | `enemy_body` | Enemy `CharacterBody2D` | 3 | 1 (+2 opt.) |
| 4 | `player_hurtbox` | Area2D Player, verwundbar | 4 | — |
| 5 | `player_hitbox` | Area2D Player-Angriff | 5 | 6 |
| 6 | `enemy_hurtbox` | Area2D Gegner, verwundbar | 6 | — |
| 7 | `enemy_hitbox` | Area2D Gegner-Angriff | 7 | 4 |
| 8 | `interactable` | Schalter/Tür-Trigger | 8 | — (Player-Interact scannt 8) |

**Phase-Dash (Reif, Phase 5):** zur Laufzeit `player_body`-Mask um Bit 3 kürzen + Player-Hurtbox
aussetzen (invuln). Nur Masken toggeln, keinen Node-Umbau.

## Ordnerstruktur (Feature-Folder)

```
assets/{external/<packname>/,  placeholder/}   external = manuell abgelegte Packs, nie herunterladen
docs/{progress,credits,assets-todo}.md
globals/            Autoloads (hitstop_manager.gd, debug.gd)
resources/          tuning_stats.gd (class_name TuningStats) + *.tres pro Aktor
components/         hitbox, hurtbox, state_machine/  (wiederverwendbar)
actors/player/      player.tscn/.gd + states/{idle,move,attack,hurt}.gd
actors/enemy/       enemy.tscn/.gd + states/{idle,approach,telegraph,attack,retreat,hurt}.gd
ui/debug_overlay/   debug_overlay.tscn/.gd
scenes/             main.tscn (Bootstrap/Arena) + rooms/room_01.tscn (Phase 6)
```

## Namenskonventionen

- Dateien/Ordner: `snake_case`. Skript-Datei = Node-Zweck (`player.gd`, `hitbox.gd`).
- `class_name`: `PascalCase` (`TuningStats`, `StateMachine`, `Hitbox`).
- Nodes in Szenen: `PascalCase`. Signale: `snake_case`, Vergangenheitsform (`hit_landed`).
- Konstanten `UPPER_SNAKE`, private Member `_leading_underscore`.
- **Type Hints Pflicht.** Timings in **Frames** (int), nicht Sekunden, wo an Animation gekoppelt.

## Feel-Tuning → Resource, nicht Skript

Alle Feel-Werte liegen in `resources/tuning_stats.gd` (`class_name TuningStats extends Resource`)
und je Aktor als `.tres` (`player_kurier.tres`, `player_zwerg.tres`, `enemy_*.tres`). Felder u. a.:
`max_speed, acceleration, friction, attack_startup_frames, attack_active_frames,
attack_recovery_frames, knockback_speed, knockback_curve, knockback_duration, hitstop_frames,
iframe_duration, iframe_blink_interval, attack_buffer_frames, attack_damage, max_health`.
**Werte ändert man ausschließlich im `.tres`, nie im Code.** Attack-Frame-Werte richten sich nach
den Frames der Angriffsanimation aus dem Pack — nicht umgekehrt.

## Kernmechanik-Merker (Reif, Phase 5)

Zeitdehnung/Hitstop **niemals** über `Engine.time_scale` (träfe UI + Partikel). Immer über den
`HitstopManager`-Autoload, der nur die betroffenen Aktor-Nodes pausiert.

## State-Machine (generisch) & Gegner-KI

- **`components/state_machine/`** ist generisch: `StateMachine` injiziert `child.actor = get_parent()`,
  `State` hält `var actor: Node`. Konkrete States casten lokal (`var player := actor as Player`
  bzw. `var enemy := actor as Skeleton`). Von Player UND Gegnern genutzt.
- **Timing-Konvention:** Der **Player-Angriff** läuft über den AnimationPlayer-Call-Method-Track
  (frame-genaues Hitbox-Toggling). **Gegner-KI-Timing** (Telegraph/Active/Retreat) läuft über
  **Frame-Counting in den States** (deterministisch, **keine `Timer`-Nodes**, kein `Engine.time_scale`).
- **Gegner** (`actors/enemy/skeleton.*`): FSM idle→approach→telegraph→attack→retreat (+hurt/dead),
  **kein Pathfinding** (Bewegung direkt Richtung/weg vom Player). Telegraph = Rot-Blink + gehaltene
  Attack-Pose (Lesbarkeit). Nutzt `Hitbox`/`Hurtbox` (enemy_hitbox 64 → player_hurtbox 8).

## Persistenz-Pflicht

Nach **jedem** abgeschlossenen Schritt `docs/progress.md` aktualisieren. `docs/credits.md` beim
Einbinden eines Packs ausfüllen. Fehlende Assets → farbiges Rechteck + Eintrag in
`docs/assets-todo.md` (nichts nachmalen, nichts herunterladen).
