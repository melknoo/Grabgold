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
- **Freigegebene Nodes und Typisierung** (im Spielen aufgefallen, Phase 9): wo eine gemerkte
  Node-Referenz freigegeben sein *kann* — Merklisten im `HitstopManager` und im `Reif`, Argumente
  seiner Abfragen — muss die Variable bzw. der Parameter **`Variant`** sein, nicht `Node`. Die
  Zuweisung an einen typisierten Platz ist selbst schon der Fehler („Trying to assign invalid
  previously freed instance" / „…not a subclass of the expected argument class") und schlägt zu,
  **bevor** `is_instance_valid` überhaupt gefragt werden kann. Also: untypisiert aufnehmen,
  prüfen, dann verwenden.
- **`monitorable` nie direkt in einem Area-Signal setzen** — Godot blockt es dort
  („Function blocked during in/out signal"), der Wert bleibt einfach stehen. Immer
  `set_deferred("monitorable", …)`; dieselbe Klasse Problem wie beim `process_mode` im
  HitstopManager (Phase 2) und bei der Tür (Phase 6).
- **4.6-Besonderheit:** `TileMap` gibt es nicht mehr → **`TileMapLayer`** verwenden. Dessen
  `tile_map_data` ist eine binäre `PackedByteArray` — eine Tilemap ist damit **nicht von Hand**
  in eine `.tscn` schreibbar und muss generiert werden (`tools/build_room_resources.gd`).

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
- **Input-Actions**: **nie von Hand in `project.godot` editieren** — `tools/add_input_actions.gd`
  ist die einzige Quelle der Belegung und **ueberschreibt** beim Lauf die komplette Map.
  Layout (steuern mit WASD, austeilen mit der Maus): `move_up/down/left/right` (WASD + Pfeile),
  `attack` (**Linksklick** + E + J), `dash` (**Leertaste** + Shift + Gamepad A — wirkt nur bei
  gehaltenem Reif), `reif_channel` (**Rechtsklick** + L + rechter Trigger, **halten**),
  `switch_figure` (Q + Schultertasten; im Hauptmenue **loescht** Q einen Slot),
  `interact` (**F** + Enter + Gamepad Y; bestaetigt auch in jedem Menue),
  `pause` (**Escape** + Gamepad Start; oeffnet die Pause und ist in jedem Menue „zurueck"),
  `debug_toggle` (F1).
  **Menues bekommen keine eigenen Actions** — sie lesen `move_*`, `interact`/`attack` und
  `pause`. Der Spieler soll im Menue dieselben Tasten druecken wie im Spiel.
  Regel fuer neue Bindings: alles, was im Kampf gedrueckt oder *gehalten* wird, muss die linke Hand
  auf WASD oder die rechte auf der Maus erreichen.

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
| 2 | `player_body` | Player `CharacterBody2D` | 2 | 1 + 3 |
| 3 | `enemy_body` | Enemy `CharacterBody2D` | 3 | 1 + 2 |
| 4 | `player_hurtbox` | Area2D Player, verwundbar | 4 | — |
| 5 | `player_hitbox` | Area2D Player-Angriff | 5 | 6 |
| 6 | `enemy_hurtbox` | Area2D Gegner, verwundbar | 6 | — |
| 7 | `enemy_hitbox` | Area2D Gegner-Angriff | 7 | 4 |
| 8 | `interactable` | Druckplatte, Raum-Tuer (`RoomExit`), Speicherpunkt (`SavePoint`) | 8 | 2 (sie scannen den Spieler) |

**Körper sind solide** (seit Phase 5): Spieler und Gegner scannen sich gegenseitig (Bit 2 ↔ Bit 3).
Bis Phase 4 taten sie das nicht — man lief durcheinander hindurch, und der Phase-Dash unten wäre
ein No-Op gewesen. Genau diese Solidität macht ihn zur Fähigkeit.

**Phase-Dash (Reif, Phase 5) — umgesetzt:** `Dash`-State kürzt zur Laufzeit die `player_body`-Mask
um Bit 3 (`set_collision_mask_value(3, false)`) und setzt die Player-Hurtbox aus
(`monitorable = false`, **nicht** die I-Frames — die gehören dem Trefferfeedback). Nur Masken
toggeln, keinen Node-Umbau. **Die Maske kommt verzögert zurück:** endet der Dash *in* einem Gegner,
bliebe der Spieler sonst stecken. `Reif._restore_body_mask()` setzt Bit 3 darum erst, wenn
`test_move(..., recovery_as_collision = true)` keine Überlappung mehr meldet — und muss die Maske
für diesen Test kurz selbst setzen, weil `test_move` gegen die *aktuelle* Maske prüft.

## Ordnerstruktur (Feature-Folder)

```
assets/{external/<packname>/,  placeholder/}   external = manuell abgelegte Packs, nie herunterladen
docs/{progress,credits,assets-todo}.md
globals/            Autoloads (hitstop_manager.gd, debug.gd, room_manager.gd, save_manager.gd,
                    audio_manager.gd, settings_manager.gd)
resources/          tuning_stats.gd + figure_profile.gd + room_registry.gd + save_data.gd
                    + audio_bank.gd (class_names) + *.tres
                    + default_bus_layout.tres (generiert, Phase 10)
components/         hitbox, hurtbox, state_machine/  (wiederverwendbar)
actors/player/      player.tscn/.gd + party_manager.gd + reif.gd + states/{idle,move,attack,hurt,dash}.gd
actors/enemy/       enemy.tscn/.gd + states/{idle,approach,telegraph,attack,retreat,hurt}.gd
                    waechter.tscn (geerbt von skeleton.tscn, Phase 12)
actors/props/       door.tscn/.gd + pressure_plate.tscn/.gd (Raum-Interaktion, Phase 6)
                    room_exit.tscn/.gd (Raum-Tuer, Phase 8)
                    save_point.tscn/.gd (Speicherpunkt, Phase 9)
ui/main_menu/       Dateiauswahl + Optionen + Beenden (Phase 11, liegt in der Huelle)
ui/options_menu/    Lautstaerkeregler je Bus (Phase 11)
ui/pause_menu/      Weiter / Optionen / Hauptmenue (Phase 11)
ui/debug_overlay/   debug_overlay.tscn/.gd
ui/corruption_overlay/  Vignette fuer Korruptionsstufe 1 (.tscn/.gd/.gdshader)
ui/game_over/       Schwarzblende beim Game Over (Phase 7)
ui/game_over_menu/  Auswahl nach der Blende: Speicherstand / Neu beginnen (Phase 9)
ui/transition_fade/ Blende des Raumwechsels (Phase 8, vom RoomManager instanziert)
scenes/             boot.tscn (HUELLE, run/main_scene ab Phase 11)
                    main.tscn (persistente Weltszene, `class_name World`) + rooms/
scenes/rooms/       room.gd (Basis) + spawn_point.gd + room_0{1,2,3}.tscn
                    + room_0{1,2,3}.gd (Raum-Verdrahtung; 02/03 seit Phase 12)
                    + room_0{1,2,3}_tiles.tscn (generiert)
tools/              Godot-Tool-Skripte, die Resources/Settings generieren (nie von Hand editieren)
tests/              headless Verifikations-Szenen (*_sim.tscn/.gd)
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

## Reif & Korruption (Phase 5, umgesetzt)

Zeitdehnung/Hitstop **niemals** über `Engine.time_scale` (träfe UI + Partikel). Immer über den
`HitstopManager`-Autoload, der nur die betroffenen Aktor-Nodes pausiert. Er hat zwei Betriebsarten:

- `hitstop(frames, nodes)` — Freeze-Frame beim Treffer (Phase 2).
- `set_time_scale(node, faktor)` / `clear_time_scale(node)` / `time_scale_for(node)` — **Duty-Cycle**:
  der Node läuft nur jeden n-ten Frame (Akkumulator, `process_mode` INHERIT/DISABLED). Faktor 0.55
  = 55 % der Ticks. Beides komponiert ohne Sonderfall, weil ein DISABLED-Elternteil jedes INHERIT
  im Kind schlägt.
- **Verlangsamt wird nicht der Gegner-Body**, sondern nur dessen `StateMachine` (Bewegung +
  Zustandsfortschritt) und `AnimatedSprite2D` (Animation). Der Body behält durchgehend aktive
  Collision-Shapes und Hurtbox — sonst flackerten seine Areas und Treffer gingen verloren.

- **`ReifStats`** (`resources/reif_stats.gd` + `reif.tres`) hält alle Reif-Werte: `time_scale`,
  `damage_multiplier`, `dash_speed/frames/cooldown_frames`, `corruption_max`,
  `corruption_per_second`, `corruption_decay_per_second`, `level_thresholds`, `drift_chance/scale`.
  Eigene Resource, weil der Reif **ein** Gegenstand ist und keiner Figur gehört. Die einzige
  figurabhängige Achse ist `corruption_gain_scale` in `TuningStats` (Kurier 1.0, Zwerg 0.7).
- **`Reif`** (`actors/player/reif.gd`, Kind-Node des Players) steuert Kanal, Korruptions-Tick,
  Zeitdehnung und Maskenwiederherstellung. **Kanalisieren ist rein input-getrieben und
  zustandsunabhängig** — man hält den Ring durch Angriff und Hitstun hindurch, sonst wäre der
  Schadensbonus unerreichbar.
- **Korruption liegt pro Figur im `PartyManager`** (wie Health), nicht im Player: der Reif ist
  weiterreichbar, die Korruption bleibt bei der Figur und baut extrem langsam ab.
- **Korruptionsstufen (seit Phase 7 alle vier verdrahtet):**
  1 = entsättigte Bildschirmränder (`ui/corruption_overlay/`, Shader liest per
  `hint_screen_texture`); 2 = Dash trägt gelegentlich weiter als eingegeben (**ohne** eigenes
  Feedback — soll wie ein Bug wirken); 3 = der Reif **schlägt von selbst zu** (Vorwarnung per
  Sprite-Flackern, dann Zwangsangriff); 4 = **Figurenwechsel gesperrt**.
- **Zwei Invarianten der hohen Stufen:** Der Zwangsangriff feuert nur aus `idle`/`move`
  (`Player.is_neutral()`) und fällt aus, wenn die Figur während der Vorwarnung getroffen wird —
  der Reif ist **kein Cancel-Tool**, dieselbe Regel wie beim Figurenwechsel. Und Stufe 4 sperrt
  nur den *freiwilligen* Wechsel: der Zwangswechsel nach einem Ausfall umgeht sie, sonst wäre
  Stufe 4 bei 0 HP ein totes Spiel.

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
- **Kein Pathfinding heißt: Hindernisse müssen konvex sein.** `move_and_slide` lässt einen Gegner
  an einer Säulenecke entlangrutschen und wieder herumkommen; eine konkave Nische wäre eine Falle.
  Gilt für jedes künftige Raum-Layout (Phase 12).
- **Eine neue Gegnerart ist keine neue Klasse** (Phase 12): `actors/enemy/waechter.tscn` erbt von
  `skeleton.tscn` und tauscht nur `SpriteFrames` (SkeletonDemon) und `TuningStats`
  (`enemy_waechter.tres`). **Einfärben per `modulate` funktioniert nicht** — `states/telegraph.gd`
  und `states/hurt.gd` setzen `sprite.modulate` bei jedem Blinken auf Weiß zurück; nur der
  Alpha-Kanal überlebt (den bespielt die Hurtbox).
- **`knockback_taken_scale` gilt seit Phase 12 auch für Gegner** (`Skeleton._on_hurt`). Default
  1.0 = unverändert; der Wächter steht mit 0.35 fester und lässt sich nicht in die Ecke prügeln.

## Figuren-Ensemble (Phase 4)

Eine Figur = **`FigureProfile`** (`resources/figure_profile.gd`): `display_name` + `SpriteFrames` +
`AnimationLibrary` + `TuningStats`. Je Figur ein `figure_*.tres`. Eine neue Figur anlegen heißt:
Profil-`.tres` schreiben, in `PartyManager.figures` eintragen — **kein Code**.

- **`PartyManager`** (`actors/player/party_manager.gd`, Node in `main.tscn`) schaltet durch das
  Ensemble. Input-Action `switch_figure` (Q + Gamepad-Schultertasten).
- **Profil-Tausch, kein Despawn/Respawn.** Der Player-Node bleibt dieselbe Instanz und bekommt
  Sprite-Satz/AnimLibrary/Stats gesetzt (`Player.apply_profile`). Position, Velocity und laufende
  I-Frames überleben den Wechsel dadurch von selbst.
- **Per-Figur-Zustand lebt im `PartyManager`**, nicht im Player (Health; ab Phase 5 die Korruption).
  Er muss den Wechsel überleben — der Reif ist weiterreichbar und Korruption baut extrem langsam ab.
- **Wechsel nur aus `idle`/`move`** (`Player.can_switch()`). Invariante: die Schultertaste darf
  weder Angriff noch Hitstun canceln, sonst ist der Nachteil „langsamer Zwerg" folgenlos.
- **Wechsel setzt `velocity = ZERO`**, sonst erbt die neue Figur das Tempo der alten.
- Figuren bisher: **Kurier** (NinjaGreen, schnell/schwach, wird weggestoßen) und **Zwerg**
  (Knight, langsam/hoher Schaden, `knockback_taken_scale = 0.0` → steht wie ein Fels).

## Generierte Resources — nie von Hand

`SpriteFrames` und `AnimationLibrary` werden **erzeugt**, nicht editiert:

- `$GODOT --headless --path . --script res://tools/build_figure_resources.gd`
  baut `player_*_frames.tres` und `player_*_anims.tres` aus dem Pack. Die Zeiten der
  Call-Method-Tracks werden **aus den Frame-Werten der jeweiligen `TuningStats` abgeleitet** —
  wer `attack_startup/active/recovery_frames` im `.tres` ändert, **muss das Tool neu laufen lassen**,
  sonst passen Anim und Stats nicht mehr zusammen.
- `$GODOT --headless --path . --script res://tools/build_room_resources.gd` baut
  `resources/tileset_room.tres` **und** die `*_tiles.tscn` **aller** Räume (reine Geometrie).
  Die Layouts stehen als Rechteck-Konstanten in der Tabelle `ROOMS` im Tool und werden beim Lauf
  als ASCII-Karte ausgegeben — wer einen Raum ändern oder anlegen will, tut es dort. Die Tile-Auswahl ist **empirisch**
  belegt (voll deckend + selbst-nahtlos kachelbar), nicht nach Augenmaß gegriffen.
  Felder je Raum: `walkable` (begehbare Rechtecke), `cells` (Einzelzellen) und seit Phase 12
  **`blocks`** (Wandinseln *innerhalb* der Fläche — Säulen, Trennwände). `blocks` wird zuletzt
  abgezogen und gewinnt darum immer.
- `$GODOT --headless --path . --script res://tools/build_enemy_resources.gd` baut die
  `SpriteFrames` **aller** Gegner (`skeleton_frames.tres`, `skeleton_demon_frames.tres`) aus dem
  Pack. Ein neuer Gegner ist ein Eintrag in der Tabelle `ENEMIES` plus ein `TuningStats`-`.tres`
  — **kein Code** (dieselbe Regel wie `FigureProfile` für die Figuren). Konvention wie überall:
  Spalte = Richtung, Zeile = Frame; `dead` ist **richtungslos** (`states/dead.gd` spielt `dead`,
  nicht `dead_<facing>`).
- `$GODOT --headless --path . --script res://tools/add_input_actions.gd` legt fehlende
  Input-Actions per ProjectSettings-API an (idempotent).
- `$GODOT --headless --path . --script res://tools/build_audio_resources.gd` baut
  `resources/default_bus_layout.tres` (Master/Music/SFX) **und** `resources/audio_bank.tres`
  und setzt `audio/buses/default_bus_layout` in den ProjectSettings. Die Zuordnung
  „Spielereignis → Datei im Pack" steht als Tabellen `SOUNDS`/`MUSIC` im Tool und **nirgends
  sonst** — ein neuer Klang ist eine Zeile dort plus ein `AudioManager.play(&"id")`.
  Ein `AudioBusLayout` hat **keine skriptbaren Properties** (gegen die Klassen-DB geprüft), er
  ist gar nicht von Hand schreibbar und muss vom `AudioServer` erzeugt werden.
- Sheet-Konvention im ganzen Pack: **Spalte = Richtung** (0=down, 1=up, 2=left, 3=right),
  **Zeile = Frame**. Gilt für NinjaGreen (32×32) *und* `Actor/Character/*` (16×16).
  Achtung: `Actor/Character/*` hat nur **1 Attack-Frame** (Sheet 64×16), NinjaGreen hat 4.

## Tod & Ensemble (Phase 7)

Bis Phase 6 gab es **kein Game-Over** — bei 0 HP wurde die Health zurückgesetzt.

- **Bei 0 HP fällt die Figur aus** und bleibt draußen (`_health[i] == 0` im `PartyManager`).
  `Player` emittiert `downed`, der `PartyManager` wechselt **zwangsweise** auf die nächste
  stehende Figur. Steht keine mehr → `party_wiped`.
- Damit ist der Figurenwechsel **drei** Dinge: Kampf-Achse (Phase 4), Puzzle-Verb (Phase 6) und
  Lebensvorrat (Phase 7). Die Korruption bleibt bei der ausgefallenen Figur.
- **Beim Wipe hält die Welt SOFORT an**, nicht erst hinter der Blende: `main.gd` sperrt den
  Input, setzt `Player.set_defeated(true)` (Hurtbox aus) und friert den Raum ein
  (`RoomManager.set_room_frozen(true)`, `process_mode` am `RoomHost`). Ohne das schlug der
  Gegner hinter der Schwarzblende weiter auf die gefallene Figur ein, und jeder dieser Treffer
  feuerte erneut `downed` → `party_wiped`. Zurückgenommen wird beides **nicht** an der Stelle,
  sondern dort, wo die Welt wieder aufgebaut wird: `_swap_room` lässt jeden neuen Raum laufen,
  `PartyManager._activate` macht jede Figur, die das Feld betritt, wieder verwundbar.
- **Game Over** = `ui/game_over/` blendet in `fade_frames` (60 F) schwarz. Danach **fragt**
  `scenes/main.gd` seit Phase 9 das `ui/game_over_menu/` (bis Phase 8 startete es blind neu).
  `restart_on_wipe` auf `main.gd` schaltet Menü und Neustart für Testszenen ab — seit Phase 8
  reine Testabsicht und kein Selbstschutz mehr, weil keine Szene neu geladen wird.
- `PartyManager.revive_all()` setzt Health **und Korruption** zurück. Ohne den Korruptions-Reset
  startete man neu und stünde sofort wieder auf Stufe 4.

## Der Raum (Phase 6)

`scenes/rooms/room_01.tscn` ist der erste echte Raum: 40×24 Tiles = **640×384 px**, exakt der
doppelte Viewport — erst dadurch hat die Kamera einen Zweck.

- **Zwei TileMapLayer** aus `room_01_tiles.tscn` (generiert): `Floor` ohne Kollision, `Walls` mit.
  Boden liegt **überall**, auch unter den Wänden — so klafft beim Öffnen der Tür kein Loch.
- **`Camera2D` ist Kind des Players**, nicht des Raums: der Figurenwechsel tauscht nur das Profil
  am bestehenden Node (Phase 4), die Kamera überlebt ihn damit von selbst — und seit Phase 8 auch
  den Raumwechsel. Ihre Limits setzt der `RoomManager` bei **jedem** Raumwechsel aus
  `Room.bounds()` (bis Phase 7: einmalig in `scenes/main.gd`). **Smoothing bleibt aus** (siehe
  „Auflösung & Look").
- **`PressurePlate`** löst über `TuningStats.weight` aus (Kurier 1.0, Zwerg 3.0, Schwelle 2.0) —
  damit wird der Figurenwechsel vom Kampf- zum **Puzzle-Verb**. Sie wertet die Überlappung
  **jeden Physik-Frame** aus, nicht per `body_entered`: wer auf der Platte stehend wechselt, löst
  kein neues `body_entered` aus, und genau das ist die zentrale Interaktion des Raums.
- **`Door`** öffnet für `open_frames` (240 F = 4 s) und **schließt nie auf jemandem**: steht noch
  ein Körper im Türfeld, wartet sie. Dasselbe Muster wie `Reif._restore_body_mask()`.
- **Die Puzzle-Zahl:** Distanz Platte→Tür = **304 px**. Zwerg (58 px/s) schafft in 4 s nur 232 px,
  Kurier (95 px/s) 380 px. Wer `open_frames`, `max_speed` oder die Positionen ändert, **muss diese
  drei Zahlen zusammen betrachten** — sonst ist das Puzzle entweder unlösbar oder trivial.
- **Kein Y-Sort:** die Wandkacheln sind flache 16×16-Blöcke ohne Oberkante, es gibt nichts zu
  sortieren. Wird erst nötig, wenn Wände Höhe bekommen.

## Raumwechsel (Phase 8)

`scenes/main.tscn` ist die **persistente Weltszene** und wird nie gewechselt: Player,
PartyManager, Corruption-Overlay, Game-Over-Blende und Debug-Overlay hängen dort als Geschwister
des Raums. Der Raum selbst ist das einzige Kind von **`RoomHost`** und wird getauscht.

- **`RoomManager`** (Autoload, `globals/room_manager.gd`) ist der einzige Weg in einen anderen
  Raum: `transition_to(room_id, spawn_id)`. Ablauf: Input sperren → ausblenden → **bei voller
  Schwärze** alten Raum freigeben und neuen laden → Spieler auf den Spawn, Kamera-Limits → wieder
  einblenden → Input frei. Signale `room_changed(room_id)` und `transition_finished`;
  `room_changed` ist der Andockpunkt für Audio (Autoloads koordinieren über Signale, nie über
  direkte Referenzen aufeinander).
- Der Autoload kennt die Weltszene **nicht statisch**, sie registriert sich per
  `bind_world(host, player, party)` in `main.gd`. Grund: die Testszenen hängen `main.tscn` als
  *Kind* unter sich, ein `/root/Main/Player` wäre dort falsch.
- **Kein `change_scene_to_file`**: es gäbe die alte Szene frei, bevor die Blende zu ist — und
  nähme den Player mit, der den Wechsel überleben muss. Geladen wird **synchron** (`load()`
  cacht), weil der Ladevorgang komplett hinter der Blende liegt und ein Threaded-Load mit Polling
  headless nicht deterministisch wäre.
- Die Blende (`ui/transition_fade/`) zählt **Frames**, kein Tween — wie Tür, Gegner-KI, Angriff
  und Game-Over-Blende, und aus demselben Grund. `fade_frames = 18` (0,3 s je Hälfte).
- **Input-Sperre über EIN Flag am Player** (`Player.set_input_locked`): drei Stellen lesen den
  `Input`-Singleton (Player, Reif, PartyManager) und fragen alle denselben Schalter. Beim Sperren
  fällt die Figur in den Stand und nach `idle`; der Reif räumt seine Zeitdehnung auf, sonst bliebe
  ein Gegner des alten Raums als verlangsamt registriert.
- **Räume erben von `Room`** (`scenes/rooms/room.gd`): `room_id`, `size_tiles`, `music_id`,
  `bounds()`, `spawn_point(spawn_id)` und `debug_text()`. Raum 01 ist `Room01` und ergänzt nur
  seine Platte-Tür-Verdrahtung. Das Debug-Overlay fragt `debug_text()` und kennt keine
  raumspezifischen Nodes mehr.
- **Spawn-Punkte** sind `SpawnPoint`-`Marker2D` mit `spawn_id`, gesucht unter den *eigenen*
  Kindern des Raums (nicht per Gruppe — der alte Raum hängt beim Suchen noch einen Frame im Baum).
  Sie liegen **neben** der Tür, nicht in ihr, sonst läuft man beim Ankommen sofort zurück.
- **Raum-Tür** = `RoomExit` (Area2D, Layer 8 / Mask 2), `@export target_room/target_spawn/`
  `auto_enter`. Default `auto_enter = true` (ALTTP: reinlaufen genügt); auf `false` wertet sie die
  Überlappung **jeden Physik-Frame** aus und wartet auf `interact` — gleiches Muster wie die
  `PressurePlate` und aus demselben Grund.
- **Gegner respawnen** von selbst, weil der Raum bei jedem Betreten frisch instanziert wird. Ein
  Flag-System für Bosse/Quest-Kills kommt mit dem Speichern.
- **Raum-Verzeichnis** = `resources/room_registry.tres` (`room_id` → Szenenpfad + Startraum). Ein
  neuer Raum ist ein Eintrag dort plus ein Eintrag in der `ROOMS`-Tabelle des Bau-Tools — **kein
  Code**.
- **Die Kette:** `room_01` (A, 40×24, das Puzzle) ↔ `room_02` (B, 20×12) ↔ `room_03` (C, 20×12).
  B und C sind bewusst Testgerüst, kein Content.

## Speichern & Laden (Phase 9)

- **`SaveData`** (`resources/save_data.gd`) ist eine typisierte Resource-**Klasse**, liegt aber
  als **JSON** unter `user://saves/slot_N.json` — nicht als `.tres` (User-Entscheidung). Gründe:
  ein `.tres` trägt den Skriptpfad im Savefile mit, `ResourceLoader` cacht nach Pfad (ein
  Slot-Overwrite wäre im laufenden Spiel unsichtbar), und ein neues Feld ist in JSON ein
  `data.get(key, default)`. Die `.tres`-Regel des Projekts gilt für **Autorendaten**
  (`TuningStats`, `ReifStats`, `RoomRegistry`) — ein Spielstand ist das Gegenteil.
- **`from_dict()` ist die einzige Lesestelle** und prüft **vor** der ersten Zuweisung an die
  Welt: kein Dictionary, falsche `VERSION`, kein `room_id` → `null`. Ein kaputter Slot darf nie
  halb angewandt werden. **JSON kennt keinen Integer** — jede Zahl läuft durch `int()`/`float()`,
  sonst nimmt `Array[int]` den geparsten `6.0` nicht an.
- **`SaveManager`** (Autoload) hält den **Fortschritt** — `world_flags`, Spielzeit (in Frames),
  aktiver Slot — und ist der einzige Weg auf die Platte. Aufteilung zum `RoomManager`: der
  besitzt den **Raum**, der SaveManager den **Fortschritt**. Die Abhängigkeit läuft **nur in eine
  Richtung**: SaveManager ruft RoomManager, nie umgekehrt. Die Welt holt er sich über
  `RoomManager.player()/party()` — kein zweites `bind_world`.
- **Reihenfolge beim Laden ist Absicht:** erst `world_flags`, **dann** der Raum. Ein erledigter
  Boss liest sein Flag in `_ready()`, das Flag muss also stehen, bevor der Raum instanziert wird.
- Geladen wird über **`RoomManager.enter_from_black()`** (aus Phase 7 verallgemeinert): kein
  Ausblenden, sondern ein harter Schnitt nach Schwarz. Bei Game Over ist das Bild schon zu, und
  es gibt keinen Zustand, in dem die alte Welt beim Laden noch etwas zu zeigen hätte.
- **`SavePoint`** (`actors/props/save_point.tscn`, Layer 8 / Mask 2) speichert **nie automatisch**
  — anders als die `RoomExit` mit `auto_enter`: Speichern überschreibt einen Slot, das braucht
  einen `interact`-Druck. Er wertet die Überlappung **jeden Physik-Frame** aus (gleicher Grund
  wie `PressurePlate`). Sein `spawn_id` nennt den `SpawnPoint` **neben** ihm — geladen wird nie
  eine rohe Position, sonst setzt ein verschobener Raum alte Spielstände in die Wand.
- **Der Punkt frischt auf, wäscht aber nicht** (`PartyManager.restore_all()`): Health voll,
  ausgefallene Figuren stehen wieder, **die Korruption bleibt bei jeder Figur**. Sie ist die
  Langzeitschuld des Reifs (Phase 5) — ein Speicherpunkt, der sie mitnimmt, macht sie folgenlos.
  Nur `revive_all()` (Game Over / Neu beginnen) setzt sie auf 0. **Aufgefrischt wird vor dem
  Schreiben**, sonst hält der Slot genau die Verletzungen fest, die der Punkt gerade geheilt hat.
- **Game-Over-Menü** (`ui/game_over_menu/`): „Letzter Speicherstand" (leerer Slot → grau und
  **nicht anwählbar**, nicht bloß wirkungslos) und „Neu beginnen". Navigation `move_up/down`,
  Bestätigen `interact` **oder** `attack` — wer gerade gestorben ist, hat die Hand nicht zwingend
  auf F. Beim Öffnen sperrt `main.gd` den Player-Input (sonst schlägt der Bestätigungsdruck im
  Hintergrund noch zu); freigegeben wird er vom Raumaufbau, nicht vom Menü.
- **Persistente Kills:** `Skeleton.persist_id` leer = respawnt weiter (Regel für normale Gegner,
  fällt seit Phase 8 von selbst so aus). Gesetzt = der Tod landet als `kill:<id>` in den
  `world_flags`, und der Gegner baut sich beim Betreten gar nicht erst auf. Die ID ist der
  **Flag-Name** und muss über alle Räume eindeutig sein.
- **Die Slot-Auswahl kam in Phase 11** (Hauptmenü, siehe unten). Bis dahin waren die drei Slots
  angelegt und adressierbar (`SaveManager.active_slot`), aber der Spieler konnte nicht sehen und
  nicht wählen, in welchen ein Speicherpunkt schreibt.

## Ton (Phase 10)

Bis Phase 9 war das Spiel **vollständig stumm**. `globals/audio_manager.gd` (Autoload
`AudioManager`) ist seither der **einzige** Ort, an dem Klang abgespielt wird.

- **Warum ein Autoload:** Musik muss den Raumwechsel überleben, um den es gerade geht — dieselbe
  Begründung, die in Phase 8 die Blende in den `RoomManager` gelegt hat. `PROCESS_MODE_ALWAYS`,
  damit weder Hitstop noch der Game-Over-Freeze (Phase 9) den Ton abreißen lassen.
- **Aufteilung der Autoloads:** RoomManager = Raum, SaveManager = Fortschritt, AudioManager =
  Ton. Der AudioManager hängt an `RoomManager.room_changed` und liest `Room.music_id` — über ein
  **Signal**, nie über eine direkte Referenz, und nur in diese Richtung. Der `AudioManager`-
  Autoload muss darum in `project.godot` **nach** `RoomManager` stehen.
- **Nicht positional** (`AudioStreamPlayer`, nicht `AudioStreamPlayer2D`): die Kamera folgt dem
  Spieler, ein Raum ist maximal der doppelte Viewport — alles Hörbare ist auf dem Bild.
  Positionaler Ton hätte Abspieler an jeden Aktor gehängt, und der Manager wäre nicht mehr die
  einzige Stelle.
- **Pegel liegen auf den BUSSEN** (Master / Music -9 dB / SFX 0 dB, im generierten Layout), die
  Abspieler-Lautstärke gehört ganz der Kreuzblende der Musik. Zur Laufzeit über
  `AudioManager.set_bus_db`; seit Phase 11 schreibt dort das Optionsmenü hinein — **relativ** zu
  diesen Vorgaben, nicht absolut.
- **Ein Klang pro ID pro Physik-Frame.** Zwei Gegner, die im selben Frame getroffen werden, sind
  zwei Aufrufe von `hit_enemy`; deckungsgleich addiert klingt das nach einem Knacken statt nach
  zwei Treffern. Pool aus 12 Abspielern, round-robin — ein abgeschnittener alter Klang ist besser
  als ein verschluckter neuer.
- **Der Reif fährt in den Pitch.** `Skeleton.play_sound(id)` fragt
  `HitstopManager.time_scale_for(state_machine)` und übergibt den Faktor als `pitch`: ein
  zeitgedehnter Gegner klingt tiefer. Das ist die einzige Stelle, an der der Reif hörbar auf
  etwas anderes als sich selbst wirkt.
- **`Hitbox.hit_sound` ist ein `@export` am Node**, kein Zweig im Code: die Hitbox ist der eine
  Trichter, durch den **jeder** Treffer läuft. Wer zuschlägt, sagt die Szene
  (`player.tscn` → `hit_enemy`, `skeleton.tscn` → `hit_player`). Gespielt wird **nur, wenn
  `take_hit` `true` liefert** — ein Klang, den I-Frames abgeprallt haben, wäre eine Lüge.
- **Gehaltener Klang:** genau **einer** (`start_loop`/`stop_loop`, der kanalisierende Reif).
  `start_loop` ist idempotent, sonst stotterte er jeden Frame; die WAV-Schleife läuft über
  `finished` → neu anwerfen, weil das `loop_mode` in der `.import` des Packs liegt. Der Reif
  räumt ihn bei Input-Sperre auf — sonst summt er durch die Blende in den nächsten Raum.
- **Musik: gleiche ID = kein Neustart.** Die wichtigste Regel von `play_music`. Die Kette ist
  A `dungeon` ↔ B `crypt` ↔ C `crypt`; ein Stück, das an jeder Tür von vorn anfängt, verrät die
  Raumgrenze. Kreuzblende über zwei Abspieler, **in Frames** gezählt (`music_fade_frames = 45`)
  wie Tür, Gegner-KI und beide Blenden. Leere `music_id` = ausblenden.
- **Ogg-Schleife setzt der Manager beim Einhängen** (`_apply_music_stream`), nicht das Bau-Tool:
  in der `.tres` steht nur eine `ExtResource`-Referenz, das `loop`-Flag des Streams lebt in der
  `.ogg.import` des Packs (dort `false`) und wird von `ResourceSaver` nicht mitgeschrieben.
- **Jingles** (Game Over) haben einen eigenen Abspieler auf dem Musik-Bus: `play_jingle` stellt
  das Stück ab, und `stop_music` darf den Jingle nicht mit abräumen. `scenes/main.gd` würgt ihn
  ab, bevor eine neue Welt aufgebaut wird.
- **`AudioManager.enabled = false`** schaltet stumm, lässt die **Buchführung** aber laufen
  (`current_music`, `music_starts`, `play_count`, Dedup, Pitch). Zwei Gründe: es ist der Anfang
  der Stummschaltung, die ein Optionsmenü braucht — und die Suiten phase4..9 setzen es, siehe
  unten.

**Godot-Eigenheit, die man kennen muss:** endet der Prozess, **während ein Ogg spielt**, stehen
im Log `WARNING: ObjectDB instances leaked at exit` und `ERROR: 2 resources still in use at
exit`. In einem Projekt aus zwölf Zeilen ohne eine Zeile dieses Autoloads nachgestellt, in beiden
Audio-Treibern (Fenster wie headless), und auch mit `stop()` + `stream = null` kurz vor dem Ende
nicht abstellbar. Ein **geladenes, nicht abgespieltes** Ogg ist dagegen sauber. Kein Leck im
laufenden Spiel — aber der Grund, warum die Testsuiten stumm laufen.

## Hülle: Hauptmenü, Optionen, Pause (Phase 11)

Bis Phase 10 war `scenes/main.tscn` die Startszene und baute sich in `_ready` selbst den
Startraum — es gab **nie** einen Zustand „Spiel läuft nicht". Phase 9 hatte das Hauptmenü genau
deshalb verschoben („eine eigene Szene **vor** der persistenten Weltszene und damit ein eigener
Umbau"). `scenes/boot.tscn` **ist** dieser Umbau und ist seither `run/main_scene`.

Die Schichtung ist drei tief, und jede Schicht wird von der darüber weggeworfen:

```
Boot (nie gewechselt)   Menues, Optionen, Pause — die Huelle
  +- WorldHost
       +- main.tscn     persistente Weltszene: Player, PartyManager, Overlays
            +- RoomHost
                 +- room_0N.tscn   vom RoomManager getauscht (Phase 8)
```

- **Die Menüs liegen in der Hülle, nicht in der Welt.** Das Hauptmenü muss ohne Welt existieren,
  und Options- und Pausenbildschirm teilen sich einen Bildschirm mit ihm. Das **Game-Over-Menü
  bleibt in der Weltszene** — es gehört zum Sterben, nicht zur Hülle; es reicht seinen dritten
  Eintrag als Signal `World.main_menu_requested` nach oben, weil eine Szene sich nicht selbst
  wegwerfen kann.
- **`World.enter_on_ready`** (Default `true`) entscheidet, ob die Weltszene beim Aufbau selbst
  den Startraum betritt. Die Hülle setzt es **vor** `add_child` auf `false` und entscheidet dann
  zwischen Startraum und Spielstand. Der Default bleibt `true`, damit die sechs Suiten davor
  `main.tscn` weiter als Kind unter sich hängen können — genau das Muster von `restart_on_wipe`.
- **Zurück ins Hauptmenü heißt: die Welt wird weggeworfen**, nicht angehalten. Ein Spiel, das
  hinter dem Menü weiterlebte, wäre ein zweiter Weltzustand neben dem Spielstand, und die Frage
  „welcher gilt" hat keine gute Antwort. Freigegeben wird mit `remove_child` **plus** `queue_free`
  (Muster aus `RoomManager._swap_room`), und `RoomManager.clear_fade()` räumt die Blende auf —
  sie lebt im Autoload und überlebt jede Welt.
- **Es liest kein Menü in demselben Frame denselben Tastendruck.** Wer einen anderen Bildschirm
  aufmacht, blendet seinen eigenen aus, und jeder Bildschirm hat nach `open()` **einen Frame
  Schonzeit** (`_grace`). Ohne die schlüge der `pause`-Druck, der die Optionen aufmacht, im
  Pausenmenü gleich noch einmal zu.

**Hauptmenü = Dateiauswahl** (ALTTP-Muster), nicht „Neues Spiel / Laden / Optionen": die drei
Slots stehen als Zeilen da, ein voller lädt, ein **leerer beginnt dort** ein neues Spiel. Damit
ist der Slot immer bewusst gewählt — bis Phase 10 schrieb jeder Speicherpunkt in
`SaveManager.active_slot`, und welcher das war, konnte der Spieler nirgends sehen.

- **Löschen liegt hier und nirgends sonst**, mit Inline-Bestätigung auf der Zeile selbst (Q lädt
  scharf, F löscht, Q bricht ab, Wegbewegen entschärft). Ohne es wäre die Auswahl ein
  Sackgassen-Menü: nach drei Spielständen ließe sich kein neues Spiel mehr beginnen, weil ein
  voller Slot immer lädt.
- Ein leerer Slot ist hier **anwählbar** und darum nicht grau — anders als im Game-Over-Menü, wo
  derselbe leere Slot nichts zu laden hat.

**Pause** friert mit den Mitteln aus Phase 9: `RoomManager.set_room_frozen` (`process_mode` am
`RoomHost`) plus `Player.set_input_locked` — über `World.set_paused`. Ausdrücklich **nicht**
`get_tree().paused` und nicht `Engine.time_scale`, dasselbe Argument wie beim HitstopManager.

- **Die Musik läuft in der Pause weiter** — sonst wäre der Musikregler nicht zu hören, während
  man ihn zieht. Der Reif räumt seinen gehaltenen Klang bei der Input-Sperre selbst auf (Phase 10),
  ein Summen durch die Pause gibt es also von selbst nicht.
- **Die Taste wird in der Hülle gelesen**, nicht in der Welt: nur die Hülle weiß, ob gerade ein
  anderer Bildschirm offen ist. Sie geht nicht auf während einer Blende
  (`RoomManager.is_transitioning`) und nicht im Game Over (`World.accepts_pause`) — dort hält die
  Welt schon und ein zweiter Bildschirm hörte auf dieselben Tasten.

**Einstellungen: `globals/settings_manager.gd` (Autoload `Settings`), `user://settings.cfg`.**
Vierter Besitzer neben RoomManager (Raum), SaveManager (Fortschritt) und AudioManager (Ton).

- **Nicht im Spielstand.** Eine Lautstärke gehört dem Gerät, nicht dem Durchlauf — wer Slot 2
  lädt, will nicht die Pegel von Slot 1. Der Autoload steht in `project.godot` **nach**
  `AudioManager`, weil er dessen `set_bus_db` benutzt.
- **`ConfigFile`, nicht JSON wie `SaveData`** (Phase 9): es ist die Einrichtung der Engine, von
  Hand lesbar, und `get_value(section, key, default)` trägt ein später dazukommendes Feld von
  selbst. Eine Versionsnummer braucht sie nicht — eine unbekannte Datei kostet hier höchstens
  eine Lautstärke, während ein halb angewandter Spielstand ein kaputtes Spiel wäre.
- **Übernommen wird Schlüssel für Schlüssel**, und nur was da ist und eine Zahl ist. Ein
  fehlender Schlüssel lässt den laufenden Wert stehen, statt ihn auf die Vorgabe zurückzusetzen.
  `ConfigFile` ist nachsichtig — Zeilen, die es nicht versteht, überliest es und meldet trotzdem
  `OK`; der Rückgabewert kann also nicht die Prüfung sein.
- **Der Pegel ist eine STUFE 0..10, nicht dB** — das ist, was die UI zeigt und der Spieler
  einstellt. Und er ist **relativ zur Vorgabe** aus `default_bus_layout.tres`: Stufe 10 heißt
  „wie der Autor es gemischt hat" (Musik −9 dB), nicht „0 dB". Sonst hätte der erste Griff an den
  Regler die Mischung aus Phase 10 eingerissen. Stufe 0 ist `SILENT_DB` (−80), weil
  `linear_to_db(0.0)` −inf wäre.
- Die Regler zeigen **Prozentzahlen, keinen Balken**: der Standardfont ist nicht monospaced.
  Siehe `docs/assets-todo.md`.

## Raum-Inhalt (Phase 12)

Bis Phase 11 war **A** der einzige Raum mit einer Aufgabe; **B** und **C** waren leere Rechtecke
(Testgerüst für den Raumwechsel). Seit Phase 12 hat jeder Raum ein Verb:

- **A** (40×24) = Gewicht und Zeit (Platte/Tür, Phase 6). **Unverändert** — die Puzzle-Zahl
  (304 px gegen `open_frames`) hängt an Geometrie und Positionen.
- **B** (`Room02`, 20×12) = **Kampfkammer**: vier Säulen, drei Skelette, ein **Riegel** vor dem
  Ausgang nach C. Bleibt **ein Bildschirm** — in einem scrollenden Raum stünde ein zuschlagender
  Gegner außerhalb des Bildes.
- **C** (`Room03`, 24×16) = **Gruftkammer**: Vorraum, 2-Tile-Korridor, Halle mit **Wächter** und
  dem Speicherpunkt **hinter** ihm.

- **Der Riegel ist eine `Door`** ohne Zähler (`open_permanently(announce)`), verdrahtet im
  Raum-Skript wie Platte→Tür in `room_01.gd`. `Room02` öffnet **alle** `Door`-Kinder, weil die
  Öffnung zwei Kacheln hoch ist.
- **Durchgänge sind zwei Tiles hoch.** Die Kollisionsbox des Spielers sitzt **4 px unter** seinem
  Ursprung (Füße, `player.tscn`); eine ein Tile hohe Öffnung lässt ihm ein 8 px schmales Fenster,
  und auf der Mittellinie der Kachel streift er schon die Wand darunter. Gilt für jeden neuen
  Durchgang.
- **Der geräumte Raum steht im Spielstand, die Gegner nicht.** Die drei Skelette in B haben
  **keine** `persist_id` (normale Gegner respawnen, Regel aus Phase 8); der Riegel merkt sich den
  Raum als Welt-Flag `gate:room_02` (`Room02.CLEARED_FLAG`). Sonst wäre die Rückkehr aus C ein
  zweiter Pflichtkampf am selben Riegel.
- **Der Wächter** trägt `persist_id = skeleton_c` und bleibt tot (Phase 9). Genau da liegt der
  Unterschied: ein Kampf, den der Raum *stellt*, gegen einen Gegner, den man einmal wegräumt.

## Tests

- `$GODOT --headless --path . res://tests/phase4_sim.tscn` — Figurenwechsel (27 Checks).
- `$GODOT --headless --path . res://tests/phase5_sim.tscn` — Reif (57 Checks).
- `$GODOT --headless --path . res://tests/phase6_sim.tscn` — Raum, Platte, Tür, Kamera (26 Checks).
- `$GODOT --headless --path . res://tests/phase7_sim.tscn` — Korruptionsstufen 3/4, Ausfall,
  Game Over.
- `$GODOT --headless --path . res://tests/phase8_sim.tscn` — Raumwechsel, Blende, Input-Sperre,
  Gegner-Respawn, Game-Over-Neustart (84 Checks).
- `$GODOT --headless --path . res://tests/phase9_sim.tscn` — Speicherpunkt, Slot-Inhalt, Laden,
  drei Slots, kaputte Spielstände, persistente Kills, Welt-Stopp beim Wipe, Game-Over-Menü
  (135 Checks).
- `$GODOT --headless --path . res://tests/phase10_sim.tscn` — Busse, Bank, Dedup, Pool, Pitch,
  gehaltener Klang, Kreuzblende, „gleiche ID startet nicht neu", und dass jedes bisher stumme
  Ereignis einen Klang anwirft (120 Checks).
- `$GODOT --headless --path . res://tests/phase11_sim.tscn` — Einstellungen (Stufen, dB relativ
  zum Mix, Datei, kaputte Datei), Hauptmenue ohne Welt, neues Spiel in einem gewaehlten Slot,
  Laden, Loeschen mit Bestaetigung, Optionen aus beiden Aufrufern, Pause (Raum steht wirklich),
  wann die Pause **nicht** aufgeht, der dritte Game-Over-Eintrag, Menue-Klaenge (146 Checks).
- `$GODOT --headless --path . res://tests/phase12_sim.tscn` — Raum-Inhalt: Geometrie von B und C
  (gegen die generierte `Walls`-Ebene, nicht gegen die Tabelle im Tool), Aufstellung, Riegel
  (solide, oeffnet erst beim dritten Toten, bleibt offen, steht im Spielstand, man laeuft zu Fuss
  hindurch), Waechter (Sheet, Stats, Knockback-Faktor), und dass nichts in einer Wand steht
  (71 Checks).

Alle neun müssen „ALLES GRUEN" melden (**705 Checks**).

**`phase11_sim` haengt `boot.tscn` unter sich**, nicht `main.tscn` wie die sechs Suiten davor —
genau darum geht es in der Phase. Es setzt zusaetzlich `Settings.path` auf eine eigene `.cfg`
(gleicher Grund wie `save_dir`) und beginnt mit `Settings.reset()`: der Autoload hat die **echte**
Datei beim Hochkommen schon gelesen und angewandt.

**Tests laufen stumm.** `phase4..9_sim` und `phase11_sim` setzen `AudioManager.enabled = false` **vor**
`add_child(main)` — dort betritt der Bootstrap den Startraum und würfe schon Musik an. Grund ist
die Godot-Eigenheit oben: eine laufende Ogg-Wiedergabe hinterlässt beim Beenden zwei Fehlerzeilen,
und sechs Suiten, die keinen Ton prüfen, sollen die nicht erben. Die Buchführung des Managers
läuft stumm unverändert weiter, die Suiten verhalten sich also identisch. `phase10_sim` schaltet
für **einen** Abschnitt echten Ton ein — dort ausschließlich **WAV**-Effekte, nie ein Ogg.

**Tests fassen `user://saves` nicht an:** `SaveManager.save_dir` ist zur Laufzeit setzbar, und
phase8/9/10/11_sim zeigen auf eigene Verzeichnisse (`user://saves_phase8`, `user://saves_test`,
`user://saves_phase10`, `user://saves_phase11`).
Sonst würde ein Testlauf die echten Spielstände überschreiben. `phase9_sim` hat außerdem eine
**Notbremse** (`FRAME_BUDGET`): es wartet an mehreren Stellen auf Signale, und ein Fehler darin
würde headless nicht fehlschlagen, sondern ewig laufen. `phase10_sim` hat sie aus demselben
Grund.

Tests laufen als **Szene**, nicht per `--script`: bei `--script` registriert Godot die Autoloads
nicht, und `Hitbox`/`Hurtbox` referenzieren `Debug` → Compile-Error vor dem ersten Check.

## Persistenz-Pflicht

Nach **jedem** abgeschlossenen Schritt `docs/progress.md` aktualisieren. `docs/credits.md` beim
Einbinden eines Packs ausfüllen. Fehlende Assets → farbiges Rechteck + Eintrag in
`docs/assets-todo.md` (nichts nachmalen, nichts herunterladen).
