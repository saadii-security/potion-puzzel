# Potion Sort Adventure

Flutter + Flame alchemy puzzle. Sort essences, complete objectives, walk six worlds.

## Run

```
flutter pub get
flutter test
flutter run
```

Android first. iOS project is generated and ready.

## What is implemented

- Core pour engine (legal moves, undo, win/fail, combos)
- Flame bottle board with pour motion
- First 20 handcrafted tutorial vials
- Seeded generator for vials 21–300 (6 worlds × 50)
- Solver used for star thresholds when the search budget allows
- Objectives, blockers (lock, crystal, frost, mystery, portal, blight)
- Boosters: rewind, hint, extra vial, color burst, clear, prism
- Local save, stars, coins, gems, lab cosmetics, daily distill, streak
- Home / Map / Lab / Events / Shop / Settings

## Not wired yet (architecture only)

- Supabase auth, cloud save, live leaderboards, remote config
- Real rewarded ads, interstitials, and IAP store calls

Those stay stubbed so the game stays playable offline without fake completions.

## Mascot

Lumen, a young alchemist who tips the first vials.
