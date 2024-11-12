; Define PPU Registers
PPU_CONTROL = $2000 ; PPU Control Register 1 (Write)
PPU_MASK = $2001 ; PPU Control Register 2 (Write)
PPU_STATUS = $2002; PPU Status Register (Read)
PPU_SPRRAM_ADDRESS = $2003 ; PPU SPR-RAM Address Register (Write)
PPU_SPRRAM_IO = $2004 ; PPU SPR-RAM I/O Register (Write)
PPU_VRAM_ADDRESS1 = $2005 ; PPU VRAM Address Register 1 (Write)
PPU_VRAM_ADDRESS2 = $2006 ; PPU VRAM Address Register 2 (Write)
PPU_VRAM_IO = $2007 ; VRAM I/O Register (Read/Write)
SPRITE_DMA = $4014 ; Sprite DMA Register

; Define PPU control register masks
NT_2000 = $00 ; nametable location
NT_2400 = $01
NT_2800 = $02
NT_2C00 = $03

VRAM_DOWN = $04 ; increment VRAM pointer by row

OBJ_0000 = $00 
OBJ_1000 = $08
OBJ_8X16 = $20

BG_0000 = $00 ; 
BG_1000 = $10

VBLANK_NMI = $80 ; enable NMI

BG_OFF = $00 ; turn background off
BG_CLIP = $08 ; clip background
BG_ON = $0A ; turn background on

OBJ_OFF = $00 ; turn objects off
OBJ_CLIP = $10 ; clip objects
OBJ_ON = $14 ; turn objects on

; Define APU Registers
APU_DM_CONTROL = $4010 ; APU Delta Modulation Control Register (Write)
APU_CLOCK = $4015 ; APU Sound/Vertical Clock Signal Register (Read/Write)

; Joystick/Controller values
JOYPAD1 = $4016 ; Joypad 1 (Read/Write)
JOYPAD2 = $4017 ; Joypad 2 (Read/Write)

; Gamepad bit values
PAD_A      = $01
PAD_B      = $02
PAD_SELECT = $04
PAD_START  = $08
PAD_U      = $10
PAD_D      = $20
PAD_L      = $40
PAD_R      = $80

; Useful PPU memory addresses
NAME_TABLE_0_ADDRESS		= $2000
ATTRIBUTE_TABLE_0_ADDRESS	= $23C0
NAME_TABLE_1_ADDRESS		= $2400
ATTRIBUTE_TABLE_1_ADDRESS	= $27C0


.segment "HEADER"
INES_MAPPER = 0                                                     ; 0 = NROM
INES_MIRROR = 0                                                     ; 0 = horizontal mirror/1 = vertical
INES_SRAM = 0                                                       ; 1 = battery save at $6000-7FFF

.byte 'N', 'E', 'S', $1A ; ID
.byte $02                                                           ; 16 KB program bank count
.byte $01                                                           ; 8 KB program bank count
.byte INES_MIRROR | (INES_SRAM << 1) | ((INES_MAPPER & $f) << 4)
.byte (INES_MAPPER & %11110000)
.byte $0, $0, $0, $0, $0, $0, $0, $0                                ; padding

.segment "TILES"
.incbin "Tiles.chr"

.segment "VECTORS"
.word nmi
.word reset
.word irq

.segment "ZEROPAGE"

;*****************************************************************
; 6502 Zero Page Memory (256 bytes)
;*****************************************************************

nmi_ready:		.res 1 ; set to 1 to push a PPU frame update, 
					   ;        2 to turn rendering off next NMI
gamepad:		.res 1 ; stores the current gamepad values

paddr:          .res 2 ; 16-bit address pointer

ppu_ctl0:		.res 1 ; PPU Control Register 2 Value

ppu_ctl1:		.res 1 ; PPU Control Register 2 Value

.segment "OAM"
oam: .res 256	; sprite OAM data

.segment "BSS"
palette: .res 32 ; current palette buffer

.macro vram_set_address newaddress
    lda PPU_STATUS
    lda #>newaddress
    sta PPU_VRAM_ADDRESS2
    lda #<newaddress
    sta PPU_VRAM_ADDRESS2
.endmacro

.macro assign_16i dest, value
    lda #<value
    sta dest+0
    lda #>value
    sta dest+1
.endmacro

.macro vram_clear_address
    lda #0
    sta PPU_VRAM_ADDRESS2
    sta PPU_VRAM_ADDRESS2
.endmacro

.segment "CODE"
.proc wait_frame
	inc nmi_ready
@loop:
	lda nmi_ready
	bne @loop
	rts
.endproc

.segment "CODE"
; ppu_update: waits until next NMI, turns rendering on (if not already), uploads OAM, palette, and nametable update to PPU
.proc ppu_update
lda ppu_ctl0
	ora #VBLANK_NMI
	sta ppu_ctl0
	sta PPU_CONTROL
	lda ppu_ctl1
	ora #OBJ_ON|BG_ON
	sta ppu_ctl1
	jsr wait_frame
	rts
.endproc

; ppu_off: waits until next NMI, turns rendering off (now safe to write PPU directly via PPU_VRAM_IO)
.proc ppu_off
jsr wait_frame
	lda ppu_ctl0
	and #%01111111
	sta ppu_ctl0
	sta PPU_CONTROL
	lda ppu_ctl1
	and #%11100001
	sta ppu_ctl1
	sta PPU_MASK
	rts
.endproc

.segment "CODE"
.proc reset
    sei
    lda #0
    sta PPU_CONTROL
    sta PPU_MASK
    ;sta APU_DM_CONTROL
    lda #40
    sta JOYPAD2 

    cld
    ldx #$FF
    txs

    bit PPU_STATUS
wait_vblank:
    bit PPU_STATUS
    bpl wait_vblank

    lda #0
    ldx #0

clear_ram:
    sta $0000, x
    sta $0100, x
    sta $0200, x
    sta $0300, x
    sta $0400, x
    sta $0500, x
    sta $0600, x
    sta $0700, x
    inx
    bne clear_ram

    lda #255
    ldx #0

clear_oam:
    sta oam, x
    inx
    inx
    inx
    inx
    bne clear_oam

wait_vblank2:
    bit PPU_STATUS
    bpl wait_vblank2

    lda #%10001000
    sta PPU_CONTROL

    jmp main
.endproc

.segment "CODE"
.proc clear_nametable
    lda PPU_STATUS 
    lda #$20
    sta PPU_VRAM_ADDRESS2
    lda #$00
    sta PPU_VRAM_ADDRESS2

    lda #0
    ldy #30
    rowloop:
        ldx #32
        columnloop:
            sta PPU_VRAM_IO
            dex
            bne columnloop
        dey
        bne rowloop

    ldx #64
    loop:
        sta PPU_VRAM_IO
        dex
        bne loop
    rts
.endproc

.segment "CODE"
irq:
	rti

.segment "CODE"
.proc nmi
    ;save registers
    pha
    txa
    pha
    tya
    pha

    bit PPU_STATUS
	; transfer sprite OAM data using DMA
	lda #>oam
	sta SPRITE_DMA

	; transfer current palette to PPU
	vram_set_address $3F00
	ldx #0 ; transfer the 32 bytes to VRAM
@loop:
	lda palette, x
	sta PPU_VRAM_IO
	inx
	cpx #32
	bcc @loop

	; write current scroll and control settings
	lda #0
	sta PPU_VRAM_ADDRESS1
	sta PPU_VRAM_ADDRESS1
	lda ppu_ctl0
	sta PPU_CONTROL
	lda ppu_ctl1
	sta PPU_MASK

	; flag PPU update complete
	ldx #0
	stx nmi_ready

	; restore registers and return
	pla
	tay
	pla
	tax
	pla
	rti
.endproc

.segment "CODE"
.proc main
    ldx #0
palette_loop:
    lda default_palette, x
    sta palette, x
    inx
    cpx #32
    bcc palette_loop

    jsr ppu_off

    jsr clear_nametable
    
    vram_set_address (NAME_TABLE_0_ADDRESS)
    assign_16i paddr, welcome_txt
    ldy #0
loop:
	lda (paddr),y
	sta PPU_VRAM_IO
	iny
	cpy #32
	bne loop

    jsr ppu_update
    rts
.endproc

;*****************************************************************
; Our default palette table 16 entries for tiles and 16 entries for sprites
;*****************************************************************

.segment "RODATA"
default_palette:
.byte $0F,$15,$26,$37 ; bg0 purple/pink
.byte $0F,$09,$19,$29 ; bg1 green
.byte $0F,$01,$11,$21 ; bg2 blue
.byte $0F,$00,$10,$30 ; bg3 greyscale
.byte $0F,$18,$28,$38 ; sp0 yellow
.byte $0F,$14,$24,$34 ; sp1 purple
.byte $0F,$1B,$2B,$3B ; sp2 teal
.byte $0F,$12,$22,$32 ; sp3 marine


welcome_txt:
.byte 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0




;TODO:
; - definitions in apparte file zetten
; - macros in aparte file zetten
; - etc.