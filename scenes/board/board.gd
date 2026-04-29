extends Node2D
class_name Board

## Тактическое игровое поле — серая сетка клеток
## Шахматный паттерн, адаптивные линии, подсветка зон и выбора.

## Количество столбцов
signal unit_inspected(unit_data: UnitData, is_inspecting: bool)

@export_range(4, 20) var grid_columns: int = 8
## Количество строк
@export_range(4, 20) var grid_rows: int = 8
## Размер одной клетки в пикселях
@export_range(32, 256) var cell_size: int = 64
## Визуальная толщина разделителей (в экранных пикселях)
@export_range(0.5, 4.0) var line_screen_width: float = 1.0
## Количество рядов зоны деплоя (с каждой стороны)
@export_range(1, 5) var deploy_rows: int = 3

## --- Цветовая палитра ---
@export var cell_light: Color = Color(0.16, 0.16, 0.18)
@export var cell_dark: Color = Color(0.13, 0.13, 0.15)
@export var line_color: Color = Color(0.22, 0.22, 0.25)
@export var deploy_light: Color = Color(0.16, 0.21, 0.16)
@export var deploy_dark: Color = Color(0.13, 0.18, 0.13)
@export var hover_color: Color = Color(0.28, 0.28, 0.32)
@export var invalid_color: Color = Color(0.28, 0.14, 0.14)
@export var move_dot_color: Color = Color(0.3, 0.7, 1.0, 0.5)
@export var move_dot_hover_color: Color = Color(0.4, 0.85, 1.0, 0.8)
@export var selected_outline_color: Color = Color(0.4, 0.85, 1.0, 0.7)

var hovered_cell: Vector2i = Vector2i(-1, -1)
var show_deploy_zone: bool = false
var selected_unit: Node2D = null
## Текущий инспектируемый юнит
var inspected_unit: Node2D = null

## Режим боя: если true, то клик ЛКМ — это атака, а не движение
var is_combat_mode: bool = false

## Режим предпросмотра (TAB): если true, показываем радиус атаки, иначе радиус хода
var preview_is_attack: bool = false

var reachable_cells: Array[Vector2i] = []
var attackable_cells: Array[Vector2i] = []
var preview_reachable_cells: Array[Vector2i] = []

var time_passed: float = 0.0
var occupied_cells: Dictionary = {}

var _overlay: Node2D
var _needs_redraw := true

func _ready() -> void:
	_overlay = Node2D.new()
	_overlay.z_index = 100
	add_child(_overlay)
	_overlay.draw.connect(_on_overlay_draw)
	
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	GameManager.deploy_mode_started.connect(_on_deploy_started)
	GameManager.deploy_mode_ended.connect(_on_deploy_ended)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.player_changed.connect(_on_player_changed)


func _on_deploy_started(_unit_data: UnitData) -> void:
	show_deploy_zone = true
	_needs_redraw = true


func _on_deploy_ended() -> void:
	show_deploy_zone = false
	_needs_redraw = true


func _on_phase_changed(new_phase: int) -> void:
	if new_phase == GameManager.Phase.ACTION:
		# Сброс действий юнитов ТЕКУЩЕГО игрока при начале хода
		for cell in occupied_cells:
			var unit: Unit = occupied_cells[cell]
			if unit.owner_id == GameManager.current_player:
				unit.reset_actions()
		selected_unit = null
		update_reachable_cells()
		_needs_redraw = true


func _on_player_changed(_player_id: int) -> void:
	selected_unit = null
	update_reachable_cells()
	_needs_redraw = true


func _process(delta: float) -> void:
	time_passed += delta
	
	# TAB preview handling
	var is_tab_pressed := Input.is_key_pressed(KEY_TAB)
	if is_tab_pressed:
		var unit: Unit = null
		if is_valid_cell(hovered_cell) and is_cell_occupied(hovered_cell):
			unit = occupied_cells[hovered_cell] as Unit
		
		if inspected_unit != unit:
			inspected_unit = unit
			preview_is_attack = false
			_update_tab_preview()
			_needs_redraw = true
			if inspected_unit != null:
				unit_inspected.emit((inspected_unit as Unit).unit_data, true)
			else:
				unit_inspected.emit(null, false)
	elif inspected_unit != null:
		inspected_unit = null
		preview_is_attack = false
		preview_reachable_cells.clear()
		_needs_redraw = true
		unit_inspected.emit(null, false)
	
	# Перерисовка только при выбранном юните (пульсация) или изменении состояния
	if _needs_redraw or selected_unit != null:
		queue_redraw()
		if _overlay:
			_overlay.queue_redraw()
		_needs_redraw = false


func _update_tab_preview() -> void:
	preview_reachable_cells.clear()
	if inspected_unit != null:
		if preview_is_attack:
			preview_reachable_cells = _calculate_attackable_cells(inspected_unit as Unit)
		else:
			preview_reachable_cells = _calculate_reachable_cells(inspected_unit as Unit)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE and key_event.pressed:
			if GameManager.is_deploying:
				GameManager.cancel_deploy()
			elif selected_unit != null:
				selected_unit = null
				is_combat_mode = false
				update_reachable_cells()
				_needs_redraw = true

	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		var world_pos := _screen_to_world(mouse_event.global_position)
		var new_hovered := world_to_grid(world_pos)
		if new_hovered != hovered_cell:
			hovered_cell = new_hovered
			_needs_redraw = true

	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		
		if Input.is_key_pressed(KEY_TAB):
			if mouse_event.pressed:
				if mouse_event.button_index == MOUSE_BUTTON_LEFT:
					preview_is_attack = false
					_update_tab_preview()
				elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
					preview_is_attack = true
					_update_tab_preview()
			get_viewport().set_input_as_handled()
			return
			
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			var world_pos := _screen_to_world(mouse_event.global_position)
			var grid_pos := world_to_grid(world_pos)
			_on_cell_clicked(grid_pos, MOUSE_BUTTON_LEFT)
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			var world_pos := _screen_to_world(mouse_event.global_position)
			var grid_pos := world_to_grid(world_pos)
			_on_cell_clicked(grid_pos, MOUSE_BUTTON_RIGHT)


func _on_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	if not is_valid_cell(grid_pos):
		# Клик вне поля сбрасывает выделение
		if button == MOUSE_BUTTON_RIGHT and selected_unit != null:
			selected_unit = null
			is_combat_mode = false
			update_reachable_cells()
			_needs_redraw = true
		return

	# Только в свой ход
	if not GameManager.is_my_turn():
		return

	if GameManager.is_deploying:
		if button == MOUSE_BUTTON_RIGHT:
			GameManager.cancel_deploy()
			return
		# Деплой в СВОЮ зону
		if is_deploy_zone(grid_pos, GameManager.my_player_id) and not is_cell_occupied(grid_pos):
			GameManager.try_place_unit(grid_pos)
	
	elif GameManager.current_phase == GameManager.Phase.ACTION:
		var sel_unit: Unit = selected_unit as Unit
		
		# Логика правого клика
		if button == MOUSE_BUTTON_RIGHT:
			if is_cell_occupied(grid_pos):
				var clicked_unit: Unit = occupied_cells[grid_pos]
				# Можно взаимодействовать только со своими
				if clicked_unit.owner_id == GameManager.my_player_id:
					if sel_unit == clicked_unit:
						if is_combat_mode:
							# Повторный ПКМ в режиме атаки полностью снимает выделение
							selected_unit = null
							is_combat_mode = false
						else:
							# ПКМ в режиме ходьбы включает режим атаки
							is_combat_mode = true
					else:
						# ПКМ по другому своему юниту - сразу выделяет и включает боевку
						selected_unit = clicked_unit
						is_combat_mode = true
					update_reachable_cells()
					_needs_redraw = true
				return
			
			# Клик мимо юнитов снимает выделение
			selected_unit = null
			is_combat_mode = false
			update_reachable_cells()
			_needs_redraw = true
			return
			
		# Логика левого клика
		if is_combat_mode and sel_unit != null and sel_unit.can_attack and grid_pos in attackable_cells:
			# Отправляем запрос на атаку (включая удары в пустоту)
			GameManager.request_attack(sel_unit.grid_pos, grid_pos, sel_unit.unit_data.attack_power)
			sel_unit.can_attack = false
			is_combat_mode = false
			selected_unit = null # Снимаем выделение после атаки
			update_reachable_cells()
			_needs_redraw = true
			
		elif not is_combat_mode and sel_unit != null and sel_unit.can_move and grid_pos in reachable_cells:
			# Перемещение через RPC
			GameManager.request_move(sel_unit.grid_pos, grid_pos)
			_needs_redraw = true
			
		elif is_cell_occupied(grid_pos):
			var clicked_unit: Unit = occupied_cells[grid_pos]
			# Можно выбирать только СВОИХ юнитов
			if clicked_unit.owner_id != GameManager.my_player_id:
				return
			if clicked_unit == sel_unit:
				# Повторный ЛКМ включает режим перемещения (если был бой)
				if is_combat_mode:
					is_combat_mode = false
					update_reachable_cells()
				else:
					selected_unit = null
					is_combat_mode = false
					update_reachable_cells()
			else:
				selected_unit = clicked_unit
				is_combat_mode = false
				update_reachable_cells()
		else:
			# Клик в пустую клетку (и не атака, и не перемещение)
			selected_unit = null
			is_combat_mode = false
			update_reachable_cells()


func update_reachable_cells() -> void:
	reachable_cells.clear()
	attackable_cells.clear()
	_needs_redraw = true
	var sel_unit: Unit = selected_unit as Unit
	if sel_unit == null:
		return
	
	if is_combat_mode:
		if sel_unit.can_attack:
			attackable_cells = _calculate_attackable_cells(sel_unit)
	else:
		if sel_unit.can_move:
			reachable_cells = _calculate_reachable_cells(sel_unit)


func _calculate_attackable_cells(unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
		
	var start_pos: Vector2i = unit.grid_pos
	var attack_range: int = unit.unit_data.attack_range
	var pattern: UnitData.AttackPattern = unit.unit_data.attack_pattern
	
	if pattern == UnitData.AttackPattern.NORMAL:
		# Обычный квадрат
		for dx in range(-attack_range, attack_range + 1):
			for dy in range(-attack_range, attack_range + 1):
				if dx == 0 and dy == 0:
					continue
				var check_pos := start_pos + Vector2i(dx, dy)
				if is_valid_cell(check_pos):
					result.append(check_pos)
					
	elif pattern == UnitData.AttackPattern.FORWARD_CONE:
		# Направление "вперед" зависит от команды (владельца)
		var forward_y: int = -1 if unit.owner_id == 0 else 1
		
		# Лучи: прямо (0) и по диагоналям (-1, 1) на длину attack_range
		for r in range(1, attack_range + 1):
			for dx_dir in [-1, 0, 1]:
				var check_pos := start_pos + Vector2i(dx_dir * r, forward_y * r)
				if is_valid_cell(check_pos):
					result.append(check_pos)
	
	return result


func _calculate_reachable_cells(unit: Unit) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if unit == null:
		return result
		
	var start_pos: Vector2i = unit.grid_pos
	var max_range: int = unit.unit_data.move_range
	
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)
	]
	
	for dir in directions:
		for step in range(1, max_range + 1):
			var check_pos: Vector2i = start_pos + dir * step
			if not is_valid_cell(check_pos):
				break
			if is_cell_occupied(check_pos):
				break
			result.append(check_pos)
	
	return result


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam:
		var viewport_size := get_viewport_rect().size
		return cam.position + (screen_pos - viewport_size / 2.0) / cam.zoom
	return screen_pos


# ===================== УТИЛИТЫ СЕТКИ =====================

func _to_canonical(visual_pos: Vector2i) -> Vector2i:
	if GameManager.my_player_id == 1:
		return Vector2i(grid_columns - 1 - visual_pos.x, grid_rows - 1 - visual_pos.y)
	return visual_pos


func _to_visual(grid_pos: Vector2i) -> Vector2i:
	if GameManager.my_player_id == 1:
		return Vector2i(grid_columns - 1 - grid_pos.x, grid_rows - 1 - grid_pos.y)
	return grid_pos


func world_to_grid(world_pos: Vector2) -> Vector2i:
	var board_w: float = grid_columns * cell_size
	var board_h: float = grid_rows * cell_size
	var offset := Vector2(-board_w / 2.0, -board_h / 2.0)
	var local_pos := world_pos - global_position - offset
	var v_col := int(floor(local_pos.x / cell_size))
	var v_row := int(floor(local_pos.y / cell_size))
	var visual_pos := Vector2i(v_col, v_row)
	return _to_canonical(visual_pos)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var board_w: float = grid_columns * cell_size
	var board_h: float = grid_rows * cell_size
	var offset := Vector2(-board_w / 2.0, -board_h / 2.0)
	var visual_pos := _to_visual(grid_pos)
	var x: float = offset.x + visual_pos.x * cell_size + cell_size / 2.0
	var y: float = offset.y + visual_pos.y * cell_size + cell_size / 2.0
	return global_position + Vector2(x, y)


func is_valid_cell(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_columns \
		and grid_pos.y >= 0 and grid_pos.y < grid_rows


func is_deploy_zone(grid_pos: Vector2i, player_id: int) -> bool:
	if not is_valid_cell(grid_pos):
		return false
	if player_id == 0:
		return grid_pos.y >= grid_rows - deploy_rows
	else:
		return grid_pos.y < deploy_rows


func is_cell_occupied(grid_pos: Vector2i) -> bool:
	return occupied_cells.has(grid_pos)


func occupy_cell(grid_pos: Vector2i, unit: Node2D) -> void:
	occupied_cells[grid_pos] = unit


func free_cell(grid_pos: Vector2i) -> void:
	occupied_cells.erase(grid_pos)
	_needs_redraw = true


## Проверить, валидна ли атака с клетки from на клетку to
func is_attack_valid(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not is_cell_occupied(from_pos):
		return false
	var unit := occupied_cells[from_pos] as Unit
	if unit == null or not unit.can_attack:
		return false
	var attackable := _calculate_attackable_cells(unit)
	return to_pos in attackable


## Проверить, валидно ли перемещение с клетки from на клетку to
func is_move_valid(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not is_cell_occupied(from_pos):
		return false
	var unit := occupied_cells[from_pos] as Unit
	if unit == null or not unit.can_move:
		return false
	var reachable := _calculate_reachable_cells(unit)
	return to_pos in reachable


# ===================== ОТРИСОВКА =====================

func _draw() -> void:
	var board_w: float = grid_columns * cell_size
	var board_h: float = grid_rows * cell_size
	var offset := Vector2(-board_w / 2.0, -board_h / 2.0)
	
	var cam_zoom := 1.0
	var cam := get_viewport().get_camera_2d()
	if cam:
		cam_zoom = cam.zoom.x

	var my_pid: int = GameManager.my_player_id

	# 1) Клетки
	for v_row in range(grid_rows):
		for v_col in range(grid_columns):
			var visual_pos := Vector2i(v_col, v_row)
			var grid_pos := _to_canonical(visual_pos)
			var rect_pos := offset + Vector2(v_col * cell_size, v_row * cell_size)
			var rect := Rect2(rect_pos, Vector2(cell_size, cell_size))
			var is_light: bool = (v_col + v_row) % 2 == 0
			var color := cell_light if is_light else cell_dark

			# Подсветка зоны деплоя (своей)
			if show_deploy_zone and is_deploy_zone(grid_pos, my_pid):
				color = deploy_light if is_light else deploy_dark

			# Подсветка выбранного юнита
			if selected_unit != null and (selected_unit as Unit).grid_pos == grid_pos:
				if is_combat_mode:
					color = Color(0.6, 0.2, 0.2) # Красная для боевого режима
				else:
					color = Color(0.2, 0.3, 0.4) # Синяя для перемещения

			# Подсветка при наведении
			if grid_pos == hovered_cell and is_valid_cell(grid_pos):
				if show_deploy_zone:
					if is_deploy_zone(grid_pos, my_pid) and not is_cell_occupied(grid_pos):
						color = hover_color
					else:
						color = invalid_color
				elif is_combat_mode and grid_pos in attackable_cells:
					color = Color(0.5, 0.2, 0.2) # Наведение на цель для атаки
				elif not is_combat_mode and grid_pos in reachable_cells:
					color = Color(0.2, 0.3, 0.35)
				else:
					color = hover_color

			draw_rect(rect, color)

	# 3) Рамка выбранного юнита
	if selected_unit != null:
		var sel_pos: Vector2i = (selected_unit as Unit).grid_pos
		var visual_sel_pos := _to_visual(sel_pos)
		var sel_rect_pos := offset + Vector2(visual_sel_pos.x * cell_size, visual_sel_pos.y * cell_size)
		var inset: float = cell_size * 0.04
		var sel_rect := Rect2(
			sel_rect_pos + Vector2(inset, inset),
			Vector2(cell_size - inset * 2, cell_size - inset * 2)
		)
		var outline_w: float = max(2.0, 3.0 / cam_zoom)
		var pulse_alpha := (sin(time_passed * 6.0) + 1.0) / 2.0 * 0.3 + 0.7
		var out_color := selected_outline_color
		out_color.a *= pulse_alpha
		draw_rect(sel_rect, out_color, false, outline_w)

	# 4) Линии сетки
	var world_width: float = line_screen_width / cam_zoom

	for col in range(grid_columns + 1):
		var x: float = offset.x + col * cell_size
		draw_line(Vector2(x, offset.y), Vector2(x, offset.y + board_h), line_color, world_width, true)

	for row in range(grid_rows + 1):
		var y: float = offset.y + row * cell_size
		draw_line(Vector2(offset.x, y), Vector2(offset.x + board_w, y), line_color, world_width, true)


func _on_overlay_draw() -> void:
	var board_w: float = grid_columns * cell_size
	var board_h: float = grid_rows * cell_size
	var offset := Vector2(-board_w / 2.0, -board_h / 2.0)
	
	# 2) Маркеры доступного хода или атаки
	var sel_unit_draw: Unit = selected_unit as Unit
	if sel_unit_draw != null:
		var dot_radius: float = cell_size * 0.12
		
		if is_combat_mode and sel_unit_draw.can_attack:
			for a_cell in attackable_cells:
				var v_pos := _to_visual(a_cell)
				var center := offset + Vector2(
					v_pos.x * cell_size + cell_size / 2.0,
					v_pos.y * cell_size + cell_size / 2.0
				)
				var color := Color(1.0, 0.3, 0.3, 0.5)
				var r := dot_radius
				
				if is_cell_occupied(a_cell):
					var target_unit := occupied_cells[a_cell] as Unit
					if target_unit.owner_id != sel_unit_draw.owner_id:
						# Враг в зоне атаки: яркая толстая точка
						color = Color(1.0, 0.1, 0.1, 0.9)
						r = dot_radius * 1.8
						
				if a_cell == hovered_cell:
					r *= 1.3
					color.a = 1.0
					
				_overlay.draw_circle(center, r, color)
					
		elif not is_combat_mode and sel_unit_draw.can_move:
			for r_cell in reachable_cells:
				var v_pos := _to_visual(r_cell)
				var center := offset + Vector2(
					v_pos.x * cell_size + cell_size / 2.0,
					v_pos.y * cell_size + cell_size / 2.0
				)
				if r_cell == hovered_cell:
					_overlay.draw_circle(center, dot_radius * 1.6, move_dot_hover_color)
				else:
					_overlay.draw_circle(center, dot_radius, move_dot_color)

	# 2.5) Маркеры теоретического хода (инспектор TAB)
	if inspected_unit != null:
		var dot_radius: float = cell_size * 0.12
		for r_cell in preview_reachable_cells:
			var v_pos := _to_visual(r_cell)
			var center := offset + Vector2(
				v_pos.x * cell_size + cell_size / 2.0,
				v_pos.y * cell_size + cell_size / 2.0
			)
			# Рисуем полупрозрачные точки для превью
			var color := Color(0.8, 0.3, 0.3, 0.5) if preview_is_attack else Color(0.4, 0.4, 0.4, 0.5)
			var r := dot_radius
			
			if preview_is_attack and is_cell_occupied(r_cell):
				var target_unit := occupied_cells[r_cell] as Unit
				if target_unit.owner_id != (inspected_unit as Unit).owner_id:
					# Особая подсветка, если зона атаки задевает врага: ярче и крупнее
					color = Color(1.0, 0.1, 0.1, 0.9)
					r = dot_radius * 1.8
					
			_overlay.draw_circle(center, r, color)
