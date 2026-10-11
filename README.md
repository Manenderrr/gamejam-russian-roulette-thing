# Russian Roulette Thing

Game made for a game jam at CDT / КЦТ (Колледж Цифровых Технологий — College of Digital Technologies).

**Genre:** mostly vampire-survivors-like action roguelike
**Inspired by:** Vampire Survivors, Hotline Miami, DOOM

## How to run

Requires **Godot 4.7**. Open the project in the editor and press Run
(entry scene: `src/hud/main_menu.tscn`), or run a built export.

## Controls

- **WASD** — move
- **Mouse** — aim
- **LMB** — attack (katana / gun)
- **TAB** — switch weapon
- **SPACE** — dash
- **ESC** — pause

## Gameplay

Fight through procedurally generated floors in a kill-all-each-wave loop:
clear the floor of enemies, grab XP / ammo / heal drops, pick an upgrade
(max HP, katana levels, stats), descend to a fresh floor. Enemy roster grows
from office planktons and security officers up to a boss that spawns minions.

## Project structure

- `src/enemies/` — enemy AI (AStar pathfinding), boss, minion spawns
- `src/weapon/` — katana slash arcs, gun, bullets, pickups wiring
- `src/level/` — procedural room/corridor generation, wave manager, autotiled floors
- `src/hud/` — main menu, pause, upgrades, HUD, death screen
- `src/player.gd`, `src/player_stats.gd`, `src/game_manager.gd`, `src/camera.gd`
- `assets/gfx/` — pixel art sources (`.ase`/`.aseprite`) and exports
- `assets/audio/` — menu and battle music

## Music
All music is written by Aust Alexander (known as D7TUN6 in music industry), main menu and battle1 track is unique, other are taken from D7TUN6's albums "B TWIN", "Wh1te Hous3" and "obksr3.e" (genres: braindance/hardcore)

## Made by

- Artur Salyakhutdinov — sprites, characters
- Makar Guryanov — code
- Pyotr Struin — sprites, sound effects
- Aust Alexander — code, sprites, music
