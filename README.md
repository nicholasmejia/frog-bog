# FrogBog

A 2D Godot game where you play as a frog catching flies with your tongue.

## Requirements

- [Godot 4.6](https://godotengine.org/) (GL Compatibility renderer)

## Running

Open the project in Godot by importing `project.godot`, then press F5 to run.

## Controls

| Action | Keyboard | Gamepad |
| --- | --- | --- |
| Charge jump / shoot tongue | Space | — |
| Aim | — | Left stick |
| Bullet time | V | — |

Hold the jump button to charge — longer charge = bigger jump.

## Project layout

- `main.tscn` / `main.gd` — main scene and game loop
- `frog.gd` / `frog.tscn` — player frog (movement, charging, tongue)
- `fly.gd` / `fly.tscn` — fly behavior
- `fly_spawner.gd` / `fly_spawner.tscn` — fly spawning
- `tongue.gd` / `tongue.tscn` — tongue extension and hit detection
- `bullet_time.gd` — time-scale slowdown handling
- `platform.gd` — platform/ground behavior
- `shadow.gd` — frog shadow
- `score.gd` — score tracking
- `game_events.gd` — autoloaded event bus (see `[autoload]` in `project.godot`)
- `art/`, `fonts/` — assets
