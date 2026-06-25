# CLAUDE.md — гайд для Claude по этому проекту

Этот файл я (Claude) читаю в начале каждой сессии. Здесь — постоянный контекст проекта,
чтобы не путаться и не переспрашивать.

## О проекте
Учебный прототип 2D-метроидвании в стиле **Hollow Knight**. Делаем с нуля.
Цель: сначала ядро механик + один расширяемый уровень, потом наращиваем контент.

## Стек и окружение
- **Движок: Godot 4.7** (Standard, без .NET). Язык: **GDScript**.
- ОС: Windows 11, оболочка PowerShell. Godot НЕ в PATH (запускается вручную из редактора).
- Папка проекта: `c:\Users\МИкс\OneDrive\Документы\Холоу найт`.
- Главная сцена: `res://scenes/levels/level_01.tscn`. Запуск игры — F5 в редакторе.

## Как со мной работать (важно!)
- Пользователь — **новичок** в программировании и геймдеве, язык общения **русский**.
- Код — **с подробными комментариями на русском**. Объяснять концепции Godot простыми словами.
- Идём **по милстоунам M1→M5**, каждый шаг должен быть играбелен. После моих изменений
  пользователь сам запускает игру (F5) и сообщает результат — я НЕ могу запустить Godot сам.
- `.tscn`/`.gd` пишу текстом вручную. Если Godot выдаёт ошибку — прошу текст ошибки и правлю.

## Конвенции кода
- Сцена `.tscn` и её скрипт `.gd` лежат рядом в одной папке.
- Глобальное состояние — синглтон **`GameState`** (autoload), доступен везде по имени.
- Связь логики и UI — через **сигналы** (GameState эмитит, HUD слушает). Не дёргать UI напрямую.
- Числа геймплея — `@export`-переменные в скриптах + дублируются в `docs/game_design.md`.
- Слои физики: 1=world, 2=player, 3=enemy, 4=player_hitbox, 5=player_hurtbox.
- Управление — через имена действий Input Map (`jump`, `attack`...), не коды клавиш.
- Графика пока — цветные `Polygon2D` (заглушки). Ассеты прикрутим позже; каждый ассет
  записывать в `docs/CREDITS.md` с лицензией.

## Git / GitHub
- Репозиторий: **https://github.com/sanefmtt52-boop/hollow-like-prototype** (public), ветка `main`, remote `origin`.
- Установлены `git` (2.54) и `gh` (2.95), пользователь залогинен в gh (аккаунт `sanefmtt52-boop`).
- **В PowerShell-вызовах git/gh могут быть не в PATH** — в начале команды обновлять:
  `$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")`
- Когда пользователь просит «сохрани на гитхаб» → `git add -A; git commit -m "..."; git push`.
  Коммит-сообщения на русском. `gh auth login` запускает ТОЛЬКО пользователь (интерактивно).

## Грабли при ручной правке .tscn (проверять!)
- **Корневой узел сцены НЕ должен иметь `parent="..."`** (пиши `[node name="X" type="Y"]`).
  Только дочерние узлы получают `parent="."` / `parent="Имя"`. Иначе: "root node ... cannot
  specify a parent node" → сцена не грузится и тянет за собой всех, кто её инстансит.
- `load_steps` = (кол-во ext_resource + sub_resource) + 1. Несовпадение — лишь предупреждение.

## Структура
```
project.godot              настройки (управление, autoload, гл. сцена)
scenes/player/             игрок (player.tscn + player.gd)
scenes/enemies/            враги (M3)
scenes/levels/             уровни (level_01)
scenes/objects/            скамейка, пикапы (M3-M4)
scenes/ui/                 HUD
scripts/autoload/          GameState
docs/                      game_design.md, CREDITS.md
assets/                    sprites/audio/fonts (пока пусто)
```

## Прогресс по милстоунам
- [x] **M1** — движение, прыжок (coyote time + jump buffer + переменная высота), уровень, камера, HUD, GameState. **Проверено пользователем: работает.**
- [x] **M2** — бой гвоздём (удар во все стороны, pogo вниз) + Soul + лечение (Focus) + враг-мишень.
  Важно: лечиться при ПОЛНОМ HP нельзя (как в HK), поэтому soul не тратится — это не баг.
- [x] **M3** — враг-crawler (патруль + разворот у стены/края), контактный урон игроку (knockback +
  i-frames с миганием), смерть/респаун у скамейки, скамейка (F — сохранение + полное лечение).
- [x] **M4** — пикап рывка (`ability_pickup`, ставит `has_dash`), пропасть-«ворота» (gap 300px,
  без даша не перепрыгнуть), система сообщений на экране, зона падения (возврат к точке сохранения).
- [~] **M5** — сохранение на диск (`user://save.json`, JSON). Пишется на скамейке (`save_game`),
  читается при старте (`GameState._ready -> load_game`). Игрок появляется у сохранённой скамейки.
  `GameState.delete_save()` — сброс (новая игра). **Код готов, ждём проверку пользователем.**
- [x] **M6** — заклинание «Vengeful Spirit» (клавиша I): снаряд `spell_projectile` за 33 soul,
  летит в сторону взгляда, бьёт первого врага (`take_damage(15)`). Флаг `GameState.has_spell`
  (по умолчанию true). **Проверено пользователем: работает.**
- [x] **M7** — чармы (амулеты). Тип-ресурс `Charm` (`scripts/charm.gd`), каталог из 5 чармов
  в коде (`GameState._build_charm_catalog`), хранилище (notch_capacity=3, owned/equipped),
  применение бонусов в `player.gd`, экран экипировки `charm_menu` (клавиша C, пауза), пикапы
  `charm_pickup` в уровне, сохранение в JSON. **Проверено пользователем: работает.**

ПРОТОТИП СОБРАН (M1-M5) + добавлены спелл (M6) и чармы (M7). Дальше — расширение: ассеты,
второй спелл/враг/уровень, полировка.

## Дорожная карта (следующие шаги, ещё не начаты)
Приоритет не задан — спросить пользователя, с чего начать.
1. **Графика (ассеты).** Заменить цветные `Polygon2D` на спрайты. Игроку — `AnimatedSprite2D`
   (idle/run/jump/attack), уровню — `TileMapLayer` с тайлсетом. Источники: Kenney (CC0),
   Ansimuz (itch.io). Каждый ассет писать в `docs/CREDITS.md` с лицензией. Хитбоксы/коллизии
   не трогать — меняется только визуал.
2. **Контент.** Второй тип врага (напр. летающий/прыгающий), новые платформенные секции,
   второй уровень + переход между сценами (зоны-двери `Area2D` → `change_scene_to_file`,
   состояние переносит `GameState`).
3. ~~**Боевая глубина.** Charms + спелл Vengeful Spirit.~~ **СДЕЛАНО (M6–M7), ждёт проверки.**
   Осталось по желанию: второй/третий спелл (вверх/вниз), рост числа ячеек (notch_capacity),
   привязка меню чармов к скамейке вместо клавиши C, больше чармов.
4. **Полировка.** Звук (решить проблему с аудиодрайвером у пользователя), частицы при ударе,
   меню/пауза/экран смерти, кнопка «Новая игра» (`GameState.delete_save()`).

## Как продолжить в новой сессии
- Прочитать этот файл + `docs/game_design.md`. Прогресс — в чек-листе милстоунов выше.
- Спросить пользователя, какой пункт дорожной карты делаем.
- Рабочий цикл: правлю файлы → пользователь запускает F5 и сообщает результат → по «коммить»
  делаю `git add -A; git commit; git push` (PATH для git/gh обновлять, см. раздел Git/GitHub).

## Управление
A/D или стрелки — движение · W/S или ↑/↓ — прицел удара · Space — прыжок ·
J — атака · K — даш · L — лечение (Focus) · I — заклинание (Vengeful Spirit) ·
C — меню чармов · F — действие (скамейка/пикап).

## Текущее состояние кода (детали, которые легко забыть)
- `player.gd`: даш написан, но заблокирован (`GameState.has_dash=false`) — включится в M4.
  Атака — корутина `_do_attack()` (await physics_frame для регистрации overlaps), вызывается
  без await. Хитбокс `$NailHitbox` (Area2D, layer 8 / mask 4), позиция меняется под направление.
  Pogo: удар "down" в воздухе по врагу → `velocity.y=pogo_velocity`. Спрайт зеркалится `$Visual.scale.x`.
- `enemy_crawler.gd`: патруль (`patrol_speed`), разворот при `is_on_wall()` или когда `$FloorCheck`
  (RayCast2D-щуп вниз перед собой) не видит пол. В группе "enemy", метод `take_damage(amount)`, HP=10.
  Контактный урон игроку идёт через Hurtbox игрока (враг про игрока не знает). Слой врага = 3 (layer=4).
- Урон игроку: `$Hurtbox` (Area2D, layer 16 / mask 4) ловит врагов; `_take_hit` → `take_damage(1)` +
  i-frames (`_invincible_timer`, мигание через `$Visual.modulate.a`) + откидывание (`_knockback_timer`,
  во время него управление отключено). Смерть → `GameState.player_died` → `_on_player_died` (респаун).
- `bench.gd` (`scenes/objects/`): Area2D, при `interact` (F) в зоне → `set_respawn` + `restore_full_health`.
- `ability_pickup.gd` (`scenes/objects/`): Area2D, при касании игрока → `has_dash=true` + `show_message` + `queue_free`.
  В `_ready` сам удаляется, если способность уже открыта (иначе после загрузки сейва пикап лежит повторно).
  Этот паттерн (пикап исчезает, если эффект уже применён) повторять для будущих подбираемых предметов.
- Сообщения: `GameState.show_message(text)` → сигнал `message` → HUD `MessageLabel` (исчезает через 2.5с).
- Спелл (M6): `player._try_cast()` по клавише `cast` (I), если `has_spell` и хватило 33 soul
  (`spend_soul_for_cast`), `instantiate` сцену `spell_projectile` в `get_parent()` (уровень),
  задаёт `direction=_facing`. Снаряд — Area2D (layer 0 / mask 4), летит, `body_entered` → урон врагу.
- Чармы (M7): `scripts/charm.gd` (`class_name Charm extends Resource`, поля-эффекты). Каталог в коде
  (`GameState._build_charm_catalog`, 5 чармов). Хранилище: `notch_capacity`, `owned_charm_ids`,
  `equipped_charm_ids`; функции `equip_charm/unequip_charm/toggle_charm/can_equip`, сигнал `charms_changed`.
  Бонусы суммируются в `_recalc_charm_bonuses` (nail_damage_bonus, soul_per_hit_bonus, move_speed_mult,
  focus_time_mult, nail_range_mult), `player.gd` читает их в точке применения. Меню `scenes/ui/charm_menu`
  (CanvasLayer, `process_mode=Always`, клавиша C, ставит `get_tree().paused`). Пикапы `charm_pickup`
  (поле `charm_id`, паттерн «исчезает, если уже получен»). Всё сохраняется в JSON.
- Падение: `player._check_fall()` — если `global_position.y > fall_limit (800)` → `_respawn_at_savepoint()`
  (общий метод, его же зовёт `_on_player_died`, но смерть ещё и полностью лечит).
- Уровень `level_01`: пол разделён на FloorLeft (x -100..1000) и FloorRight (1300..1600), пропасть 300px.
  Пикап рывка на FloorLeft у края (960,430), за пропастью «ЦЕЛЬ». Даш: `dash_time=0.24`.
- `game_state.gd`: есть `add_soul`, `spend_soul_for_cast`, `can_cast`, `take_damage`, `heal`,
  `restore_full_health`, `set_respawn` + функции чармов (см. выше). `save_game`/`load_game` —
  рабочие (JSON), сохраняют HP, soul, has_dash, has_spell, точку респауна и чармы.
- Лечение Focus: держать L на земле, тратит 33 soul, лечит 1 маску за `focus_time` (0.9с).
  Видно только если HP не полное (полноценно проверится в M3, когда враги наносят урон).
- Версия движка в `project.godot` управляется самим редактором Godot — не перетирать вручную.
