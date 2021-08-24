org 0x7c00
use16

%define clock_ms 0x7e00 ; in RAM right after the boot sector

entry:
    ; set video mode 13h (https://ibm.retropc.se/video/bios_video_modes.html)
    xor ah, ah
    mov al, 13h
    int 10h
    ; set fs = VGA buffer
    mov ax, 0xa000
    mov fs, ax

    ; draw sky
    mov cx, 131
    xor bx, bx
    mov dl, 0x35
    call fill_portion
    ; draw sea
    mov cx, 69
    mov bx, 131
    inc dl ; dl = 0x36
    call fill_portion

    ; draw foam
    mov si, foam_sprite
    mov dh, 128
    mov dl, 0xf
    xor bx, bx
    mov cx, 13
    .foam:
        call draw_sprite
        add bx, 24
        loop .foam
    ; draw the remainder
    mov cx, 1
    mov bx, 130
    call fill_portion

    ; draw fish
    mov cl, byte [fish_locations]
    xor di, di
    mov dl, 0x37
    .fish:
        mov si, word [fish_locations+di+1]
        mov bx, word [fish_locations+di+3]
        mov dh, byte [fish_locations+di+5]
        add di, 6
        call draw_sprite
        loop .fish

    ; set PIT channel 0 frequency (1kHz)
    mov ax, 1193182 / 1000
    out 0x40, al
    mov al, ah
    out 0x40, al
    ; set IRQ0 handler
    mov ax, cs
    mov word [0x0022], ax
    mov word [0x0020], irq0

    jmp $

irq0:
    ; advance clock
    inc word [clock_ms]
    cmp word [clock_ms], 1000
    jb .no_overflow
    mov word [clock_ms], 0
    .no_overflow:
    mov ax, word [clock_ms]

    ; shift top foam row right on every 250th ms
    cmp ax, 250
    jne .nostr
    mov bx, 128
    call shift_row_right
    .nostr:
    ; shift top foam row left on every 750th ms
    cmp ax, 750
    jne .nostl
    mov bx, 128
    call shift_row_left
    .nostl:
    ; shift middle and bottom rows right on every 500th ms
    cmp ax, 500
    jne .nosbr
    mov bx, 131
    call shift_row_right
    mov bx, 129
    call shift_row_right
    .nosbr:
    ; shift middle and bottom rows left on every 999th ms
    cmp ax, 999
    jne .nosbl
    mov bx, 131
    call shift_row_left
    mov bx, 129
    call shift_row_left
    .nosbl:

    ; move top fish every 50 ms
    push ax
    mov bl, 50
    div bl
    cmp ah, 0
    jne .notfish
    mov bx, 138
    mov cx, 11
    call shift_rect_left
    .notfish:
    pop ax

    ; move bottom fish every 70 ms
    mov bl, 70
    div bl
    cmp ah, 0
    jne .nobfish
    mov bx, 157
    mov cx, 29
    call shift_rect_left
    .nobfish:

    ; EOI
    mov al, 0x20
    out 0x20, al
    iret

;description:
; fills a rectangle with the width of 320px starting at X=0
;input:
; CX = height
; BX = Y position
; DL = color
fill_portion:
    ; save DX
    push dx
    ; calculate end
    mov ax, 320
    add bx, cx
    mul bx
    mov di, ax
    ; multiply CX by 320
    mov ax, cx
    mov dx, 320
    mul dx
    mov cx, ax
    ; restore DX
    pop dx
    .iter:
        dec di
        mov byte [fs:di], dl
        loop .iter
    ret

;description:
; shifts a row of pixels to the right
;input:
; BX = Y position
shift_row_right:
    ; save regs
    push ax
    push cx
    push dx
    ; calculate end of line
    mov ax, 320
    inc bx
    mul bx
    mov di, ax
    mov cx, 319
    .iter:
        dec di
        mov al, byte [fs:di-1]
        mov byte [fs:di], al
        loop .iter
    ; restore regs
    pop dx
    pop cx
    pop ax
    ret

;description:
; shifts a row of pixels to the left
;input:
; BX = Y position
shift_row_left:
    ; save regs
    push ax
    push cx
    push dx
    ; calculate start of line
    mov ax, 320
    mul bx
    mov di, ax
    mov cx, 319
    .iter:
        mov al, byte [fs:di+1]
        mov byte [fs:di], al
        inc di
        loop .iter
    ; wrap around
    mov al, byte [fs:di-319]
    mov byte [fs:di], al
    ; restore regs
    pop dx
    pop cx
    pop ax
    ret

;description:
; shifts a rectangle to the left
;input:
; BX = Y position
; CX = height
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
    push si
    push cx
    push di
    push ax
    ; calculate vmem offset
    mov al, dh
    mov cl, 160 ;
    mul cl      ; multiplication by 320
    shl ax, 1   ;
    mov di, ax
    add di, bx
    ; read height into cx
    mov al, byte [si]
    movzx cx, al
    and cx, 0xf
    ; keep width in al
    shr al, 4
    inc si
    push ax
.row:
    pop ax
    push ax
    .chunk:
        ; read chunk
        mov ah, byte [si]
        mov bp, 8
        .pixel:
            test ah, 0x80 ; test leftmost pixel
            jz .bg_pixel
            mov byte [fs:di], dl ; foreground pixel
            .bg_pixel:
            shl ah, 1
            inc di
            dec bp
            jnz .pixel
        inc si
        dec al
        jnz .chunk
    ; go to second row
    pop ax
    add di, 320
    shl al, 3
    xor ah, ah
    sub di, ax
    shr al, 3
    push ax
    loop .row
.return:
    pop ax
    ; restore regs
    pop ax
    pop di
    pop cx
    pop si
    ret

; sprites
foam_sprite:
    db (3 << 4) | (4 << 0) ; width: 3 bytes (24px), height: 4 bytes (4 px)
    db 00011100b, 00000000b, 00000000b
    db 01111110b, 00000011b, 00001110b
    db 11111111b, 11111111b, 11111111b
    db 00000000b, 00011111b, 11000000b
small_fish:
    db (3 << 4) | (6 << 0)
    db 00111110b, 00001101b, 10000000b
    db 01111111b, 11100111b, 00000000b
    db 11011111b, 11111110b, 00000000b
    db 11111111b, 11111100b, 00000000b
    db 01111111b, 11111000b, 00000000b
    db 00111111b, 11100000b, 00000000b
coralfish:
    db (1 << 4) | (8 << 0)
    db 00010000b
    db 00110010b
    db 01110010b
    db 10111110b
    db 11111110b
    db 01110110b
    db 00110010b
    db 00010000b

fish_locations:
    db 10 ; length
    dw small_fish, 54, 159
    dw small_fish, 121, 143
    dw small_fish, 252, 140
    dw small_fish, 169, 157
    dw small_fish, 78, 180
    dw small_fish, 152, 176
    dw coralfish, 92, 157
    dw coralfish, 80, 138
    dw coralfish, 217, 160
    dw coralfish, 233, 173

times 510 - ($-$$) db 0 ; useless! all the code and data above fits in 510 bytes with no space to spare
dw 0xAA55 ; boot sector signature