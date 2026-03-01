# Major Visual Polish — Implementation Plan

## Overview
Transform the game UI to feel like an authentic ancient Roman gladiator management game with themed buttons, animated gladiators, cinematic transitions, and consistent visual language.

## 1. Roman-Themed UI Buttons
- Stone/marble `StyleBoxFlat` with gold borders via `roman_theme.gd`
- All buttons get `create_roman_button()` helper

## 2. Ludus Management → Top-Left Corner
- Remove UpgradesMenuButton from DoorActions in .tscn
- Create dynamic "Ludus Management" icon button in top-left (code)
- Connects to existing upgrades modal

## 3. Gladiator Random Movement (AI Wandering)  
- Each gladiator: random target → walk → pause → new target
- Strict boundaries: x(80-720), y(310-600)
- Direction-aware sprites based on movement vector
- Loading walking frames for Fighter_Gladiator, directional rotation for others

## 4. Battle Day Transition
- "Go To Battle" → walk all gladiators to center door (~2s)
- Fade to black (~1s)  
- Then transition to battle scene

## 5. Slow Victory/Defeat Modal
- Result overlay fades in over ~1.5s instead of instant
- Slight scale bounce on result text

## 6. Pixel Art Icons
- Generate 6 themed icons for buttons using generate_image tool

## TODO / Progress
- [x] Roman button helpers
- [x] Pixel art icons (generated via PixelLab MCP — download from docs/asset_downloads.md)
- [x] Ludus Management button top-left
- [x] Gladiator wandering
- [x] Battle transition
- [x] Slow battle result
- [ ] Final verification
