throttle_hold 1.0
=================

Game: The Zone - FPV Drone Simulator (Steam App ID 3491280)
  https://store.steampowered.com/app/3491280/The_Zone__FPV_Drone_Simulator/
Mod loader: zonemods
  https://github.com/goodluckNito/The-Zone-FPV-mods

Disarms the drone and zeroes motor RPM on start and on every respawn until the
physical throttle stick is lowered to zero.


WHY IT IS NEEDED
  In player_rigid_body.gd, Player.respawn() resets transform and velocity, but
  does not reset auto_armed or current_motor_rpm. If you respawn while the
  throttle stick is above zero (or while the motors are still spinning at flight
  RPM), the drone immediately hops or launches off the ground.

  throttle_hold connects to Player's `teleported` signal (emitted synchronously
  on the first line of Player.respawn()) and immediately sets auto_armed = false
  and current_motor_rpm = 0.0. While disarmed, the game applies zero thrust and
  shows "LOWER THROTTLE TO ARM" on the OSD. As soon as you lower the throttle
  stick to <= release_threshold (default 0.05 = 5%), the drone arms and is ready
  to fly.


INSTALL
  1. Install the zonemods loader first (third-party, NOT bundled here):
       https://github.com/goodluckNito/The-Zone-FPV-mods
  2. Steam: right-click The Zone FPV > Manage > Browse local files.
  3. Put override.cfg and throttle_hold/ next to thezone.exe.


SETTINGS
  throttle_hold/settings.cfg is created on first launch:
    enabled=true             ; false turns the mod off
    release_threshold=0.05   ; throttle (0.01 .. 0.15) at or below which it arms


UNINSTALL
  Set enabled=false in throttle_hold/settings.cfg, or delete the throttle_hold
  folder (and override.cfg if no other mods are used).
