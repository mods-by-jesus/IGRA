extends Control
class_name Hand

## Рука игрока — веер карт внизу экрана (Slay the Spire стиль)
## Карты обновляются через сигнал hand_updated от GameManager.

@export var card_spacing: float = 230.0
@export var angle_per_card: float = 5.0
@export var visible_pixels: float = 100.0
@export var hover_rise: float = 260.0
@export var lerp_speed: float = 14.0
@export var arc_bend: float = 0.8

var _cards: Array[CardUI] = []
var _hovered_index: int = -1
var _hand_visible: bool = true

var _current_x_offsets: Array[float] = []
var _current_y_offsets: Array[float] = []
var _current_rotations: Array[float] = []
var _current_scales: Array[float] = []
var _card_delays: Array[float] = []


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	# Подписываемся на события менеджера
	GameManager.player_changed.connect(_on_player_or_phase_changed)
	GameManager.phase_changed.connect(_on_phase_changed_hand)
	GameManager.hand_updated.connect(_on_hand_updated)
	
	_update_hand_visibility()
	
	# Подхватить текущее состояние руки (если draw_cards уже был вызван до создания Hand)
	if GameManager.hand_cards.size() > 0:
		_on_hand_updated(GameManager.hand_cards)


func _on_player_or_phase_changed(_val: int) -> void:
	_update_hand_visibility()


func _on_phase_changed_hand(_val: int) -> void:
	_update_hand_visibility()


## Сигнал от GameManager — рука изменилась (добор/сброс/розыгрыш)
func _on_hand_updated(cards: Array[UnitData]) -> void:
	var old_count := _cards.size()
	
	# Анимируем улет старых карт в стопку сброса
	var viewport_h := get_viewport_rect().size.y
	var viewport_w := get_viewport_rect().size.x
	var discard_x := viewport_w - 80.0
	var discard_y := viewport_h - 60.0
	
	for card in _cards:
		var target_pos := Vector2(discard_x - card.size.x / 2.0, discard_y)
		var peak_y := minf(card.position.y, target_pos.y) - 300.0
		
		var tween_x := create_tween()
		tween_x.tween_property(card, "position:x", target_pos.x, 0.4).set_trans(Tween.TRANS_LINEAR)
		tween_x.parallel().tween_property(card, "scale", Vector2(0.2, 0.2), 0.4)
		tween_x.parallel().tween_property(card, "rotation_degrees", 180.0, 0.4)
		tween_x.parallel().tween_property(card, "modulate:a", 0.0, 0.4)
		tween_x.tween_callback(card.queue_free)
		
		var tween_y := create_tween()
		tween_y.tween_property(card, "position:y", peak_y, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween_y.tween_property(card, "position:y", target_pos.y, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	
	_cards.clear()
	_current_x_offsets.clear()
	_current_y_offsets.clear()
	_current_rotations.clear()
	_current_scales.clear()
	_card_delays.clear()
	_hovered_index = -1
	
	# Создаём новые из полученного массива
	var is_drawing := cards.size() > old_count  # Добор карт
	for i in range(cards.size()):
		var unit_data: UnitData = cards[i]
		var card := CardUI.new()
		add_child(card)
		card.setup(unit_data)
		card.card_clicked.connect(_on_card_clicked)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cards.append(card)
		
		if is_drawing:
			# Вылет из стопки добора по дуге
			var draw_pile_x := 80.0
			var draw_pile_y := viewport_h - 60.0
			var start_pos := Vector2(draw_pile_x - card.size.x / 2.0, draw_pile_y)
			
			card.position = start_pos
			card.rotation_degrees = -180.0
			card.scale = Vector2(0.2, 0.2)
			card.modulate.a = 0.0
			card.z_index = 50 + i
			
			var targets := _get_targets(i, cards.size(), false, false)
			var center_x := viewport_w / 2.0
			var target_pos := Vector2(center_x + targets["x_off"] - card.size.x / 2.0, viewport_h - visible_pixels + targets["y_off"])
			
			_current_x_offsets.append(targets["x_off"])
			_current_y_offsets.append(targets["y_off"])
			_current_rotations.append(targets["rot"])
			_current_scales.append(targets["scl"])
			
			var delay := i * 0.15
			var anim_dur := 0.4
			_card_delays.append(delay + anim_dur)
			
			var peak_y := minf(start_pos.y, target_pos.y) - 300.0
			
			var tween_x := create_tween()
			tween_x.tween_interval(delay)
			tween_x.tween_property(card, "position:x", target_pos.x, anim_dur).set_trans(Tween.TRANS_LINEAR)
			tween_x.parallel().tween_property(card, "scale", Vector2(targets["scl"], targets["scl"]), anim_dur)
			tween_x.parallel().tween_property(card, "rotation_degrees", targets["rot"], anim_dur)
			tween_x.parallel().tween_property(card, "modulate:a", 1.0, anim_dur * 0.5)
			
			var tween_y := create_tween()
			tween_y.tween_interval(delay)
			tween_y.tween_property(card, "position:y", peak_y, anim_dur * 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			tween_y.tween_property(card, "position:y", target_pos.y, anim_dur * 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		else:
			_current_x_offsets.append(0.0)
			_current_y_offsets.append(0.0)
			_current_rotations.append(0.0)
			_current_scales.append(1.0)
			_card_delays.append(0.0)
	
	_update_hand_visibility()
	if not is_drawing:
		_snap_cards()


func _update_hand_visibility() -> void:
	# Рука видна в свой ход в фазе ACTION
	_hand_visible = GameManager.is_my_turn() and GameManager.current_phase == GameManager.Phase.ACTION
	
	# Обновить affordability
	for card in _cards:
		card._update_affordability()


func _snap_cards() -> void:
	var count := _cards.size()
	for i in range(count):
		var targets := _get_targets(i, count, false)
		_current_x_offsets[i] = targets["x_off"]
		_current_y_offsets[i] = targets["y_off"]
		_current_rotations[i] = targets["rot"]
		_current_scales[i] = targets["scl"]
		_apply_transform(i, count)


func _get_targets(index: int, count: int, is_hovered: bool, force_reveal: bool = false) -> Dictionary:
	var center_offset: float = 0.0
	if count > 1:
		center_offset = float(index) - float(count - 1) / 2.0
	
	var arc_drop: float = center_offset * center_offset * arc_bend
	
	var target_rot: float = center_offset * angle_per_card
	var target_x_off: float = center_offset * card_spacing
	var target_y_off: float = arc_drop
	var target_scl: float = 1.0
	
	if not _hand_visible:
		# Рука скрыта — карты уходят вниз за экран
		target_y_off = 400.0
		target_rot = 0.0
		target_scl = 0.8
	elif is_hovered or force_reveal:
		target_rot = 0.0
		target_y_off = -hover_rise
		target_scl = 1.15
	
	return {"x_off": target_x_off, "y_off": target_y_off, "rot": target_rot, "scl": target_scl}


func _apply_transform(index: int, count: int) -> void:
	var card := _cards[index]
	var viewport_h: float = get_viewport_rect().size.y
	var viewport_w: float = get_viewport_rect().size.x
	
	var center_x: float = viewport_w / 2.0
	var card_center_x: float = center_x + _current_x_offsets[index]
	
	var card_top_y: float = viewport_h - visible_pixels + _current_y_offsets[index]
	
	card.pivot_offset = Vector2(card.size.x / 2.0, card.size.y)
	card.position = Vector2(card_center_x - card.size.x / 2.0, card_top_y)
	card.rotation_degrees = _current_rotations[index]
	var s: float = _current_scales[index]
	card.scale = Vector2(s, s)
	
	card.z_index = 100 if index == _hovered_index else index


func _process(delta: float) -> void:
	var count := _cards.size()
	if count == 0:
		return
	
	var factor: float = 1.0 - exp(-lerp_speed * delta)
	
	var force_alt := Input.is_key_pressed(KEY_ALT)
	
	for i in range(count):
		if _card_delays[i] > 0.0:
			_card_delays[i] -= delta
			continue
			
		var is_hovered: bool = (i == _hovered_index)
		var targets := _get_targets(i, count, is_hovered, force_alt)
		
		_current_x_offsets[i] = lerpf(_current_x_offsets[i], targets["x_off"], factor)
		_current_y_offsets[i] = lerpf(_current_y_offsets[i], targets["y_off"], factor)
		_current_rotations[i] = lerpf(_current_rotations[i], targets["rot"], factor)
		_current_scales[i] = lerpf(_current_scales[i], targets["scl"], factor)
		
		_apply_transform(i, count)


func _input(event: InputEvent) -> void:
	if not _hand_visible:
		_hovered_index = -1
		return
	
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = (event as InputEventMouseMotion).position
		if mouse_pos.y < 60.0:
			if _hovered_index != -1:
				_hovered_index = -1
			return
		
		var new_hover_index := _find_card_at(mouse_pos)
		if new_hover_index != _hovered_index and new_hover_index != -1:
			AudioManager.play_sound("card_hover", randf_range(0.9, 1.1), -5.0)
		_hovered_index = new_hover_index
	
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.position.y < 60.0:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed and _hovered_index >= 0:
			var card := _cards[_hovered_index]
			if card._is_affordable:
				AudioManager.play_sound("ui_click")
				card.card_clicked.emit(card.unit_data)
				get_viewport().set_input_as_handled()


func _find_card_at(mouse_pos: Vector2) -> int:
	var viewport_h: float = get_viewport_rect().size.y
	
	var activation_y: float = viewport_h - visible_pixels - 30.0
	if mouse_pos.y < activation_y and _hovered_index < 0:
		return -1
	
	if _hovered_index >= 0 and _hovered_index < _cards.size():
		var card := _cards[_hovered_index]
		var rect := Rect2(card.position, card.size * card.scale)
		if rect.has_point(mouse_pos):
			return _hovered_index
	
	var count := _cards.size()
	var viewport_w: float = get_viewport_rect().size.x
	var center_x: float = viewport_w / 2.0
	
	var best: int = -1
	var best_dist: float = card_spacing * 0.6
	
	for i in range(count):
		var center_offset: float = 0.0
		if count > 1:
			center_offset = float(i) - float(count - 1) / 2.0
		var card_cx: float = center_x + center_offset * card_spacing
		var dist: float = absf(mouse_pos.x - card_cx)
		if dist < best_dist:
			best_dist = dist
			best = i
	
	if best >= 0 and mouse_pos.y < activation_y:
		return -1
	
	return best


func _on_card_clicked(unit_data: UnitData) -> void:
	GameManager.start_deploy(unit_data)
