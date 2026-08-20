class_name Hurtbox
extends Area2D

signal hit_taken(damage: int, knockback: Vector2)

@export var iframe_duration: float = 0.6
@export var iframe_blink_interval: float = 0.06
@export var sprite: CanvasItem  # zum Blinken (modulate.a)

var _invulnerable: bool = false
var _iframe_left: float = 0.0

func take_hit(damage: int, knockback: Vector2) -> bool:
	if _invulnerable:
		return false
	hit_taken.emit(damage, knockback)
	_invulnerable = true
	_iframe_left = iframe_duration
	return true

func _process(delta: float) -> void:
	if _invulnerable:
		_iframe_left -= delta
		var elapsed: float = iframe_duration - _iframe_left
		if sprite:
			sprite.modulate.a = 0.35 if (int(elapsed / iframe_blink_interval) % 2 == 0) else 1.0
		if _iframe_left <= 0.0:
			_invulnerable = false
			if sprite:
				sprite.modulate.a = 1.0
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
	var color: Color = Color.CYAN if _invulnerable else Color.GREEN
	var half: Vector2 = rect_shape.size * 0.5
	var pos: Vector2 = shape_node.position
	draw_rect(Rect2(pos - half, rect_shape.size), color, false, 1.0)

func is_invulnerable() -> bool:
	return _invulnerable
