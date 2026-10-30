## Oolite JS tests

Look at OoliteProject/oolite#776 for javascript based tests.
I like this design because javascript is already used. I could adopt it. It is already an open pull request.
## Typescript instead of js extensions
Thing about making typescript instead of javascript expansions. This could be cool.

## Google Test or other test library instead of custom

There are some custome assertions.

## Fuller modernization
Use consts instead of macros, more modern style, code cleanup.
clang tidy, more complete autoformat, etc.
[[Clang Format Updates]]

## Create Windows setup/clion install guide

Instruction to setup the clion build, .run files, etc.

## `oolite.exe.manifest`
`src/SDL/OOResourcesWin/oolite.exe.manifest`
Should this file include windows 11?

## Quick JS upgrade
- [ ] Upgrade quickjs-ng version to 0.17

## Controls 
- Control this ship with an Xbox controller.
- Show controls in menus and such to make it easier to learn.
- Edit controls or customize controls
- Esc for pause menu.

## UI
- Open a clickable menu to navigate the different screens instead of remembering hotkeys.
- Kinda like the arma thing where you scroll through different actions to select things and see what is availble.

Imagine a menu in the top right with the ability to request docking clearance, see the status, cancel.
Imagine having tooltips in the UI.
Imagine having a help system to tell you what can be done in the game.


## Performance Issue in Ship Library
Lag when loading the ship. Not sure what is happening here. It happens in the base game. Curious if it could be fixed... Oh, it is a zoom in effect. The item start far away and zooms in over a second or so. Perhaps this could be smoothed to not seem like lag.


