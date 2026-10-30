# Expected results

These are the checks the prototype runs on itself (53 in total in the live build, including one data check per level).
The Godot port should pass the same list. The exact logic for each is in `reference_code_from_prototype.js` (function `selftest`).

- [ ] Winning level 1 unlocks level 2
- [ ] Two stars pay $40
- [ ] Improving to three stars pays only the $20 difference
- [ ] A worse replay pays nothing and keeps three stars
- [ ] Perfect clears counted once
- [ ] Capturing Iron Eli pays the $1,000 poster reward plus boss pay
- [ ] The poster reward is never paid twice
- [ ] Earnings ledger matches the wallet
- [ ] Production: the train is locked before Iron Eli is captured
- [ ] Production: capturing Iron Eli opens the train
- [ ] Production: posters without levels stay locked
- [ ] New save: Continue hunt goes to Iron Eli
- [ ] Iron Eli captured: Continue hunt goes to the Coal Gang
- [ ] Both captured: all bounties captured, nothing to continue
- [ ] Both captured: Digger McCall is next, coming soon
- [ ] Both captured: playtest mode agrees
- [ ] Captured bounties stay replayable from the board
- [ ] Playtest: train captured first still sends you to Iron Eli
- [ ] Cannot buy what you cannot afford
- [ ] Buying deducts the price
- [ ] Owned guns survive a save and reload
- [ ] Avatar and unlocked hints survive a save and reload
- [ ] Arcade, out of ammo with one outlaw left: +1 bullet
- [ ] Arcade, two outlaws left: no ad offer
- [ ] Puzzle levels never offer bullets, only clues
- [ ] Single-stage duels offer to keep your rounds
- [ ] Iron Eli, lost in stage 1: no ad offer
- [ ] Iron Eli, lost in stage 2 or 3: retry from that stage
- [ ] A clean perfect run earns three stars
- [ ] Any assistance caps a clear at two stars
- [ ] Assistance never lowers a one-star clear
- [ ] Shooting a hostage in an arcade level offers nothing
- [ ] Only one offer per attempt
- [ ] Every one of the 20 levels: data valid (bullets at least par; arcade levels have at least as many bullets as targets; windows and covers exist; nothing sits behind the gun; every puzzle has a hint and a hint target)

## Playthrough checks (done with a scripted player in the prototype)

- [ ] Every level can be won at par with its allotted bullets
- [ ] Puzzle solutions: Powder keg (shoot the TNT), Chain reaction (one TNT sets off the other), Hang 'em high and Bank job (shoot the sign rope), Cut loose (shoot the coupling pin), Dynamite express and End of the line (shoot the TNT; cutting the car in End of the line loses the hostage)
- [ ] Iron Eli: both armour cracks, three chase hits with reinforcements and dynamite, best-of-three duel with the double-bell last stand
- [ ] Losing anywhere in Iron Eli restarts at stage 1 (free); the ad offer resumes the stage reached, with full hearts, and caps the clear at two stars
