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

- [ ] **Hintergrund-Tile** in `scenes/main.tscn` ist noch der generierte `tile_16.png`.
      Echtes Terrain kommt mit dem `TileMapLayer`-Raum in **Phase 6** (TilesetFloor/Field aus dem Pack).
- [x] **Left/Right-Spalten** (col2/col3) zur Laufzeit geprüft — **nicht gespiegelt**, Facing korrekt
      (User-Abnahme im Editor, 2026-08-20). Kein Tausch im Build-Tool nötig.
- [x] **Zwerg-Figur gewählt: Knight** (`Actor/Character/Knight/SeparateAnim/`, 16x16).
      Gegner (Phase 3) = Skelett aus `Monster/`.
- [ ] **Knight Links/Rechts** visuell bestätigen. Beleg bisher rein aus dem Sheet: `Idle` col2 ist
      der exakte Spiegel von col3, und im `Attack` zeigt die Waffen-Ausdehnung col2=links /
      col3=rechts. Falls im Spiel gespiegelt: `DIRS` in `tools/build_figure_resources.gd` tauschen.
- [ ] **Knight hat kein Hit-Sheet** → hurt = Idle-Pose + Blink (wie beim Skelett). Kein Ersatz im
      Pack vorhanden; bleibt Platzhalter-Feedback.

## Platzhalter-Register

| Asset | Ersetzt durch | Phase | Status |
|---|---|---|---|
| `assets/placeholder/tile_16.png` | echtes Terrain-Tile (TileMapLayer) | 6 | Platzhalter (Boden) |
| `assets/placeholder/dummy.png` | echter Gegner-Sprite aus Pack (Monster/NPC) | 3 | Platzhalter (Trainingsdummy) |
| Knight hurt-Pose (= Idle + Blink) | echte Hurt-Anim (im Pack nicht vorhanden) | 4 | Platzhalter-Feedback |
