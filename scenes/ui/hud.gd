extends CanvasLayer
## HUD — интерфейс поверх игры (здоровье и Soul).
##
## CanvasLayer рисуется поверх мира и НЕ двигается вместе с камерой,
## поэтому интерфейс всегда на экране.
##
## HUD ничего не считает сам — он только слушает сигналы GameState
## и обновляет текст. Это и есть смысл сигналов: логика отдельно, UI отдельно.

@onready var health_label: Label = $HealthLabel
@onready var soul_label: Label = $SoulLabel


func _ready() -> void:
	# Подключаемся к сигналам синглтона GameState.
	# Когда GameState вызовет health_changed.emit(...), сработает _on_health_changed.
	GameState.health_changed.connect(_on_health_changed)
	GameState.soul_changed.connect(_on_soul_changed)

	# Показываем актуальные значения сразу при запуске.
	_on_health_changed(GameState.health, GameState.MAX_HEALTH)
	_on_soul_changed(GameState.soul, GameState.MAX_SOUL)


func _on_health_changed(current: int, maximum: int) -> void:
	# Рисуем здоровье "масками": ♥ за каждую жизнь, ♡ за потерянную.
	health_label.text = "HP: " + "♥".repeat(current) + "♡".repeat(maximum - current)


func _on_soul_changed(current: int, maximum: int) -> void:
	soul_label.text = "SOUL: %d / %d" % [current, maximum]
