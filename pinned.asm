loadPinnedConfig:
    kld(ix, pinned_apps)
    ld bc, 0x0A00
.loop:
    push bc
        push de
            kld(de, pin_path)
            kld(hl, number@pin_path)
            ld a, c
            add a, '0'
            ld (hl), a
            config(openConfigRead)
            jr nz, .emptyPin

            kld(hl, config_name_variable)
            config(readOption)
            jr nz, _
            ld (ix + 2), l
            ld (ix + 3), h

_:          kld(hl, config_exec_variable)
            config(readOption)
            jr nz, _
            ld (ix + 0), l
            ld (ix + 1), h

_:          kld(hl, config_icon_variable)
            config(readOption)

            push af
                config(closeConfig)
            pop af
            jr nz, .emptyPin
            ; Load icon
            ld b, h \ ld c, l
            ex de, hl
            pcall(openFileRead)
            push ix
                push af
                    push bc \ pop ix \ pcall(free) ; Free icon path
                pop af
                jr nz, .emptyPin_
                pcall(getStreamInfo)
                pcall(malloc)
                pcall(streamReadToEnd)
                pcall(closeStream)
                push ix \ pop hl
            pop ix
            ld (ix + 4), l
            ld (ix + 5), h
            ; TODO: Use kernel image handlers
            ; TODO: Check for monochrome images
            ; TODO: Check that image is 16x16
            jr .emptyPin
.emptyPin_:
            pop ix
.emptyPin:
            ld bc, 6
            add ix, bc
        pop de
    pop bc
    inc c
    djnz .loop_
    ret
.loop_:
    kjp(.loop)

pin_path:
    .db "/var/castle/pin-"
.number:
    .db " ", 0
config_icon_variable:
    .db "icon", 0
config_exec_variable:
    .db "exec", 0
config_name_variable:
    .db "name", 0
pinned_apps:
    ; struct {
    ;   char *exec;
    ;   char *name;
    ;   char *icon_mem;
    ; }[10]
    .dw 0, 0, 0
    .dw 0, 0, 0
    .dw 0, 0, 0
    .dw 0, 0, 0
    .dw 0, 0, 0
    .dw 0, 0, 0
    .dw 0, 0, 0
    .dw 0, 0, 0
    .dw 0, 0, 0
    .dw 0, 0, 0
