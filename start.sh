#!/usr/bin/env sh

rm -r build
mkdir build
nasm -f bin -o build/boot.bin src/$1.asm
ndisasm -b 16 build/boot.bin
hexdump -C build/boot.bin
truncate -s 1474560 build/boot.bin

qemu-system-i386 \
    -name guest="bootsect",debug-threads=on \
    -machine q35,accel=kvm,usb=off,vmport=off,dump-guest-core=off \
    -overcommit mem-lock=off \
    -fda ./build/boot.bin \
    -monitor stdio \
    -display sdl \
    -s
