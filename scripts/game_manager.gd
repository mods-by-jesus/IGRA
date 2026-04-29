extends Node

## Центральный менеджер игры (AutoLoad синглтон)
## Управляет состоянием: монеты, ходы, фазы, размещение юнитов.
## Поддержка LAN мультиплеера через ENet.
## Система колоды в стиле Slay the Spire.

# --- Сигналы ---
signal gold_changed(new_amount: int)
signal opponent_gold_changed(new_amount: int)
signal phase_changed(new_phase: Phase)
signal turn_changed(new_turn: int)
signal deploy_mode_started(unit_data: UnitData)
signal deploy_mode_ended()
signal unit_should_be_placed(unit_data: UnitData, grid_pos: Vector2i, unit_name: String, owner_id: int)
signal current_player_time_updated(time_left: float)
signal player_changed(player_id: int)
signal game_started()
signal peer_connected_signal()
signal game_over(winner_id: int)

signal unit_attacked(from: Vector2i, to: Vector2i, damage: int)
signal unit_died(pos: Vector2i)

signal unit_should_move(from_pos: Vector2i, to_pos: Vector2i)
signal names_updated()

# Сигналы колоды
signal hand_updated(cards: Array[UnitData])
signal card_played(unit_data: UnitData)
signal card_deployed(unit_data: UnitData, grid_pos: Vector2i)
signal deck_ready_changed(player_id: int, is_ready: bool)

# --- Фазы ---
enum Phase { ACTION, INCOME }

# --- Настройки ---
@export var starting_gold: int = 5
@export var base_income: int = 3

const PORT: int = 9999
const HAND_SIZE: int = 5
const DECK_SIZE: int = 16

# --- Сетевые ---
## Мой id игрока (0 = хост, 1 = клиент)
var my_player_id: int = 0
## Чей сейчас ход
var current_player: int = 0
## Подключен ли второй игрок
var peer_connected: bool = false
## Игра началась
var game_active: bool = false

## Ссылка на доску (устанавливается из main.gd)
var board_ref: Board = null
## Количество юнитов на доске у каждого игрока
var units_on_board: Array[int] = [0, 0]
## Сколько юнитов было развёрнуто (для проверки game over)
var _total_deployed: Array[int] = [0, 0]

var local_player_name: String = ""
var player_names: Array[String] = ["Хост", "Клиент"]

# --- Состояние ---
## Монеты каждого игрока [player0, player1]
var player_gold: Array[int] = [5, 5]

## Свои монеты (shortcut)
var gold: int:
	get: return player_gold[my_player_id]
	set(value):
		player_gold[my_player_id] = value
		gold_changed.emit(player_gold[my_player_id])

## Монеты оппонента (shortcut)
var opponent_gold: int:
	get: return player_gold[1 - my_player_id]

var turn: int = 1:
	set(value):
		turn = value
		turn_changed.emit(turn)

var current_phase: Phase = Phase.ACTION:
	set(value):
		current_phase = value
		phase_changed.emit(current_phase)

var is_deploying: bool = false
var deploying_unit_data: UnitData = null

## Доступные типы юнитов для покупки
var available_units: Array[UnitData] = []

# --- Колода ---
## Колода, собранная в лобби (16 карт)
var my_deck: Array[UnitData] = []
## Стопка добора
var draw_pile: Array[UnitData] = []
## Стопка сброса
var discard_pile: Array[UnitData] = []
## Текущая рука
var hand_cards: Array[UnitData] = []

# --- Готовность в лобби ---
var player_ready: Array[bool] = [false, false]
## Колоды обоих игроков в виде имён (для синхронизации)
var player_deck_names: Array = [[], []]

# --- Пул имён ---
const FIRST_NAMES: PackedStringArray = [
	"Фришинбо", "Вольцлав", "Фермунд", "Лустенций", "Парно",
	"Шансви", "Крустенций", "Малегус", "Патронций", "Ренстенментий",
	"Дьякфринуа", "Контролус", "Каролинус", "Илид", "Шолюми",
	"Тит", "Тулит", "Альцпологет", "Марк", "Варфамаэль",
	"Гибс", "Вадуц", "Шатон", "Марон"
]

const LAST_NAMES: PackedStringArray = [
	"Фришинг", "Вольцгау", "Фермундо", "Лузиньяно", "Прустонцо",
	"Шанстувольт", "вон Альба", "Амфидирьяри", "Трудо́", "Алепос",
	"Грубсдоттер", "Фригихо", "Марминг", "Вакуцо", "вон Флезинг",
	"дир Марблфло", "Вифиний", "Тамингруо", "Флегатус", "вон Лонж",
	"Лонжинг", "Фли", "Паулиний", "вон Нель", "вон Крин"
]


func _ready() -> void:
	player_gold = [starting_gold, starting_gold]
	_load_unit_types()
	
	# Подключаем сигналы мультиплеера
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)


## Установить ссылку на доску (вызывается из main.gd)
func register_board(board: Board) -> void:
	board_ref = board


func _load_unit_types() -> void:
	var swordsman := UnitData.new()
	swordsman.unit_name = "Мечник"
	swordsman.description = "Мечник. Ходит на 3 клетки (без диагоналей)."
	swordsman.portrait = preload("res://assets/sprites/swordsman.png")
	swordsman.cost = 3
	swordsman.max_hp = 3
	swordsman.attack_power = 2
	swordsman.move_range = 3
	available_units.append(swordsman)

	var archer := UnitData.new()
	archer.unit_name = "Лучник"
	archer.description = "Лучник. Ходит на 1 клетку, стреляет веером вперед (до 5 клеток)."
	archer.portrait = preload("res://assets/sprites/archer.png")
	archer.cost = 2
	archer.max_hp = 2
	archer.attack_power = 1
	archer.move_range = 1
	archer.attack_range = 5
	archer.attack_pattern = UnitData.AttackPattern.FORWARD_CONE
	available_units.append(archer)


## Генерация случайного имени из пула
func generate_unit_name() -> String:
	var first := FIRST_NAMES[randi() % FIRST_NAMES.size()]
	var last := LAST_NAMES[randi() % LAST_NAMES.size()]
	return first + " " + last


# ===================== КОЛОДА =====================

## Задать свою колоду из массива имён юнитов
func set_my_deck(deck_names: Array[String]) -> void:
	my_deck.clear()
	for name_str in deck_names:
		var data := _find_unit_data(name_str)
		if data:
			my_deck.append(data)


## Инициализация стопки добора (в начале игры)
func _init_draw_pile() -> void:
	draw_pile.clear()
	discard_pile.clear()
	hand_cards.clear()
	
	# Копируем колоду в стопку добора
	for card in my_deck:
		draw_pile.append(card)
	
	# Тасуем
	_shuffle_array(draw_pile)


## Перемешать массив (Fisher-Yates)
func _shuffle_array(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## Добрать карты из стопки добора
func draw_cards(count: int) -> void:
	for i in range(count):
		if draw_pile.is_empty():
			_shuffle_discard_into_draw()
		if draw_pile.is_empty():
			break  # Совсем карт нет
		hand_cards.append(draw_pile.pop_back())
	
	hand_updated.emit(hand_cards)


## Перетасовать сброс в стопку добора
func _shuffle_discard_into_draw() -> void:
	for card in discard_pile:
		draw_pile.append(card)
	discard_pile.clear()
	_shuffle_array(draw_pile)


## Сбросить все карты из руки в стопку сброса (конец хода)
func discard_hand() -> void:
	for card in hand_cards:
		discard_pile.append(card)
	hand_cards.clear()
	hand_updated.emit(hand_cards)


## Разыграть карту (убрать из руки, положить в сброс)
func play_card_from_hand(unit_data: UnitData) -> void:
	for i in range(hand_cards.size()):
		if hand_cards[i] == unit_data:
			hand_cards.remove_at(i)
			discard_pile.append(unit_data)
			card_played.emit(unit_data)
			hand_updated.emit(hand_cards)
			return


# ===================== ГОТОВНОСТЬ В ЛОББИ =====================

## Отправить свою готовность
func set_ready(ready: bool) -> void:
	player_ready[my_player_id] = ready
	deck_ready_changed.emit(my_player_id, ready)
	
	# Синхронизировать
	if multiplayer.is_server():
		_rpc_sync_ready.rpc(my_player_id, ready)
	else:
		_rpc_request_ready.rpc_id(1, ready)


## Отправить свою колоду серверу
func send_deck_to_server(deck_names: Array[String]) -> void:
	if multiplayer.is_server():
		player_deck_names[0] = deck_names
	else:
		_rpc_send_deck.rpc_id(1, deck_names)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_send_deck(deck_names: Array[String]) -> void:
	if not multiplayer.is_server():
		return
	player_deck_names[1] = deck_names


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_ready(ready: bool) -> void:
	if not multiplayer.is_server():
		return
	player_ready[1] = ready
	deck_ready_changed.emit(1, ready)
	# Синхронизировать обоим
	_rpc_sync_ready.rpc(1, ready)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_ready(player_id: int, ready: bool) -> void:
	player_ready[player_id] = ready
	deck_ready_changed.emit(player_id, ready)


func are_all_ready() -> bool:
	return player_ready[0] and player_ready[1]


# ===================== СЕТЬ =====================

## Создать сервер (хост)
func host_game() -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	if err != OK:
		push_error("Не удалось создать сервер: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	my_player_id = 0
	print("Сервер создан на порте %d" % PORT)
	return OK


## Подключиться к серверу
func join_game(ip: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("Не удалось подключиться: %s" % error_string(err))
		return err
	multiplayer.multiplayer_peer = peer
	my_player_id = 1
	print("Подключение к %s:%d..." % [ip, PORT])
	return OK


func _on_peer_connected(id: int) -> void:
	print("Peer подключился: %d" % id)
	peer_connected = true
	
	if multiplayer.is_server():
		# При подключении клиента, хост сохраняет свое имя как Хост (0)
		player_names[0] = local_player_name if local_player_name != "" else "Хост"
	
	peer_connected_signal.emit()


func _on_peer_disconnected(id: int) -> void:
	print("Peer отключился: %d" % id)
	peer_connected = false
	if game_active:
		game_active = false
		game_over.emit(my_player_id)


func _on_connected_to_server() -> void:
	print("Подключено к серверу. Мой peer_id: %d" % multiplayer.get_unique_id())
	# Отправляем своё имя хосту
	_rpc_send_name.rpc_id(1, local_player_name)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_send_name(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	player_names[1] = player_name if player_name != "" else "Клиент"
	# Синхронизируем имена обоим
	_rpc_sync_names.rpc(player_names)
	names_updated.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_names(names: Array[String]) -> void:
	player_names = names
	names_updated.emit()


## Хост запускает игру для обоих
func start_multiplayer_game() -> void:
	if not multiplayer.is_server():
		return
	player_gold = [starting_gold, starting_gold]
	
	# Рандомизируем первого игрока
	current_player = randi() % 2
	
	turn = 1
	current_phase = Phase.ACTION
	game_active = true
	
	# Синхронизируем клиенту
	_rpc_start_game.rpc(starting_gold, starting_gold, current_player)
	
	game_started.emit()
	gold_changed.emit(player_gold[my_player_id])
	opponent_gold_changed.emit(player_gold[1 - my_player_id])
	player_changed.emit(current_player)
	
	# Инициализация колоды хоста и первый добор
	_init_draw_pile()
	# Добор карт для текущего игрока (если это я)
	if current_player == my_player_id:
		draw_cards(HAND_SIZE)


@rpc("authority", "call_remote", "reliable")
func _rpc_start_game(gold0: int, gold1: int, first_player: int) -> void:
	player_gold = [gold0, gold1]
	current_player = first_player
	turn = 1
	current_phase = Phase.ACTION
	game_active = true
	
	game_started.emit()
	gold_changed.emit(player_gold[my_player_id])
	opponent_gold_changed.emit(player_gold[1 - my_player_id])
	player_changed.emit(current_player)
	
	# Инициализация колоды клиента и первый добор
	_init_draw_pile()
	if current_player == my_player_id:
		draw_cards(HAND_SIZE)


# ===================== ИГРОВАЯ ЛОГИКА =====================

## Мой ли сейчас ход?
func is_my_turn() -> bool:
	return current_player == my_player_id


## Начать режим размещения юнита (в фазе ACTION)
func start_deploy(unit_data: UnitData) -> void:
	if current_phase != Phase.ACTION:
		return
	if not is_my_turn():
		return
	if player_gold[my_player_id] < unit_data.cost:
		return
	# Проверяем, что карта в руке
	if unit_data not in hand_cards:
		return
	deploying_unit_data = unit_data
	is_deploying = true
	deploy_mode_started.emit(unit_data)


## Отменить размещение
func cancel_deploy() -> void:
	deploying_unit_data = null
	is_deploying = false
	deploy_mode_ended.emit()


## Попытка разместить юнита — отправляет запрос на хост
func try_place_unit(grid_pos: Vector2i) -> bool:
	if not is_deploying or deploying_unit_data == null:
		return false
	if player_gold[my_player_id] < deploying_unit_data.cost:
		cancel_deploy()
		return false

	var data_name := deploying_unit_data.unit_name
	var unit_name := generate_unit_name()
	
	# Сигнал для анимации полёта карты к месту размещения
	card_deployed.emit(deploying_unit_data, grid_pos)
	
	# Убираем карту из руки в сброс
	play_card_from_hand(deploying_unit_data)
	
	if multiplayer.is_server():
		# Хост — сразу выполняем
		_execute_place_unit(data_name, grid_pos, unit_name, my_player_id)
	else:
		# Клиент — отправляем запрос хосту
		_rpc_request_place.rpc_id(1, data_name, grid_pos, unit_name)
	
	deploying_unit_data = null
	is_deploying = false
	deploy_mode_ended.emit()
	return true


## Клиент → Хост: запрос на размещение
@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_place(data_name: String, grid_pos: Vector2i, unit_name: String) -> void:
	if not multiplayer.is_server():
		return
	var player_id: int = 1
	# Серверная валидация
	var data := _find_unit_data(data_name)
	if data == null:
		return
	if player_gold[player_id] < data.cost:
		return
	if board_ref != null:
		if not board_ref.is_valid_cell(grid_pos):
			return
		if not board_ref.is_deploy_zone(grid_pos, player_id):
			return
		if board_ref.is_cell_occupied(grid_pos):
			return
	_execute_place_unit(data_name, grid_pos, unit_name, player_id)


## Выполнить размещение (на хосте) и синхронизировать
func _execute_place_unit(data_name: String, grid_pos: Vector2i, unit_name: String, player_id: int) -> void:
	var data := _find_unit_data(data_name)
	if data == null:
		return
	if player_gold[player_id] < data.cost:
		return
	
	player_gold[player_id] -= data.cost
	
	# Локально
	unit_should_be_placed.emit(data, grid_pos, unit_name, player_id)
	units_on_board[player_id] += 1
	_total_deployed[player_id] += 1
	_emit_gold_signals()
	
	# Синхронизировать клиенту (или хосту, если вызвал клиент)
	_rpc_sync_place.rpc(data_name, grid_pos, unit_name, player_id, player_gold[0], player_gold[1])


## Синхронизация размещения
@rpc("authority", "call_remote", "reliable")
func _rpc_sync_place(data_name: String, grid_pos: Vector2i, unit_name: String, player_id: int, gold0: int, gold1: int) -> void:
	player_gold = [gold0, gold1]
	var data := _find_unit_data(data_name)
	if data:
		unit_should_be_placed.emit(data, grid_pos, unit_name, player_id)
	_emit_gold_signals()


## Запрос на перемещение юнита
func request_move(from: Vector2i, to: Vector2i) -> void:
	if multiplayer.is_server():
		_execute_move(from, to)
	else:
		_rpc_request_move.rpc_id(1, from, to)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_move(from: Vector2i, to: Vector2i) -> void:
	if not multiplayer.is_server():
		return
	# Серверная валидация
	if board_ref == null:
		return
	if not board_ref.is_cell_occupied(from):
		return
	var unit := board_ref.occupied_cells[from] as Unit
	if unit == null or unit.owner_id != 1:
		return
	if not board_ref.is_move_valid(from, to):
		return
	_execute_move(from, to)


func _execute_move(from: Vector2i, to: Vector2i) -> void:
	# Валидация делается в Board
	unit_should_move.emit(from, to)
	_rpc_sync_move.rpc(from, to)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_move(from: Vector2i, to: Vector2i) -> void:
	unit_should_move.emit(from, to)


## Запрос на атаку
func request_attack(from: Vector2i, to: Vector2i, damage: int) -> void:
	if multiplayer.is_server():
		_execute_attack(from, to, damage)
	else:
		_rpc_request_attack.rpc_id(1, from, to, damage)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_attack(from: Vector2i, to: Vector2i, damage: int) -> void:
	if not multiplayer.is_server():
		return
	# Серверная валидация
	if board_ref == null:
		return
	if not board_ref.is_cell_occupied(from):
		return
	var attacker := board_ref.occupied_cells[from] as Unit
	if attacker == null or attacker.owner_id != 1:
		return
	if damage != attacker.unit_data.attack_power:
		return
	if not board_ref.is_attack_valid(from, to):
		return
	_execute_attack(from, to, damage)


func _execute_attack(from: Vector2i, to: Vector2i, damage: int) -> void:
	unit_attacked.emit(from, to, damage)
	_rpc_sync_attack.rpc(from, to, damage)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_attack(from: Vector2i, to: Vector2i, damage: int) -> void:
	unit_attacked.emit(from, to, damage)


## Перейти к следующей фазе (завершить ход)
func next_phase() -> void:
	if not is_my_turn():
		return
	if multiplayer.is_server():
		_execute_next_phase()
	else:
		_rpc_request_next_phase.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_next_phase() -> void:
	if not multiplayer.is_server():
		return
	_execute_next_phase()


func _execute_next_phase() -> void:
	# ACTION → INCOME → переключение игрока → ACTION
	current_phase = Phase.INCOME
	_process_income_and_switch()


func _process_income_and_switch() -> void:
	player_gold[current_player] += base_income
	
	# Переключаем игрока
	if current_player == 0:
		current_player = 1
	else:
		current_player = 0
		turn += 1
	
	current_phase = Phase.ACTION
	
	_emit_gold_signals()
	player_changed.emit(current_player)
	_sync_state_to_remote()
	
	# Локальная логика колоды: сбросить руку и добрать новые
	discard_hand()
	if current_player == my_player_id:
		draw_cards(HAND_SIZE)


func _sync_state_to_remote() -> void:
	_rpc_sync_state.rpc(
		current_phase as int, current_player, turn,
		player_gold[0], player_gold[1]
	)


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_state(phase: int, player: int, t: int, gold0: int, gold1: int) -> void:
	current_phase = phase as Phase
	current_player = player
	turn = t
	player_gold = [gold0, gold1]
	_emit_gold_signals()
	player_changed.emit(current_player)
	
	# Локальная логика колоды на клиенте: сбросить и добрать
	discard_hand()
	if current_player == my_player_id:
		draw_cards(HAND_SIZE)


## Вызывается при смерти юнита (из main.gd)
func on_unit_died(player_id: int) -> void:
	if not game_active:
		return
	units_on_board[player_id] = max(0, units_on_board[player_id] - 1)
	unit_died.emit(Vector2i.ZERO)
	_check_game_over()


func _check_game_over() -> void:
	if not game_active:
		return
	for pid in range(2):
		if units_on_board[pid] == 0 and _total_deployed[pid] > 0:
			var winner_id := 1 - pid
			game_active = false
			game_over.emit(winner_id)
			_rpc_sync_game_over.rpc(winner_id)
			return


@rpc("authority", "call_remote", "reliable")
func _rpc_sync_game_over(winner_id: int) -> void:
	game_active = false
	game_over.emit(winner_id)


func _emit_gold_signals() -> void:
	gold_changed.emit(player_gold[my_player_id])
	opponent_gold_changed.emit(player_gold[1 - my_player_id])


# ===================== УТИЛИТЫ =====================

func _find_unit_data(unit_name: String) -> UnitData:
	for u in available_units:
		if u.unit_name == unit_name:
			return u
	return null


func get_phase_name(p: Phase = current_phase) -> String:
	match p:
		Phase.ACTION:
			return "Действия"
		Phase.INCOME:
			return "Доход"
	return ""
