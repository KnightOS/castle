applicationList:
    xor a
    kld((manifestScroll), a)
    pcall(clearBuffer)
    kcall(drawAppsChrome)
    kcall(drawAppsHome)
    kcall(getManifestList)
    ; Check for empty
    kld(a, (manifestCount))
    or a
    kjp(z, displayEmptyMessage)
    kcall(drawManifestList)

    ld c, 0
    kcall(xorManifestCaret)
.loop:
    kcall(.drawIcon)
    pcall(fastCopy)

    pcall(flushKeys)
    pcall(waitKey)
    cp kClear
    kjp(z, returnToHome)
    cp kF1
    kjp(z, returnToHome)
    cp kDown
    jr z, .handleDown
    cp kUp
    jr z, .handleUp
    cp kEnter
    kjp(z, .launchSelected)
    cp k2nd
    kjp(z, .launchSelected)
    jr .loop
.handleDown:
    kld(a, (manifestCount))
    dec a
    cp c
    jr z, .loop ; Can't move past last manifest
    ld a, 6
    kld(hl, manifestScroll)
    add a, (hl)
    cp c
    jr z, .scrollDown
    kcall(xorManifestCaret)
    inc c
    kcall(xorManifestCaret)
    jr .loop
.handleUp:
    xor a
    cp c
    jr z, .loop ; Can't move past first manifest
    kld(a, (manifestScroll))
    cp c
    jr z, .scrollUp
    kcall(xorManifestCaret)
    dec c
    kcall(xorManifestCaret)
    jr .loop
.scrollDown:
    kld(a, (manifestScroll))
    add a, b
    kld(hl, manifestCount)
    cp (hl)
    jr z, .loop
    kld(a, (manifestScroll))
    inc a
    kld((manifestScroll), a)
    push bc
        pcall(clearBuffer)
        kcall(drawAppsChrome)
        kcall(drawAppsHome)
        kcall(drawManifestList)
    pop bc
    inc c
    kcall(xorManifestCaret)
    kjp(.loop)
.scrollUp:
    kld(a, (manifestScroll))
    dec a
    kld((manifestScroll), a)
    push bc
        pcall(clearBuffer)
        kcall(drawAppsChrome)
        kcall(drawAppsHome)
        kcall(drawManifestList)
    pop bc
    dec c
    kcall(xorManifestCaret)
    kjp(.loop)
.launchSelected:
    kld(hl, (manifestList))
    ld a, c
    add a, a \ ld b, a \ add a, a \ add a, b ; A *= 6
    ld b, 0 \ ld c, a
    add hl, bc
    inc hl \ inc hl
    ld e, (hl) \ inc hl
    ld d, (hl)
    kjp(launch)
.drawIcon:
    push hl
    push de
    push bc
        ; Clear away old icon
        ld e, 77 ; x
        ld l, 10 ; y
        ld bc, 0x1414 ; height, width
        pcall(rectOR)
        ld e, 78 ; x
        ld l, 11 ; y
        ld bc, 0x1212 ; height, width
        pcall(rectAND)
        ; Draw icon
        kld(hl, (manifestList))
    pop bc \ push bc
        ld a, c
        add a, a \ ld b, a \ add a, a \ add a, b ; A *= 6
        ld b, 0 \ ld c, a
        add hl, bc
        inc hl \ inc hl \ inc hl \ inc hl
        ld e, (hl) \ inc hl
        ld d, (hl) \ inc hl
        ld bc, 0
        pcall(cpBCDE)
        jr nz, _
        kld(de, emptySlotIcon - 10)
_:      ex de, hl
        ld bc, 10
        add hl, bc ; Skip KIMG header
        ld b, 16
        ld d, 79
        ld e, 12
        pcall(putSprite16XOR)
    pop bc
    pop hl
    pop de
    ret

drawManifestList:
    ld de, 0x060C
    kld(hl, (manifestList))
    kld(a, (manifestCount))
    ld b, a
    ; Adjust for scroll
    kld(a, (manifestScroll))
    neg \ add a, b \ ld b, a
    kld(a, (manifestScroll))
    push bc
        add a, a \ ld b, a \ add a, a \ add a, b ; A *= 6
    pop bc
    add a, l \ ld l, a \ jr nc, $+3 \ inc h
    push hl \ pop ix
.loop:
    push bc
        ld l, (ix)
        ld h, (ix + 1)
        pcall(drawStr)
        ld b, 6
        pcall(newline)
        ld bc, 6
        add ix, bc
    pop bc
    ld a, 0x0C + (7 * 6) ; Bottom of screen
    cp e
    jr z, .exitEarly
    djnz .loop
    jr .ret
.exitEarly:
    ld a, 1
    cp b
    jr z, .ret
    ld de, 0x5934
    kld(hl, menuArrowSpriteFlip)
    ld b, 3
    pcall(putSpriteOR)
.ret:
    kld(a, (manifestScroll))
    or a
    ret z
    ld de, 0x590D
    kld(hl, menuArrowSprite)
    ld b, 3
    pcall(putSpriteOR)
    ret

displayEmptyMessage:
    kld(hl, emptyMessage)
    ; Center text
    push hl
        pcall(measureStr)
        neg
        add a, 96
        sra a
        ld d, a
        ld e, (64 - 5) / 2
    pop hl
    pcall(drawStr)
.loop:
    pcall(fastCopy)

    pcall(flushKeys)
    pcall(waitKey)
    cp kClear
    jr z, returnToHome
    cp kF1
    jr z, returnToHome
    jr .loop

returnToHome:
    kcall(freeExistingManifest)
    kjp(resetToHome)

manifestScroll:
    .db 0

xorManifestCaret:
    ld de, 0x010C
    kld(a, (manifestScroll))
    neg
    add a, c
    add a, a \ ld b, a \ add a, a \ add a, b ; A *= 6
    add a, e \ ld e, a
    ld b, 5
    kld(hl, selectionIndicatorSprite)
    pcall(putSpriteXOR)
    ret

getManifestList:
    kld(hl, (manifestList))
    ld bc, 0
    pcall(cpHLBC)
    kcall(nz, freeExistingManifest)

    ld bc, 0x200 ; Default length of manifest list
    pcall(malloc)
    jr nz, $ ; TODO: Handle OOM
    kld((manifestList), ix)
    ld a, 0
    kld((manifestCount), a)

    pcall(malloc) ; Scratch area
    push ix \ pop de
    kld(hl, manifestPath)
    ld bc, manifestPath_end - manifestPath
    ldir

    kld(de, manifestPath)
    kld(hl, .callback)
    pcall(listDirectory)

    pcall(memSeekToStart)
    pcall(free) ; Free scratch area

    kld(ix, compareManifests)
    kld(hl, (manifestList))
    kld(de, (manifestList))
    kld(a, (manifestCount))
    dec a
    add a, a \ ld b, a \ add a, a \ add a, b ; A *= 6
    ld b, 0 \ ld c, a
    add hl, bc
    ex de, hl
    ld bc, 6
    pcall(callbackSort)
    ret
.callback:
    cp fsFile
    jr z, _
    cp fsSymLink
    jr z, _
    ret
_:  push de
    push hl
    push bc
        ld bc, (manifestPath_end - manifestPath) - 1 ; Overwrite null delimiter
        push ix \ pop hl
        add hl, bc
        ex de, hl
        ld hl, kernelGarbage
        pcall(strlen)
        inc bc
        ldir
        push ix \ pop de
        ld hl, 0
        kld((.icon_scratch), hl) ; Default icon is 0
        config(openConfigRead)
        kld(hl, config_name_variable)
        config(readOption)
        kjp(nz, .error)
        kld((.name_scratch), hl)
        kld(hl, config_exec_variable)
        config(readOption)
        jr nz, .error
        kld((.exec_scratch), hl)
        kld(hl, config_icon_variable)
        config(readOption)
        jr nz, _
        kld((.icon_scratch), hl)
_:      config(closeConfig)
        ; Names list in memory is:
        ; struct {
        ;   char *name;
        ;   char *exec;
        ;   void *icon;
        ; }
        kld(a, (manifestCount))
        kld(hl, (manifestList))
        add a, a \ ld b, a \ add a, a \ add a, b ; A *= 6
        add a, l \ ld l, a \ jr nc, $+3 \ inc h
        kld(de, (.name_scratch))
        ld (hl), e \ inc hl
        ld (hl), d \ inc hl
        kld(de, (.exec_scratch))
        ld (hl), e \ inc hl
        ld (hl), d \ inc hl
        kld(de, (.icon_scratch))
        ; Load icon file
        push ix
        push hl
            ld b, d \ ld c, e
            pcall(openFileRead)
            push af
                push bc \ pop ix
                pcall(free)
            pop af
            jr nz, .no_icon
            pcall(getStreamInfo)
            pcall(malloc)
            pcall(streamReadToEnd)
            pcall(closeStream)
            push ix \ pop de
            jr .continue
.no_icon:
            ld de, 0
.continue:
        pop hl
        pop ix
        ld (hl), e \ inc hl
        ld (hl), d
        kld(hl, manifestCount)
        inc (hl)
.error:
    pop bc
    pop hl
    pop de
    ret
.name_scratch:
    .dw 0
.exec_scratch:
    .dw 0
.icon_scratch:
    .dw 0

freeExistingManifest:
    kld(hl, (manifestList))
    kld(a, (manifestCount))
    ld b, a
_:  ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    push de \ pop ix
    pcall(free)
    djnz -_

    kld(ix, (manifestList))
    pcall(free)
    ld hl, 0
    kld((manifestList), hl)
    xor a
    kld((manifestCount), a)
    ret

compareManifests:
    pcall(strcmp_sort)
    ret

; List of names of installed applications
manifestList:
    .dw 0
manifestCount:
    .db 0 ; Note: will you ever have more than 256 apps installed?

manifestPath:
    .db "/var/applications/", 0
manifestPath_end:

emptyMessage:
    .db "No applications!", 0
