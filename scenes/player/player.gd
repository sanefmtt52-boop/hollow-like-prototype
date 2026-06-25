extends CharacterBody2D
## Player — управление персонажем (движение, прыжок, даш, бой, лечение).
##
## CharacterBody2D — узел Godot для персонажей, которыми управляет код.
## Мы задаём velocity (скорость), а move_and_slide() двигает тело и
## обрабатывает столкновения. Управление в стиле Mega Man X: без инерции
## по горизонтали, большой контроль в воздухе.

# --- Движение ---
@export var speed: float = 300.0
@export var jump_velocity: float = -420.0
@export var gravity: float = 980.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.1
@export var jump_cut_factor: float = 0.5

# --- Даш (открывается пикапом в M4; см. GameState.has_dash) ---
@export var dash_speed: float = 700.0
@export var dash_time: float = 0.18
@export var dash_cooldown: float = 0.5

# --- Бой гвоздём ---
@export var nail_damage: int = 5
@export var attack_cooldown: float = 0.25
@export var pogo_velocity: float = -380.0  # отскок вверх при ударе вниз (pogo)

# --- Лечение (Focus) ---
@export var focus_time: float = 0.9  # сколько держать кнопку, чтобы вылечить 1 маску

# --- Получение урона ---
@export var invincible_time: float = 1.0   # кадры неуязвимости после удара
@export var knockback_force: float = 320.0 # сила откидывания от врага
@export var knockback_time: float = 0.2    # сколько длится откидывание (без управления)

# --- Внутренние таймеры/состояния ---
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _attack_cooldown_timer: float = 0.0
var _focus_timer: float = 0.0
var _invincible_timer: float = 0.0
var _knockback_timer: float = 0.0
var _is_dashing: bool = false
var _facing: int = 1  # 1 = вправо, -1 = влево
var _spawn_position: Vector2 = Vector2.ZERO  # стартовая точка (если ещё нет скамейки)


func _ready() -> void:
	add_to_group("player")
	_spawn_position = global_position
	# Подписываемся на смерть: когда здоровье дойдёт до 0, GameState крикнет player_died.
	GameState.player_died.connect(_on_player_died)


func _physics_process(delta: float) -> void:
	# Уменьшаем таймеры каждый кадр.
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_attack_cooldown_timer = maxf(_attack_cooldown_timer - delta, 0.0)
	_invincible_timer = maxf(_invincible_timer - delta, 0.0)
	_update_invincible_blink()

	# Во время рывка обрабатываем только его.
	if _is_dashing:
		_process_dash(delta)
		return

	# Во время откидывания не слушаем управление — просто летим по инерции.
	if _knockback_timer > 0.0:
		_knockback_timer -= delta
		_apply_gravity(delta)
		move_and_slide()
		return

	_apply_gravity(delta)
	_handle_horizontal()
	_handle_focus(delta)   # лечение может обнулить горизонтальную скорость
	_handle_jump(delta)
	_try_start_dash()
	_try_attack()
	_check_enemy_contact()  # касание врага -> урон (если не неуязвимы)

	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func _handle_horizontal() -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed
	if direction != 0:
		_facing = signi(int(direction))
		$Visual.scale.x = _facing  # зеркалим спрайт по направлению взгляда


func _handle_jump(delta: float) -> void:
	# Coyote time: на полу держим таймер полным, в воздухе он тает.
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	# Jump buffer: запоминаем нажатие прыжка на короткое время.
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	# Переменная высота: отпустил прыжок на подъёме — гасим скорость.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_factor


# --- Лечение (Focus) ---

func _handle_focus(delta: float) -> void:
	# Лечимся, только если: держим кнопку, стоим на земле, не полное здоровье,
	# и хватает soul. Во время лечения стоим на месте.
	var channeling := (
		Input.is_action_pressed("focus")
		and is_on_floor()
		and GameState.health < GameState.MAX_HEALTH
		and GameState.can_cast()
	)
	if channeling:
		velocity.x = 0.0
		_focus_timer += delta
		if _focus_timer >= focus_time:
			_focus_timer = 0.0
			if GameState.spend_soul_for_cast():
				GameState.heal(1)
	else:
		_focus_timer = 0.0


# --- Даш ---

func _try_start_dash() -> void:
	if not GameState.has_dash:
		return
	if Input.is_action_just_pressed("dash") and _dash_cooldown_timer <= 0.0:
		_is_dashing = true
		_dash_timer = dash_time
		_dash_cooldown_timer = dash_cooldown
		velocity = Vector2(_facing * dash_speed, 0.0)


func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	velocity.y = 0.0
	move_and_slide()
	if _dash_timer <= 0.0:
		_is_dashing = false


# --- Бой гвоздём ---

func _try_attack() -> void:
	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0:
		_attack_cooldown_timer = attack_cooldown
		# _do_attack — корутина (есть await). Вызываем БЕЗ await: она работает
		# "в фоне", а основной _physics_process продолжает движение без задержки.
		_do_attack(_get_attack_direction())


func _get_attack_direction() -> String:
	# Приоритет: вверх -> вниз (только в воздухе, для pogo) -> в сторону.
	if Input.is_action_pressed("move_up"):
		return "up"
	if Input.is_action_pressed("move_down") and not is_on_floor():
		return "down"
	return "side"


func _do_attack(dir: String) -> void:
	var hitbox: Area2D = $NailHitbox

	# Ставим хитбокс в сторону удара.
	match dir:
		"up":
			hitbox.position = Vector2(0, -50)
		"down":
			hitbox.position = Vector2(0, 50)
		_:
			hitbox.position = Vector2(_facing * 40, 0)

	_show_swing()

	# Включаем хитбокс и ждём 2 физических кадра, чтобы движок успел
	# зарегистрировать пересечения (overlaps появляются не мгновенно).
	hitbox.monitoring = true
	await get_tree().physics_frame
	await get_tree().physics_frame

	var hit_enemy := false
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("enemy"):
			body.take_damage(nail_damage)
			hit_enemy = true

	hitbox.monitoring = false

	if hit_enemy:
		GameState.add_soul(GameState.SOUL_PER_HIT)
		# Pogo: удар вниз в воздухе по врагу отталкивает игрока вверх.
		if dir == "down" and not is_on_floor():
			velocity.y = pogo_velocity


func _show_swing() -> void:
	# Кратко показываем "взмах" (белый прямоугольник у хитбокса).
	var swing: Polygon2D = $NailHitbox/SwingVisual
	swing.visible = true
	await get_tree().create_timer(0.1).timeout
	swing.visible = false


# --- Получение урона ---

func _check_enemy_contact() -> void:
	# Пока неуязвимы — урон не берём.
	if _invincible_timer > 0.0:
		return
	for body in $Hurtbox.get_overlapping_bodies():
		if body.is_in_group("enemy"):
			_take_hit(body)
			break


func _take_hit(enemy: Node2D) -> void:
	GameState.take_damage(1)
	_invincible_timer = invincible_time
	_knockback_timer = knockback_time
	# Откидываемся в сторону ОТ врага и немного вверх.
	var away := signi(int(global_position.x - enemy.global_position.x))
	if away == 0:
		away = -_facing
	velocity = Vector2(away * knockback_force, -180.0)


func _update_invincible_blink() -> void:
	# Мигаем во время неуязвимости (визуальный сигнал "меня нельзя бить").
	if _invincible_timer > 0.0:
		$Visual.modulate.a = 0.35 if int(_invincible_timer * 12) % 2 == 0 else 1.0
	else:
		$Visual.modulate.a = 1.0


func _on_player_died() -> void:
	# Возрождаемся: у последней скамейки, либо на стартовой точке.
	var target := GameState.respawn_position if GameState.has_respawn_point else _spawn_position
	global_position = target
	velocity = Vector2.ZERO
	_knockback_timer = 0.0
	_invincible_timer = invincible_time  # короткая защита после возрождения
	GameState.restore_full_health()


## Направление взгляда (1 вправо / -1 влево).
func get_facing() -> int:
	return _facing
