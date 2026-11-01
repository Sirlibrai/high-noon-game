# High Noon: style guide

## Direction

The final style is a bold cartoon: **thick dark outlines, flat bright colours with one or two hard-edged shade steps, chunky simplified shapes and big-headed characters**. It reads like a modern mobile cartoon rather than a painting. It replaces the earlier painted storybook look and the pixel art before it.

- `assets/incoming/Sunset Showdown on Main Street.png`: **the reference.** Chain Reaction on Main Street with the HUD over it: the saloon and bank, the INN sign on its signpost, three outlaws and the TNT keg on the ground line, and the revolver in the corner.
- `concept_flat_stage_town_and_train.png`: still **the approved gameplay layout** (a flat side-on stage).
- `concept_gameplay.png`, `concept_office.png`, `concept_portraits.png`, `chosen_style_painted_train.png` and `concept_storyboard_depth_version.png`: earlier looks, kept for layout and colour reference only.

### The look

- **Outlines:** every character, prop and UI piece has a thick, dark brown (not black) outline, heavier on the outside edge than on inner details.
- **Colour:** flat fills in saturated warm colours (brick red, sunset orange, honey gold, cream, leather browns), with dusty lavender, slate blue and teal as the cool accents. Shading is one or two hard-edged steps, not soft gradients; a warm highlight runs along the sunlit edge.
- **Shapes:** chunky and simplified. Planks, rivets and nail heads are drawn as clear graphic shapes, not textures. Wood grain is a few bold strokes.
- **Characters:** big heads (roughly a third of the body), big hats, big boots, short legs, readable from a distance on a phone. Faces are simple: angry eyebrows, a red bandana over the mouth.
- **Backgrounds:** the same outlines and flat colour as the foreground but with lower contrast, a sunset sky (lilac to blue, peach clouds) and pink-purple mesas, so the outlaws and props stay the brightest, crispest things on screen.
- **Shadows:** the game adds its own soft contact shadows, so sheets must not have ground shadows painted under figures or props (`tools/cut.gd` removes any that do).

## Resolution

- A 1280×720 base, scaled smoothly (linear filtering) to fill the screen. Paint art at 1280×720 pixel density: 4 image pixels per gameplay unit of the 320×180 stage in `levels.json`.
- Background layers are wider than the screen (1920 pixels for Main Street) so wide phones see more of the street at the sides; everything you can shoot stays inside the central 1280×720.
- Hitboxes come from `data/geometry.json`, never from the art, so painted sprites can be any shape.

## Palette

`palette.json` and `palette_swatches.png` hold the main colours extracted from each concept image. The overall feel: warm browns, burnt oranges, sun-bleached creams and muted reds, with blue-green and teal used sparingly as contrast (the bank, Iron Eli's bandana).

## Layout: a flat stage, not a deep scene

Gameplay screens are built like a theatre set. Everything the player can shoot or use (outlaws, cover, TNT, signs, the coupling pin) stands on one ground line, or at most two clear planes, at similar sizes. Depth belongs only to the background: distant buildings, water towers, mesas and the sky, painted softer and hazier.

Why: the game's level design, hit sizes, puzzle geometry and tests all assume a side-on stage. A deep perspective (as in the storyboard test) makes distant targets too small to tap, changes every level's layout and can hide puzzle props such as the train's coupling pin. That would be a redesign, not a reskin.

- **Main Street:** saloon on the left, bank on the right, cover spread across the middle, hanging signs directly above the cover they can fall on.
- **The train:** a pure side view. Passenger carriage on the left, flatcar on the right, the coupling and its brass pin clearly visible between them. The train runs to the left, so tunnels swallow it from the left side of the screen.

## Duels

- Gameplay stays first-person: the boss alone in the street, facing the player.
- Each duel opens with a short over-the-shoulder shot from behind the player's own customised bounty hunter, then cuts to first-person when "Steady…" appears. The intro shot shows off the avatar without shrinking the target during play.

## The revolver

Small and low in the bottom-right corner, as in the flat-stage concept. It must never cover an outlaw, a prop or a window. It can tilt towards the aim point, but should stay within roughly the bottom-right eighth of the screen.

## Readability rules (more important than beauty)

- Outlaws must stand out from the background on a 6-inch phone: their bold outlines and bright flat colours do most of the work; keep backgrounds lower in contrast. Dark clothing against dark wood is the main risk.
- Only one or two outlaws should be exposed at once in normal play, even if the concepts show more.
- Interactive props (TNT, sign ropes, coupling pins) need distinct shapes and colours.
- The gun must never cover targets.

## Characters

| Character | Look |
|---|---|
| Iron Eli | Weathered gunslinger, pale cream hat, dark purple coat, teal bandana, dented iron breastplate with rivets |
| Black Jack | Black hat with a red band and an ace of hearts in it, black coat, red vest, smug smile |
| Smokey Pete | Grey hat, pale bandana, brown coat, often half-hidden in engine smoke |
| Cole Haggerty | Soot-smudged, black hat with a gold band, coal-stained coat, carries a lantern |
| The bounty hunter (player) | Customisable: hat, hat colour, skin tone, bandana, coat and facial hair (`data/avatar_options.json`) |

### Pose sheets

Each character is drawn as whole poses on a sheet, with the same outline and colour on every pose. The outlaw has: idle, aim, hit, crouch (peeking over cover), lean (side peek; mirrored for the other side), run left and right, fall (with the hat drawn on its own so it can spin away), and an 8-frame walk to the right (mirrored for the left). `tools/import_painted.gd` and `tools/import_batch1.gd` cut the sheets in `assets/incoming`, size each piece to match the art it replaces, and print the anchors for `assets/manifest.json` (`tools/set_anchors.pl` copies them in).

## Placeholder art in this kit

`art/sprites` and `art/guns` are the prototype's own pixel sprites (at 1× and 4×), and `art/reference` holds the prototype's code-drawn backgrounds. They let the port run before real art exists.
