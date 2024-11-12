#! /bin/bash

set -e

rm -f Maze.o
rm -f Maze.nes
rm -f Maze.map.txt
rm -f Maze.labels.txt
rm -f Maze.nes.*
rm -f Maze.dbg

echo Compiling...
ca65 Maze.s -g -o Maze.o

echo Linking...
ld65 -o Maze.nes -C Maze.cfg Maze.o -m Maze.map.txt -Ln Maze.labels.txt --dbgfile Maze.dbg
echo Success!
