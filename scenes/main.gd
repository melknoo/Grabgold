extends Node2D
## Bootstrap des Vertical Slice (ab Phase 6).
##
## Bis Phase 5 hat diese Datei das Platzhalter-Tile ueber den Viewport gekachelt und einen
## 8x-Zoom-Ausschnitt gezeigt — eine reine Sichtpruefung fuer Nearest-Filtering und
## Integer-Scaling aus Phase 0. Die ist vom User abgenommen, der Code ist damit erledigt und
## ersatzlos raus. Jetzt setzt der Bootstrap den Spieler in den Raum und richtet die Kamera aus.

## Game Over startet den Raum neu. Die Testszenen setzen das auf `false`, BEVOR ein Physik-Frame
## laeuft: sie haengen main.tscn als Kind unter sich, und `reload_current_scene()` wuerde dort
## nicht den Raum, sondern den Test selbst neu starten — eine Endlosschleife.
@export var restart_on_wipe: bool = true

@onready var room: Room = $Room01
@onready var player: Player = $Player
@onready var party: PartyManager = $PartyManager
@onready var game_over: GameOverFade = $GameOverFade

func _ready() -> void:
	player.global_position = room.spawn_point()
	_apply_camera_limits()
	party.party_wiped.connect(_on_party_wiped)
	game_over.fade_finished.connect(_on_fade_finished)

func _on_party_wiped() -> void:
	game_over.start()

func _on_fade_finished() -> void:
	if restart_on_wipe:
		get_tree().reload_current_scene()

## Die Kamera darf nie ueber die Aussenwand hinausschauen. Smoothing bleibt aus (CLAUDE.md >
## Auflösung & Look): es erzeugt Sub-Pixel-Kamerapositionen und damit Tile-Seams — genau die
## Naht, die mit echten Kacheln ab Phase 6 zum ersten Mal sichtbar werden koennte.
func _apply_camera_limits() -> void:
	var b: Rect2i = room.bounds()
	var cam: Camera2D = player.camera
	cam.limit_left = b.position.x
	cam.limit_top = b.position.y
	cam.limit_right = b.end.x
	cam.limit_bottom = b.end.y
	cam.limit_smoothed = false
	cam.position_smoothing_enabled = false
