---
description: How to use PixelLab MCP for pixel art asset generation — always check existing assets first
---

# PixelLab MCP Asset Workflow

## ⚠️ MANDATORY: Query Before Creating

Before creating ANY new asset via the PixelLab MCP, you **MUST** first query existing assets to avoid duplicates and wasted credits.

### Characters
1. **Always run `list_characters(limit=50)` first** to see all existing characters.
2. If a character with a matching or similar name already exists, **use `get_character(character_id="...")`** to inspect it before deciding whether to create a new one.
3. Only call `create_character(...)` if no suitable existing character is found.

### Animations
1. Before queuing an animation, **use `get_character(character_id="...")`** to check if the animation already exists on that character.
2. Check the `pending_jobs` count — if it is close to the job limit (10), wait before queuing more.
3. Queue animations **one at a time** and verify job slot availability.

### Isometric Tiles
1. **Always run `list_isometric_tiles(limit=50)` first.**
2. Inspect existing tiles with `get_isometric_tile(tile_id="...")` if a match looks possible.
3. Only create a new tile if nothing suitable exists.

### Top-Down Tilesets
1. **Always run `list_topdown_tilesets(limit=50)` first.**
2. Inspect with `get_topdown_tileset(tileset_id="...")`.
3. Only create if nothing matches.

### Sidescroller Tilesets
1. **Always run `list_sidescroller_tilesets(limit=50)` first.**
2. Inspect with `get_sidescroller_tileset(tileset_id="...")`.
3. Only create if nothing matches.

### Tiles Pro
1. **Always run `list_tiles_pro(limit=50)` first.**
2. Inspect with `get_tiles_pro(tile_id="...")`.
3. Only create if nothing matches.

### Map Objects
- Map objects are ephemeral (deleted after 8 hours). Always download and save them to the project's `assets/` directory immediately after generation completes.
- There is no list endpoint for map objects, so track IDs in your working notes.

## Job Slot Management
- The free tier allows **10 concurrent jobs**.
- Each 8-direction animation uses **8 job slots**.
- Each 8-direction character creation uses **8 job slots**.
- **Never queue more jobs than available slots.** Check with `get_character()` to see pending job counts.
- Wait for existing jobs to finish before queuing new batches.

## Asset Organization
- Save all downloaded character spritesheets to: `our-game/assets/art/characters/`
- Save all downloaded tiles to: `our-game/assets/art/tiles/`
- Save all downloaded map objects to: `our-game/assets/art/objects/`
- Save all downloaded tilesets to: `our-game/assets/art/tilesets/`
