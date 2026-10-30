# High Noon: style guide

## Direction

Pixel art for the world, painted portraits for characters.

- `concept_gameplay.png`: the target look for levels. Warm sunset light, long shadows, red saloon against a faded blue-green bank, first-person revolver in the bottom-right.
- `concept_office.png`: the target look for the sheriff's office home screen.
- `concept_portraits.png`: the target look for wanted posters, boss introductions and the player's profile.
- `concept_flat_stage_town_and_train.png`: **the approved gameplay layout.** Iron Eli's stage 1 on Main Street and the train level, both as flat side-on stages.
- `concept_storyboard_depth_version.png`: an earlier test with real depth. Kept for reference only; see "Layout" below for why it was not adopted.

These images are AI-generated concepts. Use them as direction, not as final assets.

## Resolution

- Gameplay at 640×360, scaled up with nearest-neighbour filtering to fill the screen. No smoothing.
- Portraits and posters can be drawn at a higher resolution in the painted style.

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

- Outlaws must stand out from the background on a 6-inch phone: give them a warm rim light or a subtle outline, and keep backgrounds softer and hazier with distance. Dark clothing against dark wood is the main risk.
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

## Placeholder art in this kit

`art/sprites` and `art/guns` are the prototype's own pixel sprites (at 1× and 4×), and `art/reference` holds the prototype's code-drawn backgrounds. They let the port run before real art exists.
