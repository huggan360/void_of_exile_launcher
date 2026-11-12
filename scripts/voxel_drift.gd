class_name VoxelDrift
extends Control
## Isometric voxels rising slowly over the background, like void motes.

const PALETTE := [Color("f1ede6"), Color("d9d4ca"), Color("8f8a82"), Color("3d3b38"), Color("9e8cff"), Color("82d7ed"), Color("e5b96d")]

var _cubes: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_rng.seed = 11
	for i in 34:
		_cubes.append(_spawn(true))


func _spawn(anywhere: bool) -> Dictionary:
	var accent := _rng.randf() < 0.2
	return {
		pos = Vector2(_rng.randf(), _rng.randf_range(0.0, 1.1) if anywhere else 1.08),
		size = [5.0, 8.0, 11.0, 15.0][_rng.randi() % 4],
		speed = _rng.randf_range(0.012, 0.035),
		drift = _rng.randf_range(-0.012, 0.012),
		phase = _rng.randf() * TAU,
		alpha = _rng.randf_range(0.2, 0.75),
		color = PALETTE[4 + _rng.randi() % 3] if accent else PALETTE[_rng.randi() % 4],
	}


func _process(delta: float) -> void:
	for i in _cubes.size():
		var c := _cubes[i]
		c.pos.y -= c.speed * delta
		c.pos.x += sin(Time.get_ticks_msec() / 1400.0 + c.phase) * c.drift * delta
		if c.pos.y < -0.06:
			_cubes[i] = _spawn(false)
	queue_redraw()


func _draw() -> void:
	for c in _cubes:
		var p := Vector2(c.pos.x * size.x, c.pos.y * size.y)
		var s: float = c.size
		# Fade in from the bottom and out at the top.
		var a: float = c.alpha * clampf((1.08 - c.pos.y) * 4.0, 0.0, 1.0) * clampf((c.pos.y + 0.06) * 6.0, 0.0, 1.0)
		var col: Color = c.color
		var top := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, -s * 0.5), p, p + Vector2(-s, -s * 0.5)])
		var left := PackedVector2Array([p + Vector2(-s, -s * 0.5), p, p + Vector2(0, s), p + Vector2(-s, s * 0.5)])
		var right := PackedVector2Array([p, p + Vector2(s, -s * 0.5), p + Vector2(s, s * 0.5), p + Vector2(0, s)])
		draw_colored_polygon(top, Color(col.lightened(0.15), a))
		draw_colored_polygon(left, Color(col.darkened(0.3), a))
		draw_colored_polygon(right, Color(col.darkened(0.55), a))
