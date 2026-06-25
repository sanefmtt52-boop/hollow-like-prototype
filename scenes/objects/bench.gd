extends Area2D
## Bench — скамейка (точка сохранения / отдыха).
##
## Когда игрок входит в зону и нажимает "interact" (F):
##  - запоминаем эту скамейку как точку возрождения,
##  - полностью восстанавливаем здоровье.
## Area2D замечает игрока по группе "player" (см. player.gd).

@onready var prompt: Label = $Prompt

var _player_in_range: bool = false


func _ready() -> void:
	# Сигналы Area2D: тело вошло / вышло из зоны.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt.visible = false


func _process(_delta: float) -> void:
	if _player_in_range and Input.is_action_just_pressed("interact"):
		GameState.set_respawn(global_position)
		GameState.restore_full_health()
		GameState.save_game()  # пишем прогресс на диск
		GameState.show_message("Игра сохранена")
		prompt.text = "Сохранено!"


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		prompt.visible = true
		prompt.text = "F — отдохнуть"


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		prompt.visible = false
