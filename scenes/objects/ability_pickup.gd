extends Area2D
## AbilityPickup — подбираемая способность (в M4 это рывок/даш).
##
## Как только игрок касается пикапа: открываем способность в GameState,
## показываем сообщение и удаляем пикап. Это "ключ" метроидвании —
## после него открывается участок уровня, недоступный раньше.

func _ready() -> void:
	# Если рывок уже открыт (например, после загрузки сохранения) —
	# убираем пикап сразу, чтобы он не лежал повторно.
	if GameState.has_dash:
		queue_free()
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameState.has_dash = true
		GameState.show_message("Получен РЫВОК! В прыжке жми K, чтобы рвануть вперёд")
		queue_free()
