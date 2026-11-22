#!/bin/sh
# Checks Holy Fury without a game client: Lua 5.1 syntax, locale tables,
# and a simulation of each supported WoW version's API.
set -e
cd "$(dirname "$0")/.."
LUAC=$(command -v luac5.1 || command -v luac)
LUA=$(command -v lua5.1 || command -v lua)
"$LUAC" -p Locales.lua HolyFury.lua
echo "syntax OK"
"$LUA" tests/check_locales.lua Locales.lua | tail -1
for flavor in forever era era-ancien tbc cata mop retail; do
    "$LUA" tests/mock_flavors.lua "$flavor" Locales.lua HolyFury.lua
done
