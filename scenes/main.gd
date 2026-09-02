extends Node2D
## Bootstrap und PERSISTENTE Weltszene (ab Phase 8).
##
## Bis Phase 5 hat diese Datei das Platzhalter-Tile ueber den Viewport gekachelt (Sichtpruefung
## fuer Nearest-Filtering und Integer-Scaling aus Phase 0, vom User abgenommen und ersatzlos
## raus). Bis Phase 7 instanzierte sie den Raum fest.
##
## Seit Phase 8 ist sie die Szene, die NIE gewechselt wird: Player, PartyManager und die Overlays
## haengen hier als Geschwister des Raums und ueberleben damit jeden Raumwechsel. Der Raum selbst
## ist das einzige Kind von `RoomHost` und wird vom `RoomManager`-Autoload getauscht.

## Game Over oeffnet nach der Blende das Menue (Phase 9). Auf `false` bleibt die Blende einfach
## stehen — fuer Testszenen, die weder Menue noch Neustart wollen. Seit Phase 8 ist das KEIN
## Selbstschutz mehr: `reload_current_scene()` (das in einem Test die Testszene selbst neu
## gestartet haette) ist dem Raumtausch im RoomManager gewichen.
@export var restart_on_wipe: bool = true

@onready var room_host: Node2D = $RoomHost
@onready var player: Player = $Player
@onready var party: PartyManager = $PartyManager
@onready var game_over: GameOverFade = $GameOverFade
@onready var game_over_menu: GameOverMenu = $GameOverMenu

func _ready() -> void:
	# Registrierung statt fester Pfade im Autoload: die Testszenen haengen main.tscn als Kind
	# unter sich, ein "/root/Main/Player" waere dort falsch.
	RoomManager.bind_world(room_host, player, party)
	RoomManager.enter_start_room()
	party.party_wiped.connect(_on_party_wiped)
	game_over.fade_finished.connect(_on_fade_finished)
	game_over_menu.load_requested.connect(_on_load_requested)
	game_over_menu.restart_requested.connect(_on_restart_requested)

## Keine Figur steht mehr. Die Welt hoert SOFORT auf — nicht erst, wenn die Blende zu ist:
## bis Phase 9 lief der Raum hinter der Schwarzblende weiter, das Skelett schlug auf die
## gefallene Figur ein und jeder dieser Treffer feuerte erneut `downed` -> `party_wiped`.
func _on_party_wiped() -> void:
	player.set_input_locked(true)
	player.set_defeated(true)
	RoomManager.set_room_frozen(true)
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
	if not SaveManager.load_from_slot(slot):
		# Slot in der Zwischenzeit kaputt oder verschwunden: das Menue bleibt zustaendig, statt
		# den Spieler in einer schwarzen Szene mit gesperrtem Input sitzen zu lassen.
		game_over_menu.open(slot, SaveManager.slot_info(slot))
		return
	# Erst NACH dem Umbau: `load_from_slot` setzt die Transitions-Blende sofort auf schwarz, das
	# Bild bleibt also zu. Umgekehrt waere die tote Welt fuer einen Frame wieder zu sehen.
	game_over.reset()

func _on_restart_requested() -> void:
	# Der Raum ist seit Phase 8 wegwerfbar — also wird er weggeworfen, statt die ganze Szene neu
	# aufzubauen. Gegner respawnen dabei von selbst (frische Instanz), und der Player-Node samt
	# Kamera bleibt derselbe.
	SaveManager.new_game()
	game_over.reset()

## Aktueller Raum. Nur fuer Tests und das Debug-Overlay — im Spiel fragt niemand danach, weil
## der RoomManager den Wechsel besitzt.
func room() -> Room:
	return RoomManager.current_room()
