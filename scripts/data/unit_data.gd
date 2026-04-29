extends Resource
class_name UnitData

## Данные типа юнита (ресурс)

## Название типа юнита
@export var unit_name: String = ""
## Описание юнита (отображается на карте)
@export_multiline var description: String = ""
## Арт / портрет юнита
@export var portrait: Texture2D
## Стоимость в монетах
@export var cost: int = 1
## Максимальное здоровье
@export var max_hp: int = 1
## Сила атаки
@export var attack_power: int = 1
## Дальность хода (в клетках)
@export var move_range: int = 1
enum AttackPattern {
	NORMAL,        # Квадрат вокруг юнита (attack_range)
	FORWARD_CONE   # 3 клетки перед юнитом (прямо и по диагонали)
}

## Дальность атаки (в клетках)
@export var attack_range: int = 1
## Паттерн атаки
@export var attack_pattern: AttackPattern = AttackPattern.NORMAL
