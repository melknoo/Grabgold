extends Node
## Autoload "AudioManager" (Phase 10). Der EINZIGE Ort, an dem Klang abgespielt wird.
##
## Warum ein Autoload und kein Node in der Weltszene: Musik muss den Raumwechsel ueberleben, um
## den es gerade geht — dieselbe Begruendung, die in Phase 8 die Blende in den `RoomManager`
## gelegt hat. Und weil damit auch der Game-Over-Freeze (`RoomHost` auf DISABLED, Phase 9) und
## jeder Hitstop den Ton nicht anfassen: `PROCESS_MODE_ALWAYS`, ausserhalb des Raums.
##
## Aufteilung zu den anderen Autoloads: der `RoomManager` besitzt den Raum, der `SaveManager` den
## Fortschritt, dieser hier den Ton. Er haengt sich an `RoomManager.room_changed` und liest
## `Room.music_id` — die Kopplung laeuft ueber ein SIGNAL, nie ueber eine direkte Referenz
## (Projektregel seit Phase 8), und sie laeuft nur in diese Richtung: der RoomManager kennt den
## AudioManager nicht.
##
## Zwei Entscheidungen, die man im Code nicht sieht:
##  * NICHT positional (`AudioStreamPlayer`, nicht `AudioStreamPlayer2D`). Die Kamera folgt dem
##    Spieler, ein Raum ist maximal der doppelte Viewport — alles, was zu hoeren ist, ist auf dem
##    Bild. Positionaler Ton haette Abspieler an jeden Aktor gehaengt und der Manager waere nicht
##    mehr die einzige Stelle.
##  * Pegel liegen auf den BUSSEN, nicht an den Abspielern. Die Abspieler-Lautstaerke gehoert
##    ganz der Kreuzblende der Musik; wer laut/leise stellt, verstellt einen Bus.

## Musik hat gewechselt (auch auf "nichts" -> leere ID). Andockpunkt fuer eine kuenftige Anzeige.
signal music_changed(music_id: StringName)

const BANK_PATH := "res://resources/audio_bank.tres"

## Gleichzeitige Effekte. 12 ist reichlich fuer einen Bildschirm mit einer Handvoll Aktoren; die
## Obergrenze existiert vor allem, damit ein Fehler in einem State nicht hunderte Nodes anlegt.
const POOL_SIZE := 12

## Vorgabe fuer die Kreuzblende der Musik in FRAMES, nicht Sekunden — wie Tuer, Gegner-KI,
## Angriffstiming und die beiden Blenden. 45 F = 0,75 s. Zur Laufzeit setzbar (die Tests kuerzen).
var music_fade_frames: int = 45

## Stumm. Die BUCHFUEHRUNG laeuft weiter — `current_music()`, `music_starts()`, `last_played()`,
## `play_count()` und die Frame-Dedup verhalten sich identisch, es wird nur kein Abspieler
## angeworfen. Zwei Gruende, und nur einer davon sind die Tests:
##
##  * Godot laesst beim Beenden eine LAUFENDE Ogg-Wiedergabe im Log stehen ("2 resources still
##    in use" plus vier geleakte Ogg-Instanzen). Nachgestellt in einem Projekt aus zwoelf Zeilen
##    ohne eine Zeile dieses Autoloads, und auch mit `stop()` kurz vor dem Ende nicht abstellbar:
##    Engine-Verhalten, von hier aus nicht zu beheben. Ein GELADENES, nicht abgespieltes Ogg ist
##    dagegen sauber. Die Suiten phase4..9 spielen keinen Ton und sollen davon keine
##    Fehlerzeilen erben — sie setzen dieses Flag, bevor der Startraum betreten wird.
##  * Es ist der Anfang der Stummschaltung, die ein Optionsmenue braucht.
var enabled: bool = true:
	set(value):
		enabled = value
		if not enabled:
			_silence()

## Seedbar, damit ein Test die Variantenauswahl deterministisch fahren kann (Muster aus `Reif`).
var rng := RandomNumberGenerator.new()

var _bank: AudioBank

var _pool: Array[AudioStreamPlayer] = []
var _cursor: int = 0

## Ein gehaltener Klang (der kanalisierende Reif). Genau EINER — mehr braucht der Slice nicht,
## und ein Pool gehaltener Klaenge waere ein Leck, das man nicht sieht, sondern hoert.
var _loop_player: AudioStreamPlayer
var _loop_id: StringName = &""

## Jingles (Game Over) liegen auf dem Musik-Bus, aber auf einem eigenen Abspieler: `stop_music`
## darf den Jingle nicht mit abraeumen, und der Jingle nicht die Kreuzblende belegen.
var _jingle: AudioStreamPlayer

## Zwei Abspieler fuer die Kreuzblende. `_slot` zeigt auf den, der `_music_id` haelt.
var _music: Array[AudioStreamPlayer] = []
var _slot: int = 0
var _music_id: StringName = &""
var _music_starts: int = 0

var _fade_in: AudioStreamPlayer = null
var _fade_out: AudioStreamPlayer = null
var _fade_out_from: float = 1.0
var _fade_left: int = 0
var _fade_total: int = 1

## Welche IDs in DIESEM Physik-Frame schon liefen. Zwei Gegner, die im selben Frame getroffen
## werden, sind zwei Aufrufe von `hit_enemy` — derselbe Klang zweimal deckungsgleich addiert sich
## zu einem Knacken statt zu einem doppelten Treffer. Ein Klang pro ID pro Frame.
var _played_this_frame: Dictionary[StringName, bool] = {}

## Nur fuer Tests und das Debug-Overlay.
var _last_played: StringName = &""
var _last_pitch: float = 1.0
var _play_counts: Dictionary[StringName, int] = {}


func _ready() -> void:
	# Wie der HitstopManager: laeuft weiter, waehrend Ziele pausiert sind. Ohne das reisst der Ton
	# bei jedem Hitstop und hinter der Game-Over-Blende ab.
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()

	_bank = load(BANK_PATH) as AudioBank
	if _bank == null:
		push_error("AudioManager: %s fehlt oder ist keine AudioBank." % BANK_PATH)

	for i in POOL_SIZE:
		_pool.append(_make_player(&"SFX", "Sfx%d" % i))
	_loop_player = _make_player(&"SFX", "Loop")
	# Kein `loop` am Stream: das Flag liegt in der `.import` des Packs (dort `false`) und laesst
	# sich von hier nicht sauber setzen, ohne eine geteilte Resource zu veraendern. Neu anwerfen,
	# wenn er durch ist — der Klang ist ein kurzes Summen, die Naht ist nicht zu hoeren.
	_loop_player.finished.connect(_on_loop_finished)
	_jingle = _make_player(&"Music", "Jingle")
	for i in 2:
		_music.append(_make_player(&"Music", "Music%d" % i))

	# Signal statt direkter Referenz — und der RoomManager existiert als Autoload sicher schon,
	# egal in welcher Reihenfolge die beiden hochkommen (verbunden wird ein Node, nicht sein
	# `_ready`). Der Startraum wird erst aus `scenes/main.gd::_ready` betreten, also nach uns.
	RoomManager.room_changed.connect(_on_room_changed)


## Jeden Abspieler anhalten, OHNE die Buchfuehrung anzufassen: stumm heisst "das laufende Stueck
## ist nicht zu hoeren", nicht "es laeuft keins". Wer `enabled` wieder auf `true` setzt, hoert
## den naechsten Klang und den naechsten Raumwechsel — das gerade laufende Stueck kommt nicht von
## selbst zurueck. Fuer den Slice genug; ein Optionsmenue muesste hier nachlegen.
func _silence() -> void:
	if _loop_player == null:
		return  # `enabled` vor unserem `_ready` gesetzt — es gibt noch keine Abspieler
	for p: AudioStreamPlayer in _pool:
		p.stop()
	_loop_player.stop()
	_jingle.stop()
	for p: AudioStreamPlayer in _music:
		p.stop()


func _make_player(bus: StringName, node_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = node_name
	p.bus = bus
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
	return p


func _physics_process(_delta: float) -> void:
	if not _played_this_frame.is_empty():
		_played_this_frame.clear()
	_tick_fade()


# --- Effekte ----------------------------------------------------------------------------------

## Einen Effekt anwerfen. `pitch` traegt die Zeitdehnung des Reifs: ein verlangsamter Gegner
## klingt tiefer (siehe `Skeleton.play_sound`). Rueckgabe `false` = nicht abgespielt (unbekannte
## ID oder in diesem Frame schon gelaufen) — die Tests lesen das.
func play(id: StringName, pitch: float = 1.0) -> bool:
	if _bank == null or not _bank.has_sound(id):
		push_error("AudioManager: unbekannte Klang-ID '%s'." % id)
		return false
	if _played_this_frame.has(id):
		return false
	_played_this_frame[id] = true
	var p: AudioStreamPlayer = _take_player()
	p.stream = _bank.pick_sound(id, rng)
	p.pitch_scale = maxf(pitch, 0.01)
	if enabled:
		p.play()
	_last_played = id
	_last_pitch = p.pitch_scale
	_play_counts[id] = _play_counts.get(id, 0) + 1
	return true


## Freier Abspieler, sonst der naechste im Kreis. Ein abgeschnittener alter Klang ist besser als
## ein verschluckter neuer: Rueckmeldung auf die letzte Aktion ist das, was den Kampf lesbar
## macht.
func _take_player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _pool:
		if not p.playing:
			return p
	var p: AudioStreamPlayer = _pool[_cursor]
	_cursor = (_cursor + 1) % _pool.size()
	return p


# --- Gehaltener Klang -------------------------------------------------------------------------

## Beginnt einen gehaltenen Klang (der kanalisierende Reif). Idempotent: erneuter Aufruf mit
## derselben ID setzt ihn NICHT zurueck — sonst stotterte er jeden Frame, weil der Reif seinen
## Kanal frame-getrieben auswertet.
func start_loop(id: StringName) -> bool:
	if _bank == null or not _bank.has_sound(id):
		push_error("AudioManager: unbekannte Klang-ID '%s' (Loop)." % id)
		return false
	if _loop_id == id:
		return false
	_loop_id = id
	_loop_player.stream = _bank.pick_sound(id, rng)
	if enabled:
		_loop_player.play()
	return true


func stop_loop() -> void:
	if _loop_id == &"":
		return
	_loop_id = &""
	_loop_player.stop()


func loop_id() -> StringName:
	return _loop_id


func _on_loop_finished() -> void:
	if _loop_id != &"":
		_loop_player.play()


# --- Musik ------------------------------------------------------------------------------------

## Stueck wechseln. `frames` < 0 = `music_fade_frames`, 0 = harter Schnitt.
##
## GLEICHE ID = KEIN NEUSTART. Das ist die wichtigste Zeile der Musikverwaltung: die Raumkette
## laeuft B(crypt) <-> C(crypt), und ein Stueck, das bei jedem Durchgang von vorn anfaengt,
## verrät die Raumgrenze und macht das Herumlaufen unangenehm.
func play_music(id: StringName, frames: int = -1) -> bool:
	if id == &"":
		stop_music(frames)
		return false
	if _bank == null or not _bank.has_music(id):
		push_error("AudioManager: unbekannte Musik-ID '%s'." % id)
		return false
	if id == _music_id:
		return false
	var incoming: AudioStreamPlayer = _music[1 - _slot]
	var outgoing: AudioStreamPlayer = _music[_slot]
	_slot = 1 - _slot
	_apply_music_stream(incoming, _bank.music_stream(id))
	incoming.volume_linear = 0.0
	if enabled:
		incoming.play()
	_music_starts += 1
	_music_id = id
	_start_fade(incoming, outgoing if outgoing.playing else null, frames)
	music_changed.emit(id)
	return true


## Ausblenden. Kein Zustand, in dem "kein Stueck" den Abspieler noch braucht.
func stop_music(frames: int = -1) -> void:
	var current: AudioStreamPlayer = _music[_slot]
	if _music_id == &"" and not current.playing and not is_music_fading():
		return
	_music_id = &""
	_start_fade(null, current, frames)
	music_changed.emit(&"")


## Jingle (Game Over). Stellt die Musik ab — ein Jingle UEBER dem Stueck ist Krach, und ein
## Spielende mit weiterlaufender Dungeonmusik liest sich wie ein haengender Frame.
func play_jingle(id: StringName, frames: int = 0) -> bool:
	if _bank == null or not _bank.has_music(id):
		push_error("AudioManager: unbekannte Musik-ID '%s' (Jingle)." % id)
		return false
	stop_music(frames)
	_apply_music_stream(_jingle, _bank.music_stream(id))
	_jingle.volume_linear = 1.0
	if enabled:
		_jingle.play()
	return true


## Jingle abwuergen. Aufrufer ist `scenes/main.gd`, wenn nach dem Game-Over-Menue eine Welt
## aufgebaut wird: der Jingle darf nicht unter die Musik des neuen Raums laufen.
func stop_jingle() -> void:
	_jingle.stop()


func is_jingle_playing() -> bool:
	return _jingle.playing


## Ogg-Musik muss sich schleifen. Das Flag liegt eigentlich in der `.ogg.import` des Packs (dort
## `loop=false`) und laesst sich von einem Bau-Tool nicht in die `.tres` schreiben: dort steht nur
## eine `ExtResource`-Referenz auf den importierten Stream. Also hier, an genau EINER Stelle, beim
## Einhaengen. Es veraendert eine geteilte Resource im Speicher — zulaessig, weil der einzige
## Nutzer dieser Streams dieser Autoload ist und die Zuweisung idempotent ist.
##
## Jingles sind WAV und laufen bewusst einmal durch.
func _apply_music_stream(p: AudioStreamPlayer, stream: AudioStream) -> void:
	var ogg := stream as AudioStreamOggVorbis
	if ogg != null and not ogg.loop:
		ogg.loop = true
	p.stream = stream


func _start_fade(incoming: AudioStreamPlayer, outgoing: AudioStreamPlayer, frames: int) -> void:
	_fade_in = incoming
	_fade_out = outgoing
	# Von dort aus, wo der Ausblendende gerade STEHT: bricht eine Blende die naechste ab, springt
	# die Lautstaerke sonst erst auf voll und faellt dann.
	_fade_out_from = outgoing.volume_linear if outgoing != null else 0.0
	_fade_total = maxi(frames if frames >= 0 else music_fade_frames, 1)
	_fade_left = _fade_total
	if frames == 0:
		_finish_fade()


func _tick_fade() -> void:
	if _fade_left <= 0:
		return
	_fade_left -= 1
	var t: float = 1.0 - float(_fade_left) / float(_fade_total)
	if _fade_in != null:
		_fade_in.volume_linear = t
	if _fade_out != null:
		_fade_out.volume_linear = _fade_out_from * (1.0 - t)
	if _fade_left <= 0:
		_finish_fade()


func _finish_fade() -> void:
	if _fade_in != null:
		_fade_in.volume_linear = 1.0
	if _fade_out != null:
		_fade_out.stop()
		_fade_out.volume_linear = 0.0
	_fade_in = null
	_fade_out = null
	_fade_left = 0


## `Room.music_id` — seit Phase 8 im Raum-Node angelegt und bis hierher ungenutzt. Leere ID
## (Raum 02/03 vor dieser Phase, oder ein Raum, der bewusst still ist) = ausblenden.
func _on_room_changed(_room_id: StringName) -> void:
	var room: Room = RoomManager.current_room()
	play_music(room.music_id if room != null else &"")


# --- Busse ------------------------------------------------------------------------------------

## Pegel eines Busses. Die Vorgaben stehen im generierten `default_bus_layout.tres`; hier
## verstellt sie, wer laut/leise regelt. Eine Optionen-UI gibt es noch nicht — die API ist der
## Andockpunkt (dieselbe Lage wie bei den drei Spielstand-Slots ohne Slot-Auswahl, Phase 9).
func set_bus_db(bus: StringName, db: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus)
	if idx < 0:
		push_error("AudioManager: unbekannter Bus '%s'." % bus)
		return
	AudioServer.set_bus_volume_db(idx, db)


func bus_db(bus: StringName) -> float:
	var idx: int = AudioServer.get_bus_index(bus)
	return AudioServer.get_bus_volume_db(idx) if idx >= 0 else 0.0


func has_bus(bus: StringName) -> bool:
	return AudioServer.get_bus_index(bus) >= 0


# --- Auskunft (Tests, Debug-Overlay) ----------------------------------------------------------

func bank() -> AudioBank:
	return _bank


func current_music() -> StringName:
	return _music_id


## Wie oft ein Stueck ANGEWORFEN wurde. Der Nachweis fuer "gleiche ID startet nicht neu": ueber
## B -> C -> B mit demselben `music_id` darf der Zaehler nicht steigen.
func music_starts() -> int:
	return _music_starts


func is_music_fading() -> bool:
	return _fade_left > 0


func music_volume() -> float:
	return _music[_slot].volume_linear


func last_played() -> StringName:
	return _last_played


## Pitch des letzten Effekts. Der Nachweis, dass die Zeitdehnung des Reifs im Ton ankommt
## (`Skeleton.play_sound`) — von aussen ist sonst nicht zu sehen, welcher Abspieler dran war.
func last_pitch() -> float:
	return _last_pitch


func play_count(id: StringName) -> int:
	return _play_counts.get(id, 0)


func active_sfx_count() -> int:
	var n: int = 0
	for p: AudioStreamPlayer in _pool:
		if p.playing:
			n += 1
	return n


func pool_size() -> int:
	return _pool.size()
