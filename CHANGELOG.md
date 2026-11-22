# Changelog

## 1.3.1
- Fixed: Lua errors in WoW Forever after a few fights, when the game hides aura details during combat. Holy Fury no longer queries auras while they are hidden, and relies on the expiry time read before the pull.
- If an unexpected error still happens, it is shown once in the chat instead of repeating.

## 1.3.0
- Works on more versions of the game: Classic Era (including Season of Discovery and Hardcore), Burning Crusade Anniversary, Wrath (Titan), Mists of Pandaria Classic and WoW Forever.
- Older clients: falls back to the classic aura, spell and talent functions when the modern ones are missing.
- Tank spec detection from classic talent tabs (Classic, TBC, Wrath) and from the spec role (Mists).
- In Mists, where Righteous Fury lasts until cancelled, there is no countdown, only the alert when it is missing.

## 1.2.0
- New name: **Holy Fury** (was "Rappel Fureur"). Commands: `/hf` and `/holyfury` (`/fv` and `/rfury` still work).
- Localized in 10 languages, picked automatically from the game client: English, French, German, Spanish (EU and Latin America), Italian, Brazilian Portuguese, Russian, Korean, Simplified and Traditional Chinese.
- Add-on list icon and category.

## 1.1.0
- Tank spec detection from your talents: Protection is your tank spec when it is the tree with the most points (works with dual spec).
- `/hf spec` to pick the current spec by hand, `/hf spec auto` to go back to automatic detection.

## 1.0.0
- First release: big flashing icon, raid warning message and sound when Righteous Fury is missing, countdown during its last minute.
