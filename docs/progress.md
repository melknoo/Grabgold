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

## Phase 5 — Der Reif ✅ (2026-09-01)

**Befund vorab: die Körper waren gar nicht solide**
- `player.tscn` hatte `collision_mask = 1` (nur `environment`), `skeleton.tscn` ebenfalls. Spieler
  und Skelett liefen bis Phase 4 ungehindert durcheinander hindurch. Die CLAUDE.md-Vorschrift für
  den Phase-Dash („`player_body`-Mask um Bit 3 kürzen") wäre damit ein **No-Op** gewesen und der
  Dash bedeutungslos.
- Darum als Voraussetzung: Player-Mask auf `5` (environment + enemy_body), Skelett-Mask auf `3`
  (environment + player_body). **Symmetrisch** — einseitig hätte der Gegner den Spieler geschoben,
  ohne selbst gebremst zu werden. Die Collision-Matrix in CLAUDE.md ist entsprechend aktualisiert.
- Das ist eine bewusste **Feel-Änderung an Phase 3/4** (man kann nicht mehr durch das Skelett
  laufen) und steht unter Vorbehalt der User-Abnahme. Phase-4-Sim danach erneut gelaufen: 27/27 grün.

**Erledigt**
- **Zeitdehnung als Duty-Cycle im `HitstopManager`** (`set_time_scale`/`clear_time_scale`/
  `time_scale_for`): ein Akkumulator lässt den Ziel-Node nur jeden n-ten Frame laufen
  (`process_mode` INHERIT/DISABLED). Faktor 0.55 = 55 % der Ticks.
- **`ReifStats`** (`resources/reif_stats.gd` + `reif.tres`) mit allen Reif-Werten; `TuningStats`
  um genau ein Feld erweitert: `corruption_gain_scale` (Kurier 1.0, Zwerg 0.7).
- **`Reif`-Node** (`actors/player/reif.gd`) am Player: Kanal-Input, Korruptions-Tick, Registrierung
  der Zeitdehnung, Schadensfaktor, Dash-Freigabe/-Cooldown, Maskenwiederherstellung.
- **`Dash`-State** (`actors/player/states/dash.gd`), aus `idle`/`move` erreichbar und nur bei
  gehaltenem Reif. Kürzt die Body-Maske um Bit 3, setzt die Hurtbox aus, Facing bleibt gesperrt.
- **Korruption pro Figur im `PartyManager`** (`_corruption`, index-parallel zu `_health`), gesichert
  und wiederhergestellt beim Wechsel; `Player.set_corruption`/`corruption_changed` analog zu Health.
- **Stufe 1** = `ui/corruption_overlay/` — ColorRect mit Shader, der die Szene per
  `hint_screen_texture` liest und sie zum Bildrand hin entsättigt und abdunkelt. Intensität an den
  Korruptionswert gekoppelt, mit sichtbarer Grundstärke 0.25 direkt an der Schwelle.
- **Stufe 2** = Dash-Drift: ab Stufe 2 trägt der Dash mit `drift_chance` um `drift_scale` weiter
  als eingegeben. Bewusst ohne eigenes Feedback.
- **Input-Actions** `reif_channel` und `dash` per `tools/add_input_actions.gd` angelegt
  (neuer `_axis()`-Helper für den Gamepad-Trigger).
- **Debug-Overlay** um Figur, HP, REIF-Status, Stufe, Korruption in %, Dash-Cooldown und Phasing
  ergänzt — Figur und HP fehlten dort entgegen der Phase-4-Notiz tatsächlich noch.

**Architekturentscheidungen (mit Begründung)**
- *Duty-Cycle statt skaliertem Delta:* die Alternative wäre gewesen, jedem Aktor sein `delta` zu
  skalieren — glatter, aber alle Frame-Zähler in den sieben geprüften Gegner-States hätten von
  `int` auf float-Akkumulation umgebaut werden müssen. Der Duty-Cycle fasst **keine Zeile
  Gegner-Code** an. Bei 320×180 mit gesnappten Transforms ist das Stottern praktisch unsichtbar;
  falls doch: `time_scale` im `.tres` näher an 1.0 ziehen.
- *Gegated wird `StateMachine` + `AnimatedSprite2D`, nicht der Body:* würde man den Body selbst
  gaten, flackerten seine Collision-Shapes und die Hurtbox — der Spieler-Hitbox könnte ein Treffer
  entgehen. So stehen Bewegung und Animation still, während der Gegner durchgehend trefferbar
  bleibt. Hitstop und Zeitdehnung komponieren dabei **ohne Sonderfall**: der Hitstop trifft den
  Body, und ein DISABLED-Elternteil schlägt jedes INHERIT im Kind.
- *Kanalisieren ist zustandsunabhängig:* der Kanal überlebt Angriff und Hitstun. Sonst wäre der
  Schadensbonus unerreichbar — der Schlag dauert länger als das Fenster, in dem man den Kanal
  überhaupt starten könnte.
- *Der Dash ist keine Grundfähigkeit:* „kein Dodge-Roll" aus dem Kickoff bleibt gültig; erst der
  gehaltene Reif schaltet ihn frei. Damit hat Korruptionsstufe 2 überhaupt ein Ziel.
- *I-Frames werden vom Dash nicht verbraucht:* die Unverwundbarkeit läuft über
  `hurtbox.monitorable = false`, nicht über `take_hit`. Die regulären I-Frames gehören dem
  Trefferfeedback und dürfen vom Dash nicht aufgezehrt werden.
- *Verzögerte Maskenwiederherstellung:* endet der Dash in einem Gegner, bliebe der Spieler bei
  sofortigem Zurücksetzen stecken. `Reif._restore_body_mask()` prüft jeden Frame mit
  `test_move(..., recovery_as_collision = true)` — und muss die Maske für den Test kurz selbst
  setzen, weil `test_move` gegen die *aktuelle* Maske prüft. Ohne das hätte die Prüfung stumm
  immer „frei" gemeldet; headless abgesichert.
- *Korruption im PartyManager statt im Player:* der Reif ist weiterreichbar, die Korruption nicht.
  Genau dasselbe Muster wie Health aus Phase 4.
- *Eigene `ReifStats`-Resource statt Felder in `TuningStats`:* der Reif ist EIN Gegenstand und
  gehört keiner Figur. Nur die eine figurabhängige Achse (`corruption_gain_scale`) liegt in
  `TuningStats`.

**Regel Null (gegen die lokal gedumpte Klassen-DB geprüft, nicht geraten)**
- `CollisionObject2D.set_collision_mask_value(layer_number: int, value: bool)` /
  `get_collision_mask_value(layer_number: int) -> bool`
- `PhysicsBody2D.test_move(from, motion, collision = null, safe_margin = 0.08,
  recovery_as_collision = false) -> bool`
- `JOY_AXIS_TRIGGER_RIGHT = 5`; `InputEventJoypadMotion.axis` / `.axis_value`

**Verifikation (headless, `tests/phase5_sim.*`, 51/51 grün)**
- Duty-Cycle exakt vermessen: Sonde tickt **55 von 100** Frames bei Faktor 0.55.
- **Gegner-Timing gedehnt, Spieler nicht:** der 30-Frame-Telegraph des Skeletts braucht real
  **53 Frames** (Faktor 0.57); die Laufstrecke des Spielers ist mit und ohne Kanal **44.7 px** —
  der direkte Beleg, dass kein `Engine.time_scale` im Spiel ist.
- Schaden: ohne Kanal 1, mit Kanal 2 (`roundi(1 × 1.75)`).
- Phase-Dash: Gegner steht 26 px im Weg, der Dash endet **65.8 px** weiter; ohne Kanal passiert
  nichts. Unverwundbarkeit gegen die **echte Gegner-Hitbox** geprüft (Treffer kommt im Dash nicht
  an, danach trifft derselbe Gegner wieder) — die regulären I-Frames bleiben dabei unverbraucht.
- Maske: endet der Dash im Gegner, bleibt Bit 3 gekürzt (`mask=1`) und kommt erst zurück, wenn der
  Spieler frei steht (`mask=5`).
- Stufen: Stufe 1 an der Schwelle, Vignette sichtbar (0.25) und bei Vollausschlag 1.0; Stufe 4 am
  Anschlag. Drift: bei `drift_chance = 1.0` 15 statt 10 Frames, unter Stufe 2 nie.
- Abbau: −0.80 in 2 s (unter 1 %/s).
- Persistenz: Kurier behält seine 40 über zwei Wechsel; der Zwerg lädt mit 6.30 statt 9.00 messbar
  langsamer auf (`corruption_gain_scale` 0.7) und behält seinen eigenen Wert.
- **Phase-4-Regression nach den soliden Körpern: 27/27 grün.**
- Shader kompiliert und rendert (Fenster-Lauf mit Vulkan/Forward+, Vignette bei Korruption 90
  aktiv mit Intensität 0.896) — headless wird er nicht kompiliert, darum extra geprüft.

**Feel-Abnahme durch User — teilweise erledigt (2026-09-02, beim Phase-6-Durchgang)**
- ✅ Kanal, Zeitdehnung, Phase-Dash und die **soliden Körper** wurden im Raum von Phase 6
  mitgespielt und für gut befunden. Punkte 1, 2 und 5 der Liste unten sind damit erledigt:
  der Kanal verführt, die soliden Körper bleiben, die Zeitdehnung stottert nicht sichtbar.
- ⏳ **Noch nicht bestätigt:** Vignette (Stufe 1) und Dash-Drift (Stufe 2). Beide erfordern
  längeres Halten des Reifs, um die Schwellen überhaupt zu erreichen — im Puzzle-Durchgang kommt
  man dort nicht zwangsläufig hin. Bleibt offen:
  1. Ist die Vignette lesbar, ohne den Kampf zu stören? (`inner_radius`/`outer_radius`/`tint` im
     ShaderMaterial, `ONSET` in `corruption_overlay.gd`.)
  2. Fühlt sich der Drift wie ein Bug an oder wie eine Strafe? (`drift_chance`, `drift_scale`)

**Offen / bekannte Punkte**
- **Korruptionsstufen 3 und 4 sind nicht verdrahtet** (der Phasenplan sieht für Phase 5 nur 1–2
  vor). Die Schwellen stehen im `reif.tres`, `Reif.level()` liefert bereits 3 und 4.
- **Flüstern im Sound-Mix fehlt** — das Projekt hat keine Audio-Infrastruktur. Kandidaten und die
  nötigen Schritte stehen in `docs/assets-todo.md`.
- **Nur die aktive Figur baut Korruption ab.** Inaktive Figuren frieren auf ihrem Wert ein. Für den
  Vertical Slice unkritisch (der Abbau ist ohnehin auf 250 s ausgelegt), aber eine bewusste Lücke.
- Der Kanal hat **kein Sprite-Feedback am Spieler** (nur die Vignette ab Stufe 1). Erst nach der
  Feel-Abnahme entscheiden, ob es eins braucht.
- **Testharness-Merker:** die Dash-Taste muss im Sim **zwei** Physik-Frames gehalten werden — bei
  nur einem trifft `Input.action_press` das `is_action_just_pressed`-Fenster nicht zuverlässig.

## Tastenbelegung umgestellt ✅ (2026-09-02)

**Anlass (User):** Mit WASD gesteuert war die alte Belegung unbrauchbar — `attack` lag auf J,
`reif_channel` auf L, beide für die linke Hand unerreichbar. Und der Kanal wird *gehalten*, nicht
getippt.

**Neues Layout** — steuern mit WASD, austeilen mit der Maus:

| Action | Belegung |
|---|---|
| `move_up/down/left/right` | WASD + Pfeiltasten |
| `attack` | **Linksklick** · E · J |
| `dash` | **Leertaste** · Shift · Gamepad A |
| `reif_channel` (halten) | **Rechtsklick** · L · rechter Trigger |
| `switch_figure` | Q · beide Schultertasten |
| `debug_toggle` | F1 |

- **Space musste aus `attack` raus** — es lag dort seit Phase 1 und kollidierte mit dem neuen Dash.
- E liegt direkt neben W; J und L bleiben als Zweitbelegung fürs Pfeiltasten-Spiel erhalten.
- **Regel für künftige Bindings:** alles, was im Kampf gedrückt oder *gehalten* wird, muss die
  linke Hand auf WASD oder die rechte auf der Maus erreichen.

**`tools/add_input_actions.gd` ist jetzt die alleinige Quelle der Belegung.** Vorher hat es nur
*fehlende* Actions ergänzt (`_ensure`) und hätte eine Änderung an einer bestehenden Action still
ignoriert. Jetzt deklariert es die **komplette** Map und überschreibt sie (`_write`) — wer eine
Taste ändern will, ändert sie dort und lässt das Tool laufen. Ein zweiter Lauf erzeugt exakt
dasselbe Ergebnis.
*Stolperfalle dabei:* die Hilfsfunktion durfte nicht `_set` heißen — das kollidiert mit
`Object._set(StringName, Variant) -> bool` und scheitert schon beim Parsen.

**Verifikation**
- Signaturen gegen die lokale Klassen-DB geprüft: `InputEventMouseButton.button_index`
  (enum `MouseButton`), `MOUSE_BUTTON_LEFT = 1` / `RIGHT = 2`.
- Jedes Binding mit echten `InputEvent`-Objekten durchgespielt (`Input.parse_input_event`):
  Space→dash, Shift→dash (Modifier-Matching funktioniert), E/J/Linksklick→attack,
  Rechtsklick→reif_channel, Q→switch_figure — und die **Gegenprobe, dass Space nicht mehr
  angreift**.
- Beide Sims danach erneut grün (phase4 27/27, phase5 51/51). Sie treiben Actions über
  `Input.action_press()` und sind von der Belegung unabhängig — genau deshalb bleiben sie gültig.
- Kein Konflikt mit der UI: Spieler und Reif lesen den `Input`-Singleton in `_physics_process`,
  nicht `_unhandled_input` — ein Control könnte den Klick also gar nicht wegfangen.

## Phase 6 — Ein echter Raum ✅ (2026-09-02)

**Anlass:** Bis hierher wurde in `scenes/main.tscn` gespielt — einer Phase-0-Bootstrap-Szene, die
per Skript ein Platzhalter-Tile über den Viewport kachelte. Keine Wände, keine Kamera, kein Grund,
sich irgendwohin zu bewegen. Damit waren zwei fertige Mechaniken **folgenlos**: der Figurenwechsel
war nur eine Kampf-Achse, und der Phase-Dash lief zwar durch Gegner — die man in einer offenen
Arena aber genauso gut umlaufen konnte.

**Der Raum**
- `scenes/rooms/room_01.tscn`: **40×24 Tiles = 640×384 px**, exakt der doppelte Viewport.
  Links die Kammer mit Startpunkt und Druckplatte, rechts hinter der Zeittür ein **2 Tiles hoher
  Korridor** mit einem Skelett darin, dahinter eine Zielkammer.
- Zwei `TileMapLayer` (**kein `TileMap`** — in 4.6 entfernt): `Floor` ohne Kollision, `Walls` mit.
  Boden liegt **überall**, auch unter den Wänden — so klafft beim Öffnen der Tür kein Loch.
- `Camera2D` als **Kind des Players**, Limits aus `Room.bounds()`, Smoothing aus.

**Das Puzzle: der Figurenwechsel wird zum Verb**
- Neues Feld **`TuningStats.weight`** (Kurier 1.0, Zwerg 3.0). Die `PressurePlate` gibt ab 2.0
  nach — der Kurier läuft wirkungslos darüber.
- Die Tür öffnet für `open_frames` (240 F = 4 s). **Distanz Platte→Tür = 304 px.** Der Zwerg
  schafft in dem Fenster nur 232 px, der Kurier 380 px. Also: als Zwerg auslösen, wechseln,
  als Kurier rennen. Puffer nach beiden Seiten ~75 px, damit das kein Zufallsergebnis ist.
- Im Korridor lässt sich das Skelett per Phase-Dash überlaufen statt bekämpfen — bezahlt mit
  Korruption. Damit hat der Reif zum ersten Mal eine Raum-Bedeutung.

**Architekturentscheidungen (mit Begründung)**
- *Raumgeometrie wird generiert, nicht editiert* (`tools/build_room_resources.gd`):
  `TileMapLayer.tile_map_data` ist eine binäre `PackedByteArray` — von Hand schlicht nicht
  schreibbar. Erzeugen heißt `PackedScene.pack()`, und das verbietet CLAUDE.md für Szenen mit
  instanzierten Subszenen (es klopft sie flach). Darum die Trennung: `room_01_tiles.tscn` enthält
  **nur** TileMapLayer und ist generiert; alles Instanzierte (Tür, Platte, Skelett) lebt eine
  Ebene höher in der handgeschriebenen `room_01.tscn`.
- *Tile-Auswahl empirisch, nicht nach Augenmaß:* ein Probe-Lauf hat jedes Tile aller Interior-/
  Dungeon-Sheets darauf geprüft, ob es **voll deckend und selbst-nahtlos kachelbar** ist (linke
  Spalte == rechte, obere Zeile == untere). Ergebnis: Boden = `TilesetInteriorFloor` (14,15)
  dunkles Kopfsteinpflaster, Wand = (1,7) orangeroter Ziegel. **`TilesetWallSimple.png` ist dabei
  ausgeschieden** — es sieht wie ein Wandset aus, ist aber ein 9-Slice-Rahmen mit transparenter
  Mitte und taugt nicht als Fläche. Hätte man nach Namen ausgewählt, wäre genau das schiefgegangen.
- *Die Platte scannt den Spieler* (Layer 8 `interactable`, Mask 2 `player_body`), nicht umgekehrt.
  Das spart eine Interact-Action und jede Zeile Player-Code — es gibt keinen Knopf, das Gewicht
  **ist** der Input. Die Matrix-Zeile in CLAUDE.md ist entsprechend präzisiert.
- *Ausgewertet wird jeden Physik-Frame, nicht per `body_entered`:* der Figurenwechsel tauscht nur
  das Profil am bestehenden Player-Node (Phase 4). Wer auf der Platte **stehend** wechselt, löst
  kein neues `body_entered` aus — mit signalgetriebener Auswertung wäre die zentrale Interaktion
  des Raums tot gewesen.
- *Die Tür schließt nie auf jemandem:* läuft der Zähler ab, während noch ein Körper im Türfeld
  steht, wartet sie. Dieselbe Klasse Problem und dieselbe Lösung wie
  `Reif._restore_body_mask()` — den Zustand erst zurücknehmen, wenn das Feld nachweislich frei ist.
- *`weight` ist float, kein bool:* Zwischenstufen sind tunebar und künftige Figuren ordnen sich
  ein, ohne dass eine Zeile Platten-Code angefasst wird (gleiche Begründung wie
  `knockback_taken_scale` in Phase 4).
- *Kein Y-Sort:* die Wandkacheln sind flache Blöcke ohne Oberkante — es gibt nichts zu sortieren.
  Bewusst nicht „auf Vorrat" eingeschaltet; wird erst nötig, wenn Wände Höhe bekommen.

**Bug gefunden & behoben (durch die neuen Wände aufgedeckt)**
- `Reif._restore_body_mask()` prüfte mit `test_move` gegen die **volle** Maske. Bis Phase 5 war das
  dasselbe wie „gegen Gegner prüfen", weil es außer dem Boden nichts Solides gab. Mit Wänden nicht
  mehr: ein Dash, der direkt an einer Wand endet, hätte den Test dauerhaft auf „blockiert" gehalten
  — der Spieler wäre **ohne jeden Hinweis phasend stehen geblieben** und hätte weiter durch Gegner
  laufen können. Jetzt wird gegen genau Bit 3 (`enemy_body`) geprüft. Der Phase-5-Sim hat den
  Fehler beim ersten Lauf mit Raum sofort gemeldet.

**Nebenbefund (behoben)**
- Das Debug-Overlay lief mit der **Default-Schriftgröße 16** im 320×180-Canvas und wurde mit ihm
  ×4…×6 hochskaliert — es verdeckte den halben Bildschirm. Bis Phase 5 nur unschön, mit einem Raum
  aber ein Blocker für die Sichtprüfung. Jetzt 8 px per Theme-Override in der `.tscn`. Ergänzt um
  Gewicht der Figur sowie Platten- und Türzustand.

**Verifikation (headless, `tests/phase6_sim.*`, 26/26 grün)**
- Raummaß 640×384, Spieler startet am Marker, Tür zu, Platte offen.
- **Kamera:** hängt am Player, Limits == Raumgrenzen (0,0..640,384), beide Smoothings aus.
- **Wände solide:** 120 Frames gegen die Außenwand ergeben 35 px statt 190 px freier Lauf; der
  Spieler bleibt bei x=21 im Raum (Wand 0..16 + halbe Körperbreite).
- **Platte:** Kurier (1.0) drückt sie 60 Frames lang nicht. Wechsel auf den Zwerg **im Stehen**
  → Platte gibt nach, Tür offen, Türkollision aus. Genau der Fall, den `body_entered` verpasst hätte.
- **Zeittür:** schließt nach `open_frames` wieder; steht der Spieler im Türfeld, bleibt sie offen
  und schließt erst, wenn er weg ist.
- **Puzzle-Zahl gemessen:** 304 px Distanz, 4,00 s Fenster → Zwerg 232 px (**schafft es nicht**),
  Kurier 380 px (**schafft es**), Puffer 72 / 76 px.
- **Phase-Dash im Korridor:** trägt 66,7 px durch das Skelett hindurch, die Maske kommt trotz des
  engen Korridors zurück (`mask=5`) — und gegen eine Wand endet der Dash nach 24 statt 53 px
  **an** der Wand (Bit 1 bleibt in der Maske).
- **Regression:** phase4 27/27 und phase5 51/51 weiterhin grün.
- **Fensterlauf** (Vulkan/Forward+, 180 Frames) fehlerfrei — headless rendert keine Tiles und
  kompiliert keine Shader, darum extra geprüft. Screenshot gegengesehen: Wand/Boden-Kontrast
  liest sich, die offene Tür ist als Lücke in der Trennwand erkennbar, Platte sichtbar.

**Feel-Abnahme durch User ✅ (2026-09-02)**
- Raum im Editor durchgespielt: **„sieht alles gut aus, fühlt sich gut an"**. Keine
  Tuning-Änderung gewünscht. Damit sind alle fünf offenen Fragen aus diesem Abschnitt erledigt:
  Türfenster (`open_frames = 240`) ist fair, Platte ist lesbar, Korridor funktioniert, keine
  Tile-Seams an den Kamerarändern, der repetitive Boden stört nicht.
- **Diese Werte gelten damit als abgenommen** und sind ab jetzt Referenz: `open_frames = 240`,
  `required_weight = 2.0`, `weight` 1.0/3.0, Distanz Platte→Tür 304 px, Raummaß 40×24.
  Wer einen davon ändert, ändert eine abgenommene Größe.

**Offen / bekannte Punkte**
- **Nur ein Raum, kein Raumwechsel.** `room_01.tscn` wird von `main.tscn` fest instanziert; es gibt
  keinen Übergang in einen zweiten Raum und kein Ziel in der Zielkammer.
- **Ein einziges Wand- und ein einziges Bodentile** — keine Autotile-Terrains, keine Ecken/Kanten.
  Bewusst: ein Autotiler ist Umfang, und der Vertical Slice priorisiert Kampfgefühl. Die
  9-Slice-Rahmen aus `TilesetWallSimple.png` lägen dafür bereit.
- **Kein echtes Game-Over** (unverändert seit Phase 3).

## Phase 7 — Korruption zu Ende gebaut ✅ (2026-09-02)

**Anlass (User-Entscheidung):** Der Reif ist die Kernmechanik („die beste Mechanik im Spiel ist
die, die den Spieler frisst"), hatte aber kaum einen Nachteil. Stufe 1 war eine Vignette, Stufe 2
ein leichter Dash-Drift — die Stufen 3 und 4 wurden vom Zähler gestützt, hingen aber an nichts.
Dazu gab es **kein Game-Over**: bei 0 HP wurde die Health stumm zurückgesetzt. Das war die
größte Lücke zwischen Entwurf und Gebautem, und sie zahlt direkt aufs Kampfgefühl ein.

**Stufe 3 — der Reif schlägt von selbst zu**
- Ab Stufe 3 löst der Reif mit `compulsion_per_second` (0.6/s) einen Angriff aus, den der Spieler
  nicht bestellt hat. Erst `compulsion_tell_frames` (10 F) **Vorwarnung** — der Sprite flackert
  giftig-violett —, dann der Schlag.
- *Warum ein Tell, anders als beim Dash-Drift:* der Drift ist bewusst unangekündigt, weil ein
  Stück weiter zu dashen harmlos ist. Ein Angriff aus dem Nichts kostet dagegen Positionierung
  und öffnet den Spieler für Treffer — ohne Tell liest er sich als kaputte Eingabe statt als
  Fluch. Die 10 Frames reichen zum Umpositionieren, aber nicht zum Abbestellen. (User-Entscheidung.)
- Violett bewusst **nicht rot**: Rot ist seit Phase 3 der Telegraph des Skeletts. Das eine ist
  eine Drohung von außen, das andere greift von innen zu.

**Stufe 4 — der Reif lässt die Figur nicht los**
- `Player.can_switch()` ist ab Stufe 4 false. Bis dahin durfte man den Fluch auf die nächste
  Figur abwälzen; ab hier sitzt man auf dem, was man sich geholt hat. Ausweg: abwarten
  (0.4/s Abbau, ~20 s von 100 auf unter 92).
- **Nicht stumm:** ein verweigerter Wechsel meldet `switch_refused` und lässt die Figur kurz matt
  aufflackern (`REFUSAL_TINT`, 18 F). Ohne das sähe die Sperre wie ein hakender Tastendruck aus.
  Die Vignette taugte dafür nicht — sie schlägt auf Stufe 4 ohnehin schon fast voll aus.

**Todesmodell — das Ensemble trägt (User-Entscheidung)**
- Bei 0 HP fällt **diese** Figur aus und bleibt draußen; der `PartyManager` wechselt zwangsweise
  auf die nächste stehende. Erst wenn keine mehr steht: `party_wiped` → Schwarzblende
  (`ui/game_over/`, 60 F) → Raum-Neustart.
- Damit ist der Figurenwechsel jetzt **drei** Dinge: Kampf-Achse (Phase 4), Puzzle-Verb (Phase 6)
  und Lebensvorrat (Phase 7). Der `PartyManager` hielt Health ohnehin schon pro Figur — es kam
  kein neuer Zustandsbehälter dazu.
- Die Korruption bleibt bei der ausgefallenen Figur (unverändertes Modell aus Phase 5).

**Architekturentscheidungen (mit Begründung)**
- *Der Zwangsangriff ist kein Cancel-Tool:* er feuert nur aus `idle`/`move` und **fällt aus**,
  wenn die Figur während der Vorwarnung getroffen wird oder dasht. Sonst würde der Reif Hitstun
  canceln — exakt die Invariante, die seit Phase 4 den Figurenwechsel auf idle/move beschränkt.
  Dafür wurde `Player.can_switch()` in `is_neutral()` (Zustandsfrage) und `can_switch()`
  (Zustandsfrage **plus** Reif-Sperre) aufgeteilt; beide Aufrufer nutzen jetzt das Passende.
- *Der Zwangswechsel nach einem Ausfall umgeht `can_switch()` bewusst.* Die Sperre schützt einen
  laufenden Schlag und hält ab Stufe 4 den Fluch fest — aber eine ausgefallene Figur **muss**
  weichen. Ohne diese Ausnahme wäre Stufe 4 bei 0 HP ein totes Spiel.
- *`revive_all()` setzt auch die Korruption zurück.* Sonst startet man nach dem Game Over neu und
  steht sofort wieder auf Stufe 4 — ein Neustart, der sich nicht wie einer anfühlt.
- *Tell-Färbung nur über RGB:* der Alphakanal des Sprites gehört der Hurtbox (I-Frame-Blinken).
  Beide auf `modulate` loszulassen hätte sie einander überschreiben lassen.
- *`restart_on_wipe` als `@export` auf `main.gd`:* die Testszenen hängen `main.tscn` als **Kind**
  unter sich — `reload_current_scene()` würde dort den Test neu starten statt den Raum, also eine
  Endlosschleife. Der Schalter wird im Sim vor dem ersten Physik-Frame auf `false` gesetzt.

**Verifikation (headless, `tests/phase7_sim.*`, 34/34 grün)**
- **Stufe 3:** Vorwarnung läuft, danach schlägt die Figur ohne Eingabe zu; unter Stufe 3 passiert
  das in 60 Frames nie. Wird die Figur während der Vorwarnung in den Hurt-State geworfen, **fällt
  der Zwang aus** und der Hitstun bleibt unangetastet.
- **Stufe 4:** `switch_locked()` greift, `can_switch()` ist trotz idle false, der Wechsel wird
  verweigert **und gemeldet**; eine Stufe darunter geht er wieder.
- **Todesmodell:** Ausfall wird gemeldet, Zwangswechsel auf die nächste Figur, die neue startet
  voll; ausgefallene Figuren werden vom freiwilligen Wechsel übersprungen; kein Game Over,
  solange jemand steht.
- **Game Over:** bei der zweiten ausgefallenen Figur `party_wiped`, Blende läuft an und ist nach
  `fade_frames` voll schwarz. `revive_all()` stellt Health, Korruption (auch der inaktiven Figur)
  und die Blende wieder her.
- **Regression:** phase4 27/27, phase5 51/51, phase6 26/26 weiterhin grün.
- **Fensterlauf** (240 Frames, Vulkan/Forward+) fehlerfrei.

**Merker für künftige Tests (beim Bau dieses Sims aufgelaufen)**
- **GDScript-Lambdas fangen lokale Variablen `by value`.** Ein `signal.connect(func(): flag = true)`
  auf eine *lokale* Variable setzt nichts, was der Aufrufer je sieht — Signal-Mitschriften
  gehören in **Member**-Variablen. Drei Checks waren aus genau diesem Grund still falsch.
- **Korruption exakt auf eine Schwelle zu setzen reicht nicht:** der Abbau (0.4/s) drückt den Wert
  schon im nächsten Frame darunter. Im Test mit kleinem Aufschlag setzen.
- **I-Frames überleben den Figurenwechsel** (Phase 4, gleicher Node). Zwei Todesstöße kurz
  hintereinander prallen am zweiten stumm ab — im Test auf das Ende der I-Frames warten.

**Offen / bekannte Punkte**
- **Feel-Abnahme beim User steht aus:** Ist die Vorwarnung von 10 Frames lang genug, um zu
  reagieren, und kurz genug, um zu erschrecken? Ist `compulsion_per_second = 0.6` zu häufig?
  Fühlt sich die Wechselsperre wie eine Falle an oder nur wie ein genervtes „geht nicht"?
  Alle drei Achsen liegen in `resources/reif.tres`.
- **Kein Game-Over-Bildschirm** — nur Blende und Neustart. Kein Text, kein „nochmal?"-Prompt.
- **Der Raum startet komplett neu** (`reload_current_scene`), inklusive Tür und Skelett. Es gibt
  keinen Checkpoint und keinen Fortschritt, der einen Neustart überlebt.
- **Nur zwei Figuren = zwei Leben.** Der Lebensvorrat skaliert mit der Ensemble-Größe; mit den
  geplanten vier Figuren wird Phase 7 deutlich milder. Das ist eine Balance-Achse, die beim
  Hinzufügen einer Figur mitbedacht werden muss.
- Stufen 1 und 2 (Vignette, Drift) sind weiterhin **nicht vom User abgenommen** (siehe Phase 5).

## Nächste Phase
- Offen. Kandidaten: Raumwechsel/Ziel, Audio-Infrastruktur (Flüstern für Korruptionsstufe 1),
  Game-Over-Bildschirm, weitere Figuren (mit Blick auf die Lebensvorrats-Balance oben).
