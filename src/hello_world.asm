; Prints "Hello, World!" in the 16 VGA colors, followed by
; "It's now safe to turn off your computer" in bright red.
;
; This code is in the public domain.
; Originally written live for a low-level introductory lecture at undef.space.


; Tell the assembler that this code is going to be located at 0x7C00 in the RAM.
; It ends up there thanks to the BIOS.
org 0x7C00
; Tell the assembler that it should generate instructions for the x86-16 ISA.
use16

; Three macros for convenience. The assembler will substitute the following
; names with their corresponding values.
%define vga_buffer 0xb8000
%define vga_width  80
%define vga_height 25

; Execution starts at the top irregardless of the name of this label.
entry:
    ; Set ES = vga_buffer
    ; Moving immediate values into segment registers is not allowed, so we have
    ; to use AX temporarily. Another option is to use the stack:
    ;    push vga_buffer / 16
    ;    pop es
    mov ax, vga_buffer / 16 ; Division performed at assembly time
    mov es, ax

    ; Clear the screen
    ; Every character is represented using two bytes: the ASCII code of the
    ; character itself and its attributes (background and foreground color).
    mov cx, vga_width * vga_height * 2
    xor di, di ; XORring a reguster with itself effectively resets it to zero.
               ; This is a tad more efficient than a `mov' of 0 because the
               ; instruction is one byte shorter.
    xor al, al
    rep stosb  ; Sets CX bytes starting at ES:DI with AL

    ; Print hello in 16 different colors
    xor di, di ; DI is now outside of the framebuffer, return it to zero
    mov cx, 15 ; Start with color number 15 (bright white)
    .color_loop:
        mov si, hello ; Our "print" function as defined below accepts the
                      ; pointer to the string in DS:SI.
        mov ah, cl    ; It also accepts the color in AH. CL is the lower half of
                      ; CX. Since the value of CX starts at 15 and only goes
                      ; down until it reaches zero, truncating the upper half is
                      ; fine. `mov ah, cx' is not fine since a 16-bit value
                      ; cannot be copied into an 8-bit register.
        call print    ; Call our "print" function (defined below).
        add di, (vga_width - (hello_end - hello)) * 2 ; Go to the next line
        loop .color_loop ; This decrements CX (the color index) and jumps to
                         ; `.color_loop' if the value is still bigger than 0.
                         ; `loop' is effectively equivalent to:
                         ;    dec cx
                         ;    jcxnz .color_loop   ; jump if cx is not zero
                         ; or:
                         ;    dec cx
                         ;    cmp cx, 0
                         ;    jne .color_loop

    ; Print the final message in red
    mov ah, 0x0c
    mov si, goodbye
    call print

    ; Stop
    cli ; Disable interrupts by clearing (resetting) the I flag.
    hlt ; Halt the processor until the next interrupt. Since interrupts are
        ; masked (the I flag is cleared), none will occur, and thus the
        ; processor is halted forever. An NMI (non-maskable-interrupt) may
        ; still occur, and such an occurence will lead to an unexpected result:
        ; the processor will execute "print" and proceed to go on to some random
        ; junk, interpreting whatever's in the memory as code. NMIs are a very
        ; rare occurence, usually triggered by fatal hardware errors. If one
        ; does occur, there's a problem that is more significant than the CPU
        ; executing random data as code.
        ; If the reader does, however, wish to make this code more robust, I am
        ; leaving this as an exercise for them.

; input:
;  DS:SI = input string (null-terminated)
;  AH = color
;  DI = position in framebuffer
; output:
;  none
; clobbers:
;  AL, SI, DI
print:
    .loop:
        lodsb     ; Reads one byte at DS:SI into AL and increments SI.
        stosw     ; Stores AX into a word at ES:DI and increments DI by two.
                  ; Since x86 is little endian, AL ends up in memory just before
                  ; AH, not the other way around. The VGA card thus ends up
                  ; interpreting the stored value of AL as the character and AH
                  ; as its attributes.
        cmp al, 0 ; Compare AL with 0
        jne .loop ; Continue looping if not 0
    ret           ; Return to the caller

; Here we are defining a label. Upon encountering it in the code above, the
; assembler will substitute the label with its address in memory.
; `db' injects a byte or a sequence of bytes (in this case, the ASCII
; characters encoding a string and a zero) into the instruction stream. In
; theory, nothing is stopping the CPU from interpreting data as code; in
; practice, this is prevented here by ending the program with a `cli' and a
; `hlt'. If you're curious, this is what the string looks like when decoded as a
; sequence of x86-16 instructions:
;    dec ax             ; 'H'
;    gs insb            ; 'el'
;    insb               ; 'l'
;    outsw              ; 'o'
;    sub al, 0x20       ; ', '
;    push di            ; 'W'
;    outsw              ; 'o'
;    jc 0x7cab          ; 'rl'
;    and fs:[bx+si], ax ; 'd!', 0
hello: db "Hello, World!", 0
hello_end:

goodbye: db "It's now safe to turn off your computer", 0

; This line pads the size of this program to 510 bytes with zeroes.
; $ means "the address of this line"
; $$ means "the starting address of this program"
; ($-$$) thus means "the size of this program so far"
; `times N' repeats a statement N times
times 510-($-$$) db 0

; This line injects the bytes 55, AA into the instruction steam (remember, x86
; is little endian). The BIOS expects to see these bytes at the end of the boot
; sector that it loads as a marker that it's actually bootable.
dw 0xAA55

; The assembled binary is 512 bytes long, out of which:
;   - 50 bytes are taken up by code;
;   - 54 bytes are taken up by the two strings and their null terminators;
;   - 406 bytes are taken up by the padding;
;   - 2 bytes are taken up by the executable marker.
; This source file is 6285 bytes long, which is 12 times larger than the binary.
