# Gboy Desktop Pet

Open `res://scenes/pet/desktop_pet.tscn` to run Gboy as a standalone pet-style scene.

What is included:
- Shared retro pixel sprite set used by both the platformer and the pet scene.
- Directional idles and walks for `front`, `back`, `left`, and `right`.
- Emotion and activity animations including `happy`, `angry`, `cry`, `eat`, `sleep_lie`, `cape_flutter`, `tongue`, `laser`, `portal`, and `vanish`.
- Autonomous roaming desktop-pet behavior with cursor reactions.

Desktop controls:
- Left click the pet to comfort him.
- Right click the pet to feed him.
- Drag with the left mouse button to reposition him.
- Throw him into screen edges to trigger cling and ceiling behaviors.
- He now uses a transparent always-on-top window with click passthrough outside his active shape.

Standalone macOS app export:

```bash
chmod +x tools/build_desktop_pet_macos.sh
tools/build_desktop_pet_macos.sh
open "../build/Gboy Companion.app"
```

That script installs the matching Godot 4.6.1 export templates if they are missing, then exports the pet as a standalone `.app` you can run from the Desktop without opening Godot.

Regenerate the sprite sheets if you want to iterate on the look:

```bash
python3 tools/generate_gboy_sprites.py
godot --headless --path . --script res://tools/build_gboy_spriteframes.gd
```
