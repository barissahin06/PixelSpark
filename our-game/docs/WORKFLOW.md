**Directory Layout**
- `addons/` Godot addons and third-party plugins
- `assets/` Raw assets (art, audio, fonts, UI, VFX)
- `resources/` `.tres` data assets (stats, configs, item data)
- `scenes/` Game scenes (levels, actors, UI)
- `scripts/` GDScript code (actors, systems, UI)
- `docs/` Project documentation

**Collaboration Rules**
- Prefer small, composable scenes. Put shared parts in `scenes/actors/` or `scenes/ui/` and instance them.
- Avoid two people editing the same `.tscn` at the same time. Split large scenes into sub-scenes first.
- Keep `.import` files and `.tres` files in Git. Only `.godot/` is ignored.
- Use short-lived branches and open PRs early so conflicts are discovered before they grow.

**Ownership Hint (Optional)**
- People can “own” areas to reduce conflicts: e.g., one focuses on `scenes/levels/`, one on `scripts/systems/`, one on `assets/`.
