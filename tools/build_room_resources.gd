extends SceneTree
## Tool-Skript Phase 6: baut das TileSet des Raums UND die reine Raum-Geometrie.
## Aufruf: $GODOT --headless --path . --script res://tools/build_room_resources.gd
##
## Warum ein Tool: `TileMapLayer.tile_map_data` ist eine binaere PackedByteArray — eine Tilemap
## laesst sich schlicht nicht von Hand in eine `.tscn` schreiben. Erzeugen heisst darum
## PackedScene.pack(). CLAUDE.md verbietet das fuer Szenen mit INSTANZIERTEN Subszenen (es klopft
## sie flach); `room_01_tiles.tscn` enthaelt ausschliesslich TileMapLayer, ist also unbedenklich.
## Alles Instanzierte (Tuer, Platte, Skelett) lebt eine Ebene hoeher in `room_01.tscn`, die von
## Hand geschrieben ist.
##
## Tile-Auswahl ist EMPIRISCH, nicht geraten: ein Probe-Lauf ueber alle Interior-/Dungeon-Sheets
## hat je Tile geprueft, ob es voll deckend UND selbst-nahtlos kachelbar ist (linke Spalte ==
## rechte Spalte, obere Zeile == untere Zeile). Nur solche Tiles taugen als Flaechenmaterial.
## TilesetWallSimple.png ist dabei ausgeschieden: es ist ein 9-Slice-Rahmen mit transparenter
## Mitte, kein Fuellmaterial.

const SHEET := "res://assets/external/Ninja Adventure - Asset Pack/Backgrounds/Tilesets/Interior/TilesetInteriorFloor.png"
const TILESET_PATH := "res://resources/tileset_room.tres"
const TILES_SCENE_PATH := "res://scenes/rooms/room_01_tiles.tscn"

const TILE := 16
## Atlas-Koordinaten im Sheet (Spalte, Zeile).
const ATLAS_FLOOR := Vector2i(14, 15)  # dunkles Kopfsteinpflaster — Gruft-Boden
const ATLAS_WALL := Vector2i(1, 7)     # orangeroter Ziegel — heller Kontrast, sofort als Wand lesbar

## Raummass in Tiles. 40x24 = 640x384 px = exakt der doppelte Viewport (320x180 -> 320x192 gerundet
## auf ganze Tiles); die Kamera hat damit ueberhaupt erst einen Zweck.
const ROOM := Vector2i(40, 24)

## Begehbare Flaechen (alles uebrige wird Wand). Rect2i(x, y, breite, hoehe) in Tiles.
##  * KAMMER  — links, enthaelt Startpunkt und Druckplatte
##  * TUERFELD — die einzige Oeffnung in der Trennwand
##  * KORRIDOR — 2 Tiles hoch: der Engpass, der den Phase-Dash zum Raum-Verb macht
##  * ZIEL     — kleine Kammer hinter dem Korridor
const CHAMBER := Rect2i(1, 1, 23, 22)
const DOOR_CELL := Vector2i(24, 12)
const CORRIDOR := Rect2i(25, 11, 9, 2)
const GOAL := Rect2i(34, 9, 5, 6)


func _initialize() -> void:
	var tile_set := _build_tileset()
	if tile_set == null:
		quit(1)
		return
	_build_tiles_scene(tile_set)
	quit()


func _build_tileset() -> TileSet:
	var tex: Texture2D = load(SHEET) as Texture2D
	if tex == null:
		push_error("Sheet fehlt: %s" % SHEET)
		return null
	# Validieren statt annehmen (gleiches Vorgehen wie build_figure_resources.gd).
	if tex.get_width() % TILE != 0 or tex.get_height() % TILE != 0:
		push_error("Sheet %dx%d ist kein Vielfaches von %d." % [tex.get_width(), tex.get_height(), TILE])
		return null
	var cols: int = tex.get_width() / TILE
	var rows: int = tex.get_height() / TILE
	for coord: Vector2i in [ATLAS_FLOOR, ATLAS_WALL]:
		if coord.x >= cols or coord.y >= rows:
			push_error("Atlas-Koordinate %s liegt ausserhalb von %dx%d Tiles." % [coord, cols, rows])
			return null

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	# Ein Physics-Layer auf Bit 1 = `environment` (CLAUDE.md > Collision-Layer-Matrix).
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(ATLAS_FLOOR)
	source.create_tile(ATLAS_WALL)
	ts.add_source(source, 0)

	# NUR das Wand-Tile bekommt ein Kollisionspolygon — der Boden bleibt begehbar.
	var half: float = TILE * 0.5
	var data: TileData = source.get_tile_data(ATLAS_WALL, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half),
	]))

	var err := ResourceSaver.save(ts, TILESET_PATH)
	print("TileSet %s: %s (Boden %s, Wand %s, Physics-Layer Bit 1)" % [
		TILESET_PATH, error_string(err), ATLAS_FLOOR, ATLAS_WALL])
	return ts


func _build_tiles_scene(tile_set: TileSet) -> void:
	var walkable: Dictionary = _walkable_cells()

	var root := Node2D.new()
	root.name = "Room01Tiles"

	# Boden liegt ueberall, auch unter den Waenden: so ist beim Oeffnen der Tuer sofort Boden
	# sichtbar, ohne dass irgendwo ein Loch klafft.
	var floor_layer := TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = tile_set
	floor_layer.collision_enabled = false

	var wall_layer := TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = tile_set
	wall_layer.collision_enabled = true

	var wall_count: int = 0
	for y in ROOM.y:
		for x in ROOM.x:
			var cell := Vector2i(x, y)
			floor_layer.set_cell(cell, 0, ATLAS_FLOOR)
			if not walkable.has(cell):
				wall_layer.set_cell(cell, 0, ATLAS_WALL)
				wall_count += 1

	root.add_child(floor_layer)
	root.add_child(wall_layer)
	floor_layer.owner = root
	wall_layer.owner = root

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	if pack_err != OK:
		push_error("pack() fehlgeschlagen: %s" % error_string(pack_err))
		return
	var err := ResourceSaver.save(packed, TILES_SCENE_PATH)
	print("Raum %s: %s (%dx%d Tiles = %dx%d px, %d Boden / %d Wand)" % [
		TILES_SCENE_PATH, error_string(err), ROOM.x, ROOM.y, ROOM.x * TILE, ROOM.y * TILE,
		walkable.size(), wall_count])
	# Das Skript laeuft ohne Szenenbaum — die Nodes haengen an nichts und muessen von Hand weg,
	# sonst meldet Godot beim Beenden geleakte RIDs.
	root.free()
	_print_map(walkable)


## Alle begehbaren Zellen als Set (Dictionary -> true).
func _walkable_cells() -> Dictionary:
	var cells: Dictionary = {}
	for rect: Rect2i in [CHAMBER, CORRIDOR, GOAL]:
		for y in rect.size.y:
			for x in rect.size.x:
				cells[rect.position + Vector2i(x, y)] = true
	cells[DOOR_CELL] = true
	return cells


## Die Karte wandert als ASCII in die Konsole — so ist das Layout im Tool-Output pruefbar,
## ohne die Szene zu oeffnen.
func _print_map(walkable: Dictionary) -> void:
	print("Layout ('#' Wand, '.' Boden, 'D' Tuerfeld):")
	for y in ROOM.y:
		var line := ""
		for x in ROOM.x:
			var cell := Vector2i(x, y)
			if cell == DOOR_CELL:
				line += "D"
			elif walkable.has(cell):
				line += "."
			else:
				line += "#"
		print("  " + line)
