# Boot sector application collection
A collection of simple boot sector applications written in NASM for IBM PC-compatibles.

# Why?
I got a little bored with my current big project and wanted to refresh my assembly knowledge too.

# Usage
`./start.sh [application name]` will assemble the app and run it in QEMU

# System requirements
80386 and a VGA-compatible graphics adapter (i.e. anything that was made in the last 30 years).

# Application list

## Screensaver
Displays a simple animation in 320x200 256-color mode

![demo](demo/screensaver.gif)

## Dino
Built-in Chrome dino game in 320x200 256-color mode

![demo](demo/dino.gif)