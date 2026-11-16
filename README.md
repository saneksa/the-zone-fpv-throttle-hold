# throttle_hold 1.0 — Безопасный респавн для The Zone FPV

[![EN](https://img.shields.io/badge/English-README.en.md-blue)](README.en.md)

Мод для симулятора FPV-дронов **[The Zone – FPV Drone Simulator](https://store.steampowered.com/app/3491280/The_Zone__FPV_Drone_Simulator/)**, работающий через загрузчик модов **[zonemods](https://github.com/goodluckNito/The-Zone-FPV-mods)**.

Мод удерживает дрон **обездвиженным на земле после старта и каждого респавна**, пока пилот физически не опустит стик газа в ноль. Больше никаких подскоков и самовзлётов при нажатии `R` или кнопки респавна на пульте.

---

## К чему применяется этот мод (ссылки)

| Что | Ссылка |
|---|---|
| **Игра в Steam** | https://store.steampowered.com/app/3491280/The_Zone__FPV_Drone_Simulator/ (App ID `3491280`) |
| **Официальная вики игры** | https://wiki.thezonefpv.com/ |
| **Загрузчик модов zonemods** | https://github.com/goodluckNito/The-Zone-FPV-mods |
| **Раздел модов в вики** | https://wiki.thezonefpv.com/ (поиск по «mods» / «zonemods») |

Мод рассчитан на версию игры с движком Godot 4.x (проверено на сборке с `thezone.pck` / Godot `4.7.2`) и требует установленный загрузчик **[zonemods](https://github.com/goodluckNito/The-Zone-FPV-mods)**. Файлы загрузчика **не включены в этот репозиторий** — это сторонний код, его нужно установить отдельно (см. «Установка»).

---

## Проблема, которую решает мод

В оригинальной игре при респавне дрона — по клавише `R`, тумблеру/кнопке респавна на аппаратуре или команде `/respawn` — если стик газа остался поднятым (например, в среднем положении после падения), дрон **мгновенно подпрыгивает или улетает вверх** с тем газом, на котором стоит стик.

Стандартный мод `throttle_fix` из коллекции zonemods исправляет только ошибку **первого чтения SDL** при подключении пульта (когда SDL отдаёт `0.0` = 50% газа до первого движения стика), но **не влияет на респавн**.

`throttle_hold` гарантирует, что после каждого старта и каждого респавна:

1. Дрон **стоит на земле намертво**, без малейшего подскока, моторы выключены (`DISARMED`).
2. Пока стик газа выше нуля, на OSD отображается предупреждение `LOWER THROTTLE TO ARM`.
3. Дрон взводится (`ARMED`) и разрешает взлёт **только после того, как пилот опустит стик газа в ноль**.

---

## Почему дрон подскакивает в оригинальной игре (технический разбор)

Скрипт квадрокоптера `player_rigid_body.gd` (лежит внутри `thezone.pck`) при респавне делает следующее:

```gdscript
func respawn():
    teleported.emit()
    if physics_handler:
        physics_handler.respawn()
        return
    transform = ZGamestate.respawn_transform
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
```

При этом игра:

1. **Не сбрасывает флаг `auto_armed`** — он остаётся `true`.
2. **Не обнуляет обороты моторов `current_motor_rpm`.** Если перед респавном вы летели на ~50% газа, значение `current_motor_rpm` составляет порядка 15 000 RPM и снижается со скоростью `MOTOR_RPM_DEC_PER_SECOND = 170000` (~50 физик-тиков). Даже если сразу после телепорта зажать ось газа в ноль, остаточные обороты винтов в первые кадры создают тягу вверх и подбрасывают дрон примерно на 1 метр.

Именно эта остаточная тяга и являлась причиной подскока, который не устранялся ни инжектом событий джойстика, ни срабатыванием по «скачку координат».

---

## Как работает `throttle_hold`

1. Мод находит узел игрока (`/root/ZCommands.player`, либо по скрипту `player_rigid_body`) и подписывается на встроенный сигнал **`Player.teleported`**. Игра испускает его **синхронно в первой строке `respawn()`**, то есть ещё до следующего физического тика.
2. В момент сигнала мод мгновенно выставляет:
   - `player.auto_armed = false`, `player.manually_armed = false`;
   - `player.current_motor_rpm = 0.0`;
   - `player.linear_velocity = Vector3.ZERO`, `player.angular_velocity = Vector3.ZERO`.
3. Пока `is_armed()` возвращает `false`, сама игра в `Player._physics_process` обнуляет вектор тяги (`force_in_direction = Vector3.ZERO`), отключает момент вращения и звук моторов — но продолжает читать реальное положение стика в `player.throttle_input` (диапазон `0.0 .. 1.0`).
4. Как только пилот опускает стик (`throttle_input <= release_threshold`, по умолчанию `0.05` = 5%), мод снимает предупреждение с OSD, ставит `auto_armed = true` — и дрон спокойно взлетает при следующем движении газа вверх.

Мод не подменяет скрипт игры и не ломает физику: он только корректно сбрасывает состояние взведения в нужный момент.

---

## Установка

1. Установите загрузчик **[zonemods](https://github.com/goodluckNito/The-Zone-FPV-mods)** по инструкции в его репозитории. Его файлы (**`zonemods/zonemods.gd`**) — сторонний код и **не входят в этот репозиторий**.
2. В Steam: ПКМ по **The Zone – FPV Drone Simulator** → **Управление** → **Просмотреть локальные файлы**. Откроется папка `steamapps/common/The Zone FPV`.
3. Скопируйте в неё папку `throttle_hold` и файл `override.cfg` (если `override.cfg` уже есть от zonemods — убедитесь, что в нём есть строка автозагрузки из раздела ниже).

Структура после установки (файлы загрузчика ставятся из его собственного репозитория):

```text
The Zone FPV/
├── thezone.exe
├── override.cfg          ← из этого репозитория
├── zonemods/             ← из репозитория zonemods
│   └── zonemods.gd
└── throttle_hold/        ← из этого репозитория
    ├── main.gd
    ├── zonemod.cfg
    ├── settings.default.cfg
    ├── README.md
    ├── README.en.md
    └── README.txt
```

Содержимое `override.cfg` (автозагрузка загрузчика модов):

```ini
[autoload]
ZoneMods="*res://zonemods/zonemods.gd"
```

---

## Настройка

При первом запуске загрузчик создаст файл `throttle_hold/settings.cfg` из шаблона `settings.default.cfg`:

```ini
[mod]
enabled=true

[throttle_hold]
release_threshold=0.05
```

- `enabled` — `false` временно отключает мод без удаления файлов.
- `release_threshold` — порог стика газа (`0.01 .. 0.15`; `0.05` = 5%), при котором мод считает газ опущенным и взводит дрон.

После изменения `settings.cfg` перезапустите игру.

### Диагностика

- `zonemods/status.txt` — список загруженных модов. Должно быть `OK throttle_hold 1.0`.
- `throttle_hold/status.txt` — лог работы мода за последний запуск (события `hold`, `released`, текущий порог).

Если мод не загрузился, проверьте, что `override.cfg` и папка `zonemods` лежат рядом с `thezone.exe`, а в логе нет ошибок `Parse Error` / `Failed to load script`.

---

## Удаление

1. Установите `enabled=false` в `throttle_hold/settings.cfg` — мод перестанет влиять на игру.
2. Для полного удаления удалите папку `throttle_hold` (и `override.cfg`, если больше никакие моды не используются). Загрузчик `zonemods` удаляется по его собственной инструкции.

---

## Совместимость

- Игра: **The Zone – FPV Drone Simulator** (Steam, App ID `3491280`).
- Загрузчик: **zonemods** `requires=1`.
- Мод несовместим с модификациями, которые подменяют `player_rigid_body.gdc` (например, `flight_controller`), если они меняют логику `respawn()` / `is_armed()`. Обычно сосуществует с модами, работающими через API zonemods.
- Оригинальный `throttle_fix` можно оставить установленным — он решает другую проблему и на респавн не влияет.

---

## Благодарности

- Автору игры **The Zone FPV** и сообществу за документацию.
- Автору загрузчика [zonemods — goodluckNito](https://github.com/goodluckNito/The-Zone-FPV-mods).

---

## English

English version: [README.en.md](README.en.md)
