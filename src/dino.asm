org 0x7c00
use16

%define var_base 0x7e00 ; in RAM right after the boot sector
%define var(X)   [bp+(X)]

%define clock_ms   0x0000
%define beep_start 0x0004
%define dino_vel   0x0008

%define bg_color 0x1e
%define fg_color 0x18

entry:
    ; set video mode 13h (https://ibm.retropc.se/video/bios_video_modes.html)
    mov ax, 0x13 ; also sets AH=0 as function selector
    int 10h
    ; set es = VGA buffer
    push 0xa000
    pop es

    ; fill screen
    mov cx, 320 * 200
    ; xor di, di ; commenting this out is a dirty hack to shave off two bytes!
    mov al, bg_color
    rep stosb

    ; draw ground
    ; top line
    mov di, 158 * 320
    mov cx, 320
    mov al, fg_color
    rep stosb
    ; random dots
    mov cx, 320*7
    .dot:
        in al, 0x40 ; read PIT channel 0 for randomness
        and al, 0x55
        jz .black_dot
        mov al, bg_color
        jmp .dot_cont
        .black_dot:
        mov al, fg_color
        .dot_cont:
        stosb
        loop .dot

    ; initialize vars
    mov bp, var_base
    ; mov dword var(clock_ms), 0 ; commenting these out is a dirty hack!
    ; mov byte var(dino_vel), 0  ;

    ; set PIT channel 2 (PC speaker) frequency (250Hz)
    mov al, 0xb6
    out 0x43, al
    mov ax, 1193182 / 250
    out 0x42, al
    mov al, ah
    out 0x42, al

    ; set PIT channel 0 frequency (1kHz)
    mov ax, 1193182 / 1000
    out 0x40, al
    mov al, ah
    out 0x40, al
    ; set IRQ0 (PIT channel 0) handler
    mov ax, cs
    mov word [0x0022], ax
    mov word [0x0020], irq0

    jmp $

dino_y: dw 136 ; not a %define because it needs to be initalized

irq0:
    ; stop the sound 20ms after it started
    mov eax, dword var(clock_ms)
    sub eax, 20
    cmp eax, dword var(beep_start)
    jl .nosoundstop
    xor al, al
    out 0x61, al
    .nosoundstop:

    ; clear dino at old position
    mov si, dino_sprite
    mov dl, bg_color
    mov bx, 20
    mov dh, byte [dino_y]
    call draw_sprite

    ; shift cacti and ground to the left
    test byte var(clock_ms), 3
    jnz .ground_cont
    ; shift cacti (no wrap-around)
    mov cx, 33
    mov bx, 125
    clc
    call shift_rect_left
    ; shift ground (wrap around)
    mov cx, 8
    mov bx, 158
    stc
    call shift_rect_left
    .ground_cont:

    ; draw new cacti
    test word var(clock_ms), 1023
    jnz .cactus_cont
    mov si, cactus_sprite
    mov dl, fg_color
    mov bx, 304
    mov dh, 146
    call draw_sprite
    .cactus_cont:

    ; update dino position
    test byte var(clock_ms), 31
    jnz .noupd
    ; update pos
    mov al, byte var(dino_vel)
    sub byte [dino_y], al
    cmp byte [dino_y], 136
    jae .nodown
    sub byte var(dino_vel), 1
    jmp .noupd
    .nodown:
    mov byte [dino_y], 136
    .noupd:

    ; check keypress
    mov ah, 1
    int 16h
    jz .nostroke
    ; remove from buffer
    xor ah, ah
    int 16h
    ; check dino pos
    cmp byte [dino_y], 136
    jne .nostroke
    ; make our dino jump up and play a sound
    mov al, 3
    out 0x61, al
    mov byte var(dino_vel), 7
    mov eax, dword var(clock_ms)
    mov dword var(beep_start), eax
    .nostroke:

    ; check collision
    mov bx, word [dino_y]
    mov ax, 320
    mul bx
    mov bx, ax
    mov dl, fg_color
    cmp byte [es:bx+(13*320)+34], dl
    je $
    cmp byte [es:bx+(15*320)+33], dl
    je $
    cmp byte [es:bx+(18*320)+32], dl
    je $

    ; draw dino at new position
    mov si, dino_sprite
    mov bx, 20
    mov dh, byte [dino_y]
    call draw_sprite ; dl=fg_color

    ; advance clock
    inc dword var(clock_ms)

    ; EOI
    mov al, 0x20
    out 0x20, al
    iret

;description:
; shifts a row of pixels to the left
;input:
; BX = Y position
; CF = whether or not to wrap around (0 = false, 1 = true)
shift_row_left:
    ; save regs
    push cx
    pushf ; save because we need to check CF and mul below affects it
    ; calculate start of line
    mov ax, 320
    mul bx
    mov di, ax
    mov cx, 319
    ; do the thing
    push ds
    push es
    pop ds
    lea si, [di+1]
    rep movsb
    pop ds
    ; wrap around (restore flags prematurely to check if we actually need to)
    popf
    jnc .nowrap
    mov al, byte [es:di-319]
    mov byte [es:di], al
    .nowrap:
    ; restore regs
    pop cx
    ret

;description:
; shifts a rectangle starting at X=0 with a width of 320 to the left
;input:
; BX = Y position
; CX = height
; DX = whether or not to wrap around (0 = false, 1..255 = true)
shift_rect_left:
    .iter:
        call shift_row_left
        inc bx
        loop .iter
    ret

;description:
; draws a sprite
;input:
; DS:SI = sprite data
; BX = X coord
; DH = Y coord
; DL = foreground color
draw_sprite:
    ; save regs
    pusha
    ; calculate vmem offset
    mov ax, 160
    mul dh
    shl ax, 1
    mov di, ax
    add di, bx
    ; read height into cx
    mov dh, byte [si]
    movzx cx, dh
    and cx, 0x1f
    add cl, 2
    ; keep width in dh
    shr dh, 5
    inc si
.row:
    push dx
    .chunk:
        ; read chunk
        mov ah, byte [si]
        mov al, 8
        .pixel:
            test ah, 0x80 ; test leftmost pixel
            jz .bg_pixel
            mov byte [es:di], dl ; foreground pixel
            .bg_pixel:
            shl ah, 1
            inc di
            dec al
            jnz .pixel
        inc si
        dec dh
        jnz .chunk
    ; go to second row
    pop dx
    add di, 320
    movzx ax, dh
    shl ax, 3
    sub di, ax
    loop .row
.return:
    ; restore regs
    popa
    ret

cactus_sprite: ; 11 bytes
    db (1 << 5) | (10 << 0)
    db 00001000b
    db 00011010b
    db 10011011b
    db 11011011b
    db 11011011b
    db 11011011b
    db 11011111b
    db 11111110b
    db 01111000b
    db 00011000b
    db 00011000b
    db 00011000b
dino_sprite: ; 67 bytes! MUHHHHH BLOATT!!!!!
    db (3 << 5) | (20 << 0)
    db 00000000b, 00011111b, 11100000b
    db 00000000b, 00111111b, 11110000b
    db 00000000b, 00110111b, 11110000b
    db 00000000b, 00111111b, 11110000b
    db 00000000b, 00111111b, 11110000b
    db 00000000b, 00111111b, 11110000b
    db 00000000b, 00111110b, 00000000b
    db 00000000b, 00111111b, 11000000b
    db 10000000b, 01111100b, 00000000b
    db 10000001b, 11111100b, 00000000b
    db 11000011b, 11111111b, 00000000b
    db 11100111b, 11111101b, 00000000b
    db 11111111b, 11111100b, 00000000b
    db 11111111b, 11111100b, 00000000b
    db 01111111b, 11111000b, 00000000b
    db 00111111b, 11111000b, 00000000b
    db 00011111b, 11110000b, 00000000b
    db 00001111b, 11110000b, 00000000b
    db 00000111b, 00110000b, 00000000b
    db 00000110b, 00100000b, 00000000b
    db 00000100b, 00100000b, 00000000b
    db 00000110b, 00110000b, 00000000b

times 510 - ($-$$) db 0 ; zero padding
dw 0xAA55 ; boot sector signature