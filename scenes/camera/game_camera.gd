extends Camera2D
class_name GameCamera

## Камера с WASD, перетаскиванием на СКМ и зумом колёсиком к курсору

## Скорость перемещения WASD (пикс/сек)
@export_range(50, 2000) var move_speed: float = 500.0
## Множитель скорости зума
@export_range(0.01, 0.5) var zoom_speed: float = 0.1
## Минимальный зум (максимальное отдаление)
@export_range(0.1, 1.0) var min_zoom: float = 0.2
## Максимальный зум (максимальное приближение)
@export_range(1.0, 10.0) var max_zoom: float = 5.0
## Плавность камеры (чем больше — тем резче)
@export_range(1.0, 50.0) var smoothing_speed: float = 12.0

var _target_position: Vector2
var _target_zoom: float = 1.0
var _is_dragging: bool = false
var _drag_start_mouse: Vector2
var _drag_start_camera: Vector2


var _exact_position: Vector2

func _ready() -> void:
	_target_position = position
	_exact_position = position
	_target_zoom = zoom.x


func _process(delta: float) -> void:
	_handle_wasd_movement(delta)
	
	# Плавная интерполяция точной позиции
	_exact_position = _exact_position.lerp(_target_position, smoothing_speed * delta)
	
	# Привязка к целым пикселям — устраняет мерцание сетки, 
	# но математика внутри (_exact_position) остается плавной
	position = _exact_position.round()

	var current_zoom := lerpf(zoom.x, _target_zoom, smoothing_speed * delta)
	zoom = Vector2(current_zoom, current_zoom)


func _handle_wasd_movement(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): direction.y -= 1.0
	if Input.is_key_pressed(KEY_S): direction.y += 1.0
	if Input.is_key_pressed(KEY_A): direction.x -= 1.0
	if Input.is_key_pressed(KEY_D): direction.x += 1.0

	if direction != Vector2.ZERO:
		# Скорость обратно пропорциональна зуму: при отдалении двигаемся быстрее
		var speed_modifier := 1.0 / _target_zoom
		_target_position += direction.normalized() * move_speed * speed_modifier * delta


func _unhandled_input(event: InputEvent) -> void:
	# --- СКМ: перетаскивание ---
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE:
			if mouse_event.pressed:
				_is_dragging = true
				_drag_start_mouse = mouse_event.position
				_drag_start_camera = _target_position
			else:
				_is_dragging = false

		# --- Колёсико: зум к курсору ---
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_towards_mouse(mouse_event.position, zoom_speed)
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_towards_mouse(mouse_event.position, -zoom_speed)

	elif event is InputEventMouseMotion and _is_dragging:
		var mouse_event := event as InputEventMouseMotion
		var mouse_delta := mouse_event.position - _drag_start_mouse
		_target_position = _drag_start_camera - mouse_delta / zoom


func _zoom_towards_mouse(mouse_screen_pos: Vector2, delta: float) -> void:
	# Запоминаем мировую точку под курсором ДО зума
	var mouse_world_before := _screen_to_world(mouse_screen_pos, _target_zoom)

	# Применяем зум
	_target_zoom = clampf(_target_zoom + delta, min_zoom, max_zoom)

	# Вычисляем куда сместилась та же точка ПОСЛЕ зума
	var mouse_world_after := _screen_to_world(mouse_screen_pos, _target_zoom)

	# Корректируем позицию камеры чтобы точка под мышкой осталась на месте
	_target_position += mouse_world_before - mouse_world_after


func _screen_to_world(screen_pos: Vector2, use_zoom: float) -> Vector2:
	var viewport_size := get_viewport_rect().size
	return _target_position + (screen_pos - viewport_size / 2.0) / use_zoom
