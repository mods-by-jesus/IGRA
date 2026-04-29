extends Node2D
class_name Unit

## Юнит на игровом поле

signal died(owner_id: int)

## Данные типа юнита
var unit_data: UnitData
## Сгенерированное имя юнита
var unit_display_name: String = ""
## Текущее здоровье
var current_hp: int = 0
## Позиция на сетке
var grid_pos: Vector2i = Vector2i.ZERO
## Может ли действовать в этом ходу
var can_act: bool = true
## Может ли двигаться в этом ходу
var can_move: bool = true
## Может ли атаковать в этом ходу
var can_attack: bool = true
## Владелец юнита (0 = хост, 1 = клиент)
var owner_id: int = 0

var _bg_panel: Panel
var _sprite: Sprite2D
var _hp_label: Label
var _hp_panel: Panel
var _atk_label: Label
var _name_panel: PanelContainer
var _name_label: Label
var _cost_panel: Panel
var _cell_size: float = 64.0
var _exhausted_overlay: Panel

var _idle_time: float = 0.0
var _idle_offset: float = 0.0
var _base_sprite_y: float = 0.0


func setup(data: UnitData, display_name: String, cell_sz: float, p_owner_id: int = 0) -> void:
	unit_data = data
	unit_display_name = display_name
	current_hp = data.max_hp
	_cell_size = cell_sz
	owner_id = p_owner_id
	_idle_offset = randf() * TAU
	
	# Линейная фильтрация для ВСЕГО юнита — убираем пикселизацию
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	_build_visuals()


func _build_visuals() -> void:
	var half := _cell_size / 2.0
	var bg_size := _cell_size * 0.92

	# --- Подложка ---
	_bg_panel = Panel.new()
	_bg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.10, 0.10, 0.13, 0.92)
	bg_style.set_corner_radius_all(10)
	bg_style.set_border_width_all(2)
	# Цвет рамки по владельцу
	if owner_id == 0:
		bg_style.border_color = Color(0.3, 0.5, 0.8) # Синий - игрок 1
	else:
		bg_style.border_color = Color(0.8, 0.3, 0.3) # Красный - игрок 2
	bg_style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	bg_style.shadow_size = 6
	bg_style.shadow_offset = Vector2(0, 3)
	_bg_panel.add_theme_stylebox_override("panel", bg_style)
	_bg_panel.size = Vector2(bg_size, bg_size)
	_bg_panel.position = Vector2(-bg_size / 2.0, -bg_size / 2.0)
	add_child(_bg_panel)

	# --- Спрайт юнита ---
	_sprite = Sprite2D.new()
	_sprite.texture = unit_data.portrait
	if _sprite.texture:
		var tex_size := _sprite.texture.get_size()
		var scale_factor: float = (_cell_size * 0.7) / max(tex_size.x, tex_size.y)
		_sprite.scale = Vector2(scale_factor, scale_factor)
		_sprite.position.y = -_cell_size * 0.04
	_base_sprite_y = _sprite.position.y
	add_child(_sprite)

	# --- Размеры кружков (пропорционально клетке) ---
	var circle_r: float = _cell_size * 0.105  # -25% от 0.14
	var circle_d: float = circle_r * 2.0
	var badge_font: int = max(8, int(_cell_size * 0.12))  # -25% от 0.16
	var small_font: int = max(8, int(_cell_size * 0.12))

	# --- СТОИМОСТЬ (Желтый кружок, левый верхний угол) ---
	_cost_panel = _create_circle(
		Color(0.92, 0.78, 0.12),
		Vector2(-half + circle_r + 2, -half + circle_r + 2),
		circle_d, str(unit_data.cost), badge_font
	)

	# --- ХП (Зелёный кружок, правый верхний угол) ---
	var hp_arr := _create_circle_with_ref(
		Color(0.22, 0.72, 0.32),
		Vector2(half - circle_r - 2, -half + circle_r + 2),
		circle_d, str(current_hp), badge_font
	)
	_hp_panel = hp_arr[0]
	_hp_label = hp_arr[1]

	# --- УРОН (Красный кружок, под ХП справа) ---
	var atk_arr := _create_circle_with_ref(
		Color(0.88, 0.22, 0.18),
		Vector2(half - circle_r - 2, -half + circle_r * 3 + 6),
		circle_d, str(unit_data.attack_power), badge_font
	)
	_atk_label = atk_arr[1]

	# --- НАЗВАНИЕ КЛАССА (Плашка внизу) ---
	_name_panel = PanelContainer.new()
	_name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(0.12, 0.12, 0.15, 0.92)
	ns.set_corner_radius_all(5)
	ns.set_border_width_all(1)
	ns.border_color = Color(0.35, 0.35, 0.4, 0.6)
	ns.content_margin_left = 6
	ns.content_margin_right = 6
	ns.content_margin_top = 1
	ns.content_margin_bottom = 1
	_name_panel.add_theme_stylebox_override("panel", ns)

	_name_label = Label.new()
	_name_label.text = unit_data.unit_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", small_font)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_panel.add_child(_name_label)

	add_child(_name_panel)
	_name_panel.force_update_transform()
	_name_panel.position = Vector2(-_name_panel.size.x / 2.0, half - _name_panel.size.y - 4)

	# --- Оверлей «отходил» ---
	_exhausted_overlay = Panel.new()
	_exhausted_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var eo_style := StyleBoxFlat.new()
	eo_style.bg_color = Color(0.0, 0.0, 0.0, 0.35)
	eo_style.set_corner_radius_all(10)
	_exhausted_overlay.add_theme_stylebox_override("panel", eo_style)
	_exhausted_overlay.size = Vector2(bg_size, bg_size)
	_exhausted_overlay.position = Vector2(-bg_size / 2.0, -bg_size / 2.0)
	_exhausted_overlay.visible = false
	add_child(_exhausted_overlay)

	_update_hp_display()


## Создаёт кружок-бейдж и возвращает Panel (без ссылки на лейбл)
func _create_circle(color: Color, center: Vector2, diameter: float, text: String, fsize: int) -> Panel:
	var arr := _create_circle_with_ref(color, center, diameter, text, fsize)
	return arr[0]


## Создаёт кружок-бейдж и возвращает [Panel, Label]
func _create_circle_with_ref(color: Color, center: Vector2, diameter: float, text: String, fsize: int) -> Array:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(100)
	st.set_border_width_all(2)
	st.border_color = Color(0, 0, 0, 0.6)
	st.shadow_color = Color(0, 0, 0, 0.3)
	st.shadow_size = 3
	st.shadow_offset = Vector2(0, 1)
	p.add_theme_stylebox_override("panel", st)
	p.size = Vector2(diameter, diameter)
	p.position = Vector2(center.x - diameter / 2.0, center.y - diameter / 2.0)

	var lb := Label.new()
	lb.text = text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", fsize)
	lb.add_theme_color_override("font_color", Color.WHITE)
	lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lb.add_theme_constant_override("shadow_offset_x", 1)
	lb.add_theme_constant_override("shadow_offset_y", 1)
	lb.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.add_child(lb)

	add_child(p)
	return [p, lb]


func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	_update_hp_display()
	if current_hp <= 0:
		die()


func die() -> void:
	died.emit(owner_id)
	var board := get_parent() as Board
	if board:
		board.free_cell(grid_pos)
		if board.selected_unit == self:
			board.selected_unit = null
			board.is_combat_mode = false
			board.update_reachable_cells()
	queue_free()


func _update_hp_display() -> void:
	if _hp_label == null or unit_data == null:
		return
	_hp_label.text = str(current_hp)

	var ratio: float = float(current_hp) / float(unit_data.max_hp)
	var st = _hp_panel.get_theme_stylebox("panel") as StyleBoxFlat

	if st:
		if ratio > 0.6:
			st.bg_color = Color(0.22, 0.72, 0.32, 0.95)
		elif ratio > 0.3:
			st.bg_color = Color(0.9, 0.6, 0.1, 0.95)
		else:
			st.bg_color = Color(0.5, 0.15, 0.15, 0.95)


## Сброс действий на новый ход
func reset_actions() -> void:
	can_act = true
	can_move = true
	can_attack = true
	_exhausted_overlay.visible = false
	modulate = Color.WHITE


## Проверяет, исчерпал ли юнит все действия, и если да — помечает его
func check_exhaustion() -> void:
	if not can_move and not can_attack:
		mark_exhausted()


## Визуально пометить юнита как отходившего
func mark_exhausted() -> void:
	_exhausted_overlay.visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.6, 0.6, 0.65), 0.3).set_trans(Tween.TRANS_QUAD)


func _process(delta: float) -> void:
	if _sprite == null:
		return

	# Если действия кончились, плавно возвращаем спрайт на базовую позицию и перестаем дышать
	if not can_move and not can_attack:
		_sprite.position.y = lerp(_sprite.position.y, _base_sprite_y, 10.0 * delta)
		return

	_idle_time += delta
	# Idle: мягкое покачивание вверх-вниз (дыхание)
	var breath: float = sin((_idle_time + _idle_offset) * 2.0) * _cell_size * 0.012
	_sprite.position.y = _base_sprite_y + breath
