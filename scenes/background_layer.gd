extends Node2D
class_name BackgroundLayer

## Атмосферный фоновый слой — статичный тёмный фон с виньеткой
## Перерисовывается только при движении камеры, а не каждый кадр.

var _last_cam_pos := Vector2.ZERO
var _last_cam_zoom := Vector2.ONE


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	# Перерисовка только при смещении камеры
	if cam.position != _last_cam_pos or cam.zoom != _last_cam_zoom:
		_last_cam_pos = cam.position
		_last_cam_zoom = cam.zoom
		queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return

	var viewport := get_viewport_rect().size
	var cam_pos := cam.position
	var cam_zoom := cam.zoom
	var world_size := viewport / cam_zoom
	var top_left := cam_pos - world_size / 2.0

	# 1) Основной тёмный фон
	var bg_rect := Rect2(top_left, world_size)
	draw_rect(bg_rect, Color(0.04, 0.04, 0.06))

	# 2) Центральная виньетка (мало прямоугольников — лёгкая)
	var center := cam_pos
	for i in range(5, 0, -1):
		var t: float = float(i) / 5.0
		var ring_size := world_size * t * 0.55
		var ring_rect := Rect2(center - ring_size / 2.0, ring_size)
		var alpha: float = (1.0 - t) * 0.04
		draw_rect(ring_rect, Color(0.15, 0.18, 0.22, alpha))
