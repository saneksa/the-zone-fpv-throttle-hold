# throttle_hold 1.0 — Safe Respawn Throttle Hold for The Zone FPV

[![RU](https://img.shields.io/badge/Русский-README.md-red)](README.md)

A mod for **[The Zone – FPV Drone Simulator](https://store.steampowered.com/app/3491280/The_Zone__FPV_Drone_Simulator/)**, loaded via the **[zonemods](https://github.com/goodluckNito/The-Zone-FPV-mods)** mod loader.

It keeps the drone **disarmed and sitting still on the ground after the initial spawn and every respawn**, until the pilot physically lowers the throttle stick to zero. No more hopping or self-launching when pressing `R` or the radio's respawn switch.

---

## What this mod applies to (links)

| What | Link |
|---|---|
| **Game on Steam** | https://store.steampowered.com/app/3491280/The_Zone__FPV_Drone_Simulator/ (App ID `3491280`) |
| **Official game wiki** | https://wiki.thezonefpv.com/ |
| **zonemods mod loader** | https://github.com/goodluckNito/The-Zone-FPV-mods |

The mod targets the Godot 4.x build of the game (verified on a build with `thezone.pck` / Godot `4.7.2`) and requires the **[zonemods](https://github.com/goodluckNito/The-Zone-FPV-mods)** loader. The loader's files are **not bundled in this repository** — it is third-party code and must be installed separately (see Installation).

---

## The problem it solves

In the stock game, when you respawn (with `R`, a radio respawn switch, or `/respawn`) while the throttle stick is raised — for example left at mid after a crash — the drone **immediately hops or flies upward** with whatever throttle the stick is at.

The stock `throttle_fix` mod from the zonemods collection only fixes the **first SDL read** when a controller is connected (SDL reports `0.0` = 50% throttle before the stick is first moved); it **does not affect respawn**.

`throttle_hold` guarantees that after every spawn and every respawn:

1. The drone **sits still on the ground** with zero hop, motors stopped (`DISARMED`).
2. While the physical throttle stick is above zero, `LOWER THROTTLE TO ARM` is shown on the OSD.
3. The drone arms (`ARMED`) and is ready to fly **only after the pilot lowers the throttle stick to zero**.

---

## Why the drone hops in the stock game (tech details)

The game's quad script `player_rigid_body.gd` (inside `thezone.pck`) does this on respawn:

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

The game:

1. **Does not reset the `auto_armed` flag** — it stays `true`.
2. **Does not zero `current_motor_rpm`.** If you were flying at ~50% throttle before respawning, `current_motor_rpm` is around 15,000 RPM, spinning down at `MOTOR_RPM_DEC_PER_SECOND = 170000` (~50 physics ticks). Even if the throttle axis is pushed to zero right after the teleport, residual prop RPM produces upward thrust during the first frames and hops the drone about one meter.

That residual thrust is the actual cause of the hop — it could not be fixed by injecting joystick events or by detecting a position jump.

---

## How throttle_hold works

1. The mod finds the player node (`/root/ZCommands.player`, or by the `player_rigid_body` script) and connects to the built-in **`Player.teleported`** signal. The game emits it **synchronously on the first line of `respawn()`**, before the next physics tick.
2. On that signal the mod immediately sets:
   - `player.auto_armed = false`, `player.manually_armed = false`;
   - `player.current_motor_rpm = 0.0`;
   - `player.linear_velocity = Vector3.ZERO`, `player.angular_velocity = Vector3.ZERO`.
3. While `is_armed()` returns `false`, the game itself zeroes the thrust vector (`force_in_direction = Vector3.ZERO`), disables rotation torque and motor sound — but keeps reading the real stick position into `player.throttle_input` (range `0.0 .. 1.0`).
4. As soon as the stick is lowered (`throttle_input <= release_threshold`, default `0.05` = 5%), the mod clears the OSD warning, sets `auto_armed = true`, and the drone lifts off smoothly on the next throttle input.

The mod does not replace the game script and does not break physics — it only resets the armed state at the right moment.

---

## Installation

1. Install the **[zonemods](https://github.com/goodluckNito/The-Zone-FPV-mods)** loader following its own instructions. Its files (**`zonemods/zonemods.gd`**) are third-party code and are **not included in this repository**.
2. In Steam: right-click **The Zone – FPV Drone Simulator** → **Manage** → **Browse local files**. This opens `steamapps/common/The Zone FPV`.
3. Copy the `throttle_hold` folder and `override.cfg` there (if `override.cfg` already exists from zonemods, make sure it contains the autoload line shown below).

Resulting structure (loader files come from its own repository):

```text
The Zone FPV/
├── thezone.exe
├── override.cfg          ← from this repository
├── zonemods/             ← from the zonemods repository
│   └── zonemods.gd
└── throttle_hold/        ← from this repository
    ├── main.gd
    ├── zonemod.cfg
    ├── settings.default.cfg
    ├── README.md
    ├── README.en.md
    └── README.txt
```

`override.cfg` content (loader autoload):

```ini
[autoload]
ZoneMods="*res://zonemods/zonemods.gd"
```

---

## Configuration

On first launch the loader creates `throttle_hold/settings.cfg` from `settings.default.cfg`:

```ini
[mod]
enabled=true

[throttle_hold]
release_threshold=0.05
```

- `enabled` — set `false` to disable the mod without removing files.
- `release_threshold` — throttle stick threshold (`0.01 .. 0.15`; `0.05` = 5%) at which the mod considers the throttle lowered and arms the drone.

Restart the game after editing `settings.cfg`.

### Diagnostics

- `zonemods/status.txt` — list of loaded mods; should show `OK throttle_hold 1.0`.
- `throttle_hold/status.txt` — mod log for the last launch (`hold`, `released` events and the current threshold).

If the mod does not load, check that `override.cfg` and `zonemods` are next to `thezone.exe`, and that the log contains no `Parse Error` / `Failed to load script`.

---

## Uninstall

1. Set `enabled=false` in `throttle_hold/settings.cfg` to stop the mod affecting the game.
2. For a full removal, delete the `throttle_hold` folder (and `override.cfg` if no other mods are used). Remove `zonemods` following its own instructions.

---

## Compatibility

- Game: **The Zone – FPV Drone Simulator** (Steam, App ID `3491280`).
- Loader: **zonemods** (`requires=1`).
- Not compatible with mods that replace `player_rigid_body.gdc` (e.g. `flight_controller`) if they change `respawn()` / `is_armed()` logic. Generally coexists with mods using the zonemods API.
- The original `throttle_fix` can be left installed — it solves a different problem and does not affect respawn.

---

## Credits

- The game developers of **The Zone FPV** and the community for documentation.
- [zonemods by goodluckNito](https://github.com/goodluckNito/The-Zone-FPV-mods).

---

## Русский

Русская версия: [README.md](README.md)
