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

## Phase 8 — Raumwechsel + Transition ✅ (2026-09-02)

**Erste Phase von „Schicht 1: Systemfundament".** Die Vorlage nennt sie „Phase 7"; dieses Projekt
hat aber schon eine abgenommene Phase 7 (Korruption/Todesmodell). Schicht 1 läuft darum als
**Phasen 8–11**: 8 = Raumwechsel, 9 = Speichern/Laden, 10 = HUD/Menüs, 11 = Audio/Dialog
(User-Entscheidung).

**Anlass:** Der offene Punkt aus Phase 6 — `room_01.tscn` hing fest in `main.tscn`, es gab keinen
Übergang und kein Ziel in der Zielkammer. Damit fehlte auch jeder Andockpunkt für die folgenden
Phasen: Speichern braucht einen Raum-Identifier, Audio einen Track-Wechsel pro Raum, Dialog NPCs
in Räumen.

**Die Hierarchie: `main.tscn` wird persistent**
- Der Raum verschwindet als feste Instanz; an seiner Stelle steht ein leerer `RoomHost: Node2D`
  mit genau 0 oder 1 Kind. Player, PartyManager und alle Overlays hingen ohnehin schon als
  **Geschwister** des Raums dort — die Vorgabe „der Player-Node überlebt den Raumwechsel" war
  damit schon erfüllt, ohne einen Node umzuhängen oder unter einen Autoload zu ziehen.
- Kette: `room_01` (A, 40×24, das Puzzle) ↔ `room_02` (B, 20×12) ↔ `room_03` (C, 20×12).
  Die `RoomExit` in der Zielkammer gibt dem Phase-6-Puzzle zum ersten Mal ein Ziel.

**Architekturentscheidungen (mit Begründung)**
- *`RoomManager` als Autoload, aber ohne feste Pfade:* die Weltszene registriert sich per
  `bind_world(host, player, party)`. Ein `/root/Main/Player` wäre in den Testszenen falsch — die
  hängen `main.tscn` als **Kind** unter sich (Muster seit phase4_sim). Beim `tree_exiting` des
  Hosts lässt der Autoload die Referenzen wieder los.
- *Kein `change_scene_to_file`:* es gäbe die alte Szene frei, bevor die Blende zu ist — und nähme
  den Player mit, der den Wechsel gerade überleben soll.
- *Synchron laden statt `load_threaded_request`:* der Ladevorgang liegt komplett hinter der
  schwarzen Blende, `load()` cacht, und ein Threaded-Load mit Polling wäre headless nicht
  deterministisch. Bei größeren Räumen nachzuziehen — an genau einer Stelle (`_swap_room`).
- *`remove_child` **zusätzlich** zu `queue_free`:* `queue_free` lässt den Node bis zum Frame-Ende
  im Baum; ohne das hätten kurz zwei Räume in `RoomHost` gehangen.
- *Blende zählt Frames, kein Tween* (die Vorlage schlug einen Tween vor): Tür, Gegner-KI,
  Angriffstiming und die Game-Over-Blende zählen im ganzen Projekt Frames, weil das
  deterministisch und headless prüfbar ist. Ein Tween wäre der erste Zeitgeber, der es nicht ist.
- *Input-Sperre als **ein** Flag am Player* (`set_input_locked`): drei Stellen lesen den
  `Input`-Singleton — `player.gd` (Attack-Buffer + Bewegungsvektor der States), `reif.gd`
  (Kanal/Dash) und `party_manager.gd` (Figurenwechsel). Ein Schalter an der Quelle statt fünf
  Guards an den Aufrufstellen. Der Reif **räumt beim Sperren seine Zeitdehnung auf** und lässt
  eine laufende Zwangs-Vorwarnung ausfallen: sonst bliebe ein Gegner des alten Raums im
  `HitstopManager` als verlangsamt registriert, und der Sprite käme violett gefärbt im neuen Raum
  an, wo der Zwangsangriff dann zuschlägt.
- *Gegner des neuen Raums werden während der Einblendung **nicht** gefroren:* ALTTP macht es
  genauso, und `process_mode = DISABLED` auf den Raum hätte laut Phase-5-Befund die
  Collision-Shapes flackern lassen. Stattdessen liegen alle Spawn-Punkte außerhalb der
  Aggro-Reichweite (70 px) des jeweiligen Skeletts — nachgerechnet: 112 px, 96 px, 144 px.
- *`Room` als Basisklasse, Raum 01 als `Room01`:* das Skript von Raum 01 hieß bis Phase 7 selbst
  `Room` und kannte Tür, Platte und Skelett — als Basis für drei Räume nicht tragfähig. Die Basis
  hält nur, was der RoomManager von jedem Raum braucht (`room_id`, `size_tiles`, `bounds()`,
  `spawn_point()`), plus `debug_text()`.
- *Das Debug-Overlay fragt `debug_text()`* statt Platte und Tür direkt zu lesen. Ohne das wäre es
  in Raum 02/03, die beides nicht haben, an `null` gescheitert.
- *`spawn_point()` sucht unter den **eigenen** Kindern, nicht per Gruppe:* der alte Raum hängt im
  Moment der Suche noch einen Frame im Baum (`queue_free`), eine Gruppensuche hätte dessen
  gleichnamigen Punkt liefern können. Kein Treffer → Warnung + erster vorhandener Punkt, damit ein
  Tippfehler in einer Tür-ID den Spieler nicht auf (0,0) in die Wand setzt.
- *`RoomExit` wertet bei `auto_enter = false` jeden Physik-Frame aus,* nicht per Signal-Flanke —
  gleicher Grund wie bei der `PressurePlate` (Phase 6): wer in der Tür stehend die Figur wechselt,
  löst kein neues `body_entered` aus.
- *`music_id` liegt am Raum-Node, nicht in der Registry:* sonst müsste man den Raum an zwei
  Stellen pflegen. In Phase 8 ungenutzt und bewusst schon angelegt.
- *Game Over läuft über den RoomManager* (`restart_at_start()`) statt `reload_current_scene()`
  (User-Entscheidung): der Raum ist jetzt wegwerfbar, also wird er weggeworfen. Gegner respawnen
  dabei von selbst. **Ohne Ausblende, sondern sofort schwarz** — die Game-Over-Blende hat das Bild
  schon zugezogen; ein zweites Ausblenden von 0 nach 1 hätte den toten Raum für 18 Frames wieder
  sichtbar gemacht, sobald der Aufrufer seine eigene Blende zurücknimmt. Der
  `restart_on_wipe`-Schalter bleibt, ist aber **kein Selbstschutz mehr**: es wird keine Szene mehr
  neu geladen, die einen Test neu starten könnte.
- *Neue Input-Action `interact`* (F + Enter + Gamepad Y) über `tools/add_input_actions.gd`, die
  alleinige Quelle der Belegung. F ist für die WASD-Hand erreichbar und kollidiert nicht mit
  Angriff (E) oder Dash (Space/Shift); Gamepad Y, weil A der Dash und die Schultertasten der
  Figurenwechsel sind. Gebraucht wird sie ab Phase 9 (Speicherpunkte) und 11 (NPCs) ohnehin.

**Bug gefunden & behoben (vom neuen Test aufgedeckt)**
- `actors/enemy/states/dead.gd` rief `enemy.play_anim(&"dead")`. Das hängt das Facing an und sucht
  `dead_down` — die Todes-Animation in `skeleton_frames.tres` heißt aber **richtungslos** `dead`.
  Seit Phase 3 lief bei **jedem** Gegnertod ein „There is no animation with name dead_down" ins
  Log, und die Todespose war nie zu sehen. Jetzt `sprite.play(&"dead")` direkt.

**Regel Null (gegen die echte ClassDB geprüft, nicht geraten)**
- `ResourceLoader.load(path, type_hint = "", cache_mode = 1) -> Object`
- `Node.remove_child(node)` / `Node.queue_free()`; `signal Node.tree_exiting` (ohne Argumente)
- `signal Area2D.body_entered(body: Node2D)`; `Area2D.get_overlapping_bodies() -> Array`
- `Camera2D.limit_left/top/right/bottom` sind **int**, dazu `limit_enabled`/`limit_smoothed`
- `KEY_F = 70`, `KEY_ENTER = 4194309`, `JOY_BUTTON_Y = 3`

**Verifikation (headless, `tests/phase8_sim.*`, 82/82 grün)**
- Startzustand: Raum A steht in `RoomHost`, Spieler am Spawn `start`, Kamera-Limits == `bounds()`.
- **Kette A→B→C→B→A:** je Schritt Raum-ID, Spawn-Position, **genau ein** Kind in `RoomHost`,
  alter Raum per `is_instance_valid` **freigegeben**, Blende wieder offen, Kamera-Limits passend
  zum jeweiligen Raummaß (640×384 vs. 320×192), Smoothing aus. `room_changed` und
  `transition_finished` je 4×.
- **Der Raumtausch liegt bei Alpha 1.0** — es gibt keinen Frame, in dem beide Räume sichtbar
  wären. Zusätzlich: die Blende erreicht überhaupt voll schwarz und ist danach wieder 0.
- **Party-Zustand überlebt:** HP unverändert, aktive Figur unverändert, Korruption überlebt und
  sinkt nur um den regulären Abbau (37.50 → 37.46 über zwei Wechsel; der Reif baut auch hinter
  der Blende ab, das ist gewollt).
- **Input gesperrt:** `move_right`, `attack`, `reif_channel`, `switch_figure` und `dash`
  gleichzeitig gedrückt → 0.00 px Bewegung, Zustand bleibt `Idle`, kein Kanal, keine Korruption,
  kein Figurenwechsel. Gegenprobe danach: dieselbe Eingabe trägt wieder 13.1 px.
- **Die Tür löst selbst aus:** hineinlaufen startet die Transition (`auto_enter = true`); mit
  `auto_enter = false` tut Betreten allein nichts und erst `interact` löst aus.
- **Gegner respawnen:** Skelett in B erledigt, über C zurück nach B → wieder da, volle Health,
  **neue Instanz**.
- **Unbekannte Raum-ID** wechselt nichts, hinterlässt keine hängende Transition und lässt den
  Spieler handlungsfähig (der `push_error` im Log ist der provozierte Fehlerfall).
- **Game Over:** beide Figuren ausgeschaltet → `party_wiped` → Blende → Neustart in Raum A am
  Startspawn, beide Figuren stehen, Health voll, Korruption beider Figuren 0, beide Blenden
  zurückgenommen, Input frei.
- **Tool-Gegenprobe:** `build_room_resources.gd` baut jetzt drei Räume aus der `ROOMS`-Tabelle;
  die Kachelbelegung von Raum 01 (`tile_map_data`) ist **md5-identisch** zur abgenommenen
  Fassung. Byte-identisch ist die Datei nicht und kann es nicht sein — Godot vergibt
  Sub-Resource- und `unique_id`-Werte bei jedem Speichern neu.
- **Regression:** phase4, phase5, phase6 und phase7 alle weiterhin „ALLES GRUEN".
- **Fensterlauf** (240 Frames, Vulkan/Forward+) fehlerlos — headless rendert keine Tiles und
  kompiliert keine Shader, darum extra geprüft.

**Offen / bekannte Punkte**
- **Feel-Abnahme beim User steht aus:** Ist `fade_frames = 18` (0,3 s je Hälfte) richtig, oder
  wirkt der Wechsel gehetzt bzw. träge? Fühlt sich `auto_enter` gut an, oder will die Tür einen
  `interact`-Druck? Das sind die beiden Tuning-Achsen dieser Phase.
- **Räume B und C sind leer** (Boden, Wände, ein Skelett) — bewusst Testgerüst, kein Content.
- **Die `RoomExit` hat kein eigenes Sprite:** violett getöntes `tile_16.png` als Platzhalter,
  Eintrag in `docs/assets-todo.md`. Kein geprüftes Treppen-/Torfeld vorhanden, und geraten wird
  nicht (die Tile-Auswahl in Phase 6 war empirisch belegt).
- **Kein Fortschritt überlebt einen Raumwechsel:** gedrückte Schalter, offene Türen und getötete
  Gegner sind nach dem Wiederbetreten zurückgesetzt. Das Flag-System dafür kommt mit Phase 9
  (`world_flags` in `SaveData`).
- **Kein Musik-/Ton-Wechsel:** `Room.music_id` ist angelegt und ungenutzt, `room_changed` hat noch
  keinen Hörer (damals für Phase 11 vorgesehen; tatsächlich in Phase 10 gebaut).
- **`size_tiles` steht doppelt** — im Raum-Skript und in der `ROOMS`-Tabelle des Bau-Tools. Wer
  eines ändert, muss das andere mitändern (unverändertes Thema seit Phase 6).

## Phase 9 — Speichern, Laden, Game Over (abgeschlossen)

Bis Phase 8 war jeder Fortschritt an das laufende Programm gebunden: Beenden hieß von vorn
anfangen, und Game Over startete **blind** am Startraum neu. Phase 9 gibt dem Spiel ein
Gedächtnis über den Prozess hinaus und macht aus dem Game Over eine Frage statt einer Tatsache.

**Was steht**
- **`SaveData`** (`resources/save_data.gd`) — typisierte Resource-Klasse: `version`, `room_id`,
  `spawn_id`, `figure_index`, `health[]`, `corruption[]`, `world_flags`, `playtime_frames`,
  `saved_at`. Plus `to_dict()`, `from_dict()`, `playtime_text()`, `summary()`.
- **`SaveManager`** (Autoload, `globals/save_manager.gd`) — 3 Slots unter `user://saves/`,
  `world_flags` und Spielzeit des laufenden Spiels, `capture/save_to_slot/load_from_slot/
  slot_info/delete_slot/new_game`, Signale `saved / loaded / load_failed / game_restarted`.
- **`SavePoint`** (`actors/props/save_point.tscn`) — Speicherpunkt in Raum A (neben dem Start)
  und in Raum C. Schreibt den aktiven Slot auf `interact` und frischt das Ensemble auf.
- **`ui/game_over_menu/`** — „Letzter Speicherstand" / „Neu beginnen" nach der Schwarzblende.
- **Persistente Kills** — `Skeleton.persist_id`; das Skelett in Raum C bleibt tot, die in A und B
  respawnen weiter. Damit ist der in Phase 8 offene Punkt „kein Fortschritt überlebt einen
  Raumwechsel" für Gegner geschlossen.
- **`RoomManager.enter_from_black()`** — aus `restart_at_start()` verallgemeinert; dazu
  `player()`, `party()` und `has_room()` als Fragen an die registrierte Welt.
- **`PartyManager.restore_all()`**, `health_array()`, `corruption_array()`, `apply_state()` und
  das Signal `party_restored`.
- **Welt-Stopp beim Game Over** — `Player.set_defeated()` und `RoomManager.set_room_frozen()`.

**Nachgereicht: die Welt hielt beim Game Over nicht an (vom User im Spielen gefunden)**
- Symptom: nach dem Wipe lag die Schwarzblende über dem Bild, aber **das Skelett schlug weiter
  auf die gefallene Figur ein**. Ursache: nichts hielt den Raum an. Die Hurtbox des Players blieb
  scharf, jeder weitere Treffer lief in `_on_hurt` mit `_health == 0` und feuerte erneut
  `downed` → `party_wiped`; der Input wurde erst gesperrt, **nachdem** die Blende durch war.
- Fix an drei Stellen: `main._on_party_wiped()` sperrt den Input sofort, setzt
  `Player.set_defeated(true)` (nur `monitorable`, **nicht** die I-Frames — dieselbe Trennung wie
  beim Phase-Dash) und ruft `RoomManager.set_room_frozen(true)`. Der Freeze läuft über
  `process_mode` am `RoomHost` — dasselbe Mittel wie im HitstopManager und aus demselben Grund:
  er trifft genau den Raum und lässt Player, Overlays und Blenden in Ruhe.
- *Aufgehoben wird der Zustand nicht dort, wo er gesetzt wurde*, sondern wo die Welt wieder
  entsteht: `_swap_room` setzt den `RoomHost` bei **jedem** Raumaufbau auf `INHERIT`, und
  `PartyManager._activate` nimmt die Ausfall-Sperre zurück — wer das Feld betritt, ist
  verwundbar. Damit kann kein Freeze in den nächsten Raum lecken, egal ob über Laden, „Neu
  beginnen", `revive_all()`, `restore_all()` oder den Zwangswechsel.
- `set_deferred` für die Hurtbox, weil der Ausfall aus einem Area-Signal kommt und damit mitten
  im Physik-Callback läuft (derselbe Fehler, der in Phase 2 den HitstopManager zerlegt hat).

**Nachgereicht: drei Fehler aus dem Debugger (vom User im Spielen gefunden)**
- `dead.gd:14 Function blocked during in/out signal` — der Dead-State wird aus
  `hurtbox.hit_taken` betreten, also **mitten im Area-in/out-Signal**. Dort verweigert Godot das
  direkte Setzen von `monitorable`; der Wert blieb stehen und der tote Gegner war weitere
  45 Frames treffbar. Jetzt `set_deferred("monitorable", false)` — dieselbe Klasse Problem wie
  beim `process_mode` im HitstopManager (Phase 2) und beim Türfeld (Phase 6). Dieselbe Zeile in
  `Skeleton._despawn()` (Phase 9) gleich mit umgestellt.
- `_tick_slowed: Trying to assign invalid previously freed instance` — der eigentliche Fund. Stirbt
  ein Gegner, **während** der Reif ihn dehnt, halten `HitstopManager._frozen/_slowed` und
  `Reif._slowed` noch Referenzen auf seine StateMachine und seinen Sprite. Alle diese Schleifen
  liefen mit einer als `Node` **typisierten** Laufvariable — und genau diese Zuweisung ist der
  Fehler: sie schlägt zu, **bevor** der vorhandene `is_instance_valid`-Guard gefragt wird. Jetzt
  laufen alle vier Schleifen (`hitstop`, `_tick_frozen`, `_tick_slowed`, beide Reif-Seiten) über
  `Variant` und prüfen danach. Dazu nehmen `HitstopManager.is_slowed()` und `time_scale_for()`
  jetzt `Variant`: mit `Node` in der Signatur war schon der **Aufruf** mit einer freigegebenen
  Referenz der Fehler, statt die ehrliche Antwort „nicht verlangsamt" zu geben.
- `Integer division. Decimal part will be discarded` (3×, beim Parsen) — die Spielzeit-Formatierung
  stand doppelt da, in `SaveData` und im `SaveManager`. Jetzt eine statische
  `SaveData.format_frames()` mit `@warning_ignore("integer_division")`: hier **ist**
  Ganzzahldivision gewollt (Frames → Sekunden → Minuten), und der SaveManager ruft sie auf.
- **Verifikation:** neuer Abschnitt 12 in `phase5_sim` („Gegner stirbt WÄHREND der
  Zeitdehnung"): Vorbedingung ist ein nachweislich gedehnter Gegner, dann stirbt er, gibt sich
  frei — danach hält der HitstopManager keine toten Nodes mehr, der Reif kanalisiert ungestört
  weiter, die Korruption lädt weiter auf und der Kanal endet regulär. Alle sechs Testszenen
  laufen jetzt mit **leerem stderr** durch (außer den absichtlich provozierten `push_error` in
  phase8/phase9) — vorher war das nie geprüft.
- *Merker fürs Testen:* ein Skriptfehler in einer Testszene **hängt** den Lauf, statt ihn
  fehlschlagen zu lassen (`get_tree().quit()` wird nie erreicht) und lässt einen Godot-Prozess
  stehen. Genau dafür hat `phase9_sim` seit dieser Phase das `FRAME_BUDGET`.

**Entscheidungen (und warum)**
- *JSON statt `.tres`* (User-Entscheidung): ein `.tres` trägt den Skriptpfad im Savefile mit — ein
  Spielstand sind Spielerdaten und soll nichts ausführen können. Dazu cacht `ResourceLoader` nach
  Pfad, ein Slot-Overwrite wäre im laufenden Spiel unsichtbar. Und ein später ergänztes Feld ist
  in JSON ein `data.get(key, default)`. Die `.tres`-Regel des Projekts gilt für **Autorendaten**
  (`TuningStats`, `ReifStats`, `RoomRegistry`), die von Hand gepflegt werden; ein Spielstand wird
  nur geschrieben und gelesen.
- *`from_dict()` prüft alles vor der ersten Zuweisung an die Welt* — kein Dictionary, falsche
  `VERSION`, fehlendes `room_id`, unbekannter Raum: alles endet in `null` bzw. `load_failed`, die
  Welt bleibt unangetastet. Ein halb angewandter Spielstand wäre schlimmer als kein Ladevorgang.
- *Alle Zahlen laufen durch `int()`/`float()`*: JSON kennt keinen Integer, aus einer gespeicherten
  `6` wird beim Parsen `6.0`, und `Array[int]` nimmt das nicht an.
- *Aufteilung SaveManager ↔ RoomManager:* der eine besitzt den **Fortschritt**, der andere den
  **Raum**. Die Abhängigkeit läuft nur in eine Richtung (SaveManager → RoomManager), und die Welt
  holt sich der SaveManager über `RoomManager.player()/party()` statt über ein zweites
  `bind_world` — es gibt weiter genau **eine** Registrierungsstelle (`scenes/main.gd`).
- *Erst die Flags, dann der Raum:* ein erledigter Boss liest sein Flag in `_ready()`. Umgekehrt
  stünde er nach dem Laden einmal da und verschwände beim nächsten Betreten.
- *Der Speicherpunkt heilt und holt Ausgefallene zurück, wäscht aber die Korruption nicht*
  (User-Entscheidung): die Korruption ist die Langzeitschuld des Reifs („baut extrem langsam ab",
  Phase 5). Ein Punkt, der sie mitnimmt, macht sie folgenlos — einer, der ausgefallene Figuren
  draußen lässt, macht den Ausfall bis zum Game Over unumkehrbar. Nur `revive_all()`
  (Game Over / Neu beginnen) setzt sie auf 0.
- *Aufgefrischt wird **vor** dem Schreiben*, sonst hält der Slot genau die Verletzungen fest, die
  der Punkt gerade geheilt hat.
- *Kein Auto-Speichern am Punkt* — anders als die `RoomExit` mit `auto_enter = true`: Speichern
  überschreibt einen Slot, das braucht einen Tastendruck. Die Überlappung wird trotzdem **jeden
  Physik-Frame** ausgewertet (Muster von `PressurePlate` und `RoomExit`).
- *Gespeichert wird ein `spawn_id`, keine Position:* der Punkt nennt den `SpawnPoint` neben sich.
  Eine rohe Position würde alte Spielstände nach einer Raumänderung in die Wand setzen.
- *Kein Hauptmenü* (User-Entscheidung): es wäre eine eigene Szene **vor** der persistenten
  Weltszene und damit ein eigener Umbau. Stattdessen „Neu beginnen". Die drei Slots sind angelegt
  und über `SaveManager.active_slot` adressierbar; eine Slot-Auswahl-UI fehlt bewusst.
- *Leerer Slot = grauer, **nicht anwählbarer** Eintrag* statt eines wirkungslosen: eine Taste, die
  sichtbar existiert und nichts tut, liest sich als Bug.
- *Bestätigen mit `interact` **oder** `attack`:* wer gerade gestorben ist, hat die Hand nicht
  zwingend auf F. Beim Öffnen sperrt `main.gd` den Player-Input — sonst schlägt derselbe Druck im
  Hintergrund noch die gefallene Figur zu. Freigegeben wird er vom Raumaufbau, nicht vom Menü.
- *Persistente Kills sind **opt-in*** (`persist_id` leer = respawnt): ein Vertical Slice braucht
  wiederkehrende Gegner. Die ID ist der Flag-Name und muss über alle Räume eindeutig sein.
- *Spielzeit in Frames*, wie jeder Zeitwert im Projekt (Tür, Gegner-KI, Blenden) — und sie läuft
  auch hinter einer Blende weiter.
- *`SaveManager.save_dir` ist zur Laufzeit setzbar*: die Tests dürfen die echten Spielstände des
  Entwicklers nicht anfassen (phase8_sim → `user://saves_phase8`, phase9_sim → `user://saves_test`).

**Regel Null (gegen die echte ClassDB geprüft, nicht geraten)**
- `FileAccess.open(path, flags) -> FileAccess` (static), `file_exists(path) -> bool` (static),
  `get_open_error() -> Error` (static), `store_string(s) -> bool`, `get_as_text() -> String`
- `DirAccess.make_dir_recursive_absolute(path) -> Error`, `remove_absolute(path) -> Error`,
  `dir_exists_absolute(path) -> bool` (alle static)
- `JSON.stringify(data, indent = "", sort_keys = true, full_precision = false) -> String`,
  `JSON.parse_string(json_string) -> Variant` (beide static)
- `Time.get_unix_time_from_system() -> float`
- `Array.duplicate(deep = false) -> Array`, `Dictionary.duplicate(deep = false) -> Dictionary`

**Verifikation (headless, `tests/phase9_sim.*`, 135/135 grün)**
- **Speicherpunkt:** ohne Tastendruck passiert nichts; mit `interact` wird Slot 1 geschrieben, der
  Punkt leuchtet, Health ist voll, die ausgefallene zweite Figur steht wieder — und die
  Korruption **bleibt** (40,0 aktiv / 12,0 inaktiv).
- **Inhalt auf Platte:** gültiges JSON, als `SaveData` lesbar, `version == 1`, `room_id room_01`,
  `spawn_id save_a` (der Punkt, **nicht** der Raumeingang), Health beider Figuren voll und als
  **Int** (nicht als geparster Float), Korruption beider Figuren, Spielzeit > 0, Zeitstempel.
- **Laden:** nach Raumwechsel, Figurenwechsel, HP 2, Korruption 70 und einem zusätzlichen Flag
  holt Slot 1 Raum, Spawn (136, 264), Figur, HP, Korruption **beider** Figuren und die Spielzeit
  zurück; das nach dem Speichern gesetzte Flag ist weg; genau ein Raum in `RoomHost`; Blende
  offen; Input frei; Gegenprobe: die Welt ist danach spielbar (13 px Bewegung).
- **Drei Slots sind unabhängig:** Slot 2 hält `room_02`, während Slot 1 weiter `room_01` hält;
  Slot 3 leer; Löschen wirkt und meldet beim zweiten Mal `false`; Slot 0 und 4 werden abgewiesen.
- **Kaputte Spielstände:** Müll-JSON, `version 99`, unbekannter Raum, fehlendes `room_id` — jedes
  Mal `load_from_slot() == false`, `load_failed`, unveränderte Welt und freier Input.
  `from_dict(null)` und `from_dict("nope")` ergeben `null`.
- **Persistente Kills:** das Skelett **ohne** `persist_id` (Raum B) ist nach Verlassen und
  Wiederbetreten wieder da; das **mit** `persist_id` (Raum C) bleibt weg, setzt `kill:skeleton_c`,
  ist nach „Neu beginnen" wieder da und nach dem Laden desselben Slots wieder weg.
- **Welt-Stopp beim Wipe:** der Test stirbt in Raum B **in Aggro-Reichweite eines laufenden**
  Skeletts (Vorbedingung: es bewegt sich, 5,5 px in 6 Frames). Nach dem Wipe ist der Raum sofort
  eingefroren, der Spieler als ausgefallen markiert, der Input sofort gesperrt (nicht erst nach
  der Blende), die Hurtbox nimmt nichts mehr an — und über 20 Frames bewegt sich das Skelett
  **0,0 px** und es kommt **kein zweites `party_wiped`**. Nach dem Laden läuft der Raum wieder
  und der Spieler ist wieder verwundbar.
- **Game-Over-Menü, Speicherstand:** zwei Ausfälle → Blende → Menü offen, Bild schwarz, Input
  gesperrt, Ladeeintrag vorausgewählt; Hoch/Runter wählt; Bestätigen lädt Raum C, beide Figuren
  stehen, Health voll, **beide** Blenden zurückgenommen, Input frei, Menü unsichtbar.
- **Game-Over-Menü, Neu beginnen:** Startraum, Startspawn, beide Figuren stehen, Korruption
  beider Figuren 0, Flags geräumt, Spielzeit von vorn — und der Slot bleibt liegen.
- **Game Over ohne Spielstand:** „Letzter Speicherstand" ist nicht anwählbar, „Neu beginnen" ist
  vorausgewählt, Hoch ändert daran nichts, der Neuanfang läuft trotzdem.
- **Der Test räumt auf:** eigenes Verzeichnis, am Ende leer. Dazu eine **Notbremse**
  (`FRAME_BUDGET = 6000`): der Test wartet an mehreren Stellen auf Signale, ein Fehler darin
  würde headless nicht fehlschlagen, sondern ewig laufen.
- **Regression:** phase4 (27), phase5 (**57**, inkl. des neuen Abschnitts 12), phase6 (28),
  phase7 (37), phase8 (84) alle weiterhin „ALLES GRUEN" — zusammen mit phase9 (135)
  **368 Checks**.
- **Fensterlauf** (400 Frames, Vulkan/Forward+) fehlerlos, stderr leer.

**Was in Phase 8 offen war und jetzt zu ist**
- „Kein Fortschritt überlebt einen Raumwechsel": für Gegner geschlossen (`persist_id` +
  `world_flags`). Gedrückte Platte und offene Tür bleiben absichtlich flüchtig — das ist ein
  **Zeit**-Puzzle, kein Schalterzustand.

**Offen / bekannte Punkte**
- **Feel-Abnahme steht aus** (weiterhin auch die aus Phase 8: `fade_frames = 18`, `auto_enter`).
  Neu dazu: Fühlt sich der Speicherpunkt als solcher lesbar an, ohne eigenes Sprite und ohne Ton?
  Ist „heilt, aber wäscht die Korruption nicht" im Spielen nachvollziehbar?
- **Kein Auto-Save** — nur der Speicherpunkt schreibt. Ein Auto-Save beim Raumwechsel wäre eine
  Zeile im `room_changed`-Handler, ändert aber den Charakter des Spiels (Speicherpunkte als
  Ressource) und gehört darum in eine Abnahme, nicht in diese Phase.
- **Keine Slot-Auswahl-UI und kein Hauptmenü** — die drei Slots sind adressierbar, aber im Spiel
  erreicht man nur `active_slot`.
- **Kein Ton beim Speichern**, keine Bestätigungsmeldung außer dem Aufleuchten des Punkts
  (Audio-Infrastruktur fehlt weiterhin komplett, siehe `docs/assets-todo.md`).
- **Speicherpunkt und Game-Over-Menü sind Platzhalter-Optik:** goldenes `tile_16.png`, Godots
  Standardfont im Menü. Beides in `docs/assets-todo.md` eingetragen.
- **Kein Schutz gegen einen von Hand editierten Spielstand** außer den Formatprüfungen — ein
  Slot ohne stehende Figur führt zu einer Warnung und vollständiger Wiederherstellung. Prüfsummen
  wären für einen Einzelspieler-Slice Aufwand ohne Nutzen.
- **`playtime_frames` läuft auch im Game-Over-Menü weiter** (der Autoload zählt, solange eine
  Welt gebunden ist). Sichtbar nur im Debug-Overlay, in einer Statistik-Anzeige müsste man es
  anhalten.

## Phase 10 — Ton (abgeschlossen, 2026-09-03)

Bis Phase 9 war das Spiel **vollständig stumm**. Neun Phasen Kampfgefühl ohne einen einzigen
Klang: ein Treffer war ein Freeze-Frame plus ein Knockback, der Telegraph des Skeletts ein rotes
Blinken, der Speicherpunkt ein Aufleuchten von 24 Frames. Alles davon setzt voraus, dass der
Spieler genau hinschaut. Von drei Kandidaten (Hauptmenü mit Slot-Auswahl, Ton, Raum-Inhalt) fiel
die Wahl auf den Ton, weil er als einziger direkt auf das Projektziel einzahlt — **Kampfgefühl,
nicht Umfang**.

**Was steht**
- **`AudioManager`** (Autoload, `globals/audio_manager.gd`) — der einzige Ort, an dem Klang
  abgespielt wird: `play(id, pitch)`, `start_loop/stop_loop`, `play_music(id, frames)`,
  `stop_music`, `play_jingle/stop_jingle`, `set_bus_db/bus_db/has_bus`, `enabled`.
  Signal `music_changed`. Dazu Auskunftsmethoden für Tests und das Debug-Overlay
  (`current_music`, `music_starts`, `is_music_fading`, `music_volume`, `last_played`,
  `last_pitch`, `play_count`, `active_sfx_count`, `pool_size`, `loop_id`, `bank`).
- **`AudioBank`** (`resources/audio_bank.gd` + generierte `audio_bank.tres`) — 18 Effekt-IDs
  (mehrere davon mit Varianten) und 3 Musik-IDs. Die Streams liegen als `ExtResource` darin und
  kommen mit der Bank in einem Zug.
- **`tools/build_audio_resources.gd`** — baut `resources/default_bus_layout.tres`
  (Master / Music -9 dB / SFX 0 dB) **und** die Bank und setzt
  `audio/buses/default_bus_layout` per ProjectSettings-API. Die Tabellen `SOUNDS` und `MUSIC`
  darin sind die einzige Stelle, an der „Spielereignis → Datei im Pack" steht.
- **18 verdrahtete Ereignisse**, davon war jedes einzelne vorher stumm: Angriffsschwung,
  Treffer auf Gegner, Treffer auf den Spieler, Gegnertod, Telegraph, Dash, Reif-Kanal (gehalten),
  Vorwarnung des Zwangsangriffs, neue Korruptionsstufe, Figurenwechsel, verweigerter Wechsel,
  Ausfall einer Figur, Platte runter, Platte hoch, Türbewegung, Speichern, Menü-Navigation,
  Menü-Bestätigung. Plus Game-Over-Jingle und Raummusik.
- **`Hitbox.hit_sound`** als `@export` am Node — die Hitbox ist der eine Trichter für **jeden**
  Treffer im Spiel; wer zuschlägt, sagt die Szene.
- **`Skeleton.play_sound(id)`** — legt die Zeitdehnung des Reifs auf den Pitch.
- **`Room.music_id`** wird benutzt: A `dungeon`, B `crypt`, C `crypt`.
- **Debug-Overlay** zeigt Musik (samt Blende), letzten Effekt, Zahl aktiver Abspieler und den
  gehaltenen Klang — ohne das ist eine Feel-Abnahme des Mixes nicht führbar.

**Entscheidungen und ihre Gründe**
- *Autoload, nicht Node in der Weltszene:* Musik muss den Raumwechsel überleben, um den es
  gerade geht — dieselbe Begründung, die in Phase 8 die Blende in den `RoomManager` gelegt hat.
  `PROCESS_MODE_ALWAYS`, damit weder Hitstop (Phase 2) noch der Game-Over-Freeze (Phase 9) den
  Ton abreißen lassen. Er hängt an `RoomManager.room_changed` — über ein **Signal**, nie über
  eine direkte Referenz, und nur in diese Richtung; der RoomManager kennt ihn nicht. In
  `project.godot` steht er darum **nach** dem RoomManager.
- *Nicht positional* (`AudioStreamPlayer`, nicht `AudioStreamPlayer2D`): die Kamera folgt dem
  Spieler und ein Raum ist maximal der doppelte Viewport — alles Hörbare ist auf dem Bild.
  Positionaler Ton hätte Abspieler an jeden Aktor gehängt und den Manager als einzige Stelle
  aufgegeben.
- *Pegel auf den Bussen, nicht an den Abspielern.* Die Abspieler-Lautstärke gehört ganz der
  Kreuzblende der Musik. Vorgabe im generierten Layout, zur Laufzeit über `set_bus_db` — das
  ist der Andockpunkt einer Optionen-UI, die es noch nicht gibt (dieselbe Lage wie bei den drei
  Spielstand-Slots ohne Slot-Auswahl, Phase 9).
- *Ein Klang pro ID pro Physik-Frame.* Zwei Gegner, die im selben Frame getroffen werden, sind
  zwei Aufrufe von `hit_enemy`; deckungsgleich addiert klingt das nach einem Knacken statt nach
  zwei Treffern. Pool aus 12 Abspielern, round-robin: ein abgeschnittener alter Klang ist besser
  als ein verschluckter neuer — Rückmeldung auf die **letzte** Aktion ist das, was den Kampf
  lesbar macht.
- *Varianten statt eines Klangs pro Ereignis* (Angriff 3, Treffer 3, Dash 2, Gegnertod 2): ein
  Trefferklang, der beim zehnten Schlag noch identisch klingt, wird zu Matsch.
- *Der Reif fährt in den Pitch.* `Skeleton.play_sound` fragt
  `HitstopManager.time_scale_for(state_machine)` — ein zeitgedehnter Gegner klingt tiefer. Das
  ist die einzige Stelle, an der der Reif hörbar auf etwas anderes als sich selbst wirkt, und
  genau das macht ihn im Kampf lesbar. Gefragt wird nach der StateMachine, **nicht** nach dem
  Body: verlangsamt wird sie (Phase 5, damit die Areas des Gegners nicht flackern).
- *Der Klang hängt am gelandeten Treffer, nicht am Aufruf:* gespielt wird nur, wenn
  `Hurtbox.take_hit` `true` liefert. Ein Klang, den I-Frames abgeprallt haben, wäre eine Lüge.
- *`hit_sound` als Export am Node statt als Zweig im Code:* die Hitbox ist der eine Trichter,
  durch den Spieler→Gegner **und** Gegner→Spieler laufen. Wer zuschlägt, weiß der Trichter nicht
  und soll er nicht wissen.
- *Genau EIN gehaltener Klang* (der kanalisierende Reif). `start_loop` ist idempotent — sonst
  stotterte er jeden Frame, weil der Reif seinen Kanal frame-getrieben auswertet. Aufgeräumt wird
  er bei Input-Sperre, sonst summt er durch die Blende in den nächsten Raum (dieselbe
  Aufräumpflicht wie bei der Zeitdehnung, Phase 8).
- *Gleiche Musik-ID = kein Neustart.* Die wichtigste Zeile der Musikverwaltung. Die Kette ist
  bewusst A `dungeon` ↔ B `crypt` ↔ C `crypt`: ein Stück, das an jeder Tür von vorn anfängt,
  verrät die Raumgrenze und macht Herumlaufen unangenehm. B↔C beweist den Fall im Spielen.
- *Kreuzblende in Frames* (`music_fade_frames = 45`, 0,75 s), zwei Abspieler, kein Tween — wie
  Tür, Gegner-KI, Angriffstiming und beide Blenden, und aus demselben Grund. Sie blendet vom
  **aktuellen Stand** des Ausblendenden aus, damit eine unterbrochene Blende nicht erst auf voll
  springt.
- *Die Ogg-Schleife setzt der Manager beim Einhängen, nicht das Bau-Tool.* Stand einmal im Tool
  und war ein No-Op: in der `.tres` landet nur eine `ExtResource`-Referenz, das `loop`-Flag des
  Streams liegt in der `.ogg.import` des Packs (dort `false`) und wird von `ResourceSaver` nicht
  mitgeschrieben. Der Manager verändert damit eine geteilte Resource im Speicher — zulässig, weil
  er ihr einziger Nutzer ist und die Zuweisung idempotent.
- *Jingles auf eigenem Abspieler* (Musik-Bus): `play_jingle` stellt das Stück ab — beides
  gleichzeitig ist Krach, und eine weiterlaufende Dungeonmusik hinter dem Tod liest sich wie ein
  hängender Frame. Umgekehrt darf `stop_music` den Jingle nicht mit abräumen. `scenes/main.gd`
  würgt ihn ab, bevor eine neue Welt aufgebaut wird.
- *Der Klang des Figurenwechsels hängt am freiwilligen Wechsel, nicht in `_activate`:* das läuft
  auch beim Laden, beim Wiederbeleben und beim Zwangswechsel nach einem Ausfall. Ein Spielstand
  soll nicht chirpen, und der Ausfall hat seinen eigenen Klang.
- *Eine neue Korruptionsstufe klingt, der Abbau nicht.* Steigen ist ein Ereignis, die 0,4/s
  Abbau sind ein Nachlassen über Minuten. Dazu `Reif.sync_level()`, das `PartyManager._activate`
  ruft: ohne den Abgleich chirpte jeder Wechsel auf eine schon korrumpierte Figur, obwohl sie
  nichts erreicht hat.
- *Am Rand der Menüliste bleibt es still.* Ein Klick, auf den nichts folgt, liest sich als Bug —
  dieselbe Überlegung, die in Phase 9 den leeren Slot grau **und nicht anwählbar** gemacht hat.
- *Kein Tuerklang im Pack.* `door_move` ist ein schwerer Aufprall, beim Schließen derselbe Klang
  mit Pitch 0,8 (`Door.CLOSE_PITCH`) — dieselbe Tür, andere Richtung. Behelf, eingetragen in
  `docs/assets-todo.md`.

**Regel Null (gegen die echte ClassDB geprüft, nicht geraten)**
- `AudioServer.add_bus(at_position = -1) -> void`, `set_bus_name(idx, name) -> void`,
  `set_bus_send(idx, send: StringName) -> void`, `set_bus_volume_db(idx, db) -> void`,
  `get_bus_volume_db(idx) -> float`, `get_bus_index(name: StringName) -> int`,
  `remove_bus(idx) -> void`, `generate_bus_layout() -> AudioBusLayout`, `.bus_count: int`
- `AudioBusLayout` hat **keine** skriptbaren Properties — die Klasse ist in der Doku leer, alles
  läuft über interne `bus/N/...`-Keys. Genau deshalb ist sie nicht von Hand schreibbar.
- `AudioStreamPlayer`: `.stream`, `.bus: StringName`, `.pitch_scale`, `.volume_db`,
  `.volume_linear`, `.playing`, `play(from_position = 0.0)`, `stop()`, Signal `finished`
- `AudioStreamOggVorbis.loop: bool` (Setter `set_loop`, Getter `has_loop`, Default `false`)
- `ResourceSaver.save(resource, path = "", flags) -> int`
- `db_to_linear` / `linear_to_db` als `@GlobalScope`-Funktionen
- ProjectSetting heißt `audio/buses/default_bus_layout`

**Gefunden und geklärt: die zwei Zeilen beim Beenden**
- Symptom: seit dieser Phase endete jeder Lauf mit `WARNING: ObjectDB instances leaked at exit`
  und `ERROR: 2 resources still in use at exit`; `--verbose` nennt `AudioStreamOggVorbis`,
  `OggPacketSequence` und die zugehörigen Playbacks.
- Nachgestellt in einem **eigenen Projekt aus zwölf Zeilen** ohne eine Zeile des AudioManagers:
  tritt genauso auf. In **beiden** Audio-Treibern (Fenster wie headless). Auch mit `stop()` +
  `stream = null` im `_exit_tree` nicht abstellbar — der zuerst gebaute Aufräum-Handler war ein
  No-Op und flog wieder raus, statt als Kommentar stehenzubleiben, der etwas behauptet.
- Bedingung ist ein **laufendes** Ogg beim Prozessende; ein geladenes, nicht abgespieltes ist
  sauber. Also Engine-Verhalten, kein Leck im laufenden Spiel — und der Grund für den
  Stummschalter.
- `AudioManager.enabled` schaltet stumm und lässt die **Buchführung** laufen (`current_music`,
  `music_starts`, `play_count`, Dedup, Pitch). Zwei Gründe, und nur einer sind die Tests: die
  Suiten phase4..9 prüfen keinen Ton und sollen die Zeilen nicht erben — und es ist der Anfang
  der Stummschaltung, die ein Optionsmenü braucht.

**Verifikation (headless, `tests/phase10_sim.*`, 120/120 grün)**
- **Busse und Bank:** Master/Music/SFX vorhanden, Musik liegt unter den Effekten (-9 / 0 dB);
  jede der 18 Effekt-IDs und aller 3 Musik-IDs, die im Spiel angeworfen werden, ist in der Bank;
  Angriff und Treffer haben ≥ 2 Varianten, und über 40 Ziehungen kommen auch mehrere vor
  (Variation im Ohr, nicht nur in der Bank); unbekannte ID liefert `null`.
- **Abspiel-Mechanik, mit echtem Ton (nur WAV):** `play()` meldet Erfolg, Zähler und
  `last_played` stimmen, ein Abspieler läuft **wirklich**; zweiter Aufruf derselben ID im
  gleichen Frame wird verworfen, nächsten Frame wieder erlaubt; unbekannte ID meldet Fehlschlag;
  40 Klänge über 40 Frames legen **keinen** Node nach; `start_loop` ist idempotent, `stop_loop`
  räumt auf; `enabled = false` schaltet alle Abspieler ab.
- **Musik:** Kreuzblende ist auf halber Strecke halb laut (0,50) und danach voll (1,00);
  **gleiche ID startet nicht neu** und löst auch keine Blende aus; andere ID blendet über;
  `stop_music(0)` ist ein harter Schnitt; leere und unbekannte IDs verhalten sich definiert;
  `music_changed` meldet `dungeon`, `crypt`, `""`.
- **Die Raumkette trägt die Musik:** Startraum bringt `dungeon` mit; A→B wechselt auf `crypt`;
  **B→C lässt dasselbe Stück laufen und startet es nicht neu** (Startzähler bleibt stehen), C→B
  ebenso; B→A blendet zurück und wirft `dungeon` neu an.
- **Der Kampf ist hörbar:** die Klang-IDs sitzen an den Hitboxen der jeweiligen Szene; ein
  **echter Überlapp** (nicht `hurtbox.take_hit` wie in den anderen Suiten — das umginge genau
  die Stelle, um die es geht) klingt in beide Richtungen; ein an I-Frames **abgeprallter**
  Treffer bleibt stumm; Telegraph und Gegnertod klingen; ein zeitgedehnter Gegner klingt mit
  Pitch 0,55, ein ungedehnter mit 1,00.
- **Der Reif ist hörbar:** Kanal summt, Dash zischt, Loslassen beendet den gehaltenen Klang, und
  die Input-Sperre schaltet ihn ab (er summt nicht in den nächsten Raum); die Vorwarnung des
  Zwangsangriffs warnt hörbar; eine neu erreichte Korruptionsstufe klingt, eine sinkende nicht.
- **Ensemble, Raum, Speichern:** freiwilliger Wechsel klingt; ein Wechsel auf eine schon
  korrumpierte Figur klingt **nicht** nach neuer Stufe; der ab Stufe 4 verweigerte Wechsel
  klingt; Platte runter und hoch; Tür auf und zu, das Zuschlagen mit Pitch 0,80; Speichern
  bestätigt sich hörbar.
- **Ausfall, Game Over, Menü:** eine ausgefallene Figur klingt; Game Over stellt die Musik ab;
  Menü-Navigation klickt, **am Rand der Liste bleibt es still**, Bestätigen klickt; nach dem
  Laden trägt der Raum wieder sein Stück und der Jingle läuft nicht darunter weiter.
- **Der Test räumt auf** (eigenes Verzeichnis `user://saves_phase10`, am Ende leer) und hat eine
  **Notbremse** (`FRAME_BUDGET = 6000`), aus demselben Grund wie phase9_sim.
- **Regression:** phase4 (27), phase5 (57), phase6 (28), phase7 (37), phase8 (84), phase9 (135)
  alle weiterhin „ALLES GRUEN" — zusammen mit phase10 (120) **488 Checks**, 0 Fehler, kein
  Ogg-Rauschen beim Beenden in irgendeiner Suite.
- **Fensterlauf** mit echtem Ton fehlerlos.

**Offen / bekannte Punkte**
- **Feel-Abnahme steht aus, und diesmal ist sie der eigentliche Punkt.** Die 18 Zuordnungen sind
  nach Ordnernamen gewählt, **nicht nach Gehör** — belegt ist nur, dass jede Datei existiert und
  am richtigen Ereignis hängt. Ob `Voice/Voice9.wav` wie eine fallende Figur klingt, ob der
  Reif-Loop nervt, ob -9 dB für die Musik stimmt: das entscheidet Hören. Ändern heißt eine Zeile
  in der Tabelle `SOUNDS` und ein Tool-Lauf — kein Code.
- **Der Reif-Loop hat eine Naht.** Er wird über `finished` neu angeworfen, weil das `loop_mode`
  in der `.import` des Packs liegt. Bei einem kurzen Summen sollte das nicht auffallen; fällt es
  auf, ist die Lösung die `.import` des Packs, nicht der Manager.
- **Keine Lautstärke-UI.** `set_bus_db` steht, aber im Spiel erreicht man es nicht — dieselbe
  Lage wie bei den drei Spielstand-Slots ohne Slot-Auswahl. Ein Optionsmenü hätte außerdem eine
  Persistenz nötig, die es noch nicht gibt: ein Spielstand ist der falsche Ort für eine
  Einstellung.
- **Nur ein gehaltener Klang.** Der Flüster-Layer für Korruptionsstufe 1 (offen seit Phase 5) ist
  damit **nicht** mehr durch fehlende Infrastruktur blockiert, braucht aber einen zweiten
  Loop-Platz, dessen Lautstärke an `Player.get_corruption()` hängt — und eine Entscheidung, die
  man hören muss.
- **Kein Kampfstück, keine Ambience, keine Schritte** — bewusst, siehe `docs/assets-todo.md`.
  Ein Kampfwechsel bräuchte einen Aggro-Zustand über alle Gegner eines Raums, den es nicht gibt.
- **Klang für den Raumwechsel selbst** fehlt (Tür auf/zu beim Betreten) — die `RoomExit` ist
  stumm, weil sie im ALTTP-Stil beim Reinlaufen auslöst und ein Klang dort schnell zur
  Belästigung wird. Gehört in die Abnahme.
- **Die zwei Engine-Zeilen beim Beenden** bleiben im normalen Spiellauf stehen (siehe oben). Sie
  sind erklärt und harmlos, aber sie stehen da.

## Phase 11 — Hülle: Hauptmenü, Slot-Auswahl, Optionen, Pause (abgeschlossen, 2026-09-03)

Bis Phase 10 startete das Spiel **mitten im Dungeon**. `scenes/main.tscn` war `run/main_scene`
und baute sich in `_ready` selbst den Startraum — es gab nie einen Zustand „Spiel läuft nicht".
Zwei Dinge waren dadurch gebaut, aber unerreichbar: die drei Spielstand-Slots aus Phase 9
(angelegt und adressierbar, aber ohne Auswahl-UI — der Spieler konnte nicht sehen, in welchen
sein Speicherpunkt schreibt) und `AudioManager.set_bus_db` aus Phase 10 (eine API ohne Regler).
Von den drei Kandidaten fiel die Wahl auf das Hauptmenü, weil es beide Löcher mit **einem**
Umbau schließt — dem, den Phase 9 ausdrücklich angekündigt und verschoben hatte: „eine eigene
Szene **vor** der persistenten Weltszene".

**Die Hierarchie: drei Schichten, jede wirft die darunter weg**

```
Boot (nie gewechselt)   Hauptmenue, Optionen, Pause — die Huelle
  +- WorldHost
       +- main.tscn     persistente Weltszene: Player, PartyManager, Overlays
            +- RoomHost
                 +- room_0N.tscn   vom RoomManager getauscht (Phase 8)
```

Phase 8 hat den Raum wegwerfbar gemacht, Phase 11 die Welt. `scenes/main.gd` heißt seither
`class_name World` und ist nicht mehr der Bootstrap, sondern etwas, das aufgebaut und wieder
freigegeben wird.

**Was steht**
- **`scenes/boot.tscn` / `boot.gd`** (`class_name Boot`) — neue `run/main_scene`. Hält
  `WorldHost`, `MainMenu`, `PauseMenu`, `OptionsMenu`; baut und verwirft die Weltszene, liest
  die Pausentaste und verteilt zwischen den drei Bildschirmen.
- **`World.enter_on_ready`** (`@export`, Default `true`) — betritt die Weltszene beim Aufbau
  selbst den Startraum? Die Hülle setzt es **vor** `add_child` auf `false` und entscheidet dann
  zwischen Startraum und Spielstand.
- **`ui/main_menu/`** — Dateiauswahl über die drei Slots (voller lädt, leerer beginnt dort),
  plus Optionen und Beenden. Löschen mit Inline-Bestätigung auf der Zeile.
- **`ui/options_menu/`** — ein Regler je Bus (Gesamt / Musik / Effekte) plus Zurück. Zwei
  Aufrufer (Hauptmenü, Pausenmenü), ein Bildschirm.
- **`ui/pause_menu/`** — Weiter / Optionen / Hauptmenü.
- **`globals/settings_manager.gd`** (Autoload `Settings`) — Lautstärkestufen 0..10 je Bus in
  `user://settings.cfg`. Vierter Besitzer neben RoomManager (Raum), SaveManager (Fortschritt),
  AudioManager (Ton).
- **Input-Action `pause`** (Escape + Gamepad Start) — im Spiel Pause, in jedem Menü „zurück".
  Angelegt wie alles andere über `tools/add_input_actions.gd`.
- **Game-Over-Menü bekommt einen dritten Eintrag** („Hauptmenü") und das Signal
  `menu_requested`; `World` reicht es als `main_menu_requested` nach oben.
- **`RoomManager.clear_fade()`** — die Transitions-Blende lebt im Autoload und überlebt jede
  Welt; wer eine wegwirft, muss sie zurücksetzen.
- **Zwei neue Einträge in den Audio-Tabellen:** Musik `title`
  (`Musics/1 - Adventure Begin.ogg`) und Effekt `menu_back` (`Sounds/Menu/Cancel.wav`) —
  eine Zeile in `tools/build_audio_resources.gd`, kein Code.
- **Debug-Overlay** zeigt die drei Pegel in Prozent und markiert einen eingefrorenen Raum mit
  `PAUSE` — ein stehender Raum sieht auf dem Bild sonst wie ein hängendes Spiel aus.

**Entscheidungen und ihre Gründe**
- *Die Menüs liegen in der Hülle, nicht in der Weltszene.* Das Hauptmenü muss **ohne** Welt
  existieren, und Options- und Pausenbildschirm teilen sich einen Bildschirm mit ihm. Das
  Game-Over-Menü bleibt dagegen in der Welt — es gehört zum Sterben, nicht zur Hülle.
- *Zurück ins Hauptmenü wirft die Welt weg, statt sie anzuhalten.* Ein Spiel, das hinter dem
  Menü weiterlebte, wäre ein zweiter Weltzustand neben dem Spielstand, und die Frage „welcher
  gilt" hat keine gute Antwort. Freigegeben wird mit `remove_child` **plus** `queue_free`
  (Muster aus `RoomManager._swap_room`: `queue_free` allein ließe den Node bis zum Frame-Ende
  im Baum, und der RoomManager löst seine Referenzen erst am `tree_exiting` des RoomHost).
- *`enter_on_ready` behält den Default `true`.* Die sechs Suiten davor hängen `main.tscn` als
  Kind unter sich und wollen sofort eine laufende Welt — sie prüfen den Raum, nicht das Menü.
  Genau das Muster von `restart_on_wipe` aus Phase 7; die Alternative wäre gewesen, sechs
  Testsuiten für eine Zeile umzubauen.
- *Kein Menü liest in demselben Frame denselben Tastendruck.* Wer einen anderen Bildschirm
  aufmacht, blendet seinen eigenen aus (`close()`), und jeder hat nach `open()` **einen Frame
  Schonzeit** (`_grace`). Ohne die schlüge der `pause`-Druck, der die Optionen öffnet, im
  Pausenmenü gleich noch einmal zu — beide lesen dasselbe `just_pressed`.
- *Hauptmenü = Dateiauswahl (ALTTP), nicht „Neues Spiel / Laden / Optionen".* Ein voller Slot
  lädt, ein leerer beginnt dort. Damit ist der Slot **immer bewusst gewählt** — bis Phase 10
  schrieb jeder Speicherpunkt in `SaveManager.active_slot`, und welcher das war, sah man nirgends.
- *Löschen gehört ins Hauptmenü, sonst ist die Auswahl eine Sackgasse.* Ohne Löschen ließe sich
  nach drei Spielständen kein neues Spiel mehr beginnen, weil ein voller Slot immer lädt. Die
  Bestätigung liegt **auf der Zeile selbst** (Q lädt scharf, F löscht, Q bricht ab, Wegbewegen
  entschärft) statt in einem eigenen Dialog: ein Modus weniger, und die scharfe Löschung ist
  immer da zu sehen, wo sie wirkt.
- *Ein leerer Slot ist hier anwählbar und darum nicht grau* — anders als im Game-Over-Menü, wo
  derselbe leere Slot nichts zu laden hat. Dieselbe Farbe für zwei verschiedene Aussagen wäre
  falsch.
- *Der dritte Game-Over-Eintrag ist keine Bequemlichkeit.* Ohne ihn wäre der Tod eine Sackgasse:
  man käme nur in den Speicherstand oder einen Neuanfang, nie in einen anderen Slot und nie an
  die Optionen — denn das Pausenmenü geht im Game Over bewusst nicht auf.
- *Die Pause friert mit den Mitteln aus Phase 9:* `RoomManager.set_room_frozen` (`process_mode`
  am `RoomHost`) plus `Player.set_input_locked`, gebündelt in `World.set_paused`. Ausdrücklich
  **nicht** `get_tree().paused` und nicht `Engine.time_scale` — dasselbe Argument wie beim
  HitstopManager: es trifft genau die gewünschten Nodes und lässt UI, Blenden und Ton in Ruhe.
- *Die Musik läuft in der Pause weiter.* Sonst wäre der Musikregler nicht zu hören, während man
  ihn zieht. Der Reif räumt seinen gehaltenen Klang bei der Input-Sperre selbst auf (Phase 10) —
  ein Summen durch die Pause gibt es damit von selbst nicht.
- *Die Pausentaste wird in der Hülle gelesen, nicht in der Welt.* Nur die Hülle weiß, ob gerade
  ein anderer Bildschirm offen ist. Sie geht nicht auf während einer Blende
  (`RoomManager.is_transitioning`) und nicht im Game Over (`World.accepts_pause`).
- *Einstellungen liegen NICHT im Spielstand.* Eine Lautstärke gehört dem Gerät, nicht dem
  Durchlauf — wer Slot 2 lädt, will nicht die Pegel von Slot 1.
- *`ConfigFile` statt JSON wie `SaveData` (Phase 9).* Es ist die Einrichtung der Engine, von
  Hand lesbar (INI), und `get_value(section, key, default)` trägt ein später dazukommendes Feld
  von selbst — genau die Eigenschaft, die in Phase 9 für JSON gesprochen hat. Eine
  Versionsnummer braucht sie nicht: eine unbekannte Datei kostet hier höchstens eine
  Lautstärke, während ein halb angewandter Spielstand ein kaputtes Spiel wäre.
- *Übernommen wird Schlüssel für Schlüssel* — und nur, was da ist und eine Zahl ist. Ein
  fehlender Schlüssel lässt den laufenden Wert stehen, statt ihn auf die Vorgabe zurückzusetzen;
  sonst risse eine halb geschriebene Datei die anderen Regler mit.
- *Der Pegel ist eine Stufe 0..10 und relativ zur Vorgabe.* Stufe 10 heißt „wie der Autor es
  gemischt hat" (Musik −9 dB aus dem generierten Bus-Layout), nicht „0 dB". Ein Regler, der
  absolute dB setzte, hätte beim ersten Griff die Mischung aus Phase 10 eingerissen. Stufe 0 ist
  `SILENT_DB` (−80), weil `linear_to_db(0.0)` −inf wäre.
- *Geschrieben wird bei jedem Schritt*, nicht erst beim Schließen des Menüs: drei Zeilen INI
  kosten nichts, und ein „dirty"-Merker wäre ein Zustand, den man falsch machen kann.
- *Die Regler zeigen Prozentzahlen, keinen Balken.* Der Standardfont ist nicht monospaced; ein
  aus `|` und Leerzeichen gebauter Balken wackelte bei jedem Schritt. Eingetragen in
  `docs/assets-todo.md` — mit einem Pixelfont wird eine Zahl zum Balken.

**Beim Bau aufgelaufen (und behoben)**
- *`ConfigFile.load` meldet bei Müll trotzdem `OK`.* Die erste Fassung von `load_from_disk()`
  prüfte den Rückgabewert und las danach jeden Schlüssel mit Default — eine kaputte Datei setzte
  damit **alle** Regler auf die Vorgabe zurück. Der Test hat es aufgedeckt (er erwartete einen
  Fehlschlag und bekam Erfolg). Jetzt entscheidet nicht der Rückgabewert, sondern
  `has_section_key` plus eine Typprüfung je Wert.
- *Ein laufender Abspieler beim Prozessende hinterlässt geleakte Playbacks* — die Zeilen aus
  Phase 10, dort an einem Ogg beobachtet, gelten genauso für WAV. Der Klang-Abschnitt der neuen
  Suite endete mit absichtlich noch laufenden Effekten; jetzt wartet er, bis der AudioServer sie
  losgelassen hat, statt die Zeilen als „harmlos" zu erklären.
- *`_on_world_exiting` setzt jetzt auch `_transitioning` zurück.* Keine Welt, kein Raumwechsel —
  ein stehengebliebenes Flag würde in der nächsten Welt jeden Wechsel schlucken.

**Verifikation (headless, `tests/phase11_sim.*`, 146/146 grün)**
- **Einstellungen:** drei Busse in fester Reihenfolge; Stufe 10 ist der Pegel des Mixes
  (Master 0 dB, Musik −9 dB) und steht so auch im AudioServer; halbe Stufe halbiert die
  Amplitude **relativ** dazu; Stufe 0 ist echte Stille; nach oben und unten geklemmt; derselbe
  Wert meldet kein `changed`; die Datei liegt auf Platte und die Werte überleben den Weg
  hinaus und zurück; eine kaputte Datei lässt die laufenden Werte stehen; ein unbrauchbarer
  Wert wird übersprungen, während der brauchbare daneben ankommt; ein fehlender Schlüssel
  ändert nichts; `reset()` stellt die Vorgabe wieder her.
- **Startzustand:** Hauptmenü offen und sichtbar, **keine Welt**, kein Raum gebunden, Titelstück
  läuft, alle drei Slots zeigen „leer"; die Pausentaste tut ohne Welt nichts; an beiden
  Listenrändern passiert nichts.
- **Neues Spiel in Slot 2:** `new_game_requested(2)`, Welt steht, Menü zu, aktiver Slot ist 2,
  Startraum betreten, Raummusik löst das Titelstück ab, Input frei, Spielzeit läuft.
- **Zurück ins Hauptmenü über die Pause:** Raum eingefroren und Input gesperrt, „Hauptmenü"
  gewählt → Welt weggeworfen **und abgemeldet**, Titelstück wieder da, die Blende des
  Raumwechsels ist klar, Slot 2 zeigt jetzt seine Kopfdaten und Slot 1 weiter „leer".
- **Laden:** `load_requested(2)`, Raum aus dem Spielstand, Input nach dem Aufbau frei.
- **Löschen:** Laden scharf machen, die Zeile fragt nach; Wegbewegen nimmt es zurück; zweiter
  Druck bricht ab; Bestätigen löscht den Slot, die Zeile zeigt „leer" und es wird **kein**
  Ladevorgang ausgelöst (der Druck galt der Löschung); ein leerer Slot hat nichts zu löschen;
  auf Optionen/Beenden wirkt es nicht.
- **Optionen:** aus dem Hauptmenü geöffnet blendet dieses aus; ein Regler je Bus plus Zurück;
  links senkt, rechts hebt, am Anschlag passiert nichts, der zweite Regler ist die Musik und
  lässt Master in Ruhe; links/rechts auf „Zurück" ist ein No-Op; nach dem Schließen ist das
  Hauptmenü wieder da — **auf dem Eintrag, den man gedrückt hat**.
- **Pause:** die Taste öffnet, der Raum steht (nachgewiesen daran, dass **das Skelett sich zehn
  Frames lang nicht bewegt**, nicht nur daran, dass ein Flag gesetzt ist), dieselbe Taste
  schließt wieder; aus der Pause in die Optionen: Pausenmenü aus, Raum steht weiter, Input
  bleibt gesperrt, **die Musik läuft**, der Regler wirkt; Escape führt zurück ins Pausenmenü auf
  denselben Eintrag; „Weiter" lässt die Welt wieder laufen.
- **Wann die Pause nicht aufgeht:** nicht während einer Blende, nicht bei ausgefallener Party,
  nicht über dem Game-Over-Menü.
- **Game-Over-Menü:** bei leerem Slot ist „Neu beginnen" vorausgewählt, „Hauptmenü" ist
  erreichbar und der letzte Eintrag; Bestätigen wirft die Welt weg, öffnet das Hauptmenü, startet
  das Titelstück und lässt **keinen Jingle** darunter weiterlaufen.
- **Klang (echter Ton, nur WAV):** Navigation klickt, am Listenrand bleibt es still, Löschen auf
  einem leeren Slot bleibt still, Bestätigen klickt, der Regler klickt beim Verstellen (auf dem
  SFX-Bus — wer die Effekte leiser zieht, hört das Klicken leiser werden), Zurück klingt nach
  Abbruch.
- **Der Test räumt auf** (eigenes Save-Verzeichnis `user://saves_phase11` **und** eigene
  `settings_phase11.cfg`, beide am Ende weg) und hat eine **Notbremse**
  (`FRAME_BUDGET = 7000`), aus demselben Grund wie phase9/phase10_sim.
- **Regression:** phase4 (27), phase5 (57), phase6 (28), phase7 (37), phase8 (84), phase9 (135),
  phase10 (120) alle weiterhin „ALLES GRUEN" — zusammen mit phase11 (146) **634 Checks**,
  0 Fehler. `phase10_sim` musste an einer Stelle nachziehen: der untere Rand des Game-Over-Menüs
  liegt seit dem dritten Eintrag eine Zeile tiefer.
- **Fensterlauf** fehlerfrei.

**Was in Phase 9 und 10 offen war und jetzt zu ist**
- „Die drei Slots sind angelegt und adressierbar, eine Slot-Auswahl-UI fehlt" (Phase 9) — steht.
- „Keine Lautstärke-UI. `set_bus_db` steht, aber im Spiel erreicht man es nicht" (Phase 10) —
  steht, samt der Persistenz, die Phase 10 dafür als Voraussetzung genannt hatte.
- „Ein Hauptmenü wäre eine eigene Szene vor der persistenten Weltszene und damit ein eigener
  Umbau" (Phase 9) — der Umbau ist gemacht.

**Offen / bekannte Punkte**
- **Die Feel-Abnahme des Mixes steht weiter aus** und ist jetzt bequemer geworden, nicht
  erledigt: die Regler sind da, die 18 Klang-Zuordnungen sind immer noch nach Ordnernamen
  gewählt und nicht nach Gehör. Neu dazu kommt das Titelstück, das ebenfalls ungehört gewählt
  ist. Ändern heißt weiterhin eine Zeile in `SOUNDS`/`MUSIC` plus ein Tool-Lauf.
- **Alle vier Menüs laufen auf Godots Standardfont.** Mit Phase 11 ist das kein Kosmetikpunkt
  mehr: das Hauptmenü ist der **erste** Bildschirm des Spiels und besteht ausschließlich aus
  Text. Siehe `docs/assets-todo.md`.
- **Kein Titelbild, kein Logo** — nur ein Schriftzug auf dunkler Fläche. Im Pack liegt nichts
  Passendes; ein Titelbild wäre eigene Kunst, keine Pack-Auswahl.
- **Die Optionen kennen nur Lautstärke.** Fenstermodus, Auflösung und Tastenbelegung fehlen —
  die Belegung wäre der größte Brocken, weil `tools/add_input_actions.gd` bisher die einzige
  Quelle der Belegung ist und beim Lauf die komplette Map überschreibt. Eine UI, die daneben
  schreibt, bräuchte erst eine Entscheidung, wem die Belegung gehört.
- **Kein „Fortsetzen" im Hauptmenü** über den zuletzt benutzten Slot hinaus — es gibt keinen,
  weil `active_slot` nicht persistiert wird. Beim Start steht die Auswahl immer auf Slot 1.
- **Die Pause hat kein eigenes Bild.** Sie legt eine halbtransparente Fläche über den stehenden
  Raum; ein unscharf gezeichneter Hintergrund oder ein Rahmen wäre der nächste Schritt.
- **Beenden nur aus dem Hauptmenü.** Aus der Pause führt der Weg über „Hauptmenü" — bewusst,
  damit ein Fehlgriff nicht das Spiel schließt.
- **Die zwei Engine-Zeilen beim Beenden** (Phase 10) bleiben im normalen Spiellauf stehen,
  jetzt ausgelöst vom Titelstück. Sie sind erklärt und harmlos, aber sie stehen da.

## Phase 12 — Raum-Inhalt: Kampfkammer und Gruftkammer (abgeschlossen, 2026-09-03)

Seit Phase 8 gibt es drei Räume, aber nur einer war einer. **A** trägt das Platte-Tür-Puzzle aus
Phase 6; **B** und **C** waren leere 20×12-Rechtecke mit je einem Skelett darin, ausdrücklich als
Testgerüst für den Raumwechsel gebaut und in `tools/build_room_resources.gd` auch so kommentiert
(„Bewusst SCHLICHTE Kammern […], sie sind Testgerüst für den Raumwechsel, nicht Content").
Zehn Phasen lang sind Verben dazugekommen — Angriff, Dash, Reif, Figurenwechsel, Gewicht,
Speichern —, und ab Raum A traf keines davon mehr auf einen Raum, der etwas von ihm wollte.
Diese Phase gibt B und C einen Grund.

**Was steht**

- **Das Bau-Tool kennt Wandinseln.** `tools/build_room_resources.gd` hat pro Raum ein neues Feld
  `blocks`: Rechtecke, die **nach** `walkable`/`cells` wieder abgezogen werden. Vorher konnte ein
  Raum nur ein Rechteck (oder mehrere aneinandergelegte) sein — eine Säule mitten in einer Fläche
  hätte man als vier Rechtecke um sie herum formulieren müssen. Die ASCII-Karte im Tool-Output
  zeigt sie als `o`.
- **Raum B = Kampfkammer** (20×12, unverändert **ein** Bildschirm): vier 2×2-Säulen, **drei**
  Skelette, und ein **Riegel** vor dem Ausgang nach C. Der Riegel fährt hoch, sobald keiner mehr
  steht — vorher kommt man nicht weiter. Der Weg zurück nach A bleibt offen.
- **Raum C = Gruftkammer** (24×16): Vorraum, ein 2 Tiles hoher Korridor, dahinter die Halle mit
  zwei Säulen, dem **Wächter** und — hinter ihm — dem Speicherpunkt.
- **Der Wächter** ist keine neue Klasse: `actors/enemy/waechter.tscn` erbt von `skeleton.tscn`
  und tauscht zwei Dinge, ein `SpriteFrames` (SkeletonDemon aus dem Pack) und ein
  `TuningStats`-`.tres` (`enemy_waechter.tres`: 9 Health, Schaden 2, langsamer, längerer
  Telegraph, `knockback_taken_scale = 0.35`). Er trägt die `persist_id` `skeleton_c` aus Phase 9
  und bleibt damit tot.
- **`tools/build_enemy_resources.gd`** baut die SpriteFrames **aller** Gegner aus dem Pack.
  `skeleton_frames.tres` war die letzte Resource im Projekt, die von Hand entstanden war; sie
  kommt jetzt aus dem Tool und ist dabei **Byte für Byte dieselbe** geblieben (nur die
  zufälligen Sub-Resource-IDs unterscheiden sich).
- **`Door.open_permanently()`** — dieselbe Tür wie in Raum 01, nur ohne Zähler.
- **`Skeleton` liest `knockback_taken_scale`.** Das Feld lag seit Phase 4 in `TuningStats`, aber
  nur der Player fragte es.

**Entscheidungen**

- *B bleibt ein Bildschirm.* 20×12 = 320×192 px, also genau der Viewport. Ein größerer Raum hätte
  gescrollt, und beim Scrollen steht ein zuschlagender Gegner außerhalb des Bildes. Die Priorität
  des Projekts heißt Kampfgefühl, und das fängt bei „man sieht alle drei" an. Gewachsen ist
  stattdessen **C** (24×16) — der Raum, in dem nicht gekämpft wird.
- *Der Riegel ist der Grund, warum der Kampf zählt.* Bis hierher konnte man jeden Gegner stehen
  lassen und weiterlaufen; der Kampf war Dekoration. Genau **eine** Stelle in der Kette macht ihn
  zur Bedingung. Der Weg **zurück** bleibt offen — eingesperrt wird niemand, Rückzug bleibt ein
  Zug.
- *Der Riegel ist eine `Door`, kein neuer Prop.* Eine Tür ist ein solider Körper auf
  `environment`, der auf ein Ereignis hin aus dem Weg geht. Ob das Ereignis ein Gewicht (Raum 01)
  oder der letzte gefallene Gegner ist, ändert daran nichts. Der Unterschied ist eine Zeile: der
  Zähler läuft nicht.
- *Die Öffnung ist zwei Tiles hoch — und das ist kein Detail.* Die Kollisionsbox des Spielers
  sitzt 4 px **unter** seinem Ursprung (Füße). In einer ein Tile hohen Öffnung bleibt ihm damit
  ein 8 px schmales Fenster gültiger Positionen, und wer auf der Mittellinie der Kachel steht,
  streift schon die Wand darunter. Eine Tür, durch die man zielen muss, ist keine Tür. Zwei
  Kacheln Öffnung heißen zwei `Door`-Nodes, und der Raum öffnet einfach **alle** seine Türen —
  kein Sonderfall im Code, eine Schleife.
- *Der geräumte Raum steht im Spielstand, die Gegner nicht.* Die drei Skelette bekommen bewusst
  **keine** `persist_id`: normale Gegner respawnen, das ist die Regel seit Phase 8. Der Riegel
  dagegen merkt sich den geräumten Raum als Welt-Flag `gate:room_02` (Phase-9-Mechanik, keine
  neue Infrastruktur). Sonst wäre die Rückkehr aus C ein zweiter Pflichtkampf am selben Riegel —
  eine Strafe fürs Zurückgehen.
- *Der Speicherpunkt liegt hinter dem Wächter.* Das ist die ganze Aussage von Raum C: sichern
  kostet einmal etwas. Vorher stand er frei in der Kammer herum.
- *Eine neue Gegnerart ist ein Tool-Eintrag plus ein `.tres`.* Dieselbe Regel, die seit Phase 4
  für Figuren gilt (`FigureProfile`). Darum die geerbte Szene und das Tabellen-Tool statt einer
  zweiten Handarbeit an einer `.tres`.
- *Der Wächter ist nicht eingefärbt, sondern hat ein eigenes Sheet.* Der naheliegende Weg wäre
  ein `modulate` auf dem Sprite gewesen — er hält keinen Angriff durch: `states/telegraph.gd` und
  `states/hurt.gd` setzen `sprite.modulate` bei jedem Blinken auf Weiß zurück. Nur der Alpha-Kanal
  überlebt (den bespielt die Hurtbox), die Farbe nicht.
- *`knockback_taken_scale` gilt jetzt auch für Gegner.* Ohne das wäre der Wächter nur „ein
  Skelett mit mehr Health"; mit ihm ist er einer, den man nicht einfach in die Ecke prügelt. Der
  Default 1.0 lässt jeden bisherigen Gegner unverändert — die Zeile ist additiv, kein
  Feel-Eingriff in Bestehendes.
- *Säulen sind klein und konvex.* Die Skelette haben kein Pathfinding (`move_dir` zielt direkt
  auf den Spieler); `move_and_slide` lässt sie an einer konvexen Ecke entlangrutschen und wieder
  herumkommen. Eine konkave Nische wäre eine Falle für die KI — die gibt es darum nicht.
- *Raum A wurde nicht angefasst.* Die Puzzle-Zahl aus Phase 6 (Platte→Tür = 304 px gegen
  `open_frames`, Zwerg- und Kurier-Reichweite) hängt an Positionen und Geometrie; sie steht auch
  hier unverändert.

**Beim Bau aufgelaufen (und behoben)**

- *Die erste Fassung des Riegel-Gangs war ein Tile hoch* — und der Test kam nicht hindurch: der
  Spieler blieb auch bei offenem Riegel hängen, `test_move` meldete auf der Mittellinie der
  Kachel eine Kollision. Ursache war nicht der Riegel, sondern der 4-px-Versatz der
  Kollisionsbox (siehe oben). Dass Raum 01 mit seiner ein Tile hohen Türöffnung trotzdem
  funktioniert, liegt daran, dass der Korridor dahinter zwei Tiles hoch ist und ein Mensch
  automatisch nach oben ausweicht — headless tut das niemand. Die Öffnung ist jetzt zwei Tiles
  hoch, und der Test läuft die Strecke **zu Fuß** ab, statt sie nur zu behaupten.
- *`skeleton_frames.tres` neu zu bauen war der Lackmustest für das Tool.* Der Vergleich
  vorher/nachher (Sub-Resource-IDs normalisiert) ist leer — das Tool reproduziert die Handarbeit
  exakt, also ist auch das zweite Sheet nach denselben Regeln gebaut.

**Verifikation (headless, `tests/phase12_sim.*`, 71/71 grün)**

- **Geometrie:** B misst 20×12 (= 320×192 px, ein Bildschirm), C misst 24×16 (384×256); die
  Kamera-Limits folgen beiden. Gefragt wird die **generierte `Walls`-Ebene**, nicht die
  Rechteck-Tabelle im Tool: Säulen stehen, die Mitte ist frei, der Riegel-Gang ist zugemauert
  und **genau zwei Zeilen** sind offen; Cs Korridor ist zwei Tiles hoch und darüber wie darunter
  Wand.
- **Aufstellung in B:** drei Gegner, alle drei leben, **keiner** ist persistent; der Riegel ist
  zwei Kacheln hoch, steht, ist **wirklich solide** (`test_move` vom Spawn `from_c` nach Osten),
  der Ausgang liegt dahinter, der Weg zurück nach A ist frei.
- **Der Riegel:** nach dem ersten und zweiten Toten bleibt er zu, nach dem dritten öffnet er —
  **beide** Kacheln —, bleibt offen (kein Zähler, auch 90 Frames später), setzt das Welt-Flag,
  und der Spieler **läuft** anschließend zu Fuß hinaus und steht in C (26 Frames).
- **Der Wächter:** eigene Stats (9 Health, Schaden 2, längerer Telegraph), eigenes Sheet aus dem
  Pack-Ordner `SkeletonDemon`, **dieselben 13 Animationen** wie das Skelett (inklusive des
  richtungslosen `dead`, an dem `states/dead.gd` hängt), `persist_id` gesetzt; er steht hinter
  dem Korridor und **vor** dem Speicherpunkt, der Spawn `save_c` liegt beim Punkt. 200 px/s
  Knockback werden bei ihm zu 70.
- **Rückkehr nach B:** der Riegel steht schon **beim Betreten** offen (nicht erst nach einem
  Frame), der Raum gilt weiter als geräumt, die drei Skelette sind zurück, und der Spawn `from_c`
  liegt im Raum und nicht in der Tasche hinter dem Riegel.
- **Spielstand:** Slot schreiben → „Neu beginnen" räumt das Flag ab und der Riegel ist wieder zu
  → Laden bringt Raum, Flag und offenen Riegel zurück.
- **Nichts steht in einer Wand:** für A, B und C wird **jedes** Kind des Raums (Spawn-Punkte,
  Türen, Gegner, Platte, Speicherpunkt) gegen die Wand-Ebene geprüft. Das ist der Fehler, der
  beim Verschieben von Layouts als erstes passiert und headless sonst nie auffällt.
- **Regression:** phase4 (27), phase5 (57), phase6 (28), phase7 (37), phase8 (84), phase9 (135),
  phase10 (120), phase11 (146) alle weiterhin „ALLES GRUEN" — zusammen mit phase12 (71)
  **705 Checks**, 0 Fehler. `phase9_sim` musste zwei Stellen nachziehen: der Gegner in C heißt
  jetzt `Waechter`, und der Spawn `save_c` liegt an einer anderen Stelle des größeren Raums.
- **Fensterlauf** fehlerfrei (12 s, kein stderr).

**Was vorher offen war und jetzt zu ist**

- „Raum-Inhalt statt Testgerüst (B und C sind bewusst Gerüst, kein Content)" (Phase 10/11) — B
  und C sind Räume mit einer Aufgabe.
- „Ein Flag-System für Bosse/Quest-Kills kommt mit dem Speichern" (Phase 8) — steht seit Phase 9
  und wird hier zum ersten Mal für etwas anderes als einen Kill benutzt.

**Offen / bekannte Punkte**

- **Der Mix ist weiterhin nicht abgenommen** (Phase 10/11). Neu dazu: der Riegel benutzt den
  Behelfs-Türklang aus Phase 10, jetzt an einer Stelle, an der er **doppelt** ausgelöst wird
  (zwei Kacheln) und nur durch die Dedup-Regel des AudioManagers einfach klingt.
- **Kein Kampfstück in B.** `music_id` steht pro Raum bereit und `17 - Fight.ogg` liegt im Pack,
  aber ein Wechsel „Kampf läuft / Kampf vorbei" bräuchte einen Aggro-Zustand über alle Gegner
  eines Raums. Den gibt es nicht — und der Riegel wäre jetzt der natürliche Aufhänger dafür.
- **Der Riegel hat kein eigenes Sprite** — er zeigt dieselbe Tür-Kachel wie Raum 01. Ein
  Fallgitter, das sichtbar herunter- und hochfährt, wäre die richtige Lesbarkeit; im Pack liegt
  dafür nichts Geprüftes.
- **Drei Skelette sind eine Zahl ohne Abnahme.** Ob der Kampf in B mit Kurier und Zwerg fair,
  zäh oder trivial ist, entscheidet das Spielen. Die Stellschrauben sind die Positionen im
  `.tscn` und `enemy_skeleton.tres` — kein Code.
- **Der Wächter kämpft wie ein Skelett**, nur zäher: dieselbe FSM, dieselbe Reichweite, kein
  eigener Angriff. Ein zweiter Angriffs-State (Ausfallschritt, Flächenschlag) wäre der nächste
  Schritt, wenn C mehr sein soll als eine Hürde.
- **Kein Y-Sort, weiterhin.** Die Säulen sind flache 16×16-Blöcke ohne Oberkante wie die Wände;
  es gibt nichts zu sortieren. Sobald eine Säule höher wird als ein Tile, ändert sich das.
- **Kein Grund, nach C zu gehen, außer dem Speicherpunkt.** Die Kette endet dort. Was in einer
  Gruft am Ende steht — Schatz, Aufstieg, Boss —, ist eine Content-Entscheidung, keine
  technische.

## Nächste Phase
- **Phase 13** — noch nicht festgelegt. Offen sind weiterhin die **Feel-Abnahme des Mixes**
  (Regler seit Phase 11 da, 19 Klang-Zuordnungen weiter ungehört) und das **projektweite `Theme`
  mit Pixelfont** (das Spiel fängt mit einem Textbildschirm an). Neu dazu aus dieser Phase:
  **Kampfmusik am Riegel** (der Aufhänger dafür steht jetzt) und ein **zweiter Angriffs-State
  für den Wächter**. Erst nach Go des Users.
