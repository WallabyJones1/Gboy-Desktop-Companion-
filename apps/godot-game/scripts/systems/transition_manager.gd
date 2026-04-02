extends CanvasLayer

## Screen transition manager for level changes

var transition_rect: ColorRect
var is_transitioning: bool = false


func _ready() -> void:
	layer = 100
	transition_rect = ColorRect.new()
	transition_rect.color = Color(0, 0, 0, 0)
	transition_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(transition_rect)


func transition_to(scene_path: String, duration: float = 0.5) -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# Fade to black
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, duration)
	await tween.finished

	# Change scene
	get_tree().change_scene_to_file(scene_path)

	# Fade from black
	await get_tree().process_frame
	var tween2 = create_tween()
	tween2.tween_property(transition_rect, "color:a", 0.0, duration)
	await tween2.finished
	is_transitioning = false


func fade_in(duration: float = 0.5) -> void:
	transition_rect.color.a = 1.0
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 0.0, duration)
	await tween.finished


func fade_out(duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(transition_rect, "color:a", 1.0, duration)
	await tween.finished
