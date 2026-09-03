# Assets-TODO — Grabgold

Fehlende/provisorische Assets. Regel: fehlt etwas, **farbiges Rechteck** als Platzhalter — nichts
nachmalen, nichts herunterladen.

## Abgeleitet aus Pack (Ninja Adventure, CC0) — erledigt

- [x] **Tile-Größe 16×16 bestätigt** (alle Tilesets sind 16er-Vielfache) → interne Auflösung
      **320×180 ×6 bleibt gültig**, keine Änderung an `project.godot` nötig.
- [x] **Attack-Frames abgeleitet:** NinjaGreen `Separate/Attack.png` = 4 Frames → `TuningStats`
      startup/active/recovery = 3/6/3 (4 Sprite-Frames @ 3 Engine-Frames).
- [x] **Spieler-SpriteFrames** gebaut: `resources/player_ninja_frames.tres` (16 Anims,
      idle/walk/attack/hurt × 4 Richtungen, 32×32).

## Offen / noch Platzhalter

- [x] **Hintergrund-Tile** — erledigt mit Phase 6. `scenes/main.tscn` kachelt kein
      `tile_16.png` mehr, der Boden kommt aus dem `TileMapLayer`-Raum. Gewaehlt wurden
      `TilesetInteriorFloor.png` (14,15) als Boden (dunkles Kopfsteinpflaster) und (1,7) als Wand
      (orangeroter Ziegel) — beide **empirisch** als voll deckend und selbst-nahtlos kachelbar
      belegt. `TilesetWallSimple.png` schied dabei aus: sieht wie ein Wandset aus, ist aber ein
      9-Slice-Rahmen mit transparenter Mitte.
- [ ] **Nur EIN Wand- und EIN Bodentile** (Phase 6) — keine Autotile-Terrains, keine Ecken/Kanten,
      keine Bodenvarianten. Der Boden wirkt dadurch repetitiv. Bewusste Entscheidung (ein
      Autotiler ist Umfang, der Slice priorisiert Kampfgefuehl); Material dafuer laege bereit:
      die 9-Slice-Rahmen in `Interior/TilesetWallSimple.png` und die Bodenvarianten im selben
      Sheet. Kein Platzhalter — es fehlt nichts, es ist nur sparsam.
- [x] **Left/Right-Spalten** (col2/col3) zur Laufzeit geprüft — **nicht gespiegelt**, Facing korrekt
      (User-Abnahme im Editor, 2026-08-20). Kein Tausch im Build-Tool nötig.
- [x] **Zwerg-Figur gewählt: Knight** (`Actor/Character/Knight/SeparateAnim/`, 16x16).
      Gegner (Phase 3) = Skelett aus `Monster/`.
- [ ] **Knight Links/Rechts** visuell bestätigen. Beleg bisher rein aus dem Sheet: `Idle` col2 ist
      der exakte Spiegel von col3, und im `Attack` zeigt die Waffen-Ausdehnung col2=links /
      col3=rechts. Falls im Spiel gespiegelt: `DIRS` in `tools/build_figure_resources.gd` tauschen.
- [ ] **Fluestern im Sound-Mix (Korruptionsstufe 1, Phase 5)** — weiterhin offen, aber nicht mehr
      blockiert. Der Grund von damals ("das Projekt hat keinerlei Audio-Infrastruktur") ist mit
      Phase 10 weg: Bus-Layout, `AudioManager`-Autoload und ein gehaltener Klang stehen. Was noch
      fehlt, ist **eine Entscheidung, die man hoeren muss**, und ein zweiter Loop-Platz: der
      `AudioManager` hat genau EINEN, und der gehoert dem kanalisierenden Reif. Ein
      korruptionsgekoppelter Fluester-Layer braucht einen eigenen Abspieler, dessen Lautstaerke
      an `Player.get_corruption()` haengt. Kandidaten unveraendert:
      `Audio/Sounds/Magic & Skill/Strange.wav` (in Phase 10 als `reif_compel` in Gebrauch) und
      `Spirit.wav` (als `reif_loop` in Gebrauch), ergaenzend `Voice/Voice*.wav` (verfremdet)
      sowie `Musics/14 - Curse.ogg` als Unterbett.
- [ ] **Kein Tuerklang im Pack** (Phase 10) — `Audio/Sounds/` hat nichts, was nach Tuer klingt.
      Behelf: `Hit & Impact/Impact3.wav` als schwerer Aufprall, beim Schliessen derselbe Klang
      mit Pitch 0,8 (`Door.CLOSE_PITCH`) — dieselbe Tuer, andere Richtung. Traegt, ist aber kein
      Stein auf Stein. Kein Ersatz im Pack vorhanden.
- [ ] **Die 18 Klangzuordnungen sind nach Ordnernamen gewaehlt, nicht nach Gehoer** (Phase 10).
      Belegt ist nur, dass jede Datei existiert, importiert ist und am richtigen Ereignis haengt
      (`tests/phase10_sim.tscn`). Ob `Voice/Voice9.wav` wirklich wie eine fallende Figur klingt
      und ob `Magic & Skill/Magic4.wav` eine neue Korruptionsstufe traegt, entscheidet die
      Feel-Abnahme. Aendern heisst: Zeile in der Tabelle `SOUNDS` in
      `tools/build_audio_resources.gd` tauschen, Tool laufen lassen — kein Code.
- [ ] **Keine Ambience und keine Fussschritte** (Phase 10) — bewusst. `Sounds/Ambient/` (Wind,
      Rain, River) und Schrittklaenge waeren ein Dauerbett, das man erst beurteilen kann, wenn
      die Raeume echter Inhalt sind statt Testgeruest. Fussschritte bruechten ausserdem einen
      Taktgeber im `Move`-State.
- [ ] **Nur zwei Musikstuecke** (Phase 10): `21 - Dungeon.ogg` (Raum A) und `40 - Crypt.ogg`
      (Raum B und C). Kein Kampfstueck, obwohl `17 - Fight.ogg` und `34 - Fight.ogg` bereitliegen
      — ein Kampfwechsel braucht einen Aggro-Zustand ueber alle Gegner eines Raums, und den gibt
      es nicht. `music_id` steht pro Raum bereit, ein drittes Stueck ist eine Zeile.
- [ ] **Optionaler Kanal-Effekt fuer den Reif** — solange kanalisiert wird, gibt es aktuell kein
      Sprite-Feedback am Spieler (nur die Vignette ab Stufe 1). Kandidat im Pack:
      `FX/Magic/Aura/` bzw. `FX/Magic/Circle/`. Bewusst offen: erst nach der Feel-Abnahme
      entscheiden, ob der Kanal ueberhaupt ein eigenes Sprite braucht.
- [ ] **Raum-Tuer (`RoomExit`, Phase 8) hat kein eigenes Sprite** — sie zeigt das alte
      Platzhalter-Tile `assets/placeholder/tile_16.png`, violett getoent. Bewusst Platzhalter statt
      geraten: die Tile-Auswahl in Phase 6 war empirisch belegt, und fuer einen Durchgang/Treppe
      liegt kein geprueftes Tile vor. Kandidaten zum Sichten: `TilesetDungeon.png` (Treppen- und
      Torfelder) sowie `Backgrounds/Tilesets/Interior/` fuer Tuerrahmen.
- [ ] **Speicherpunkt (`SavePoint`, Phase 9) hat kein eigenes Sprite** — er zeigt das
      Platzhalter-Tile `assets/placeholder/tile_16.png`, gold getoent, und leuchtet beim
      Speichern 24 Frames hell auf. Gleiche Begruendung wie bei der `RoomExit`: kein geprueftes
      Tile fuer Schrein/Statue/Feuerschale vorhanden, und geraten wird nicht. Kandidaten zum
      Sichten: `TilesetDungeon.png` (Statuen-/Altarfelder), `FX/Magic/Circle/` fuer einen
      Bodenkreis, `Items/` fuer eine Kerze oder Schale.
- [ ] **Alle Menues laufen auf Godots Standardfont** — `ui/game_over_menu/` (Phase 9) und seit
      Phase 11 auch `ui/main_menu/`, `ui/options_menu/` und `ui/pause_menu/` setzen nur Groessen
      (16/12 fuer Titel, 8 fuer die Eintraege). Bei 320x180 interner Auflösung ist der Vektorfont
      weich, waehrend alles andere Pixelkunst ist. Das Pack hat keinen Bitmap-Font; ein
      CC0-Pixelfont muesste **manuell** abgelegt werden (nichts herunterladen, siehe
      Kickoff-Regel) und dann als `Theme` fuer alle UI-Labels gelten, inklusive Debug-Overlay.
      **Mit Phase 11 ist das kein Kosmetikpunkt mehr:** das Hauptmenue ist der erste Bildschirm
      des Spiels, und er besteht ausschliesslich aus Text.
- [ ] **Die Lautstaerkeregler zeigen eine Zahl, keinen Balken** (`ui/options_menu/`) — bewusst:
      der Standardfont ist nicht monospaced, ein aus `|` und Leerzeichen gebauter Balken wackelt
      bei jedem Schritt. Mit einem Pixelfont (Punkt darueber) oder einer 1-px-`ColorRect`-Reihe
      wird daraus ein Balken; vorher ist eine Zahl ehrlicher als ein schiefer Balken.
- [ ] **Das Hauptmenue hat kein Titelbild und kein Logo** — nur der Schriftzug „GRABGOLD" auf
      einer dunklen Flaeche. Im Pack liegt nichts Passendes (`Backgrounds/` sind Tilesets, keine
      Bildschirme); ein Titelbild ist eigene Kunst, nicht Pack-Auswahl. Bewusst offen.
- [ ] **Knight hat kein Hit-Sheet** → hurt = Idle-Pose + Blink (wie beim Skelett). Kein Ersatz im
      Pack vorhanden; bleibt Platzhalter-Feedback.

## Platzhalter-Register

| Asset | Ersetzt durch | Phase | Status |
|---|---|---|---|
| `assets/placeholder/tile_16.png` | als Boden ersetzt durch `resources/tileset_room.tres` | 6 | Boden erledigt; dient ab Phase 8 wieder als `RoomExit`-Platzhalter |
| Tuer-Sprite = `TilesetDungeon.png` (0,0) | ggf. eigene Tuer mit Oeffnungs-Anim | 6 | Pack-Tile, offen = Sprite versteckt |
| Platte = `TilesetDungeon.png` (5,3)/(6,3) | ggf. deutlicheres Signal beim Ausloesen | 6 | Pack-Tile, rot -> blau |
| `assets/placeholder/dummy.png` | echter Gegner-Sprite aus Pack (Monster/NPC) | 3 | Platzhalter (Trainingsdummy) |
| Knight hurt-Pose (= Idle + Blink) | echte Hurt-Anim (im Pack nicht vorhanden) | 4 | Platzhalter-Feedback |
| Korruptionsstufe 1 = nur Vignette | + Fluester-Layer (Audio-Infrastruktur fehlt) | 5 | Feedback unvollstaendig |
| Phase-Dash ohne eigenes Sprite/FX | ggf. `FX/Magic/Aura` oder Smoke-Trail | 5 | kein Platzhalter noetig |
| `RoomExit` = `tile_16.png` violett getoent | Treppe/Durchgang aus `TilesetDungeon.png` | 8 | Platzhalter |
| `SavePoint` = `tile_16.png` gold getoent | Schrein/Altar aus `TilesetDungeon.png` | 9 | Platzhalter |
| Game-Over-Menue mit Standardfont | CC0-Pixelfont als projektweites `Theme` | 9 | Platzhalter |
| Tuerklang = `Hit & Impact/Impact3.wav` (+ Pitch 0,8 zum Schliessen) | echter Stein-/Torklang (im Pack nicht vorhanden) | 10 | Behelf |
| 18 Klang-IDs nach Ordnernamen gewaehlt | Auswahl nach Gehoer in der Feel-Abnahme | 10 | ungehoert |
| Titelstueck = `Musics/1 - Adventure Begin.ogg` | Auswahl nach Gehoer (Feel-Abnahme) | 11 | ungehoert |
| Hauptmenue = Schriftzug auf dunkler Flaeche | Titelbild/Logo (eigene Kunst, nicht im Pack) | 11 | offen |
| Lautstaerkeregler zeigen Prozentzahlen | Balken, sobald ein Pixelfont da ist | 11 | Behelf |
| Korruptionsstufe 1 = nur Vignette | + Fluester-Layer (Infrastruktur steht ab Phase 10, zweiter Loop-Platz fehlt) | 5/10 | Feedback unvollstaendig |
