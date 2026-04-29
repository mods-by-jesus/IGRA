extends PanelContainer
class_name CardUI

## Карта юнита в руке игрока
## Отображает арт, название, статы, описание и стоимость.

signal card_clicked(unit_data: UnitData)

var unit_data: UnitData
var _is_affordable: bool = true
var _base_style: StyleBoxFlat

var _portrait: TextureRect
var _name_label: Label
var _stats_label: Label
var _desc_label: Label
var _cost_panel: Control
var _cost_label: Label


func setup(data: UnitData) -> void:
	unit_data = data
	_build_ui()
	_update_affordability()

	GameManager.gold_changed.connect(_on_gold_changed)


func _build_ui() -> void:
	custom_minimum_size = Vector2(185, 290)

	# --- Стиль панели (основа) ---
	_base_style = StyleBoxFlat.new()
	_base_style.bg_color = Color(0.10, 0.10, 0.13, 0.97)
	_base_style.border_color = Color(0.28, 0.28, 0.33)
	_base_style.set_border_width_all(2)
	_base_style.set_corner_radius_all(10)
	_base_style.set_content_margin_all(10)
	_base_style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	_base_style.shadow_size = 6
	_base_style.shadow_offset = Vector2(0, 3)
	add_theme_stylebox_override("panel", _base_style)

	# --- Контейнер ---
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	# --- Портрет (с рамкой) ---
	var portrait_frame := PanelContainer.new()
	portrait_frame.clip_contents = true
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pf_style := StyleBoxFlat.new()
	pf_style.bg_color = Color(0.08, 0.08, 0.1)
	pf_style.set_corner_radius_all(6)
	pf_style.set_border_width_all(1)
	pf_style.border_color = Color(0.22, 0.22, 0.26)
	pf_style.set_content_margin_all(3)
	portrait_frame.add_theme_stylebox_override("panel", pf_style)
	vbox.add_child(portrait_frame)

	var p_control := Control.new()
	p_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_control.clip_contents = true
	p_control.custom_minimum_size = Vector2(160, 140)
	portrait_frame.add_child(p_control)

	_portrait = TextureRect.new()
	_portrait.texture = unit_data.portrait
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p_control.add_child(_portrait)
	
	# Создаём оверлей поверх карточки для иконок
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 5  # Гарантирует отрисовку поверх соседних карт
	add_child(overlay)

	# Размеры иконок для карты
	var icon_d: float = 24.0
	var badge_font: int = 23  # В 1.5 раза больше

	# Стоимость (Левый верхний угол, вылезает за край)
	_cost_panel = _create_icon(
		preload("res://assets/sprites/coin.png"),
		Vector2(0, 0),
		icon_d, str(unit_data.cost), badge_font
	)
	overlay.add_child(_cost_panel)
	
	# ХП (Правый верхний угол, вылезает за край)
	var hp_arr := _create_icon_with_ref(
		preload("res://assets/sprites/hp.png"),
		Vector2(165, 0),
		icon_d, str(unit_data.max_hp), badge_font
	)
	overlay.add_child(hp_arr[0])

	# УРОН (Под ХП справа, вылезает за край)
	var atk_arr := _create_icon_with_ref(
		preload("res://assets/sprites/damage.png"),
		Vector2(165, icon_d + 4),
		icon_d, str(unit_data.attack_power), badge_font
	)
	overlay.add_child(atk_arr[0])
	
	# ИМЯ КЛАССА (Плашка внизу портрета)
	var name_panel := PanelContainer.new()
	name_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color(0.12, 0.12, 0.15, 0.92)
	ns.set_corner_radius_all(5)
	ns.set_border_width_all(1)
	ns.border_color = Color(0.35, 0.35, 0.4, 0.6)
	ns.content_margin_left = 6
	ns.content_margin_right = 6
	ns.content_margin_top = 1
	ns.content_margin_bottom = 1
	name_panel.add_theme_stylebox_override("panel", ns)

	_name_label = Label.new()
	_name_label.text = unit_data.unit_name
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_panel.add_child(_name_label)
	
	p_control.add_child(name_panel)
	name_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	name_panel.position = Vector2(80 - 40, 140 - 20)

	# --- Мини-сетки (центрированные) ---
	var grids_hbox := HBoxContainer.new()
	grids_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	grids_hbox.add_theme_constant_override("separation", 8)
	grids_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var move_grid := _create_mini_grid(unit_data.move_range, false, UnitData.AttackPattern.NORMAL)
	var atk_grid := _create_mini_grid(unit_data.attack_range, true, unit_data.attack_pattern)
	
	grids_hbox.add_child(move_grid)
	grids_hbox.add_child(atk_grid)
	vbox.add_child(grids_hbox)


func _create_icon(tex: Texture2D, center: Vector2, diameter: float, text: String, fsize: int) -> Control:
	var arr := _create_icon_with_ref(tex, center, diameter, text, fsize)
	return arr[0]


func _create_icon_with_ref(tex: Texture2D, center: Vector2, diameter: float, text: String, fsize: int) -> Array:
	var tr := TextureRect.new()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size = Vector2(diameter, diameter)
	tr.position = Vector2(center.x - diameter / 2.0, center.y - diameter / 2.0)

	var lb := Label.new()
	lb.text = text
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", fsize)
	lb.add_theme_color_override("font_color", Color.WHITE)
	# Добавляем жирную чёрную обводку
	lb.add_theme_constant_override("outline_size", 6)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	# И тень
	lb.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lb.add_theme_constant_override("shadow_offset_x", 1)
	lb.add_theme_constant_override("shadow_offset_y", 1)
	lb.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Смещаем цифру на 8 пикселей вверх
	lb.offset_top -= 8
	lb.offset_bottom -= 8	
	tr.add_child(lb)

	return [tr, lb]


## Мини-сетка: 5x5 поле, центр — юнит, подсвечены клетки куда он может ходить или бить
func _create_mini_grid(grid_range: int, is_attack: bool, pattern: UnitData.AttackPattern) -> PanelContainer:
	var wrapper := PanelContainer.new()
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrapper_style := StyleBoxFlat.new()
	wrapper_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	wrapper_style.set_corner_radius_all(4)
	wrapper_style.set_border_width_all(1)
	wrapper_style.border_color = Color(0.2, 0.2, 0.25)
	wrapper_style.set_content_margin_all(4)
	wrapper.add_theme_stylebox_override("panel", wrapper_style)

	var grid_size: int = max(5, grid_range * 2 + 1)
	var max_grid_px: float = 70.0
	var gap: float = 1.0 if grid_size > 7 else 2.0
	var cell_px: float = max(2.0, (max_grid_px - gap * (grid_size - 1)) / float(grid_size))
	var center: int = grid_size / 2

	var grid := GridContainer.new()
	grid.columns = grid_size
	grid.add_theme_constant_override("h_separation", int(gap))
	grid.add_theme_constant_override("v_separation", int(gap))
	wrapper.add_child(grid)

	for row in range(grid_size):
		for col in range(grid_size):
			var cell := Panel.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.custom_minimum_size = Vector2(cell_px, cell_px)

			var dx: int = abs(col - center)
			var dy: int = row - center # тут используем реальный dy, чтобы понимать где "перед"
			var is_center: bool = (dx == 0 and dy == 0)
			
			var is_reachable: bool = false
			if not is_center:
				if is_attack:
					if pattern == UnitData.AttackPattern.FORWARD_CONE:
						# В мини-сетке "вперед" это вверх (dy < 0). Показываем лучи (прямо и по диагоналям).
						# Т.е. abs(dx) == abs(dy) (диагонали) ИЛИ dx == 0 (прямо).
						is_reachable = (dy < 0 and dy >= -grid_range and (dx == 0 or dx == abs(dy)))
					else:
						# Обычный квадрат
						is_reachable = max(dx, abs(dy)) <= grid_range
				else:
					is_reachable = (dx == 0 or dy == 0) and (dx + abs(dy)) <= grid_range

			var cs := StyleBoxFlat.new()
			cs.set_corner_radius_all(1)

			if is_center:
				# Клетка юнита — выделенная (одинаково для обеих)
				cs.bg_color = Color(0.4, 0.6, 1.0, 0.9)
				cs.set_border_width_all(1)
				cs.border_color = Color(0.5, 0.7, 1.0, 0.8)
			elif is_reachable:
				if is_attack:
					cs.bg_color = Color(0.9, 0.3, 0.3, 0.5)
					cs.set_border_width_all(1)
					cs.border_color = Color(0.9, 0.3, 0.3, 0.3)
				else:
					cs.bg_color = Color(0.3, 0.7, 1.0, 0.35)
					cs.set_border_width_all(1)
					cs.border_color = Color(0.3, 0.7, 1.0, 0.25)
			else:
				# Пустая клетка
				cs.bg_color = Color(0.15, 0.15, 0.18, 0.6)

			cell.add_theme_stylebox_override("panel", cs)
			grid.add_child(cell)

	return wrapper


func _on_gold_changed(_new_gold: int) -> void:
	_update_affordability()


func _update_affordability() -> void:
	if unit_data == null:
		return
	if GameManager.game_active:
		_is_affordable = GameManager.gold >= unit_data.cost
	else:
		# В лобби карты всегда доступны
		_is_affordable = true
	modulate.a = 1.0 if _is_affordable else 0.35


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _is_affordable:
				card_clicked.emit(unit_data)
				accept_event()


## Hover-эффект: подсветка рамки (масштаб управляется из Hand)
func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER and _is_affordable:
		_base_style.border_color = Color(0.55, 0.6, 0.7)
		_base_style.shadow_size = 12
	elif what == NOTIFICATION_MOUSE_EXIT:
		_base_style.border_color = Color(0.28, 0.28, 0.33)
		_base_style.shadow_size = 6
