class_name Hitbox
extends Area2D

@export var damage: int = 1
@export var knockback_speed: float = 220.0
@export var hitstop_frames: int = 6

var knockback_dir: Vector2 = Vector2.DOWN
var _already_hit: Array[Hurtbox] = []

func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)

func enable() -> void:
	_already_hit.clear()
	monitoring = true
	if Debug.show_boxes:
		queue_redraw()

func disable() -> void:
	monitoring = false
	if Debug.show_boxes:
		queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	if area is Hurtbox and not _already_hit.has(area):
		_already_hit.append(area)
		var hb: Hurtbox = area as Hurtbox
		var knockback: Vector2 = knockback_dir * knockback_speed
		if hb.take_hit(damage, knockback):
			HitstopManager.hitstop(hitstop_frames, [get_parent(), hb.get_parent()])

func _process(_delta: float) -> void:
	if Debug.show_boxes:
		queue_redraw()

func _draw() -> void:
	if not Debug.show_boxes:
		return
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var rect_shape: RectangleShape2D = shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return
	var color: Color = Color.ORANGE if monitoring else Color.RED
	var half: Vector2 = rect_shape.size * 0.5
	var pos: Vector2 = shape_node.position
	draw_rect(Rect2(pos - half, rect_shape.size), color, false, 1.0)
