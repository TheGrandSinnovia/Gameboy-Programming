INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

	jp EntryPoint

	ds $150 - @, 0 ; Make room for the header

EntryPoint:
	; Shut down audio circuitry
	ld a, 0
	ld [rNR52], a

	; Do not turn the LCD off outside of VBlank
WaitVBlank:
	ld a, [rLY]
	cp 144
	jr c, WaitVBlank

	; Turn the LCD off
	ld a, 0
	ld [rLCDC], a

    ; Copy the tile data
    ld de, Tiles
    ld hl, $9000
    ld bc, TilesEnd - Tiles
    call Memcopy

	; Copy the tilemap
	ld de, Tilemap
	ld hl, $9800
	ld bc, TilemapEnd - Tilemap
	call Memcopy

	; Copy the object tile data
	ld de, ObjectTiles
	ld hl, $8000
	ld bc, ObjectTilesEnd - ObjectTiles
	call Memcopy	

	; Clear OAM
	ld a, 0
    ld b, 160
    ld hl, STARTOF(OAM)
ClearOam:
    ld [hli], a
    dec b
    jp nz, ClearOam

	ld a, 128 - 64 ; Y position
	ld [wPlayerY], a
	ld a, 16 + 64 ; X position
	ld [wPlayerX], a
	ld a, 0
    ld [wFrameCounter], a ; Frame counter
	ld [wCurKeys], a
    ld [wNewKeys], a

	; Starting direction
	ld a, 0
	ld [wPlayerDir], a
	call LookUp

	; Place player sprite
	ld a, [wPlayerY]; Y position
	ld e, a
	ld a, [wPlayerX] ; X position
	ld d, a
	call PlaceSprite
	
	; Turn the LCD on
	ld a, LCDC_ON | LCDC_BG_ON | LCDC_OBJ_ON
	ld [rLCDC], a

	; During the first (blank) frame, initialize display registers
	ld a, %11100100
	ld [rBGP], a
	ld a, %11100100
	ld [rOBP0], a

Main:
	; Wait until it's *not* VBlank
	ld a, [rLY]
	cp 144
	jp nc, Main
WaitVBlank2:
	ld a, [rLY]
	cp 144
	jp c, WaitVBlank2


	; Check the current keys every frame and move left or right.
	call UpdateKeys

	; First, check if the left button is pressed.
CheckLeft:
	ld a, [wCurKeys]
    and a, PAD_LEFT
    jp z, CheckRight

CheckChangeLeftDir:
	; Check if player is looking left
	ld a, [wPlayerDir]
	cp 2
	jp nz, ChangeLeftDir

Left:
	; Move the object one pixel to the left.
	ld a, [wPlayerY] ; Y position
	ld e, a
	ld a, [wPlayerX]; X position
	dec a
	ld [wPlayerX], a
	ld d, a

CheckLeftUp:
	ld a, [wCurKeys]
	and a, PAD_UP
	jp z, CheckLeftDown

	; Move the object one pixel upwards.
	ld a, [wPlayerY] ; Y position
	dec a
	ld [wPlayerY], a
	ld e, a
	jp ContinueLeft

CheckLeftDown:
	ld a, [wCurKeys]
	and a, PAD_DOWN
	jp z, ContinueLeft

	; Move the object one pixel downwards.
	ld a, [wPlayerY] ; Y position
	inc a
	ld [wPlayerY], a
	ld e, a

ContinueLeft:
	call PlaceSprite

	jp Main

ChangeLeftDir:
	; Change player direction to look left
	ld a, 2
	ld [wPlayerDir], a
	call LookLeft

	jp Main


; Then check the right button.
CheckRight:
    ld a, [wCurKeys]
    and a, PAD_RIGHT
    jp z, CheckUp

CheckChangeRightDir:
	; Check if player is looking right
	ld a, [wPlayerDir]
	cp 3
	jp nz, ChangeRightDir

Right:
	; Move the object one pixel to the right.
	ld a, [wPlayerY] ; Y position
	ld e, a
	ld a, [wPlayerX]; X position
	inc a
	ld [wPlayerX], a
	ld d, a

CheckRightUp:
	ld a, [wCurKeys]
	and a, PAD_UP
	jp z, CheckRightDown

	; Move the object one pixel upwards.
	ld a, [wPlayerY] ; Y position
	dec a
	ld [wPlayerY], a
	ld e, a
	jp ContinueRight

CheckRightDown:
	ld a, [wCurKeys]
	and a, PAD_DOWN
	jp z, ContinueRight

	; Move the object one pixel downwards.
	ld a, [wPlayerY] ; Y position
	inc a
	ld [wPlayerY], a
	ld e, a

ContinueRight:
	call PlaceSprite

	jp Main

ChangeRightDir:
	; Change player direction to look right
	ld a, 3
	ld [wPlayerDir], a
	call LookRight

	jp Main

CheckUp:
	ld a, [wCurKeys]
	and a, PAD_UP
	jp z, CheckDown

CheckChangeUpDir:
	; Check if player is looking down
	ld a, [wPlayerDir]
	cp 0
	jp nz, ChangeUpDir

Up:
	; Move the object one pixel upwards.
	ld a, [wPlayerY] ; Y position
	dec a
	ld [wPlayerY], a
	ld e, a
	ld a, [wPlayerX]; X position
	ld d, a
	call PlaceSprite

	jp Main

ChangeUpDir:
	; Change player direction to look up
	ld a, 0
	ld [wPlayerDir], a
	call LookUp

	jp Main

CheckDown:
	ld a, [wCurKeys]
	and a, PAD_DOWN
	jp z, Main

CheckChangeDownDir:
	; Check if player is looking down
	ld a, [wPlayerDir]
	cp 1
	jp nz, ChangeDownDir

Down:
	; Move the object one pixel downwards.
	ld a, [wPlayerY] ; Y position
	inc a
	ld [wPlayerY], a
	ld e, a
	ld a, [wPlayerX]; X position
	ld d, a
	call PlaceSprite

	jp Main

ChangeDownDir:
	; Change player direction to look down
	ld a, 1
	ld [wPlayerDir], a
	call LookDown

	jp Main

	

UpdateKeys:
	; Poll half the controller
	ld a, JOYP_GET_BUTTONS
	call .onenibble
	ld b, a ; B7-4 = 1; B3-0 = unpressed buttons
	
	; Poll the other half
	ld a, JOYP_GET_CTRL_PAD
	call .onenibble
	swap a ; A7-4 = unpressed directions; A3-0 = 1
	xor a, b ; A = pressed buttons + directions
	ld b, a ; B = pressed buttons + directions
	
	; And release the controller
	ld a, JOYP_GET_NONE
	ldh [rJOYP], a
	
	; Combine with previous wCurKeys to make wNewKeys
	ld a, [wCurKeys]
	xor a, b ; A = keys that changed state
	and a, b ; A = keys that changed to pressed
	ld [wNewKeys], a
	ld a, b
	ld [wCurKeys], a
	ret
	
.onenibble
	ldh [rJOYP], a ; switch the key matrix
	call .knownret ; burn 10 cycles calling a known ret
	ldh a, [rJOYP] ; ignore value while waiting for the key matrix to settle
	ldh a, [rJOYP]
	ldh a, [rJOYP] ; this read counts
	or a, $F0 ; A7-4 = 1; A3-0 = unpressed keys
.knownret
	ret
	  

Memcopy:
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, Memcopy
	ret

LookLeft:
	ld hl, STARTOF(OAM) + 2 ; Tile start
	ld a, 8
	ld [hli], a
	ld a, 0
	ld [hl], a

	ld hl, STARTOF(OAM) + 4 + 2 ; Tile start
	ld a, 9
	ld [hli], a
	ld a, 0
	ld [hl], a

	ld hl, STARTOF(OAM) + 8 + 2 ; Tile start
	ld a, 10
	ld [hli], a
	ld a, 0
	ld [hl], a

	ld hl, STARTOF(OAM) + 12 + 2 ; Tile start
	ld a, 11
	ld [hli], a
	ld a, 0
	ld [hl], a

	ret

LookRight:
	ld hl, STARTOF(OAM) + 2 ; Tile start
	ld a, 9
	ld [hli], a
	ld a, %00100000 ; Flip
	ld [hl], a

	ld hl, STARTOF(OAM) + 4 + 2 ; Tile start
	ld a, 8
	ld [hli], a
	ld a, %00100000 ; Flip
	ld [hl], a

	ld hl, STARTOF(OAM) + 8 + 2 ; Tile start
	ld a, 11
	ld [hli], a
	ld a, %00100000 ; Flip
	ld [hl], a

	ld hl, STARTOF(OAM) + 12 + 2 ; Tile start
	ld a, 10
	ld [hli], a
	ld a, %00100000 ; Flip
	ld [hl], a

	ret

LookUp:
	ld hl, STARTOF(OAM) + 2 ; Tile start
	ld a, 4
	ld [hli], a
	ld a, 0
	ld [hl], a

	ld hl, STARTOF(OAM) + 4 + 2 ; Tile start
	ld a, 5
	ld [hli], a
	ld a, 0
	ld [hl], a

	ld hl, STARTOF(OAM) + 8 + 2 ; Tile start
	ld a, 6
	ld [hli], a
	ld a, 0
	ld [hl], a

	ld hl, STARTOF(OAM) + 12 + 2 ; Tile start
	ld a, 7
	ld [hli], a
	ld a, 0
	ld [hl], a

	ret

LookDown:
	ld hl, STARTOF(OAM) + 2 ; Tile start
	ld a, 0
	ld [hli], a
	ld a, 0
	ld [hl], a

	ld hl, STARTOF(OAM) + 4 + 2 ; Tile start
	ld a, 1
	ld [hli], a
	ld a, 0
	ld [hl], a

	ld hl, STARTOF(OAM) + 8 + 2 ; Tile start
	ld a, 2
	ld [hli], a
	ld a, 0
	ld [hl], a

	ld hl, STARTOF(OAM) + 12 + 2 ; Tile start
	ld a, 3
	ld [hli], a
	ld a, 0
	ld [hl], a

	ret

PlaceSprite:
	ld hl, STARTOF(OAM)
	ld a, e
    add a, 16
    ld [hli], a
	ld a, d
	add a, 8
    ld [hli], a

	ld hl, STARTOF(OAM) + 4
	ld a, e
    add a, 16
    ld [hli], a
	ld a, d
    add a, 8 + 8
    ld [hli], a

	ld hl, STARTOF(OAM) + 8
	ld a, e
	add a, 16 + 8
    ld [hli], a
	ld a, d
	add a, 8
    ld [hli], a

	ld hl, STARTOF(OAM) + 12
	ld a, e
	add a, 16 + 8
    ld [hli], a
	ld a, d
    add a, 8 + 8
    ld [hli], a
	
	ret

SECTION "Tile data", ROM0

; Blank tiles for blank background
Tiles:
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
	db $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00, $00,$00
TilesEnd:

SECTION "Tilemap", ROM0

Tilemap:
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $01, $02, $03, $01, $04, $03, $01, $05, $00, $01, $05, $00, $06, $04, $07, $00, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $08, $09, $0a, $0b, $0c, $0d, $0b, $0e, $0f, $08, $0e, $0f, $10, $11, $12, $13, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $14, $15, $16, $17, $18, $19, $1a, $1b, $0f, $14, $1b, $0f, $14, $1c, $16, $1d, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $1e, $1f, $20, $21, $22, $23, $24, $22, $25, $1e, $22, $25, $26, $22, $27, $1d, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $01, $28, $29, $2a, $2b, $2c, $2d, $2b, $2e, $2d, $2f, $30, $2d, $31, $32, $33, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $08, $34, $0a, $0b, $11, $0a, $0b, $35, $36, $0b, $0e, $0f, $08, $37, $0a, $38, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $14, $39, $16, $17, $1c, $16, $17, $3a, $3b, $17, $1b, $0f, $14, $3c, $16, $1d, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $1e, $3d, $3e, $3f, $22, $27, $21, $1f, $20, $21, $22, $25, $1e, $22, $40, $1d, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $00, $41, $42, $43, $44, $30, $33, $41, $45, $43, $41, $30, $43, $41, $30, $33, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
	db $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,  0,0,0,0,0,0,0,0,0,0,0,0
TilemapEnd:


SECTION "Object Tile Data", ROM0
ObjectTiles:
	INCBIN "blue.2bpp"
ObjectTilesEnd:

SECTION "Player Data", WRAM0
wFrameCounter: db
wPlayerY: db
wPlayerX: db
wPlayerDir: db ; 0 (Look up), 1 (Look down), 2 (Look left), 3 (Look right)

SECTION "Input Variables", WRAM0
wCurKeys: db
wNewKeys: db
	