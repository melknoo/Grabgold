class_name World
extends Node2D
## PERSISTENTE Weltszene (ab Phase 8). Bis Phase 10 war sie ausserdem der Bootstrap des Spiels;
## seit Phase 11 liegt der in `scenes/boot.tscn` (der Huelle) darueber, und diese Szene wird von
## ihr aufgebaut und weggeworfen.
##
## Bis Phase 5 hat diese Datei das Platzhalter-Tile ueber den Viewport gekachelt (Sichtpruefung
## fuer Nearest-Filtering und Integer-Scaling aus Phase 0, vom User abgenommen und ersatzlos
## raus). Bis Phase 7 instanzierte sie den Raum fest.
##
## Seit Phase 8 ist sie die Szene, die NIE gewechselt wird: Player, PartyManager und die Overlays
## haengen hier als Geschwister des Raums und ueberleben damit jeden Raumwechsel. Der Raum selbst
## ist das einzige Kind von `RoomHost` und wird vom `RoomManager`-Autoload getauscht.

## Ein Menue der Huelle wurde angefordert (Game-Over-Menue, Eintrag "Hauptmenue"). Die Szene
## raeumt sich NICHT selbst weg — sie kann es nicht: wer sie aufgebaut hat, wirft sie weg.
signal main_menu_requested

## Game Over oeffnet nach der Blende das Menue (Phase 9). Auf `false` bleibt die Blende einfach
## stehen — fuer Testszenen, die weder Menue noch Neustart wollen. Seit Phase 8 ist das KEIN
## Selbstschutz mehr: `reload_current_scene()` (das in einem Test die Testszene selbst neu
## gestartet haette) ist dem Raumtausch im RoomManager gewichen.
@export var restart_on_wipe: bool = true

## Betritt die Szene beim Aufbau von selbst den Startraum? Bis Phase 10 tat sie das immer, und
## damit gab es nie einen Zustand "Spiel laeuft nicht". Die Huelle (`scenes/boot.gd`) setzt das
## auf `false` und entscheidet selbst zwischen Startraum und Spielstand.
##
## Vorgabe bleibt `true`, damit die sieben Testsuiten diese Szene weiter als Kind unter sich
## haengen und sofort eine laufende Welt haben — sie pruefen den Raum, nicht das Hauptmenue.
@export var enter_on_ready: bool = true

@onready var room_host: Node2D = $RoomHost
@onready var player: Player = $Player
@onready var party: PartyManager = $PartyManager
@onready var game_over: GameOverFade = $GameOverFade
@onready var game_over_menu: GameOverMenu = $GameOverMenu

func _ready() -> void:
	# Registrierung statt fester Pfade im Autoload: die Testszenen haengen main.tscn als Kind
	# unter sich, ein "/root/Main/Player" waere dort falsch.
	RoomManager.bind_world(room_host, player, party)
	if enter_on_ready:
		RoomManager.enter_start_room()
	party.party_wiped.connect(_on_party_wiped)
	game_over.fade_finished.connect(_on_fade_finished)
	game_over_menu.load_requested.connect(_on_load_requested)
	game_over_menu.restart_requested.connect(_on_restart_requested)
	game_over_menu.menu_requested.connect(_on_menu_requested)

## Keine Figur steht mehr. Die Welt hoert SOFORT auf — nicht erst, wenn die Blende zu ist:
## bis Phase 9 lief der Raum hinter der Schwarzblende weiter, das Skelett schlug auf die
## gefallene Figur ein und jeder dieser Treffer feuerte erneut `downed` -> `party_wiped`.
func _on_party_wiped() -> void:
	player.set_input_locked(true)
	player.set_defeated(true)
	RoomManager.set_room_frozen(true)
	# Harter Schnitt statt Ausblende: die Welt hoert in derselben Zeile auf, in der der Raum
	# einfriert. Der Jingle stellt das Stueck ab — beides gleichzeitig ist Krach, und eine
	# weiterlaufende Dungeonmusik hinter dem Tod liest sich wie ein haengender Frame.
	AudioManager.play_jingle(&"game_over")
	game_over.start()

## Das Bild ist schwarz. Bis Phase 8 wurde hier blind neu gestartet; seit Phase 9 entscheidet
## der Spieler zwischen Speicherstand und Neuanfang.
func _on_fade_finished() -> void:
	if not restart_on_wipe:
		return
	# Der Input ist seit dem Wipe gesperrt und bleibt es: der Bestaetigungsdruck (attack) darf
	# nicht im Hintergrund noch die gefallene Figur zuschlagen lassen. Freigegeben wird er vom
	# Raumaufbau (`enter_from_black` am Ende jedes Wechsels) — nicht hier.
	game_over_menu.open(SaveManager.active_slot, SaveManager.slot_info(SaveManager.active_slot))

func _on_load_requested(slot: int) -> void:
	# Der Jingle darf nicht unter die Musik des neu aufgebauten Raums laufen.
	AudioManager.stop_jingle()
	if not SaveManager.load_from_slot(slot):
		# Slot in der Zwischenzeit kaputt oder verschwunden: das Menue bleibt zustaendig, statt
		# den Spieler in einer schwarzen Szene mit gesperrtem Input sitzen zu lassen.
		game_over_menu.open(slot, SaveManager.slot_info(slot))
		return
	# Erst NACH dem Umbau: `load_from_slot` setzt die Transitions-Blende sofort auf schwarz, das
	# Bild bleibt also zu. Umgekehrt waere die tote Welt fuer einen Frame wieder zu sehen.
	game_over.reset()

## Vom Game-Over-Menue: zurueck in die Huelle. Ohne diesen Eintrag waere der Tod eine
## Sackgasse — man kaeme nur noch in einen Speicherstand oder einen Neuanfang, nie an die
## Optionen oder in einen anderen Slot.
func _on_menu_requested() -> void:
	AudioManager.stop_jingle()
	main_menu_requested.emit()

func _on_restart_requested() -> void:
	# Der Raum ist seit Phase 8 wegwerfbar — also wird er weggeworfen, statt die ganze Szene neu
	# aufzubauen. Gegner respawnen dabei von selbst (frische Instanz), und der Player-Node samt
	# Kamera bleibt derselbe.
	AudioManager.stop_jingle()
	SaveManager.new_game()
	game_over.reset()

## Pause (Phase 11). Angehalten wird mit denselben zwei Mitteln wie beim Game Over (Phase 9):
## der Raum friert per `process_mode` ein, der Player-Input ist gesperrt. Die Huelle besitzt das
## Menue, diese Szene den Zustand der Welt — darum liegt der Schalter hier.
##
## Player und Overlays laufen weiter (sie haengen als Geschwister des Raums), und die Musik auch:
## sonst waere der Musikregler in den Optionen nicht zu hoeren. Der Reif raeumt seinen gehaltenen
## Klang bei der Input-Sperre selbst auf (Phase 10).
func set_paused(paused: bool) -> void:
	player.set_input_locked(paused)
	RoomManager.set_room_frozen(paused)

func is_paused() -> bool:
	return RoomManager.is_room_frozen()

## Darf die Huelle jetzt pausieren? Nicht im Game Over: dort haelt die Welt schon, der Input ist
## gesperrt und das Game-Over-Menue ist zustaendig. Ein Pausenmenue darueber waere ein zweiter
## Bildschirm, der auf dieselben Tasten hoert.
func accepts_pause() -> bool:
	return not game_over.is_running() and not game_over_menu.is_open() \
		and not player.is_defeated()

## Aktueller Raum. Nur fuer Tests und das Debug-Overlay — im Spiel fragt niemand danach, weil
## der RoomManager den Wechsel besitzt.
func room() -> Room:
	return RoomManager.current_room()
