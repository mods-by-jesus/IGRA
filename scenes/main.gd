extends Node2D

## Главная сцена — оркестрирует все системы

@onready var board: Board = $Board

var _lobby: Lobby
var _ui_layer: CanvasLayer
var _inspector_card: CardUI


func _ready() -> void:
	GameManager.register_board(board)

	GameManager.unit_should_be_placed.connect(_on_unit_placed)
	GameManager.unit_should_move.connect(_on_unit_moved)
	GameManager.unit_attacked.connect(_on_unit_attacked)
	GameManager.game_started.connect(_on_game_started)

	# Показываем лобби
	_show_lobby()


func _show_lobby() -> void:
	# Скрываем доску до старта
	board.visible = false

	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	_lobby = Lobby.new()
	_ui_layer.add_child(_lobby)


func _on_game_started() -> void:
	# Убираем лобби, показываем игру
	if _lobby:
		_lobby.queue_free()
		_lobby = null

	board.visible = true

	# Рука (внизу) — добавляем первой
	var hand := Hand.new()
	_ui_layer.add_child(hand)

	# HUD (поверх руки — оверлей стопок будет выше карт)
	var hud := HUD.new()
	_ui_layer.add_child(hud)

	# Карточка инспектора (TAB)
	_inspector_card = CardUI.new()
	_inspector_card.visible = false
	_ui_layer.add_child(_inspector_card)
	
	board.unit_inspected.connect(_on_unit_inspected)


func _on_unit_inspected(unit_data: UnitData, is_inspecting: bool) -> void:
	if _inspector_card != null:
		_inspector_card.queue_free()
		_inspector_card = null
		
	if not is_inspecting or unit_data == null:
		return
		
	_inspector_card = CardUI.new()
	_ui_layer.add_child(_inspector_card)
	_inspector_card.setup(unit_data)
	_inspector_card.visible = true
	
	# Позиционируем в правый нижний угол
	var viewport_size := get_viewport_rect().size
	var card_size := _inspector_card.get_minimum_size()
	if card_size == Vector2.ZERO:
		card_size = Vector2(185, 290) # fallback
		
	# Масштабируем карту инспектора так же, как в руке, и поднимаем повыше
	_inspector_card.scale = Vector2(1.5, 1.5)
	
	_inspector_card.position = Vector2(
		viewport_size.x - card_size.x * 1.5 - 40,
		viewport_size.y - card_size.y * 1.5 - 160
	)



func _on_unit_placed(unit_data: UnitData, grid_pos: Vector2i, unit_name: String, owner_id: int) -> void:
	# Проверяем что клетка не занята (на случай дублей при синхронизации)
	if board.is_cell_occupied(grid_pos):
		return

	var unit := Unit.new()
	unit.name = "Unit_%s" % unit_name.replace(" ", "_")
	board.add_child(unit)

	unit.setup(unit_data, unit_name, board.cell_size, owner_id)
	unit.grid_pos = grid_pos
	unit.position = board.grid_to_world(grid_pos) - board.global_position
	unit.died.connect(_on_unit_died)

	board.occupy_cell(grid_pos, unit)


func _on_unit_moved(from_pos: Vector2i, to_pos: Vector2i) -> void:
	if not board.is_cell_occupied(from_pos):
		return
	var unit: Unit = board.occupied_cells[from_pos]

	board.free_cell(from_pos)
	unit.grid_pos = to_pos

	var target_world_pos := board.grid_to_world(to_pos)
	
	AudioManager.play_sound("movement")
	
	# Добавим небольшую анимацию "прыжка" при перемещении
	var tween := create_tween()
	var target_pos := target_world_pos - board.global_position
	tween.tween_property(unit, "position", target_pos, 0.25).set_trans(Tween.TRANS_SINE)

	board.occupy_cell(to_pos, unit)
	unit.can_move = false
	unit.check_exhaustion()
	board.selected_unit = null
	board.update_reachable_cells()


func _on_unit_attacked(from_pos: Vector2i, to_pos: Vector2i, damage: int) -> void:
	# Анимация удара для атакующего (если он еще жив/существует)
	var is_ranged := false
	if board.is_cell_occupied(from_pos):
		var attacker := board.occupied_cells[from_pos] as Unit
		is_ranged = attacker.unit_data.attack_pattern == UnitData.AttackPattern.FORWARD_CONE or attacker.unit_data.attack_range > 1
		var target_world := board.grid_to_world(to_pos)
		var original_pos := attacker.position
		var target_local := target_world - board.global_position
		
		if is_ranged:
			AudioManager.play_sound("arrow")
			# Небольшой выпад (отдача/натяжение лука)
			var attack_tween := create_tween()
			var lunge_pos = original_pos + (target_local - original_pos).normalized() * 5.0
			attack_tween.tween_property(attacker, "position", lunge_pos, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			attack_tween.tween_property(attacker, "position", original_pos, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			
			# Создаем стрелу
			var arrow := Sprite2D.new()
			# Стрела направлена вверх в исходном файле, компенсируем поворот на 90 градусов (PI / 2)
			arrow.texture = preload("res://assets/sprites/archer-arrow.png")
			arrow.position = original_pos
			# Поворачиваем стрелу к цели (компенсация +PI/2)
			arrow.rotation = original_pos.angle_to_point(target_local) + PI / 2.0
			# Слегка увеличим стрелу, если она мелкая
			arrow.scale = Vector2(1.5, 1.5)
			# Добавляем стрелу на доску (чтобы координаты совпадали с юнитами)
			board.add_child(arrow)
			
			var dist := original_pos.distance_to(target_local)
			var duration := clampf(dist / 600.0, 0.1, 0.5)
			var arrow_tween := create_tween()
			arrow_tween.tween_property(arrow, "position", target_local, duration).set_trans(Tween.TRANS_LINEAR)
			arrow_tween.tween_callback(func():
				arrow.queue_free()
				_apply_damage(to_pos, damage)
			)
		else:
			# Ближний бой (резкий выпад)
			AudioManager.play_sound("sword")
			var attack_tween := create_tween()
			var lunge_pos = original_pos + (target_local - original_pos).normalized() * 20.0
			attack_tween.tween_property(attacker, "position", lunge_pos, 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			attack_tween.tween_property(attacker, "position", original_pos, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		
		# Юнит потратил атаку
		attacker.can_attack = false
		attacker.check_exhaustion()
		
	# Применение урона к цели (если ближний бой, применяем сразу)
	if not is_ranged:
		_apply_damage(to_pos, damage)


func _on_unit_died(owner_id: int) -> void:
	GameManager.on_unit_died(owner_id)


func _apply_damage(to_pos: Vector2i, damage: int) -> void:
	
	if board.is_cell_occupied(to_pos):
		var target := board.occupied_cells[to_pos] as Unit
		target.take_damage(damage)
		
		# Эффект получения урона (тряска и покраснение)
		var hit_tween := create_tween()
		hit_tween.tween_property(target, "modulate", Color(1.0, 0.3, 0.3), 0.1)
		hit_tween.tween_property(target, "modulate", Color.WHITE, 0.2).set_ease(Tween.EASE_OUT)
