extends Control
class_name Lobby

## Экран лобби — создать/присоединиться к игре + конструктор колоды

signal game_start_requested()

var _status_label: Label
var _ip_input: LineEdit
var _host_btn: Button
var _join_btn: Button
var _start_btn: Button
var _ip_display: Label
var _name_input: LineEdit

# Deckbuilder
var _deck_section: Control
var _available_cards_container: HFlowContainer
var _deck_scroll: ScrollContainer
var _deck_cards_container: HFlowContainer
var _deck_counter: Label
var _ready_btn: Button
var _opponent_ready_label: Label
var _my_deck: Array[String] = []
var _random_deck_btn: Button
var _network_vbox: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	
	get_viewport().size_changed.connect(_on_viewport_resized)
	_on_viewport_resized()

	# Фон
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.06, 0.06, 0.08)
	bg.add_theme_stylebox_override("panel", bg_style)
	add_child(bg)

	# ========= ГЛАВНЫЙ ГОРИЗОНТАЛЬНЫЙ КОНТЕЙНЕР =========
	# Слева — сеть, справа — deckbuilder (появляется после подключения)
	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 0)
	add_child(main_hbox)

	# ========= ЛЕВАЯ ПАНЕЛЬ: СЕТЕВОЕ ПОДКЛЮЧЕНИЕ =========
	var left_panel := PanelContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.0
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.08, 0.08, 0.1)
	left_style.set_border_width_all(0)
	left_style.border_width_right = 2
	left_style.border_color = Color(0.15, 0.15, 0.2)
	left_style.set_content_margin_all(30)
	left_panel.add_theme_stylebox_override("panel", left_style)
	main_hbox.add_child(left_panel)

	var left_center := CenterContainer.new()
	left_panel.add_child(left_center)

	_network_vbox = VBoxContainer.new()
	_network_vbox.add_theme_constant_override("separation", 16)
	_network_vbox.custom_minimum_size = Vector2(420, 0)
	left_center.add_child(_network_vbox)

	# Заголовок
	var title := Label.new()
	title.text = "INTERLOCKED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65))
	_network_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Тактический мультиплеер"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	_network_vbox.add_child(subtitle)

	# Ввод Ника
	_name_input = _create_line_edit("Ваш никнейм")
	_network_vbox.add_child(_name_input)

	_network_vbox.add_child(HSeparator.new())

	# Кнопка Host
	_host_btn = _create_button("Создать игру", Color(0.2, 0.35, 0.2))
	_host_btn.pressed.connect(_on_host_pressed)
	_network_vbox.add_child(_host_btn)

	# IP дисплей
	_ip_display = Label.new()
	_ip_display.text = ""
	_ip_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ip_display.add_theme_font_size_override("font_size", 13)
	_ip_display.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	_ip_display.visible = false
	_network_vbox.add_child(_ip_display)

	# Разделитель
	var or_label := Label.new()
	or_label.text = "— или —"
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	or_label.add_theme_font_size_override("font_size", 13)
	or_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.38))
	_network_vbox.add_child(or_label)

	# Ввод IP + Join
	var join_hbox := HBoxContainer.new()
	join_hbox.add_theme_constant_override("separation", 10)
	_network_vbox.add_child(join_hbox)

	_ip_input = _create_line_edit("IP адрес хоста")
	_ip_input.text = "127.0.0.1"
	_ip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_hbox.add_child(_ip_input)

	_join_btn = _create_button("Подключиться", Color(0.2, 0.25, 0.35))
	_join_btn.pressed.connect(_on_join_pressed)
	join_hbox.add_child(_join_btn)

	# Статус
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_network_vbox.add_child(_status_label)

	# ========= ПРАВАЯ ПАНЕЛЬ: КОНСТРУКТОР КОЛОДЫ =========
	_deck_section = PanelContainer.new()
	_deck_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_section.size_flags_stretch_ratio = 2.0
	_deck_section.visible = false
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.07, 0.07, 0.09)
	right_style.set_content_margin_all(25)
	_deck_section.add_theme_stylebox_override("panel", right_style)
	main_hbox.add_child(_deck_section)

	var deck_vbox := VBoxContainer.new()
	deck_vbox.add_theme_constant_override("separation", 14)
	_deck_section.add_child(deck_vbox)

	# Заголовок конструктора
	var deck_title := Label.new()
	deck_title.text = "СБОРКА КОЛОДЫ"
	deck_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_title.add_theme_font_size_override("font_size", 24)
	deck_title.add_theme_color_override("font_color", Color(0.9, 0.82, 0.55))
	deck_vbox.add_child(deck_title)

	var deck_hint := Label.new()
	deck_hint.text = "Нажми на карту, чтобы добавить в колоду. Нужно набрать 16 карт. Повторные допускаются."
	deck_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_hint.add_theme_font_size_override("font_size", 13)
	deck_hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
	deck_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	deck_vbox.add_child(deck_hint)

	# --- ДОСТУПНЫЕ КАРТЫ (настоящие CardUI) ---
	var avail_label := Label.new()
	avail_label.text = "Доступные юниты"
	avail_label.add_theme_font_size_override("font_size", 16)
	avail_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	deck_vbox.add_child(avail_label)

	var avail_margin := MarginContainer.new()
	avail_margin.add_theme_constant_override("margin_left", 35)
	avail_margin.add_theme_constant_override("margin_right", 35)
	avail_margin.add_theme_constant_override("margin_top", 35)
	avail_margin.add_theme_constant_override("margin_bottom", 35)
	deck_vbox.add_child(avail_margin)

	_available_cards_container = HFlowContainer.new()
	_available_cards_container.add_theme_constant_override("h_separation", 16)
	_available_cards_container.add_theme_constant_override("v_separation", 16)
	_available_cards_container.alignment = FlowContainer.ALIGNMENT_CENTER
	avail_margin.add_child(_available_cards_container)

	for unit_data: UnitData in GameManager.available_units:
		var card := CardUI.new()
		_available_cards_container.add_child(card)
		card.setup(unit_data)
		card.modulate.a = 1.0  # Всегда яркие в лобби
		card.card_clicked.connect(_on_available_card_clicked)

	# Разделитель
	var sep := HSeparator.new()
	deck_vbox.add_child(sep)

	# --- СОБРАННАЯ КОЛОДА ---
	_deck_counter = Label.new()
	_deck_counter.text = "Колода: 0 / 16"
	_deck_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_deck_counter.add_theme_font_size_override("font_size", 20)
	_deck_counter.add_theme_color_override("font_color", Color(0.8, 0.55, 0.25))
	deck_vbox.add_child(_deck_counter)

	# Прокручиваемый контейнер для карт колоды (вертикальный скролл, без полосы)
	_deck_scroll = ScrollContainer.new()
	_deck_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_deck_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_deck_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Скрываем ползунок
	var vscroll: VScrollBar = _deck_scroll.get_v_scroll_bar()
	vscroll.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())
	vscroll.add_theme_stylebox_override("grabber", StyleBoxEmpty.new())
	vscroll.add_theme_stylebox_override("grabber_highlight", StyleBoxEmpty.new())
	vscroll.add_theme_stylebox_override("grabber_pressed", StyleBoxEmpty.new())
	vscroll.custom_minimum_size = Vector2(0, 0)
	deck_vbox.add_child(_deck_scroll)

	var deck_margin := MarginContainer.new()
	deck_margin.add_theme_constant_override("margin_left", 35)
	deck_margin.add_theme_constant_override("margin_right", 35)
	deck_margin.add_theme_constant_override("margin_top", 35)
	deck_margin.add_theme_constant_override("margin_bottom", 35)
	deck_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_scroll.add_child(deck_margin)

	_deck_cards_container = HFlowContainer.new()
	_deck_cards_container.add_theme_constant_override("h_separation", 10)
	_deck_cards_container.add_theme_constant_override("v_separation", 10)
	_deck_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck_margin.add_child(_deck_cards_container)

	# Статус оппонента
	_opponent_ready_label = Label.new()
	_opponent_ready_label.text = ""
	_opponent_ready_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_opponent_ready_label.add_theme_font_size_override("font_size", 15)
	_opponent_ready_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	deck_vbox.add_child(_opponent_ready_label)

	# Кнопки внизу
	var buttons_hbox := HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 12)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	deck_vbox.add_child(buttons_hbox)

	_ready_btn = _create_button("Готов", Color(0.2, 0.4, 0.2))
	_ready_btn.pressed.connect(_on_ready_pressed)
	_ready_btn.disabled = true
	buttons_hbox.add_child(_ready_btn)

	_random_deck_btn = _create_button("Случайная колода", Color(0.4, 0.2, 0.4))
	_random_deck_btn.pressed.connect(_on_random_deck_pressed)
	buttons_hbox.add_child(_random_deck_btn)

	_start_btn = _create_button("  Начать игру!  ", Color(0.35, 0.55, 0.35))
	_start_btn.pressed.connect(_on_start_pressed)
	_start_btn.visible = false
	buttons_hbox.add_child(_start_btn)

	# Подписка на сигналы
	GameManager.peer_connected_signal.connect(_on_peer_connected)
	GameManager.names_updated.connect(_update_status_names)
	GameManager.deck_ready_changed.connect(_on_deck_ready_changed)


# ===================== DECKBUILDER =====================

func _on_available_card_clicked(unit_data: UnitData) -> void:
	if _my_deck.size() >= GameManager.DECK_SIZE:
		return
	
	AudioManager.play_sound("card_hover", randf_range(0.95, 1.05))
	_my_deck.append(unit_data.unit_name)
	_rebuild_deck_display()


func _on_random_deck_pressed() -> void:
	if GameManager.available_units.is_empty():
		return
		
	AudioManager.play_sound("ui_click")
	_my_deck.clear()
	
	var available_names: Array[String] = []
	for unit in GameManager.available_units:
		available_names.append(unit.unit_name)
		
	for i in range(GameManager.DECK_SIZE):
		var random_name = available_names.pick_random()
		_my_deck.append(random_name)
		
	_rebuild_deck_display()


func _on_deck_card_remove(index: int) -> void:
	if index < 0 or index >= _my_deck.size():
		return
	
	AudioManager.play_sound("ui_click")
	_my_deck.remove_at(index)
	_rebuild_deck_display()
	
	# Отменяем готовность при изменении колоды
	if GameManager.player_ready[GameManager.my_player_id]:
		GameManager.set_ready(false)
		_ready_btn.text = "Готов"
		_ready_btn.disabled = (_my_deck.size() != GameManager.DECK_SIZE)


func _rebuild_deck_display() -> void:
	# Удаляем старые карточки из контейнера
	for child in _deck_cards_container.get_children():
		child.queue_free()
	
	# Создаём уменьшенные настоящие CardUI для каждой карты в колоде
	for i in range(_my_deck.size()):
		var unit_data: UnitData = GameManager._find_unit_data(_my_deck[i])
		if unit_data == null:
			continue
		
		var card := CardUI.new()
		_deck_cards_container.add_child(card)
		card.setup(unit_data)
		card.modulate.a = 1.0
		
		# При клике — удалить из колоды
		var idx := i
		card.card_clicked.connect(func(_ud: UnitData): _on_deck_card_remove(idx))
	
	# Обновляем счётчик
	var count := _my_deck.size()
	_deck_counter.text = "Колода: %d / %d" % [count, GameManager.DECK_SIZE]
	
	if count == GameManager.DECK_SIZE:
		_deck_counter.add_theme_color_override("font_color", Color(0.35, 0.9, 0.35))
	elif count > GameManager.DECK_SIZE:
		_deck_counter.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	else:
		_deck_counter.add_theme_color_override("font_color", Color(0.8, 0.55, 0.25))
	
	# Кнопка Готов
	var is_already_ready: bool = GameManager.player_ready[GameManager.my_player_id]
	_ready_btn.disabled = (count != GameManager.DECK_SIZE) or is_already_ready


func _on_ready_pressed() -> void:
	AudioManager.play_sound("ui_click")
	var deck_names: Array[String] = []
	for name_str in _my_deck:
		deck_names.append(name_str)
	GameManager.set_my_deck(deck_names)
	GameManager.send_deck_to_server(deck_names)
	GameManager.set_ready(true)
	
	_ready_btn.text = "Готов!"
	_ready_btn.disabled = true


func _on_deck_ready_changed(player_id: int, is_ready: bool) -> void:
	var opponent_id: int = 1 - GameManager.my_player_id
	if player_id == opponent_id:
		if is_ready:
			_opponent_ready_label.text = "Оппонент готов!"
			_opponent_ready_label.add_theme_color_override("font_color", Color(0.35, 0.9, 0.35))
		else:
			_opponent_ready_label.text = "Оппонент собирает колоду..."
			_opponent_ready_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
	
	if GameManager.multiplayer.is_server() and GameManager.are_all_ready():
		_start_btn.visible = true
	else:
		_start_btn.visible = false


# ===================== СЕТЬ =====================

func _update_status_names() -> void:
	if not GameManager.peer_connected:
		return
	
	var host_name: String = GameManager.player_names[0] if GameManager.player_names[0] != "" else "Хост"
	var client_name: String = GameManager.player_names[1] if GameManager.player_names[1] != "" else "Клиент"
	
	if GameManager.multiplayer.is_server():
		_status_label.text = "Подключен: %s (Красные)\nВы: %s (Синие)" % [client_name, host_name]
	else:
		_status_label.text = "Подключено к: %s (Синие)\nВы: %s (Красные)" % [host_name, client_name]


func _on_host_pressed() -> void:
	AudioManager.play_sound("ui_click")
	GameManager.local_player_name = _name_input.text.strip_edges()
	var err: Error = GameManager.host_game()
	if err == OK:
		_status_label.text = "Сервер создан! Ожидание...\nВы: %s (Синие)" % (GameManager.local_player_name if GameManager.local_player_name != "" else "Хост")
		_status_label.add_theme_color_override("font_color", Color(0.5, 0.85, 0.5))
		_host_btn.disabled = true
		_join_btn.disabled = true
		_ip_input.editable = false
		_name_input.editable = false
		
		var ips := _get_local_ips()
		if ips.size() > 0:
			_ip_display.text = "Ваш IP: %s  (порт %d)" % [ips[0], GameManager.PORT]
		else:
			_ip_display.text = "Порт: %d" % GameManager.PORT
		_ip_display.visible = true
	else:
		_status_label.text = "Ошибка создания сервера!"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))


func _on_join_pressed() -> void:
	AudioManager.play_sound("ui_click")
	var ip := _ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	GameManager.local_player_name = _name_input.text.strip_edges()
	var err: Error = GameManager.join_game(ip)
	if err == OK:
		_status_label.text = "Подключение к %s..." % ip
		_status_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
		_host_btn.disabled = true
		_join_btn.disabled = true
		_ip_input.editable = false
		_name_input.editable = false
	else:
		_status_label.text = "Ошибка подключения!"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))


func _on_peer_connected() -> void:
	_update_status_names()
	# Показать секцию конструктора колоды
	_deck_section.visible = true
	_opponent_ready_label.text = "Оппонент собирает колоду..."


func _on_start_pressed() -> void:
	AudioManager.play_sound("ui_click")
	GameManager.start_multiplayer_game()


# ===================== УТИЛИТЫ UI =====================

func _create_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 17)
	btn.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
	btn.custom_minimum_size = Vector2(0, 46)

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(8)
	style.set_border_width_all(1)
	style.border_color = bg_color.lightened(0.3)
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := style.duplicate() as StyleBoxFlat
	pressed.bg_color = bg_color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", pressed)

	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return btn


func _create_line_edit(placeholder: String) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.text = ""
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.add_theme_font_size_override("font_size", 15)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.25, 0.3)
	style.set_content_margin_all(10)
	le.add_theme_stylebox_override("normal", style)
	le.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	le.add_theme_color_override("font_placeholder_color", Color(0.35, 0.35, 0.4))
	return le


func _get_local_ips() -> Array[String]:
	var result: Array[String] = []
	for ip in IP.get_local_addresses():
		if ip.count(".") == 3 and ip != "127.0.0.1" and not ip.begins_with("169.254"):
			result.append(ip)
	return result


func _on_viewport_resized() -> void:
	size = get_viewport_rect().size
