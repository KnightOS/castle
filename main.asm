#include "kernel.inc"
#include "corelib.inc"
#include "config.inc"
    .db "KEXC"
    .db KEXC_ENTRY_POINT
    .dw start
    .db KEXC_STACK_SIZE
    .dw 50
    .db KEXC_KERNEL_VER
    .db 0, 6
    .db KEXC_NAME
    .dw name
    .db KEXC_DESCRIPTION
    .dw description
    .db KEXC_HEADER_END
name:
    .db "Castle", 0
description:
    .db "KnightOS program launcher", 0
timer:
    .db 0
start:
    pcall(getLcdLock)
    pcall(getKeypadLock)

    pcall(allocScreenBuffer)

    kld(de, corelibPath)
    pcall(loadLibrary)

    kld(de, configlibPath)
    pcall(loadLibrary)

    kcall(loadPinnedConfig)
resetToHome:
    ei
    ld d, 0
    xor a
    kld((timer), a)
redrawHome:
    push de
        kcall(drawChrome)
        kcall(drawHome)
    pop de
homeLoop:
    kcall(drawPinnedApps)
    pcall(flushKeys)

_:  kcall(drawClock)
    pcall(fastCopy)
    pcall(getKey)

    cp kRight
    jr z, homeRightKey
    cp kLeft
    jr z, homeLeftKey
    cp kUp
    jr z, homeUpKey
    cp kDown
    jr z, homeDownKey
    cp kYEqu
    kjp(z, applicationList)
    cp kZoom
    kjp(z, powerMenu)
    cp kEnter
    jr z, homeSelect
    cp k2nd
    jr z, homeSelect
    cp kGraph
    kjp(z, openThreadList)
    cp kPlus
    kjp(z, incrementContrast)
    cp kMinus
    kjp(z, decrementContrast)
    jr -_
homeRightKey:
    ld a, 9
    cp d
    jr z, -_
    inc d
    jr homeLoop
homeLeftKey:
    xor a
    cp d
    jr z, -_
    dec d
    jr homeLoop
homeUpKey:
    ld a, 4
    cp d
    jr nc, -_
    ld a, d \ sub 5 \ ld d, a
    jr homeLoop
homeDownKey:
    ld a, 4
    cp d
    jr c, -_
    inc a \ add a, d \ ld d, a
    jr homeLoop

homeSelect:
    ld a, d
    add a, a \ ld b, a \ add a, a \ add a, b ; A *= 6
    kld(ix, pinned_apps)
    ld b, 0 \ ld c, a
    add ix, bc
    ld e, (ix + 0)
    ld d, (ix + 1)
    kjp(launch)
    kjp(homeLoop)

incrementContrast:
    ld hl, currentContrast
    inc (hl)
    ld a, (hl)
    or a
    jr nz, _
    dec (hl)
    dec a
_:  out (0x10), a
    kjp(homeLoop)

decrementContrast:
    ld hl, currentContrast
    dec (hl)
    ld a, (hl)
    cp 0xDF
    jr nz, _
    inc (hl)
    inc a
_:  out (0x10), a
    kjp(homeLoop)

openThreadList:
    kld(de, threadlist)
    jr _
launch:
_:  di
    ; Idea: load a small bootstrapping program into RAM, then kill the castle thread and transfer over to the bootstrap.
    ; This frees up the castle's memory for the new program, allowing for larger programs to be launched.
    ; Potential issue: the bootstrap would be allocated shortly after the castle in memory, and therefore only programs
    ; smaller than the castle in the first place would benefit from this.
    ; Potential solution: provide an alternative malloc that allocates in the back of RAM
    corelib(open)
    corelib(nz, showError)
    kjp(nz, resetToHome)
    ld bc, castleReturnHandler_end - castleReturnHandler
    pcall(malloc)
    pcall(reassignMemory)
    push ix \ pop de
    kld(hl, castleReturnHandler)
    push de
        ldir
    pop de \ ld h, d \ ld l, e
    ld bc, castleReturnHandler_path - castleReturnHandler
    add hl, bc
    ex de, hl
    inc hl
    ld (hl), e
    inc hl
    ld (hl), d
    dec hl \ dec hl
    pcall(setReturnPoint)
    ret

castleReturnHandler:
    ; Idea for a kernel function: setThreadStart
    ; Updates the thread table so that the current block of allocated memory is the start of the thread executable
    ; Then all further relative loads and such will load as if that were the case
    ld de, 0
    pcall(launchProgram)
    pcall(killCurrentThread)
castleReturnHandler_path:
    .db "/bin/castle", 0
castleReturnHandler_end:

powerMenu:
    push de
        kcall(drawPowerMenu)
        ld e, 38
powerMenuLoop:
        pcall(fastCopy)
        pcall(flushKeys)
        pcall(waitKey)
        
        cp kUp
        jr z, powerMenuUp
        cp kDown
        jr z, powerMenuDown
        cp k2nd
        jr z, powerMenuSelect
        cp kEnter
        jr z, powerMenuSelect
        cp kMode
        kjp(z, pop_resetToHome)
        cp kZoom
        kjp(z, pop_resetToHome)
        
        jr powerMenuLoop

powerMenuUp:
        ld a, 38
        cp e
        jr z, powerMenuLoop
        pcall(putSpriteAND)
        ld a, e
        ld e, 6
        sub e
        ld e, a
        pcall(putSpriteOR)
        jr powerMenuLoop

powerMenuDown:
        ld a, 50
        cp e
        jr z, powerMenuLoop
        pcall(putSpriteAND)
        ld a, 6
        add a, e
        ld e, a
        pcall(PutSpriteOR)
        jr powerMenuLoop

powerMenuSelect:
        ld a, e
    pop de
    cp 44
    jr z, confirmShutDown
    cp 50
    jr z, confirmRestart
    pcall(suspendDevice)
    kjp(redrawHome)

pop_resetToHome:
    pop de
    kjp(resetToHome)

confirmShutDown:
    ld hl, 0 ; boot
    jr confirmSelection
confirmRestart:
    ld hl, 0x18 ; reboot
confirmSelection:
    push hl
        kld(hl, confirmMessage)
        kld(de, shutdownOptions)
        xor a
        ld b, a
        corelib(showMessage)
    pop hl
    or a
    jr nz, _
    kjp(resetToHome)
_:  ld a, 2 \ out (0x10), a
    ld b, 255 \ djnz $
    jp (hl)

#include "graphics.asm"
#include "applist.asm"
#include "pinned.asm"

threadlist:
    .db "/bin/threadlist", 0
corelibPath:
    .db "/lib/core", 0
configlibPath:
    .db "/lib/config", 0
confirmMessage:
    .db "Are you sure?\nUnsaved data\nmay be lost.", 0
shutdownOptions:
    .db 2
    .db "No", 0
    .db "Yes", 0
dispApps_name:
    .db "Installed apps", 0
dispApps_cursorSprite:
    .db 0x80
    .db 0xc0
    .db 0xe0
    .db 0xc0
    .db 0x80
dispApps_textCursor:
    .db 0, 0
dispApps_userCursor:
    .db 0
dispApps_offset:
    .db 0
dispApps_computed:
    .db 0
dispApps_filesNb:
    .db 0
appsLocation:
    .db "/var/applications/", 0
