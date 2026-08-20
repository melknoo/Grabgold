extends SceneTree
## Tool-Skript: baut die Figur-Resources (SpriteFrames + AnimationLibrary) aus dem Asset-Pack.
## Aufruf: $GODOT --headless --path . --script res://tools/build_figure_resources.gd
##
## Warum ein Tool statt Handarbeit: `.tres` werden NIE von Hand geschrieben (CLAUDE.md > Assets) —
## die Engine serialisiert. Zusaetzlich leitet dieses Skript die Zeitpunkte der Attack-Animation
## direkt aus den Frame-Werten der jeweiligen `TuningStats` ab. Damit koennen Anim-Timing und
## `.tres` nicht auseinanderlaufen: Wer Startup/Active/Recovery im `.tres` aendert, laesst dieses
## Skript neu laufen und die Call-Method-Tracks sitzen wieder passend.

const PACK := "res://assets/external/Ninja Adventure - Asset Pack/Actor/"
const DIRS: Array[String] = ["down", "up", "left", "right"]  # = Spalten-Reihenfolge im Sheet
const PHYS_FPS := 60.0

## Eine Figur-Definition. `sheets` mappt Aktion -> [Pfad, Frames-pro-Richtung, FPS, loop].
## Die FPS sind Feel-Werte, haben aber in SpriteFrames keinen anderen Ort als die Resource selbst
## (anders als die TuningStats-Felder liegen sie deshalb hier und nicht im `.tres` zum Antippen).
## Kurier-Werte = exakt die in Phase 1/2 abgenommenen; Zwerg laeuft bewusst schwerer/langsamer.
## Sheet-Konvention im ganzen Pack: SPALTE = Richtung, ZEILE = Frame (empirisch verifiziert,
## Walk-Row0 ist pixelgleich mit der Idle-Pose).
class FigureDef:
	var frames_path: String
	var anims_path: String
	var stats_path: String
	var cell: int
	var sheets: Dictionary

	func _init(p_frames: String, p_anims: String, p_stats: String, p_cell: int, p_sheets: Dictionary) -> void:
		frames_path = p_frames
		anims_path = p_anims
		stats_path = p_stats
		cell = p_cell
		sheets = p_sheets


func _initialize() -> void:
	var figures: Array[FigureDef] = [
		# Kurier = NinjaGreen, voll animiert, 32x32-Frames, Attack = 4 Frames.
		FigureDef.new(
			"res://resources/player_ninja_frames.tres",
			"res://resources/player_kurier_anims.tres",
			"res://resources/player_kurier.tres",
			32,
			{
				"idle": [PACK + "CharacterAnimated/NinjaGreen/Separate/Idle.png", 4, 4.0, true],
				"walk": [PACK + "CharacterAnimated/NinjaGreen/Separate/Walk.png", 4, 10.0, true],
				"attack": [PACK + "CharacterAnimated/NinjaGreen/Separate/Attack.png", 4, 20.0, false],
				"hurt": [PACK + "CharacterAnimated/NinjaGreen/Separate/Hit.png", 2, 12.0, false],
			}
		),
		# Zwerg = Knight. 16x16-Frames. Attack = NUR EINE Pose (Sheet ist 64x16 = 4 Richtungen x 1
		# Frame), ebenso Idle. Das Pack gibt das Timing vor, nicht umgekehrt: die eine Pose wird
		# ueber einen langen, schweren Startup gehalten (gleiche Lesbarkeits-Idee wie der
		# Skelett-Telegraph). Kein Hit-Sheet vorhanden -> hurt = Idle-Pose + Rot-Flash/Blink.
		FigureDef.new(
			"res://resources/player_knight_frames.tres",
			"res://resources/player_zwerg_anims.tres",
			"res://resources/player_zwerg.tres",
			16,
			{
				"idle": [PACK + "Character/Knight/SeparateAnim/Idle.png", 1, 4.0, true],
				"walk": [PACK + "Character/Knight/SeparateAnim/Walk.png", 4, 6.0, true],
				"attack": [PACK + "Character/Knight/SeparateAnim/Attack.png", 1, 20.0, false],
				"hurt": [PACK + "Character/Knight/SeparateAnim/Idle.png", 1, 12.0, false],
			}
		),
	]

	for fig in figures:
		_build_sprite_frames(fig)
		_build_anim_library(fig)
	quit()


func _build_sprite_frames(fig: FigureDef) -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for action: String in fig.sheets:
		var sheet_path: String = fig.sheets[action][0]
		var frame_count: int = fig.sheets[action][1]
		var fps: float = fig.sheets[action][2]
		var loops: bool = fig.sheets[action][3]
		var tex: Texture2D = load(sheet_path) as Texture2D
		if tex == null:
			push_error("Sheet fehlt: %s" % sheet_path)
			return
		var expected := Vector2i(DIRS.size() * fig.cell, frame_count * fig.cell)
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
				at.region = Rect2(col * fig.cell, row * fig.cell, fig.cell, fig.cell)
				sf.add_frame(anim_name, at)
	var err := ResourceSaver.save(sf, fig.frames_path)
	print("SpriteFrames %s: %s (%d Anims)" % [fig.frames_path, error_string(err), sf.get_animation_names().size()])


## Baut die `attack`-Animation. Zeiten kommen aus den Frame-Werten der TuningStats der Figur —
## eine einzige Quelle der Wahrheit fuer das Angriffstiming.
func _build_anim_library(fig: FigureDef) -> void:
	var stats: TuningStats = load(fig.stats_path) as TuningStats
	if stats == null:
		push_error("TuningStats fehlt: %s" % fig.stats_path)
		return
	var startup: int = stats.attack_startup_frames
	var active: int = stats.attack_active_frames
	var recovery: int = stats.attack_recovery_frames
	var total: int = startup + active + recovery
	var sprite_frames: int = fig.sheets["attack"][1]

	var anim := Animation.new()
	anim.length = total / PHYS_FPS

	# Track 0: Sprite-Frame. Die vorhandenen Sprite-Frames werden gleichmaessig ueber die
	# Gesamtdauer verteilt. Bei nur einer Pose (Zwerg) bleibt es ein einziger Key -> gehaltene Pose.
	var value_track := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(value_track, NodePath("AnimatedSprite2D:frame"))
	anim.value_track_set_update_mode(value_track, Animation.UPDATE_DISCRETE)
	for f in sprite_frames:
		var t: float = (float(f) / float(sprite_frames)) * anim.length
		anim.track_insert_key(value_track, t, f)

	# Track 1: Call-Method-Track fuers frame-genaue Hitbox-Toggling (CLAUDE.md: nie per Timer).
	var method_track := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(method_track, NodePath("."))
	anim.track_insert_key(method_track, startup / PHYS_FPS, {"method": &"enable_hitbox", "args": []})
	anim.track_insert_key(method_track, (startup + active) / PHYS_FPS, {"method": &"disable_hitbox", "args": []})

	var lib := AnimationLibrary.new()
	lib.add_animation(&"attack", anim)
	var err := ResourceSaver.save(lib, fig.anims_path)
	print("AnimLibrary %s: %s (len %.3fs, %d/%d/%d F, %d Sprite-Frames, Hitbox %.3f..%.3f)" % [
		fig.anims_path, error_string(err), anim.length, startup, active, recovery, sprite_frames,
		startup / PHYS_FPS, (startup + active) / PHYS_FPS])
