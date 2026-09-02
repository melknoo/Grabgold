extends Node2D
## Bootstrap des Vertical Slice (ab Phase 6).
##
## Bis Phase 5 hat diese Datei das Platzhalter-Tile ueber den Viewport gekachelt und einen
## 8x-Zoom-Ausschnitt gezeigt — eine reine Sichtpruefung fuer Nearest-Filtering und
## Integer-Scaling aus Phase 0. Die ist vom User abgenommen, der Code ist damit erledigt und
## ersatzlos raus. Jetzt setzt der Bootstrap den Spieler in den Raum und richtet die Kamera aus.

@onready var room: Room = $Room01
@onready var player: Player = $Player

func _ready() -> void:
	player.global_position = room.spawn_point()
	_apply_camera_limits()

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
