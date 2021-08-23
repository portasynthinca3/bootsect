#!/usr/bin/env sh

nasm -f bin -o build/boot.bin src/bootsect.asm
truncate -s 1474560 build/boot.bin

qemu-system-x86_64 \
    -name guest="screensaver",debug-threads=on \
    -machine q35,accel=kvm,usb=off,vmport=off,dump-guest-core=off \
    -cpu IvyBridge-IBRS,ss=on,vmx=on,pcid=on,hypervisor=on,arat=on,tsc-adjust=on,umip=on,md-clear=on,stibp=on,arch-capabilities=on,ssbd=on,xsaveopt=on,ibpb=on,amd-ssbd=on,skip-l1dfl-vmentry=on \
    -m 32 \
    -overcommit mem-lock=off \
    -smp 1,sockets=1,cores=1,threads=1 \
    -no-user-config \
    -nodefaults \
    -rtc base=utc,driftfix=slew \
    -global kvm-pit.lost_tick_policy=delay \
    -no-hpet \
    -fda ./build/boot.bin \
    -device qxl-vga,id=video0,ram_size=67108864,vram_size=67108864,vram64_size_mb=0,vgamem_mb=16,max_outputs=1,bus=pcie.0,addr=0x2 \
    -sandbox on,obsolete=deny,elevateprivileges=deny,spawn=deny,resourcecontrol=deny \
    -msg timestamp=on \
    -monitor stdio \
    -soundhw pcspk \
    -s