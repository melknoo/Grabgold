extends SceneTree
## Tool-Skript Phase 12: baut die SpriteFrames ALLER Gegner aus dem Asset-Pack.
## Aufruf: $GODOT --headless --path . --script res://tools/build_enemy_resources.gd
##
## Warum es das erst jetzt gibt: `skeleton_frames.tres` war die LETZTE Resource im Projekt, die
## von Hand entstanden ist — jede andere (`player_*_frames`, `*_anims`, TileSet, Raum-Geometrie,
## Bus-Layout, Klang-Bank) kommt seit ihrer Phase aus einem Tool. Mit dem zweiten Gegner (dem
## Waechter in Raum C) waere daraus eine zweite Handarbeit geworden; stattdessen steht hier eine
## TABELLE, und eine neue Gegnerart ist ein Eintrag darin plus ein `TuningStats`-`.tres` —
## kein Code (dieselbe Regel wie `FigureProfile` fuer die Figuren, CLAUDE.md > Figuren-Ensemble).
##
## Sheet-Konvention im ganzen Pack: SPALTE = Richtung (0=down, 1=up, 2=left, 3=right),
## ZEILE = Frame. Gilt fuer `Actor/Character/*` mit 16x16-Zellen. Die Masse werden gegen das
## Sheet geprueft und nicht angenommen (gleiches Vorgehen wie build_figure_resources.gd).
##
## `dead` ist RICHTUNGSLOS (Sheet 16x16, eine Pose): `states/dead.gd` spielt bewusst `dead` und
## nicht `dead_<facing>`. Wer das hier aendert, bricht dort die Todespose.

const PACK := "res://assets/external/Ninja Adventure - Asset Pack/Actor/Character/"
const DIRS: Array[String] = ["down", "up", "left", "right"]  # = Spalten-Reihenfolge im Sheet
const CELL := 16

## Aktion -> [Datei im SeparateAnim-Ordner, Frames pro Richtung, FPS, loop].
## Die FPS sind Feel-Werte, haben in einer SpriteFrames aber keinen anderen Ort als die Resource
## selbst — dieselbe Begruendung wie in build_figure_resources.gd.
const SHEETS: Dictionary = {
	"idle": ["Idle.png", 1, 1.0, true],
	"walk": ["Walk.png", 4, 8.0, true],
	"attack": ["Attack.png", 1, 1.0, false],
}

## Die eine richtungslose Animation. Eigener Eintrag, weil sie NICHT ueber die Spalten laeuft.
const DEAD_SHEET := "Dead.png"
const DEAD_FPS := 5.0

## Alle Gegner, die das Tool baut. Ein neuer Gegner = ein Eintrag hier.
##  * `name`   nur fuer die Ausgabe
##  * `folder` Ordner unter Actor/Character/ im Pack
##  * `path`   Ausgabepfad der SpriteFrames
const ENEMIES: Array[Dictionary] = [
	{
		"name": "Skelett",
		"folder": "Skeleton",
		"path": "res://resources/skeleton_frames.tres",
	},
	{
		# Waechter (Phase 12). Gleiche Familie, sofort als "das ist nicht das Uebliche" lesbar —
		# genau darum dieser Ordner und keine Faerbung per `modulate`: Telegraph und Hurt setzen
		# `sprite.modulate` bei jedem Blinken auf Weiss zurueck, eine Tuchfarbe haette den ersten
		# Angriff nicht ueberlebt.
		"name": "Waechter",
		"folder": "SkeletonDemon",
		"path": "res://resources/skeleton_demon_frames.tres",
	},
]


func _initialize() -> void:
	for enemy: Dictionary in ENEMIES:
		_build_sprite_frames(enemy)
	quit()


func _build_sprite_frames(enemy: Dictionary) -> void:
	var dir: String = PACK + enemy["folder"] + "/SeparateAnim/"
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")

	for action: String in SHEETS:
		var sheet_path: String = dir + SHEETS[action][0]
		var frame_count: int = SHEETS[action][1]
		var fps: float = SHEETS[action][2]
		var loops: bool = SHEETS[action][3]
		var tex: Texture2D = load(sheet_path) as Texture2D
		if tex == null:
			push_error("Sheet fehlt: %s" % sheet_path)
			return
		var expected := Vector2i(DIRS.size() * CELL, frame_count * CELL)
		if tex.get_size() != Vector2(expected):
			push_error("%s: erwartet %s, ist %s" % [sheet_path, expected, tex.get_size()])
			return
		for col in DIRS.size():
			var anim_name := StringName("%s_%s" % [action, DIRS[col]])
			sf.add_animation(anim_name)
			sf.set_animation_loop(anim_name, loops)
			sf.set_animation_speed(anim_name, fps)
			for row in frame_count:
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(col * CELL, row * CELL, CELL, CELL)
				sf.add_frame(anim_name, at)

	var dead_path: String = dir + DEAD_SHEET
	var dead_tex: Texture2D = load(dead_path) as Texture2D
	if dead_tex == null:
		push_error("Sheet fehlt: %s" % dead_path)
		return
	if dead_tex.get_size() != Vector2(CELL, CELL):
		push_error("%s: erwartet %dx%d, ist %s" % [dead_path, CELL, CELL, dead_tex.get_size()])
		return
	sf.add_animation(&"dead")
	sf.set_animation_loop(&"dead", false)
	sf.set_animation_speed(&"dead", DEAD_FPS)
	var dead_at := AtlasTexture.new()
	dead_at.atlas = dead_tex
	dead_at.region = Rect2(0, 0, CELL, CELL)
	sf.add_frame(&"dead", dead_at)

	var path: String = enemy["path"]
	var err := ResourceSaver.save(sf, path)
	print("SpriteFrames %s (%s): %s (%d Anims: %s)" % [
		path, enemy["name"], error_string(err), sf.get_animation_names().size(),
		", ".join(sf.get_animation_names())])
