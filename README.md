# Holy Fury

**Never tank without Righteous Fury again.** Holy Fury is a small add-on for paladins on **WoW Forever, Classic Era (Season of Discovery, Hardcore), Burning Crusade Anniversary and Mists of Pandaria Classic** that shows a big, impossible-to-miss alert when Righteous Fury is missing or about to run out while you tank.

## What it does

- **Righteous Fury missing:** a large icon with a red frame flashes on screen with "RIGHTEOUS FURY!". You also get a raid warning message and sound, and the sound repeats every 20 seconds until you recast it.
- **Last minute:** the icon turns gold and counts down the seconds left (not in Mists, where Righteous Fury lasts until cancelled).
- **Only when you tank:** it watches when your active spec is your tank spec. By default, that is the spec where Protection has the most talent points (or the Protection specialization in Mists), so dual spec works on its own. In a healing or Retribution spec, it stays quiet.
- **Only where it matters:** in dungeons and raids by default, or everywhere if you prefer.
- **Works in combat:** if the game hides aura details during a fight, Holy Fury relies on the expiry time it read before the pull.
- **Speaks your language:** English, French, German, Spanish, Italian, Brazilian Portuguese, Russian, Korean, Simplified and Traditional Chinese, picked automatically from your game client.

## Commands

| Command | What it does |
|---|---|
| `/hf` | Show the current settings, your talent points and the help |
| `/hf test` | Show the alert so you can see it (type it again to hide it) |
| `/hf move` | Unlock the alert and drag it where you want; type it again to lock |
| `/hf dungeon` / `always` / `off` | Watch in dungeons and raids, everywhere, or never |
| `/hf sound` | Turn the sound off or on |
| `/hf spec` | Make your current spec the tank spec (`/hf spec auto` for automatic detection) |

`/holyfury` works too. Command words also work in your own language, for example `/hf donjon` or `/hf verschieben`.

## Settings

Settings are saved per character.

## Install

Download Holy Fury from CurseForge (search for "Holy Fury"), or copy this repository into `Interface/AddOns/HolyFury` of your game folder.

## Development

There is no game client in CI, so the add-on is checked with Lua 5.1 and a simulation of each supported version's API:

```sh
tests/run.sh
```

It checks the Lua syntax, that every language has all its texts (or falls back to English cleanly), and runs the alert logic against mocked Forever, Classic Era, TBC, Cataclysm, Mists and Retail APIs.

Translations live in `Locales.lua`. Corrections from native speakers are welcome.
