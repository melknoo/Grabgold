extends Node2D
## Phase-0-Bootstrap: verifiziert Nearest-Filtering + Integer-Scaling.
## Kachelt das Platzhalter-Tile ueber den kompletten 320x180-Viewport und zeigt
## einen 8x-vergroesserten Ausschnitt, an dem Filter-/Skalierungs-Artefakte sofort
## sichtbar waeren. Kein Produktionscode — nur Sichtpruefung fuer Phase 0.

const TILE: Texture2D = preload("res://assets/placeholder/tile_16.png")
const TILE_SIZE: int = 16

func _ready() -> void:
	var view: Vector2i = get_viewport_rect().size
	# Grundflaeche mit dem Tile kacheln.
	var cols: int = int(ceil(view.x / float(TILE_SIZE)))
	var rows: int = int(ceil(view.y / float(TILE_SIZE)))
	for y in rows:
		for x in cols:
			var s := Sprite2D.new()
			s.texture = TILE
			s.centered = false
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.position = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			s.z_index = -100
			add_child(s)

	# Ein 8x hochskaliertes Tile: hier wuerde Sub-Pixel-Blur brutal auffallen.
	var zoom := Sprite2D.new()
	zoom.texture = TILE
	zoom.centered = false
	zoom.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	zoom.scale = Vector2(8, 8)
	zoom.position = Vector2(96, 26)
	zoom.z_index = -100
	add_child(zoom)

	# Kontext-Label fuer die Sichtpruefung/Screenshot.
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "GRABGOLD — Phase 0\n320x180 · Integer x6 · Nearest"
	label.position = Vector2(6, 6)
	layer.add_child(label)
