; Bootstrap script
; It is needed because real BIOSes expect a partition table
; and there's no way I'm fitting it into the main code.
; It is only theoretically required if you want to boot this on an actual PC.

org 0x7c00
use16

bpb:
    jmp reloc
reloc:
    ; relocate the loading code to 0x7a00
    push ds
    pop es
    mov cx, load_app.end - load_app
    mov di, 0x7a00
    mov si, load_app
    cld
    rep movsb
    ; jump to relocated code
    jmp 0x7a00

load_app:
    ; make a BIOS function call to load LBA 1 to 0x7c00
    mov ah, 02h
    mov al, 1
    xor ch, ch
    mov cl, 2
    xor dh, dh
    push 0
    pop es
    mov bx, 0x7c00
    int 13h
    ; jump to loaded code
    jmp 0x0000:0x7c00
.end:

times 446 - ($-$$) db 0 ; zero padding
mbr:
    ;           active  CHS   type   CHS   LBA start LBA len
    .entry1: db 0x80,  0,0,1, 0x7F, 0,0,2, 1,0,0,0,  1,0,0,0
    .entry2: db 0x00,  0,0,0, 0x00, 0,0,0, 0,0,0,0,  0,0,0,0
    .entry3: db 0x00,  0,0,0, 0x00, 0,0,0, 0,0,0,0,  0,0,0,0
    .entry4: db 0x00,  0,0,0, 0x00, 0,0,0, 0,0,0,0,  0,0,0,0
dw 0xAA55 ; boot sector signature