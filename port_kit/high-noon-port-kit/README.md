# High Noon: Godot port kit

Everything needed to rebuild High Noon in Godot 4 for iPhone and Android, taken from the web prototype.

## What's inside

| Folder | Contents |
|---|---|
| `prototype/` | `highnoon.html`, the complete web prototype. Open it in a browser to play. Add `#playtest` to the address to open every level and the playtest tools. |
| `data/` | Game data as JSON: chapters (wanted posters), all 20 levels, scenes, cover sizes, weapons and finishes, avatar options, ranks, trophies, payouts. |
| `specs/` | `rules.md` (exact gameplay behaviour), `expected_results.md` (the checks the port must pass), `reference_code_from_prototype.js` (the prototype's rule functions and self-tests). |
| `style/` | Concept images, the extracted colour palette and the style guide. |
| `art/` | The prototype's sprites and guns as placeholder PNGs, plus reference backgrounds. |
| `audio/` | The full original score as loopable OGG files, with loop points and note data. |

Design doc: https://claude.ai/artifact/Rwad9WQFTQh6afvqQ7U93T

## How to start

1. Install Xcode, Godot 4 (standard version, GDScript) and Claude Code on your Mac.
2. Create a GitHub repository and an empty folder for the Godot project.
3. Unzip this kit into the folder as `port_kit/`.
4. Open Claude Code in the folder and paste the prompt below.

## First prompt for Claude Code

> We're building High Noon, a one-finger Western shooter, in Godot 4 with GDScript for iPhone and Android, landscape only. The `port_kit/` folder contains the HTML prototype, the game data as JSON, a rules spec, expected test results, a style guide, placeholder art and the music. Read `port_kit/README.md`, `specs/rules.md` and the prototype first, then summarise the plan before writing code.
>
> Set up a project with data-driven levels loaded from `port_kit/data`, autoload managers for game state, saving, audio and ads, and a 640×360 base resolution scaled crisply with nearest-neighbour filtering. Build only Main Street level 1 (the tutorial) and level 5 (the Black Jack duel) using the placeholder art and music, with native haptics. Then help me run it on my iPhone through Xcode and stop, so I can test how it feels.

## Milestones after that

1. **Feel test:** the tutorial and Black Jack on your iPhone, compared with the web version.
2. **Parity:** all 20 levels, the sheriff's office, Gunsmith, profile, saves with iCloud and the music, passing `expected_results.md`.
3. **TestFlight:** a handful of players, with analytics.
4. **Launch:** real art, rewarded ads, the Sheriff's Pass through Apple's purchase system, the App Store listing.
