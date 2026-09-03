extends SceneTree
## Baut die Audio-Resources (Phase 10). Nie von Hand editieren, was hier herauskommt:
##
##   * `res://resources/default_bus_layout.tres` — Busse Master / Music / SFX. Ein
##     `AudioBusLayout` hat KEINE skriptbaren Properties (gegen die Klassen-DB geprueft: die
##     Klasse ist leer, alles laeuft ueber interne `bus/N/...`-Keys). Er ist damit gar nicht
##     sinnvoll von Hand schreibbar und muss vom `AudioServer` erzeugt werden.
##   * `res://resources/audio_bank.tres` — die Tabellen `SOUNDS` und `MUSIC` unten als
##     `AudioBank`. Das ist die EINZIGE Stelle, an der "Spielereignis -> Datei im Pack" steht.
##
## Aufruf (CLAUDE.md > Engine & Aufruf):
##   $GODOT --headless --path . --script res://tools/build_audio_resources.gd
##
## Idempotent: mehrfacher Lauf ergibt dieselben Dateien. Setzt ausserdem
## `audio/buses/default_bus_layout` in den ProjectSettings (per API, wie `add_input_actions.gd`).

const PACK := "res://assets/external/Ninja Adventure - Asset Pack/Audio/"

const BANK_PATH := "res://resources/audio_bank.tres"
const LAYOUT_PATH := "res://resources/default_bus_layout.tres"

## Busse: Name -> Vorgabepegel in dB. Master existiert immer (Index 0), die beiden anderen
## senden auf ihn. Musik liegt unter den Effekten — ein Trefferklang muss durch das Stueck
## kommen, nicht mit ihm um denselben Platz kaempfen.
##
## Der Pegel steht HIER und nicht im `AudioManager`: das Layout ist die eine Wahrheit ueber die
## Vorgabe. Zur Laufzeit verstellbar bleibt er trotzdem (`AudioManager.set_bus_db`) — ein
## kuenftiges Optionsmenue schreibt dort hinein, nicht in diese Datei.
const BUSES: Dictionary = {
	&"Music": -9.0,
	&"SFX": 0.0,
}

## SFX: Ereignis-ID -> Dateien im Pack (relativ zu PACK). Mehrere Dateien = Variation, der
## AudioManager waehlt zufaellig — ein Trefferklang, der beim zehnten Schlag noch identisch
## klingt, wird zu Matsch.
##
## Es gibt im Pack KEINEN Tuerklang. `door_move` ist darum ein schwerer Aufprall, den der
## Aufrufer beim Schliessen tiefer abspielt (Door: Pitch 0.8) — dieselbe Tuer, andere Richtung.
const SOUNDS: Dictionary = {
	# Kampf — das Projektziel. Diese vier tragen das Kampfgefuehl.
	&"attack_swing":  ["Sounds/Whoosh & Slash/Slash.wav",
					   "Sounds/Whoosh & Slash/Slash2.wav",
					   "Sounds/Whoosh & Slash/Slash3.wav"],
	&"hit_enemy":     ["Sounds/Hit & Impact/Hit1.wav",
					   "Sounds/Hit & Impact/Hit2.wav",
					   "Sounds/Hit & Impact/Hit3.wav"],
	&"hit_player":    ["Sounds/Hit & Impact/Impact.wav",
					   "Sounds/Hit & Impact/Impact2.wav"],
	&"enemy_dead":    ["Sounds/Hit & Impact/Impact4.wav",
					   "Sounds/Hit & Impact/Impact5.wav"],
	# Lesbarkeit: der Telegraph des Skeletts war bisher rein visuell (Rot-Blink).
	&"enemy_alert":   ["Sounds/Alert/Alert.wav"],

	# Reif (Phase 5/7)
	&"dash":          ["Sounds/Whoosh & Slash/Whoosh.wav",
					   "Sounds/Whoosh & Slash/Whoosh2.wav"],
	&"reif_loop":     ["Sounds/Magic & Skill/Spirit.wav"],
	&"reif_compel":   ["Sounds/Magic & Skill/Strange.wav"],
	&"corruption_up": ["Sounds/Magic & Skill/Magic4.wav"],

	# Ensemble (Phase 4/7)
	&"switch_figure": ["Sounds/Magic & Skill/Fx.wav"],
	&"switch_refused":["Sounds/Menu/Cancel.wav"],
	&"figure_down":   ["Sounds/Voice/Voice9.wav"],

	# Raum (Phase 6) und Speichern (Phase 9)
	&"plate_press":   ["Sounds/Hit & Impact/Hit7.wav"],
	&"plate_release": ["Sounds/Hit & Impact/Hit6.wav"],
	&"door_move":     ["Sounds/Hit & Impact/Impact3.wav"],
	&"save_point":    ["Jingles/Success1.wav"],

	# Menue (Phase 9)
	&"menu_move":     ["Sounds/Menu/Move1.wav"],
	&"menu_confirm":  ["Sounds/Menu/Accept.wav"],
}

## Musik und Jingles: ID -> genau eine Datei. Die Raeume nennen ihre ID in `Room.music_id`,
## `game_over` holt sich `scenes/main.gd`.
const MUSIC: Dictionary = {
	&"dungeon":   "Musics/21 - Dungeon.ogg",
	&"crypt":     "Musics/40 - Crypt.ogg",
	&"game_over": "Jingles/GameOver.wav",
}


func _initialize() -> void:
	var ok: bool = true
	ok = _build_bus_layout() and ok
	ok = _build_bank() and ok
	print("")
	print("FERTIG." if ok else "MIT FEHLERN BEENDET.")
	quit(0 if ok else 1)


## Master / Music / SFX anlegen und als Layout ablegen. Laeuft gegen den `AudioServer` des
## laufenden (headless) Prozesses; `generate_bus_layout()` friert dessen Zustand ein.
func _build_bus_layout() -> bool:
	print("--- Busse ---")
	# Auf den Ausgangszustand zuruecksetzen: der Prozess hat das bestehende Layout eventuell
	# schon geladen, und ein zweiter Lauf soll nicht "Music2" anlegen.
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(AudioServer.bus_count - 1)
	AudioServer.set_bus_name(0, "Master")
	for bus_name: StringName in BUSES:
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, String(bus_name))
		AudioServer.set_bus_send(idx, &"Master")
		AudioServer.set_bus_volume_db(idx, BUSES[bus_name])
		print("  %d  %-6s -> Master  %+.1f dB" % [idx, bus_name, BUSES[bus_name]])

	var layout: AudioBusLayout = AudioServer.generate_bus_layout()
	var err: int = ResourceSaver.save(layout, LAYOUT_PATH)
	if err != OK:
		push_error("build_audio_resources: %s nicht schreibbar (%d)." % [LAYOUT_PATH, err])
		return false
	print("  -> %s" % LAYOUT_PATH)

	# Wie die Input-Actions: per API in die ProjectSettings, nicht von Hand in project.godot.
	if ProjectSettings.get_setting("audio/buses/default_bus_layout", "") != LAYOUT_PATH:
		ProjectSettings.set_setting("audio/buses/default_bus_layout", LAYOUT_PATH)
		err = ProjectSettings.save()
		if err != OK:
			push_error("build_audio_resources: ProjectSettings nicht speicherbar (%d)." % err)
			return false
		print("  ProjectSettings: audio/buses/default_bus_layout gesetzt")
	else:
		print("  ProjectSettings: audio/buses/default_bus_layout stand schon")
	return true


## `SOUNDS` und `MUSIC` in eine `AudioBank`. Fehlt eine Datei, wird NICHTS geschrieben: eine
## halb gefuellte Bank waere im Spiel ein stummes Ereignis ohne Fehlermeldung.
func _build_bank() -> bool:
	print("")
	print("--- Bank ---")
	var missing: Array[String] = []
	var bank := AudioBank.new()

	for id: StringName in SOUNDS:
		var variants: Array = []
		for rel: String in SOUNDS[id]:
			var stream: AudioStream = _load_stream(PACK + rel, missing)
			if stream != null:
				variants.append(stream)
		bank.sounds[id] = variants
		print("  SFX   %-16s %d Variante(n)" % [id, variants.size()])

	for id: StringName in MUSIC:
		var stream: AudioStream = _load_stream(PACK + MUSIC[id], missing)
		bank.music[id] = stream
		# Die Schleife wird hier NICHT gesetzt. Sie stand einmal hier und war ein No-Op: in der
		# `.tres` landet nur eine `ExtResource`-Referenz auf den importierten Stream, das
		# `loop`-Flag des Streams selbst liegt in der `.ogg.import` des Packs (dort `loop=false`)
		# und wird von `ResourceSaver` nicht mitgeschrieben. Der `AudioManager` setzt es darum
		# beim Einhaengen — siehe `_apply_music_stream`.
		print("  MUSIK %-16s %s" % [id, MUSIC[id]])

	if not missing.is_empty():
		for path: String in missing:
			push_error("build_audio_resources: '%s' fehlt oder ist nicht importiert." % path)
		print("  %d Datei(en) fehlen -> Bank NICHT geschrieben." % missing.size())
		return false

	var err: int = ResourceSaver.save(bank, BANK_PATH)
	if err != OK:
		push_error("build_audio_resources: %s nicht schreibbar (%d)." % [BANK_PATH, err])
		return false
	print("  -> %s  (%d SFX-IDs, %d Musik-IDs)" % [BANK_PATH, bank.sounds.size(),
		bank.music.size()])
	return true


func _load_stream(path: String, missing: Array[String]) -> AudioStream:
	if not ResourceLoader.exists(path):
		missing.append(path)
		return null
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		missing.append(path)
	return stream
