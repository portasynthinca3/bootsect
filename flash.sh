#!/usr/bin/env sh

rm -r build
mkdir build
nasm -f bin -o build/app.bin src/$1.asm
nasm -f bin -o build/bootstrap.bin src/bootstrap.asm
cat build/bootstrap.bin build/app.bin > build/boot.bin
truncate -s 1474560 build/boot.bin
sudo dd if=build/boot.bin of=$2
