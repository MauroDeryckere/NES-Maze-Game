# NES Maze Game

## Overview

![Gameplay Preview](https://i.imgur.com/UIlM1vd.gif)

The Maze Game is a game inspired by classic titles from the golden era of gaming. Designed for the Nintendo Entertainment System (NES). The game implements a maze generation algorithm, 2 solving algorithms, and normal gameplay. All coded in Assembly (6502).

Players can enjoy the game on original NES hardware or through a compatible NES emulator.

## Table of Contents
1. [Overview](#overview)
2. [How To Play](#how-to-play)
   - [Gamemodes](#gamemodes) 
   - [Title Screen Controls](#title-screen-controls)
   - [In-Game Controls](#in-game-controls)  
   - [Objective](#objective)  
4. [Used Software](#used-software)
5. [Project Information](#project-information)  

## How To Play

To play the game if you don't have a NES, you need an emulator, we have tested the game in Mesen and FCEUX but other emulators may also work when they support PAL mode. If you do have a NES you will need a way to upload the NES file to a cartridge (Everdrive, ...)

### Gamemodes

- **Hard**: Hard mode stops displaying the maze once it's been generated and has the player looking for their way out using a classic "Fog of War" system.
- **Auto**: The auto gamemode disables player input (in hardmode) and uses solving algorithms to solve the maze. This allows you to sit back and enjoy the satisfying animation. Starting in auto mode with the hard flag enabled uses the Left Hand Rule solving algorithm, without it uses a Breadth First Search.

### Title Screen Controls

- **DPAD UP**: Move selection up
- **DPAD DOWN**: Move selection down
- **SELECT**: Select a menu item
- **START**: Start the game with the current selections

### In-Game Controls

- **START**: Pause the game
- **DPAD**: Move up, right, down, or left

### Objective

Navigate through the maze and reach the end to complete the level.

## Used Software
**Graphics:**
- [YY-CHR](https://wiki.vg-resource.com/YY-CHR)
- [NEXXT Studio 3](https://frankengraphics.itch.io/nexxt)

**Audio:**
- [FamiStudio](https://famistudio.org/)

**Coding:**
- [Visual Studio Code](https://code.visualstudio.com/)
- [Mesen](https://www.mesen.ca/) and [MesenX](https://github.com/NovaSquirrel/Mesen-X) (debugging and emulating)
- [FCEUX](https://fceux.com/web/home.html) (debugging and emulating)

## Project information

The project was made during a class in a [DAE](https://www.digitalartsandentertainment.be/page/31/Game+Development) course (Retro Console & Emulator Programming) given by Tom Tesch.

**We used the following book in that class to setup the project:** </br>
Cruise, Tony. (2024). </br>
Classic Programming on the NES. </br>
Manning Publications Co.</br>
ISBN: 9781633438019.

**Contributors**
- Mauro Deryckere
- Seppe Mestdagh
- Aaron Van Sichem De Combe
