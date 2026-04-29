extends Node

var _players: Array[AudioStreamPlayer] = []
var _sounds: Dictionary = {}

# Здесь можно настроить базовую громкость для каждого звука (в децибелах)
# 0.0 - оригинальная громкость, -5.0 - тише, 5.0 - громче
var _volumes: Dictionary = {
	"arrow": 0.0,
	"sword": 0.0,
	"ui_click": 0.0,
	"card_hover": -5.0, # Звук карт по умолчанию тише
	"movement": -2.0
}

func _ready() -> void:
	# Предзагружаем звуки из корня проекта
	_sounds["arrow"] = preload("res://assets/audio/arrow.wav")
	_sounds["sword"] = preload("res://assets/audio/sword.wav")
	_sounds["ui_click"] = preload("res://assets/audio/ui-click.wav")
	_sounds["card_hover"] = preload("res://assets/audio/card-hover-over.wav")
	_sounds["movement"] = preload("res://assets/audio/movement.wav")
	
	# Создаем пул плееров (чтобы звуки могли накладываться)
	for i in range(12):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)

func play_sound(sound_name: String, pitch_scale: float = 1.0, volume_offset_db: float = 0.0) -> void:
	if not _sounds.has(sound_name):
		push_warning("Sound not found: " + sound_name)
		return
		
	for p in _players:
		if not p.playing:
			p.stream = _sounds[sound_name]
			p.pitch_scale = pitch_scale
			
			# Итоговая громкость = базовая громкость + смещение из кода
			var base_vol: float = _volumes.get(sound_name, 0.0)
			p.volume_db = base_vol + volume_offset_db
			
			p.play()
			return
			
	push_warning("AudioManager: No free players available to play " + sound_name)
