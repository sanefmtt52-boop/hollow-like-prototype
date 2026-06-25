extends Area2D
## SpellProjectile — снаряд заклинания «Vengeful Spirit» (мстительный дух).
##
## Это самостоятельный объект: игрок «выпускает» его (создаёт копию сцены в рантайме),
## после чего снаряд живёт сам по себе — летит по прямой, бьёт первого врага и исчезает.
##
## Area2D выбран потому, что снаряду не нужна физика тел (он не падает, не отскакивает),
## а нужно лишь ЛОВИТЬ пересечение с врагом. collision_mask = слой 3 (enemy) — см. сцену.

# --- Настройки (можно крутить в инспекторе) ---
@export var speed: float = 600.0    # скорость полёта, px/с
@export var lifetime: float = 0.8   # сколько секунд живёт, если ни в кого не попал
@export var damage: int = 15        # урон врагу при попадании

# Направление полёта по горизонтали: 1 = вправо, -1 = влево.
# Игрок задаёт это поле сразу после создания снаряда (см. player._try_cast).
var direction: int = 1

var _life_timer: float = 0.0


func _ready() -> void:
	_life_timer = lifetime
	# Зеркалим визуал по направлению, чтобы «нос» ромба смотрел туда, куда летим.
	$Polygon2D.scale.x = direction
	# Подписываемся на касание тел: когда снаряд пересечётся с телом — сработает _on_body_entered.
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	# Двигаем снаряд по горизонтали (global_position — мировые координаты,
	# не зависят от того, к какому узлу нас прикрепили).
	global_position.x += direction * speed * delta

	# Считаем время жизни; вышло — исчезаем (чтобы снаряды не копились бесконечно).
	_life_timer -= delta
	if _life_timer <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	# Бьём только врагов — как и гвоздь, опознаём их по группе "enemy".
	if body.is_in_group("enemy"):
		body.take_damage(damage)
		queue_free()  # снаряд тратится на одного врага и пропадает
