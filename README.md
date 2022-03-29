# Sven-Coop-Scripts
What is this? This repository will contain scripts for public use

**click on the preview images to open a showcase video**

weapon_tar21 AMX port to Angelscript

[![weapon_tar21](https://img.youtube.com/vi/MPmh9jf0qtI/hqdefault.jpg)](https://youtu.be/MPmh9jf0qtI)

halfnuked pack C++ port to Angelscript

[![halfnuked](https://img.youtube.com/vi/hdSyG3rtY7w/hqdefault.jpg)](https://youtu.be/hdSyG3rtY7w)

## My Custom DynamicDifficulty 

What's new in this DD?

The things I changed were:

- The skills now are reading from store/Matrix.txt

- The DDX-Maplist.txt now works in reverse. With this I mean that the maps that you put here will be where the DD doesn't work (it will take the default skill of SC)

- I added a timer to see how much time has passed on the map
  - This have 2 modes:
    - g_timer.GetMessage(0): In this mode the time is going to show ( Timer: Hours : Minutes : Seconds )
    - g_timer.GetMessage(1): In this mode the timer will be progressive. By this I mean that if only seconds pass on the map, it only shows how many seconds have elapsed and so on. 

- I added a way to change the velocity of the enemies
  - In the part called "MonsterSpeedMultiplier" you can add the multiplier, putting a multiplier too high may not work.

- I added a way to vote for the player to change the diff
  - I added a way to block player voting in the array called "SteamIDArray" and if a player spams more than 3 times the vote, they won't be able to vote anymore. 

### Console:

- .diff [number] - All players

- .admin_diff [number] - Only admins

### In the chat:

- /vote diff [number] - All players

- /votediff [number] - All player

- I added a way to barnacle eat more fast
  - In the part called "BarnacleSpeed" you can add how many units per second the barnacle is gonna eat.


Information:
Author | files | script ported | showcase
------ | ----- | ------------- | --------
[KORD_12.7, Koshak](http://aghl.ru/forum/) | [weapon_tar21.rar](https://github.com/Gaftherman/Sven-Coop-Scripts/blob/main/Half-Life%20-%20Weapon%20Mod/weapon_tar21.rar) | [weapon_tar21.as](https://github.com/Gaftherman/Sven-Coop-Scripts/blob/main/Half-Life%20-%20Weapon%20Mod/weapon_tar21.as) | [KEZÆIV](https://youtu.be/MPmh9jf0qtI)
[Maxxiii](https://github.com/HLSources/Half-Nuked) | [half-life nuked files](https://github.com/Gaftherman/Sven-Coop-Scripts/blob/main/Half-Life%20-%20Nuked/hl_nuked.rar) | [hl_nuked.as](https://github.com/Gaftherman/Sven-Coop-Scripts/blob/main/Half-Life%20-%20Nuked/hl_nuked.as) | [KEZÆIV](https://youtu.be/hdSyG3rtY7w)

