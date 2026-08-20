# Projekt-Kickoff: "Grabgold"

Du bist Lead-Architekt für ein 2D-Action-RPG in **Godot 4**. Wir bauen in dieser Session **keinen** kompletten Titel, sondern einen **Vertical Slice**: ein Raum, eine Figur, ein Gegner — aber das Kampfgefühl muss sitzen.

## Regel Null

Bevor du irgendwas planst: prüfe die tatsächlich installierte Godot-Version (`godot --version`). Godot 4.3 hat `TileMap` durch `TileMapLayer` ersetzt, spätere Versionen bringen weitere API-Änderungen. Verlasse dich **nicht** auf Trainingswissen zur Godot-API — schau in die lokalen Docs oder die Klassendefinition. Rate nie eine Methodensignatur.

## Spielkonzept (Kurzfassung)

Top-down Action-RPG, ALTTP-Tempo, kein Dodge-Roll. Ensemble von 4 Figuren, aber **immer nur eine aktiv** — Schultertaste wechselt durch, die anderen despawnen. Kein Party-KI-Code, kein Pathfinding. Bewusste Scope-Entscheidung, nicht zu revidieren.

Kernmechanik ist der **Reif** (ein verfluchter Ring): Taste halten = kanalisieren. Solange gehalten: leichte Zeitdehnung, höherer Schaden, Phase-Dash durch Gegner hindurch. Fühlt sich hervorragend an — und lädt pro Sekunde Korruption auf. Die beste Mechanik im Spiel ist die, die den Spieler frisst.

Korruptionsstufen (eskalierendes Feedback):
1. Bildschirmränder entsättigen, Flüstern im Sound-Mix
2. Dash trägt gelegentlich weiter als eingegeben (minimaler Input-Drift — soll sich wie ein Bug anfühlen)
3. Figur schlägt sporadisch von selbst zu
4. Figurenwechsel gesperrt

Reif ist jederzeit weiterreichbar. Korruption baut sich extrem langsam ab. Der Spieler verteilt also Schaden auf seine Leute.

## Assets

Ich verwende ein **externes Asset-Pack** (itch.io / CC0 oder gekauft). Ich lege es selbst unter `assets/external/<packname>/` ab.

- **Lade nichts herunter und suche keine Packs.** Frag mich nach dem Pfad, wenn du ihn brauchst.
- **Interne Auflösung wird aus der Tile-Größe des Packs abgeleitet, nicht vorgegeben.** Inspiziere die Tile- und Sprite-Maße (`file`, Pillow, oder Sichtprüfung) und schlage mir eine passende Auflösung vor, die ganzzahlig auf 1080p skaliert. Richtwert: 15–25 sichtbare Tiles horizontal.
- **Frame-Aufteilung der Angriffsanimationen aus dem Pack auslesen** und die Tuning-Resource daran ausrichten — nicht umgekehrt. Wenn das Pack 4 Attack-Frames hat, hat Startup/Active/Recovery sich danach zu richten.
- Fehlt etwas im Pack (z. B. eine Richtung, ein Effekt), nutze ein **farbiges Rechteck als Platzhalter** und notiere es in `docs/assets-todo.md`. Male nichts nach.

Lege ab Tag eins `docs/credits.md` an: Pack-Name, Autor, Quelle, Lizenz, Attributionspflicht ja/nein. Nachträglich rekonstruieren ist die Hölle.

## Technische Leitplanken

**Look:** Stretch Mode `canvas_items`, **Integer Scaling an**, Texture Filter `Nearest`. Kein Sub-Pixel-Movement bei Sprites — sonst flimmert Pixelart. Y-Sort für Tiefenstaffelung.

**Combat-Architektur:**
- `CharacterBody2D` + `move_and_slide()` für alle Aktoren
- Hitboxes/Hurtboxes als `Area2D` auf **getrennten Collision Layers** (player_hurtbox, player_hitbox, enemy_hurtbox, enemy_hitbox, environment). Layer-Matrix früh festlegen und dokumentieren.
- Hitboxes werden **frame-genau** über `AnimationPlayer` Call-Method-Tracks an/ausgeschaltet — nicht per Timer.
- **Hitstop** nicht über `Engine.time_scale` (trifft auch UI und Partikel). Stattdessen: eigener `HitstopManager` als Autoload, der betroffene Nodes für N Frames pausiert.
- I-Frames als Zustand im Hurtbox-Node, mit sichtbarem Blink-Feedback.
- **Input-Buffer** für Angriff (~6 Frames) — ohne das fühlt sich jedes Actionspiel träge an.

**Feel-Tuning-Constants gehören in eine eigene `Resource` (`.tres`)**, nicht ins Skript. Attack-Startup, Active-Frames, Recovery, Knockback-Kurve, Hitstop-Dauer, I-Frame-Dauer, Beschleunigung, Reibung. Ich muss diese Werte hunderte Male ändern können, ohne Code anzufassen. Das ist die wichtigste Architekturentscheidung im Projekt.

**Debug-Overlay ab Tag eins:** Hitbox/Hurtbox-Visualisierung togglebar, aktuelle Frame-Nummer der Attack-Animation, aktueller State der State-Machine. Ohne das kann ich Combat-Feel nicht beurteilen.

## Persistenz

`docs/progress.md` nach **jedem** abgeschlossenen Schritt aktualisieren: erledigte Phasen, offene Punkte, Architekturentscheidungen mit Begründung, bekannte Probleme.

`CLAUDE.md` anlegen mit: Godot-Version, Ordnerstruktur, Collision-Layer-Matrix, Namenskonventionen, interne Auflösung, Verweis auf die Tuning-Resource.

## Subagent-Delegation

- **Opus** — Architektur: State-Machine-Design, Collision-Layer-Matrix, Struktur des Reif-/Korruptionssystems, Aufbau der Tuning-Resource. Schreibt keinen Produktionscode.
- **Sonnet** — Implementierung: GDScript-Umsetzung der von Opus festgelegten Struktur, Szenenaufbau, Debug-Overlay.
- **Haiku** — Review: Konventions-Checks, ungenutzte Variablen, fehlende Type Hints, Abweichungen von `CLAUDE.md`. Kein Refactoring auf eigene Faust.

Jeder Subagent bekommt **nur** die Dateien in den Kontext, die er braucht. Keine Repo-weiten Dumps.

## Phasenplan

Arbeite **strikt sequenziell**. Nach jeder Phase: Stopp, Zusammenfassung, warte auf mein Go.

| Phase | Inhalt | Fertig, wenn |
|---|---|---|
| **0** | Godot-Version prüfen, Asset-Pack inspizieren, Auflösung ableiten, Projekteinstellungen, Ordnerstruktur, `CLAUDE.md`, `docs/progress.md`, `docs/credits.md`, Collision-Layer-Matrix | Godot startet, ein Test-Tile ist pixelscharf und korrekt skaliert |
| **1** | Player-Controller: 8-Wege-Bewegung mit Beschleunigung/Reibung, State-Machine (idle/move/attack/hurt), Tuning-Resource, Sprite aus dem Pack angebunden | Figur bewegt sich, Animationen wechseln sauber |
| **2** | **Kampfgefühl.** Ein Angriff. Startup/Active/Recovery, Hitbox via AnimationPlayer, Hitstop, Knockback, I-Frames, Input-Buffer, Debug-Overlay | Ein einzelner Schlag gegen eine Trainingspuppe fühlt sich befriedigend an |
| **3** | Gegner mit Telegraph-Animation, einfache KI (kein Pathfinding: nur Approach/Attack/Retreat) | Ein Kampf ist lesbar und fair |
| **4** | Figurenwechsel: 2 Figuren mit unterschiedlichem Movement- und Angriffsgefühl (Kurier = schnell/schwach, Zwerg = langsam/kein Knockback) | Der Unterschied ist ohne HUD spürbar |
| **5** | Reif: Kanalisierung, Zeitdehnung, Phase-Dash, Korruptionszähler, Stufen 1–2 als Feedback | Die Mechanik verführt und beunruhigt gleichzeitig |
| **6** | Ein echter Raum mit TileMapLayer, Tür, Schalter — der Figurenwechsel wird zum Puzzle-Verb | Vertical Slice spielbar |

**Phase 2 ist der Flaschenhals.** Rechne mit vielen Iterationen. Wenn Phase 2 nicht sitzt, trägt der Rest nicht — dann lieber dort bleiben als weitergehen.

## Jetzt

Starte mit Phase 0. Prüfe zuerst die Godot-Version und frag mich nach dem Pfad zum Asset-Pack. Dann zeig mir **Auflösungsvorschlag, Ordnerstruktur und Collision-Layer-Matrix zur Freigabe** — bevor du Dateien anlegst.