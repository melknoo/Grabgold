# Fortschritt — Grabgold

## Phase 0 — Setup ✅ (2026-08-20)

**Erledigt**
- Godot-Version verifiziert: `4.6.1.stable` (Flatpak `org.godotengine.Godot`, kein `godot` im PATH).
- `project.godot`: interne Auflösung 320×180, Integer-Scaling ×6, Stretch `canvas_items`/`keep`,
  Texture-Filter Nearest, `snap_2d_transforms_to_pixel`, Renderer Forward+.
- 8 Collision-Layer benannt (environment, player/enemy _body/_hurtbox/_hitbox, interactable).
- Ordnerstruktur (Feature-Folder) angelegt.
- Platzhalter-Test-Tile `assets/placeholder/tile_16.png` (16×16 Kontrastmuster).
- Bootstrap `scenes/main.tscn` + `main.gd`: kachelt das Tile + 8×-Zoom für Filter-/Skalierungs-Check.
- Docs: `CLAUDE.md`, `docs/{progress,credits,assets-todo}.md`.

**Architekturentscheidungen (mit Begründung)**
- *Auflösung aus Tile-Größe abgeleitet, nicht vorgegeben:* 16px × 20 Tiles = 320px, ×6 exakt auf
  1080p. Provisorisch, weil noch kein Pack — beim echten Pack neu abzuleiten.
- *Renderer Forward+:* sicherste Wahl, keine Überraschungen bei den Korruptions-Shadern (Phase 5).
- *Collision: Hitbox aktiv / Hurtbox passiv* — trennt austeilen/einstecken eindeutig, ein Owner
  pro Overlap-Erkennung, keine Doppelverarbeitung.
- *Feel-Werte in `TuningStats`-Resource* — Kernanforderung: Werte hunderte Male ohne Code ändern.
- *Kein `Engine.time_scale`* für Hitstop/Zeitdehnung — würde UI/Partikel mittreffen; stattdessen
  `HitstopManager`-Autoload (Phase 2/5).

**Verifikation (headless)**
- `--import` fehlerfrei (tile_16.png + icon.svg importiert, `main.gd` kompiliert ohne Fehler).
- ProjectSettings-Introspektion: alle Keys von Godot erkannt (kein `<UNSET>`) und mit den
  gesetzten Werten aktiv → keine stillen Tippfehler. Tile lädt (16×16), `main.tscn` lädt.

**Offen / bekannte Punkte**
- Auflösung + Attack-Frame-Timing sind provisorisch (16px-Annahme) → beim echten Pack neu ableiten.
- **Pixelschärfe visuell vom User im Editor zu bestätigen** (headless rendert nicht):
  `flatpak run org.godotengine.Godot --path .` starten → Tile + 8×-Zoom scharf, keine verwaschenen
  Kanten, Fenster ×4 = 1280×720.

## Asset-Pack eingebunden ✅ (2026-08-20)
- **Ninja Adventure Asset Pack** (Pixel-boy + AAA, **CC0**) unter `assets/external/`.
- **Tile 16×16 bestätigt** → interne Auflösung 320×180 ×6 bleibt (keine Änderung).
- **Spieler = NinjaGreen** (32×32-Frames, **Spalte = Richtung, Zeile = Frame**, Attack = 4 Frames).
- `resources/player_ninja_frames.tres` gebaut (SpriteFrames, 16 Anims). credits.md/assets-todo.md/CLAUDE.md aktualisiert.

## Phase 1 — Player-Controller ✅ (2026-08-20)

**Erledigt**
- Vier Konventionen in CLAUDE.md verankert (Movement ohne Rampe, Facing-Priorität horizontal,
  Facing-Lock im Attack, Camera-Smoothing aus).
- `TuningStats` (`resources/tuning_stats.gd`) + `player_kurier.tres`: ALTTP-Movement
  (max_speed 95, accel 2400 ≈ Vollspeed in 2,4 F, friction 3200 ≈ Stopp in 1,8 F) und Attack-Timing
  3/6/3 **abgeleitet aus den 4 echten Attack-Frames**.
- Input-Actions `move_up/down/left/right` (WASD+Pfeile), `attack` (J+Space) via ProjectSettings-API.
- FSM (Opus-Design → Sonnet-Umsetzung): `components/state_machine/{state,state_machine}.gd`,
  `actors/player/player.gd` + `states/{idle,move,attack,hurt}.gd`, `actors/player/player.tscn`
  (CharacterBody2D + AnimatedSprite2D + CollisionShape2D + StateMachine). Player in `main.tscn`.
- Haiku-Review: keine Blocker (der gemeldete Facing-„Blocker" ist strukturell bereits erfüllt).

**Architekturentscheidungen (mit Begründung)**
- *AnimatedSprite2D + SpriteFrames* in Phase 1 (robust, editorfreundlich). *Phase 2:* AnimationPlayer
  mit Call-Method-Tracks fürs frame-genaue Hitbox-Toggling (Textures aus SpriteFrames wiederverwendbar).
- *FSM Node-basiert*, StateMachine injiziert `player`/`state_machine`; `enter()` **call_deferred**, weil
  Kind-`_ready()` vor Eltern-`_ready()` läuft (Player-`@onready` sonst noch null).
- *Facing-Lock strukturell*: nur idle/move rufen `update_facing`, attack nicht → während Attack gesperrt.

**Verifikation (headless)**
- Import + 60-Frame-Smoketest: keine Fehler.
- FSM-Übergangstest mit simuliertem Input: idle→move→idle, move→attack; Facing-Priorität korrekt;
  **Facing bleibt im Attack gesperrt**; Stillstand im Attack; Bewegung mit korrekter Speed.

**Offen / bekannte Punkte**
- **Visuelle Feel-Abnahme steht beim User aus** (headless rendert nicht): `flatpak run org.godotengine.Godot --path .`.
- **Behoben (2026-08-20):** SpriteFrames-Achsen waren transponiert (Zeile↔Spalte) → Figur „drehte sich
  im Stand", weil eine Idle-Schleife alle 4 Richtungen durchlief. Neu gebaut: **Spalte=Richtung,
  Zeile=Frame**; Richtungstreue headless verifiziert (jede Anim teilt eine Spalte).
- Left/Right-**Spalten** (col2/col3) zur Laufzeit prüfen (falls gespiegelt → left↔right im Build-Tool tauschen; down/up bestätigt).
- NIT: 1 Frame altes Facing beim Losgehen (walk_down während schon rechts) — Feel-Politur, optional.
- NIT: `_states: Dictionary` könnte `Dictionary[String, State]` sein (optional).

## Phase 2 — Kampfgefühl ✅ (2026-08-20)

**Erledigt (Opus-Architektur → Sonnet-Umsetzung → Haiku-Review)**
- **Angriff über AnimationPlayer**: `resources/player_anims.tres` (AnimationLibrary) — Animation `attack`
  (0,2s) keyt `AnimatedSprite2D:frame` 0→3 UND ruft per **Call-Method-Track** `enable_hitbox()` @0.05 /
  `disable_hitbox()` @0.15 (Active = Frames 1–2). Kein Timer.
- **Hitbox/Hurtbox** (`components/`): Hitbox self-resolving mit `_already_hit` (kein Multi-Hit);
  Hurtbox mit I-Frames + Blink. Collision-Werte exakt nach Matrix (Hitbox 16/32, Hurtbox 8/0,
  Dummy-Body 4/1, Dummy-Hurtbox 32/0).
- **HitstopManager** (Autoload): friert beteiligte Nodes N Physik-Frames via `process_mode`, **kein**
  `Engine.time_scale`. Player-Integration: Input-Buffer (`attack_buffer_frames`), `enable/disable_hitbox`,
  `facing_vector`. **Debug/Debug-Overlay** (F1 = Hitbox/Hurtbox-Viz, FPS/State/Anim-Frame).
- **Trainingsdummy** (`actors/enemy/dummy.*`, Platzhaltersprite) mit Knockback + Health-Reset.

**Bug gefunden & behoben (Opus, bei eigener Verifikation)**
- `HitstopManager` setzte `process_mode` mitten im `area_entered`-Physics-Callback → Godot-Fehler
  „Disabling a CollisionObject during a physics callback" + Folgefehler: **Attack-State verklemmte**
  (endete nie). Fix: `set_deferred("process_mode", …)`. Danach sauber.

**Verifikation (headless Combat-Sim mit simuliertem Angriff)**
- Trefferkette: Startup → Hitbox an (Frame ~active) → **Treffer** (hp −1) → **Hitstop** (~6 Physik-Frames,
  Player FROZEN) → **Knockback** (Dummy fliegt weg, whifft Folgeschlag wegen Reichweite → Knockback wirkt)
  → I-Frames (invuln ~0,4s) → **Attack endet sauber → Idle**. Nur **ein** Treffer pro Schlag.
- **Facing-Lock verifiziert**: Facing blieb über den kompletten Schlag konstant (`right`); zusätzlich
  einmalige Erfassung von Hitbox-Position/knockback_dir bei `enable_hitbox()` → doppelt abgesichert.

**Offen / bekannte Punkte**
- **Feel-Abnahme + Debug-Overlay (F1) beim User** (headless rendert/blinkt nicht). Iterieren über
  `player_kurier.tres` (hitstop_frames, knockback_speed, iframe_duration, attack_buffer_frames …).
- `knockback_curve` (Curve) noch ungenutzt — Knockback aktuell linear via `Dummy.knockback_friction`.
  Bei Bedarf Kurven-Falloff nachrüsten.
- NIT (Haiku): expliziter `facing_locked`-Guard als Härtung denkbar, sobald Angriffe cancelbar werden
  (Phase 5, Phase-Dash) — derzeit strukturell erfüllt, nicht nötig.

## Phase 3 — Gegner ✅ (2026-08-20)

**Erledigt (Opus-Architektur → Sonnet → Haiku)**
- **State-Machine generalisiert**: `State.actor: Node` statt `player: Player`; StateMachine injiziert
  `get_parent()`. Player-States auf `actor as Player` umgestellt (Logik identisch), Gegner nutzt
  dieselbe FSM. Zahlt auf Phase 4 (Figurenwechsel) ein.
- **Skeleton-Gegner** (`actors/enemy/skeleton.*`, CC0-Skelett, 16×16, `skeleton_frames.tres` +
  `enemy_skeleton.tres`): FSM idle→approach→**telegraph**→attack→retreat (+hurt/dead), **kein
  Pathfinding**. Telegraph = Rot-Blink + gehaltene Pose (Lesbarkeit). Enemy-Timing via Frame-Counting
  (keine Timer-Nodes). Enemy-Hitbox (64→8) trifft Player-Hurtbox; Tod bei hp0 → `dead` (richtungslose
  Anim) → deaktiviert Boxen/Collision → `queue_free`.
- **Player nimmt Schaden**: `player._on_hurt` (Hurtbox-Signal) → Hurt-State (Knockback + Stun) +
  I-Frames/Blink (aus Hurtbox-Component). Phase-3-Death = Health-Reset (kein echtes Game-Over).
- Dummy in `main.tscn` durch Skeleton ersetzt (dummy.gd/.tscn bleiben für reine Feel-Tests erhalten).

**Verifikation (headless Kampf-Sims)**
- Voller KI-Zyklus: Approach → **Telegraph (~0,5 s, lesbar)** → Attack → Retreat → Approach.
- **Player nimmt Schaden**: Skelett-Attack trifft passiven Player → php 6→5, Hurt-State, Knockback,
  I-Frames aktiv, danach Erholung.
- **Player tötet Gegner**: 4 Treffer → shp 4→0 → Dead. Beide Seiten Hitstop, kein `not allowed`-Error.
- FSM-Generalisierung ohne Regression (Player-Movement/Attack unverändert funktional).

**Offen / bekannte Punkte**
- **Feel-/Fairness-Abnahme beim User** (Telegraph-Länge, aggro/attack_range, Schaden). AI-Ranges als
  `@export` auf `skeleton.gd` (im Inspector tunebar); Combat-Feel in `enemy_skeleton.tres`.
- Skelett-Sprite hat keine eigene Hurt-Anim → Hurt = Idle-Pose + Rot-Flash (Platzhalter-Feedback).
- Kein echtes Game-Over (Phase 6+).

## Nächste Phase
- **Phase 4 — Figurenwechsel** (nach Go & Fairness-Abnahme): 2 Figuren mit unterschiedlichem
  Movement-/Angriffsgefühl (Kurier = schnell/schwach, Zwerg = langsam/kein Knockback) über je eigene
  `.tres`; Schultertaste wechselt, andere despawnt. Unterschied ohne HUD spürbar.
