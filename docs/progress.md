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

## Zweiter Arbeitsplatz + Repo-Hygiene ✅ (2026-08-20)

**Kontext:** Weiterarbeit auf einem zweiten Rechner (Windows 11) statt Linux/Flatpak.

**Erledigt**
- **Godot auf Windows verifiziert:** `4.6.3.stable.official.7d41c59c4` (Patch-Delta zu 4.6.1 auf dem
  Linux-Rechner, keine für dieses Projekt relevanten API-Unterschiede). Portable EXE unter
  `~/Downloads/Godot_v4.6.3-stable_win64.exe/` — der `.exe`-Name ist ein **Ordner**; die nutzbare
  Binary ist die `_console.exe` darin (die GUI-Variante liefert headless keine Ausgabe).
- `CLAUDE.md` → „Engine & Aufruf" auf **zwei Maschinen** umgeschrieben (`$GODOT`-Platzhalter je
  Plattform, Stolperfallen dokumentiert). Regel Null gilt unverändert.
- **`--headless --path . --import` auf Windows fehlerfrei** (2107 Assets, keine Skript-Fehler) →
  Projekt baut auf beiden Maschinen.
- **`--doctool` verifiziert:** Zielverzeichnis **muss vorher existieren**, sonst „Argument supplied
  to --doctool must be a valid directory path". Dump = `<out>/doc/classes/*.xml`, 1063 Klassen.
- **`.gitignore` angelegt, `.godot/` aus der Versionierung entfernt** (4494 von 8908 getrackten
  Dateien waren Editor-/Import-Cache). *Begründung:* der Cache ist maschinenlokal und wird bei
  jedem Import neu erzeugt — getrackt produziert er auf dem jeweils anderen Rechner tausende
  bedeutungslose Diffs und verdeckt echte Änderungen. Die `*.import`-Dateien neben den Assets
  bleiben versioniert (Godot braucht sie).
- **`.gitattributes` (`* text=auto eol=lf`)** + repo-lokal `core.autocrlf=false`, `core.eol=lf`.
  *Begründung:* global ist auf dem Windows-Rechner `core.autocrlf=true`; Godot schreibt LF. Ohne
  Normalisierung meldet Git 2112 Dateien als geändert, obwohl inhaltlich identisch (verifiziert:
  `git diff --numstat` zeigte nur `CLAUDE.md`). Binärtypen explizit als `binary` markiert.

**Visuelle Abnahme durch User ✅**
- Phasen 0–3 im Editor gegengeprüft: Pixelschärfe/Skalierung, Movement-Feel, Schlag-Feel
  (Hitstop/Knockback/I-Frames), Skelett-Telegraph — **alles in Ordnung, keine Tuning-Änderung
  gewünscht**. Damit sind die „Feel-Abnahme steht aus"-Punkte aus Phase 0/1/2/3 erledigt.
- Left/Right-Spalten des SpriteFrames sind **nicht gespiegelt** (Facing korrekt) → Punkt in
  `docs/assets-todo.md` geschlossen.

## Phase 4 — Figurenwechsel ✅ (2026-08-20)

**Pack-Befund vorab (Timing folgt den Frames, nicht umgekehrt)**
- Die 93 Figuren unter `Actor/Character/` haben ein **anderes Format** als NinjaGreen: 16×16-Frames
  und `Attack.png` = 64×16, also **4 Richtungen × 1 Frame**. Der Zwerg hat damit **eine einzige
  Angriffs-Pose**, keine 4-Frame-Animation. Auch alle Ninja-Farbvarianten liegen so vor; nur
  NinjaGreen ist unter `CharacterAnimated/` voll animiert.
- Konsequenz (User-Entscheidung): die eine Pose wird über einen **langen, schweren Startup gehalten**
  — dieselbe Lesbarkeits-Idee wie der Skelett-Telegraph aus Phase 3.
- Kein Skalierungsbruch: NinjaGreen belegt 15×15 px in seinem 32×32-Frame, Knight 14×14 in 16×16 →
  on-screen gleich groß.
- Sheet-Achsen empirisch verifiziert (nicht geraten): **Spalte = Richtung, Zeile = Frame**, wie bei
  NinjaGreen. Beleg: Row0 des Walk-Sheets ist pixelgleich mit der Idle-Pose (Distanz 0), und
  `Idle` col2 ist der exakte Spiegel von col3. Richtungszuordnung 0=down/1=up/2=left/3=right über
  die Waffen-Ausdehnung im Attack-Sheet bestätigt.

**Figurenwahl (User)**
- Zwerg = **Knight** (grauer Vollhelm-Panzer — liest sich als schwer/unverrückbar).
- „kein Knockback" = **er wird nicht weggestoßen** (Vorteil zum Nachteil „langsam", analog
  Kurier schnell/schwach). Seine eigenen Treffer stoßen weiterhin.

**Architektur**
- **`FigureProfile`** (`resources/figure_profile.gd`) bündelt pro Figur: `display_name`,
  `SpriteFrames`, `AnimationLibrary`, `TuningStats`. Eine neue Figur = ein neues `.tres`, kein Code.
  → `figure_kurier.tres`, `figure_zwerg.tres`.
- **`PartyManager`** (`actors/player/party_manager.gd`, Node in `main.tscn`) hält das Ensemble und
  schaltet durch. Input-Action **`switch_figure`** (Q + beide Gamepad-Schultertasten).
- *Profil-Tausch statt Despawn/Respawn* (Abweichung vom Kickoff-Wortlaut „die anderen despawnen",
  mit Begründung): es gibt ohnehin nie zwei Körper in der Welt, und der Tausch am bestehenden
  Player-Node erbt Position/Velocity/laufende I-Frames automatisch, statt sie bei jedem Wechsel von
  Hand umzuhängen. Weniger Failure-Modes, gleiches Spielverhalten.
- *Per-Figur-Zustand liegt im PartyManager*, nicht im Player: Health muss den Wechsel überleben —
  und ab Phase 5 gilt das genauso für die Korruption (der Reif wird weitergereicht, Korruption baut
  extrem langsam ab). Der Spieler verteilt Schaden auf seine Leute; das braucht persistente Slots.
- *Wechsel gesperrt außer in idle/move* (`Player.can_switch()`): sonst wird die Schultertaste zum
  Cancel-Tool für Angriff und Hitstun und der Nachteil „langsamer Zwerg" wäre folgenlos.
- *Wechsel startet aus dem Stand* (`velocity = ZERO`): sonst erbt der Zwerg die Vollgeschwindigkeit
  des Kuriers und der Tempo-Unterschied wäre im Moment des Wechsels unsichtbar.
- **Zwei Felder neu in `TuningStats`** (beides Feel-Werte, gehören per CLAUDE.md dorthin):
  `hitbox_offset` (war eine `const` im Player-Skript; muss pro Figur unterschiedlich sein) und
  `knockback_taken_scale` (1.0 Kurier / 0.0 Zwerg — absichtlich float statt bool, Zwischenwerte
  sind tunebar). Das Skelett nutzt `hitbox_offset` jetzt ebenfalls aus seinem `.tres`, sonst wäre
  das Feld für Gegner wirkungslos gewesen.

**Tooling (neu)**
- **`tools/build_figure_resources.gd`** baut SpriteFrames *und* AnimationLibrary pro Figur aus dem
  Pack. Es leitet die Zeiten der Call-Method-Tracks **aus den Frame-Werten der jeweiligen
  `TuningStats` ab** — Anim-Timing und `.tres` können damit nicht auseinanderlaufen. Wer
  Startup/Active/Recovery ändert, lässt das Tool neu laufen. Validiert außerdem die Sheet-Maße;
  hat dabei gleich gefunden, dass NinjaGreens `Hit.png` **2** Hurt-Frames hat, nicht 1.
- **`tools/add_input_actions.gd`** legt fehlende Input-Actions per ProjectSettings-API an (idempotent).
- **`tests/phase4_sim.gd` + `.tscn`** — 27 Checks, wiederholbar.
  *Merker:* Der Test läuft als **Szene**, nicht per `--script`. Bei `--script` registriert Godot die
  Autoloads nicht, und Hitbox/Hurtbox referenzieren `Debug` → Compile-Error vor dem ersten Test.
- *Merker Serialisierung:* Ein typisiertes `Array[FigureProfile]` steht in der `.tscn` als
  `figures = Array[ExtResource("<script-id>")]([ExtResource(...), ...])`. Von der Engine ermittelt,
  nicht geraten. **Nicht** die ganze Szene per `PackedScene.pack()` neu schreiben — das klopft die
  instanzierten Sub-Szenen flach (schreibt `type=` und `unique_id=` neu).

**Verifikation (headless, 27/27 grün)**
- Startzustand, Profil-Tausch (Stats/SpriteFrames/AnimLibrary wechseln alle mit), Attack-Länge
  0.2 s → 0.4 s.
- **Tempo-Unterschied gemessen:** Kurier 44.7 px in 30 Frames, Zwerg 27.7 px = **62 %** (58/95).
- **Zwerg steht wie ein Fels:** 0.00 px Versatz bei 400er Knockback, Schaden kommt trotzdem an.
  Kurier fliegt weiterhin 21.8 px.
- **Wechsel-Sperre** im Attack greift; **Health-Persistenz** über zwei Wechsel hinweg korrekt.
- **Zwerg trifft** trotz 1-Frame-Pose und kleinerem Offset: Skelett 4→2 (Schaden 2 vs. Kurier 1),
  Attack endet sauber. Gesamtbindung bei Treffer ≈ 34 Frames (24 Anim + 10 Hitstop) ≈ 0.57 s.
- **Phase-2-Regression:** Kurier-Angriff unverändert (Schaden 1, endet in Idle).
- **Zwei starke Gegenproben, dass das Tool nichts kaputt macht:** die neu generierte
  `player_ninja_frames.tres` ist **byte-identisch** zur abgenommenen Fassung, und die abgeleitete
  `player_kurier_anims.tres` ist (bis auf Sub-Resource-IDs) identisch zur handgebauten
  `player_anims.tres` aus Phase 2 (die dadurch überflüssig wurde und gelöscht ist).

**Offen / bekannte Punkte**
- **Feel-Abnahme beim User:** Ist der Unterschied ohne HUD spürbar? Tuning-Achsen liegen in
  `player_zwerg.tres` (max_speed 58, Attack 9/6/9, damage 2, knockback_speed 340, hitstop 10,
  max_health 9). Nach Änderungen an den Attack-Frames `tools/build_figure_resources.gd` neu laufen
  lassen.
- `acceleration`/`friction` sind bei beiden Figuren **absichtlich identisch** (2400/3200). Das wäre
  eine starke zusätzliche Feel-Achse für den Zwerg (träges Anfahren), fällt aber unter die
  Rücksprache-Regel in CLAUDE.md → erst nach Freigabe.
- **Knight-Links/Rechts** noch nicht visuell bestätigt (Beleg ist die Waffen-Ausdehnung im Sheet).
  Falls gespiegelt: `DIRS` im Build-Tool tauschen.
- Knight hat **kein Hit-Sheet** → hurt = Idle-Pose + Blink (Platzhalter-Feedback, wie beim Skelett).
- Kein Camera-Node im Spiel; bei Räumen größer als der Viewport (Phase 6) muss der Wechsel die
  Kamera nicht anfassen — der Player-Node bleibt derselbe. Netter Nebeneffekt des Profil-Tauschs.
- Nur 2 der 4 geplanten Figuren existieren. Weitere = je ein `figure_*.tres` + Eintrag in
  `PartyManager.figures`.

## Nächste Phase
- **Phase 5 — Reif** (nach Go & Feel-Abnahme von Phase 4): Kanalisierung auf gehaltene Taste,
  Zeitdehnung **nur über den HitstopManager** (nie `Engine.time_scale`), Phase-Dash (zur Laufzeit
  `player_body`-Mask um Bit 3 kürzen + Hurtbox aussetzen, nur Masken toggeln), Korruptionszähler
  und Stufen 1–2 als Feedback. Der Korruptions-Zustand gehört pro Figur in den `PartyManager`
  (dort liegt schon die persistente Health) — der Reif ist weiterreichbar.
