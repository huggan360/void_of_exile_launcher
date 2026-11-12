class_name InkWeapon
extends TextureRect
## The game's ink loader: a bow, wand or trident firing in six frames at 5 fps.

const WEAPONS := ["bow", "wand", "trident"]

var _atlas := AtlasTexture.new()
var _frame := 0
var _time := 0.0


func _ready() -> void:
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = MOUSE_FILTER_IGNORE
	material = CanvasItemMaterial.new()
	(material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pick()
	texture = _atlas


func pick() -> void:
	_atlas.atlas = load("res://assets/loader/%s.png" % WEAPONS[randi() % WEAPONS.size()])
	_show(0)


func _show(frame: int) -> void:
	var w := _atlas.atlas.get_width() / 3.0
	var h := _atlas.atlas.get_height() / 2.0
	_atlas.region = Rect2((frame % 3) * w, (frame / 3) * h, w, h)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	if _time >= 0.2:
		_time -= 0.2
		_frame = (_frame + 1) % 6
		_show(_frame)
