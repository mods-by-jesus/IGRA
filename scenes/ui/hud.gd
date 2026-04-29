extends Control
class_name HUD

## Новый HUD — надежная верстка через HBox/VBox.

var _gold_label: Label
var _opponent_gold_label: Label
var _turn_label: Label
var _end_phase_btn: Button

# Стопки
var _draw_pile_btn: TextureButton
var _discard_pile_btn: TextureButton
var _draw_count_label: Label
var _discard_count_label: Label
var _pile_overlay: ColorRect
var _pile_scroll: ScrollContainer
var _pile_cards_container: HFlowContainer
var _pile_close_btn: Button
var _pile_title_label: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

	var coin_diam: float = 48.0
	var coin_color := Color(0.92, 0.78, 0.12)

	var main_margin := MarginContainer.new()
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 30)
	main_margin.add_theme_constant_override("margin_right", 30)
	main_margin.add_theme_constant_override("margin_top", 30)
	main_margin.add_theme_constant_override("margin_bottom", 30)
	main_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(main_margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_margin.add_child(main_vbox)

	# ================= ВЕРХНИЙ РЯД =================
	var top_hbox := HBoxContainer.new()
	top_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(top_hbox)

	var opp_container := Control.new()
	opp_container.custom_minimum_size = Vector2(coin_diam, coin_diam)
	opp_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	top_hbox.add_child(opp_container)

	var opp_coin_bg := _create_card_coin_circle(coin_color, coin_diam)
	_opponent_gold_label = _create_label("0", 24)
	opp_coin_bg.add_child(_opponent_gold_label)
	opp_container.add_child(opp_coin_bg)

	var center_container := CenterContainer.new()
	center_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_hbox.add_child(center_container)

	_end_phase_btn = Button.new()
	_end_phase_btn.text = "Закончить размещение"
	_end_phase_btn.add_theme_font_size_override("font_size", 22)
	_end_phase_btn.custom_minimum_size = Vector2(300, 50)
	_end_phase_btn.pressed.connect(_on_end_phase_pressed)
	center_container.add_child(_end_phase_btn)

	var right_container := MarginContainer.new()
	right_container.size_flags_horizontal = Control.SIZE_SHRINK_END
	top_hbox.add_child(right_container)

	_turn_label = Label.new()
	_turn_label.text = "Ход 1"
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_turn_label.add_theme_font_size_override("font_size", 28)
	_turn_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_turn_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_turn_label.add_theme_constant_override("shadow_offset_x", 1)
	_turn_label.add_theme_constant_override("shadow_offset_y", 1)
	right_container.add_child(_turn_label)

	# ================= ПУСТОТА =================
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(spacer)

	# ================= НИЖНИЙ РЯД =================
	var bottom_hbox := HBoxContainer.new()
	bottom_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_hbox.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(bottom_hbox)

	# Левая колонка: монеты сверху, стопка добора снизу
	var left_vbox := VBoxContainer.new()
	left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_vbox.add_theme_constant_override("separation", 8)
	bottom_hbox.add_child(left_vbox)

	var my_container := Control.new()
	my_container.custom_minimum_size = Vector2(coin_diam, coin_diam)
	left_vbox.add_child(my_container)

	var my_coin_bg := _create_card_coin_circle(coin_color, coin_diam)
	_gold_label = _create_label("0", 24)
	my_coin_bg.add_child(_gold_label)
	my_container.add_child(my_coin_bg)

	_draw_pile_btn = _create_pile_button(preload("res://assets/sprites/draw-pile.png"))
	_draw_pile_btn.pressed.connect(_on_draw_pile_pressed)
	_draw_count_label = _create_pile_count_label()
	_draw_pile_btn.add_child(_draw_count_label)
	left_vbox.add_child(_draw_pile_btn)

	# Пустота
	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_hbox.add_child(bottom_spacer)

	# Стопка сброса (снизу справа)
	_discard_pile_btn = _create_pile_button(preload("res://assets/sprites/discard-pile.png"))
	_discard_pile_btn.pressed.connect(_on_discard_pile_pressed)
	_discard_count_label = _create_pile_count_label()
	_discard_pile_btn.add_child(_discard_count_label)
	bottom_hbox.add_child(_discard_pile_btn)

	# ================= ОВЕРЛЕЙ СТОПКИ =================
	_build_pile_overlay()

	call_deferred("_connect_and_update")


func _on_viewport_resized() -> void:
	size = get_viewport_rect().size


func _create_card_coin_circle(color: Color, diameter: float) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(100)
	st.set_border_width_all(2)
	st.border_color = Color(0, 0, 0, 0.6)
	st.shadow_color = Color(0, 0, 0, 0.3)
	st.shadow_size = 4
	st.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(diameter, diameter)
	p.size = Vector2(diameter, diameter)
	return p


func _create_label(txt: String, fsize: int) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	return lbl


func _connect_and_update() -> void:
	GameManager.gold_changed.connect(_on_gold_changed)
	GameManager.opponent_gold_changed.connect(_on_opponent_gold_changed)
	GameManager.turn_changed.connect(_on_turn_changed)
	GameManager.phase_changed.connect(_on_phase_changed)
	GameManager.player_changed.connect(_on_player_changed)
	GameManager.hand_updated.connect(_on_hand_updated_for_piles)
	GameManager.card_played.connect(_on_card_played_for_piles)

	_on_gold_changed(GameManager.gold)
	_on_opponent_gold_changed(GameManager.opponent_gold)
	_on_turn_changed(GameManager.turn)
	_update_button_state()
	_update_pile_counts()


func _on_gold_changed(amount: int) -> void:
	_gold_label.text = str(amount)


func _on_opponent_gold_changed(amount: int) -> void:
	_opponent_gold_label.text = str(amount)


func _on_hand_updated_for_piles(_cards: Array[UnitData]) -> void:
	_update_pile_counts()


func _on_card_played_for_piles(_unit_data: UnitData) -> void:
	_update_pile_counts()


func _on_turn_changed(new_turn: int) -> void:
	var current_player: int = GameManager.current_player
	var player_name: String = GameManager.player_names[current_player]
	if player_name == "":
		player_name = "Игрок " + str(current_player + 1)
		
	var team_color: String = "Синие" if current_player == 0 else "Красные"
	
	_turn_label.text = "Ход %d\n%s (%s)" % [new_turn, player_name, team_color]
	
	if current_player == 0:
		_turn_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	else:
		_turn_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))


func _on_player_changed(_player_id: int) -> void:
	_on_turn_changed(GameManager.turn)
	_update_button_state()


func _on_phase_changed(_new_phase: int) -> void:
	_update_button_state()


func _update_button_state() -> void:
	var is_my_turn: bool = GameManager.is_my_turn()
	var current_phase: int = GameManager.current_phase
	var opponent_id: int = 1 - GameManager.my_player_id

	if current_phase == GameManager.Phase.ACTION:
		_end_phase_btn.text = "Завершить ход"
	elif current_phase == GameManager.Phase.INCOME:
		_end_phase_btn.text = "Ожидание..."

	_end_phase_btn.visible = (current_phase != GameManager.Phase.INCOME)

	var normal_style := StyleBoxFlat.new()
	normal_style.set_corner_radius_all(8)
	normal_style.set_border_width_all(2)
	normal_style.set_content_margin_all(12)

	if is_my_turn:
		normal_style.bg_color = Color(0.2, 0.35, 0.2)
		normal_style.border_color = Color(0.4, 0.7, 0.4)
		normal_style.shadow_color = Color(0, 0, 0, 0.5)
		normal_style.shadow_size = 4
		_end_phase_btn.add_theme_color_override("font_color", Color.WHITE)
		_end_phase_btn.disabled = false
	else:
		normal_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		
		var opp_color: Color = Color(0.8, 0.3, 0.3) if opponent_id == 1 else Color(0.3, 0.5, 0.8)
		normal_style.border_color = opp_color
		normal_style.shadow_color = opp_color
		normal_style.shadow_size = 6
		
		_end_phase_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_end_phase_btn.disabled = true

	_end_phase_btn.add_theme_stylebox_override("normal", normal_style)
	_end_phase_btn.add_theme_stylebox_override("disabled", normal_style)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	if is_my_turn:
		hover_style.bg_color = Color(0.25, 0.45, 0.25)
	_end_phase_btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	if is_my_turn:
		pressed_style.bg_color = Color(0.15, 0.25, 0.15)
	_end_phase_btn.add_theme_stylebox_override("pressed", pressed_style)
	_end_phase_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _on_end_phase_pressed() -> void:
	AudioManager.play_sound("ui_click")
	GameManager.next_phase()


func _create_pile_button(tex: Texture2D) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal = tex
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = Vector2(56, 56)
	btn.modulate = Color(0.9, 0.9, 0.9)
	return btn


func _create_pile_count_label() -> Label:
	var lb := Label.new()
	lb.text = "0"
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.set_anchors_preset(Control.PRESET_FULL_RECT)
	lb.add_theme_font_size_override("font_size", 20)
	lb.add_theme_color_override("font_color", Color.WHITE)
	lb.add_theme_constant_override("outline_size", 5)
	lb.add_theme_color_override("font_outline_color", Color.BLACK)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Сдвигаем вниз чтобы не перекрывать иконку
	lb.offset_top += 28
	lb.offset_bottom += 28
	return lb


func _build_pile_overlay() -> void:
	_pile_overlay = ColorRect.new()
	_pile_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pile_overlay.color = Color(0, 0, 0, 0.75)
	_pile_overlay.visible = false
	_pile_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pile_overlay.z_index = 200  # Рисуем поверх всего, включая Hand
	add_child(_pile_overlay)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pile_overlay.add_child(vbox)

	# Отступы
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 20)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(margin)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 16)
	inner_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(inner_vbox)

	# Заголовок
	_pile_title_label = Label.new()
	_pile_title_label.text = "Стопка"
	_pile_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pile_title_label.add_theme_font_size_override("font_size", 28)
	_pile_title_label.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))
	inner_vbox.add_child(_pile_title_label)

	# Прокрутка карт
	_pile_scroll = ScrollContainer.new()
	_pile_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_pile_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_pile_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var ps_vscroll: VScrollBar = _pile_scroll.get_v_scroll_bar()
	ps_vscroll.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	ps_vscroll.add_theme_stylebox_override("grabber", StyleBoxEmpty.new())
	ps_vscroll.add_theme_stylebox_override("grabber_highlight", StyleBoxEmpty.new())
	ps_vscroll.add_theme_stylebox_override("grabber_pressed", StyleBoxEmpty.new())
	ps_vscroll.custom_minimum_size = Vector2(0, 0)
	inner_vbox.add_child(_pile_scroll)

	var pile_margin := MarginContainer.new()
	pile_margin.add_theme_constant_override("margin_left", 35)
	pile_margin.add_theme_constant_override("margin_right", 35)
	pile_margin.add_theme_constant_override("margin_top", 35)
	pile_margin.add_theme_constant_override("margin_bottom", 35)
	pile_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pile_scroll.add_child(pile_margin)

	_pile_cards_container = HFlowContainer.new()
	_pile_cards_container.add_theme_constant_override("h_separation", 14)
	_pile_cards_container.add_theme_constant_override("v_separation", 14)
	_pile_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pile_margin.add_child(_pile_cards_container)

	# Кнопка закрытия внизу по центру
	var close_center := CenterContainer.new()
	close_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(close_center)

	_pile_close_btn = Button.new()
	_pile_close_btn.text = "Закрыть"
	_pile_close_btn.add_theme_font_size_override("font_size", 20)
	_pile_close_btn.custom_minimum_size = Vector2(200, 45)
	_pile_close_btn.pressed.connect(_close_pile_overlay)
	var close_style := StyleBoxFlat.new()
	close_style.bg_color = Color(0.25, 0.12, 0.12)
	close_style.border_color = Color(0.6, 0.25, 0.25)
	close_style.set_border_width_all(2)
	close_style.set_corner_radius_all(8)
	close_style.set_content_margin_all(8)
	_pile_close_btn.add_theme_stylebox_override("normal", close_style)
	var close_hover := close_style.duplicate() as StyleBoxFlat
	close_hover.bg_color = Color(0.35, 0.15, 0.15)
	_pile_close_btn.add_theme_stylebox_override("hover", close_hover)
	_pile_close_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close_center.add_child(_pile_close_btn)

	# Нижний отступ
	var bottom_pad := Control.new()
	bottom_pad.custom_minimum_size = Vector2(0, 20)
	bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(bottom_pad)


func _on_draw_pile_pressed() -> void:
	_show_pile_overlay("Стопка добора", GameManager.draw_pile)


func _on_discard_pile_pressed() -> void:
	_show_pile_overlay("Стопка сброса", GameManager.discard_pile)


func _show_pile_overlay(title: String, pile: Array[UnitData]) -> void:
	_pile_title_label.text = title + " (" + str(pile.size()) + ")"

	# Очистить старые карты
	for child in _pile_cards_container.get_children():
		child.queue_free()

	# Показать карты в случайном порядке
	var shuffled := pile.duplicate()
	shuffled.shuffle()
	for unit_data: UnitData in shuffled:
		var card := CardUI.new()
		_pile_cards_container.add_child(card)
		card.setup(unit_data)
		card.modulate.a = 1.0

	_pile_overlay.visible = true


func _close_pile_overlay() -> void:
	_pile_overlay.visible = false


func _update_pile_counts() -> void:
	_draw_count_label.text = str(GameManager.draw_pile.size())
	_discard_count_label.text = str(GameManager.discard_pile.size())


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _pile_overlay.visible:
			_close_pile_overlay()
			get_viewport().set_input_as_handled()
