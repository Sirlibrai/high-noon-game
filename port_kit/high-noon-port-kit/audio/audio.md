# High Noon: audio

## Music

All music is original and was synthesised by the prototype; you own it outright.

| File | Scene | Loops |
|---|---|---|
| `splash.ogg` | Splash standoff: ticking clock, tremolo guitar, whistled theme | Yes, from the loop point after the one-bar intro |
| `office.ogg` | Sheriff's office and menus: saloon guitar and harmonica | Yes |
| `street.ogg` | Main Street levels: galloping shootout | Yes |
| `train.ogg` | Train levels: banjo, steam rhythm | Yes |
| `boss.ogg` | Boss fights and duels: rising tension | Yes |
| `victory.ogg` | Winning a level: short fanfare | No |

`loop_points.json` gives each file's length and the point (in seconds) to loop back to. `music_cues.json` holds every note as data (step, voice, note, length, velocity) if you'd rather rebuild or rearrange it.

Behaviour: music never starts before the player's first tap, fades between scenes, ducks to about 30% while paused and while waiting for a duel's bell, stops on failure, and follows both the sound switch and a separate music switch.

## Sound effects

The prototype synthesises its effects in code (gunshot, ricochet, wood thunk, glass, explosion, bell, clank, creak, paper rustle and so on). The recipes are in the prototype's `sfx` object. For the Godot version, recording or sourcing short sample files is simpler and will sound better.
