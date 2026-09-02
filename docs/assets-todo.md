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
- [ ] **Fluestern im Sound-Mix (Korruptionsstufe 1, Phase 5)** — der zweite Teil des Stufe-1-Feedbacks
      fehlt noch. Umgesetzt ist nur die Vignette (`ui/corruption_overlay/`). Grund: das Projekt hat
      bislang **keinerlei Audio-Infrastruktur** — dafuer waeren Audio-Bus-Layout (eigener Bus fuer
      den Fluester-Layer, damit die Lautstaerke an die Korruption koppelbar ist), ein
      AudioStreamPlayer-Autoload und ein Loop-Setup noetig. Kandidaten liegen im Pack bereit:
      `Audio/Sounds/Magic & Skill/Strange.wav` und `Spirit.wav`, ergaenzend `Voice/Voice*.wav`
      (verfremdet) sowie `Musics/14 - Curse.ogg` als Unterbett.
- [ ] **Optionaler Kanal-Effekt fuer den Reif** — solange kanalisiert wird, gibt es aktuell kein
      Sprite-Feedback am Spieler (nur die Vignette ab Stufe 1). Kandidat im Pack:
      `FX/Magic/Aura/` bzw. `FX/Magic/Circle/`. Bewusst offen: erst nach der Feel-Abnahme
      entscheiden, ob der Kanal ueberhaupt ein eigenes Sprite braucht.
- [ ] **Knight hat kein Hit-Sheet** → hurt = Idle-Pose + Blink (wie beim Skelett). Kein Ersatz im
      Pack vorhanden; bleibt Platzhalter-Feedback.

## Platzhalter-Register

| Asset | Ersetzt durch | Phase | Status |
|---|---|---|---|
| `assets/placeholder/tile_16.png` | ersetzt durch `resources/tileset_room.tres` | 6 | **erledigt** (nicht mehr verwendet) |
| Tuer-Sprite = `TilesetDungeon.png` (0,0) | ggf. eigene Tuer mit Oeffnungs-Anim | 6 | Pack-Tile, offen = Sprite versteckt |
| Platte = `TilesetDungeon.png` (5,3)/(6,3) | ggf. deutlicheres Signal beim Ausloesen | 6 | Pack-Tile, rot -> blau |
| `assets/placeholder/dummy.png` | echter Gegner-Sprite aus Pack (Monster/NPC) | 3 | Platzhalter (Trainingsdummy) |
| Knight hurt-Pose (= Idle + Blink) | echte Hurt-Anim (im Pack nicht vorhanden) | 4 | Platzhalter-Feedback |
| Korruptionsstufe 1 = nur Vignette | + Fluester-Layer (Audio-Infrastruktur fehlt) | 5 | Feedback unvollstaendig |
| Phase-Dash ohne eigenes Sprite/FX | ggf. `FX/Magic/Aura` oder Smoke-Trail | 5 | kein Platzhalter noetig |
