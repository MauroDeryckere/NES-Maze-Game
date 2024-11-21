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

; MAP BUFFER DEFINES
MAP_BUFFER_SIZE = 120
MAP_BUFFER_ADDRESS = $00
MAP_COLUMNS = 32 ;32 bits
MAP_ROWS = 30 

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

maze_buffer:        .res 120

nmi_ready:		    .res 1 ; set to 1 to push a PPU frame update, 
					       ;        2 to turn rendering off next NMI
gamepad:		    .res 1 ; stores the current gamepad values

paddr:              .res 2 ; 16-bit address pointer

byte_loop_couter:   .res 1 ; counter for the bits in map transfer

should_show_map:    .res 1 ; temp var for testing 

ppu_ctl0:		    .res 1 ; PPU Control Register 2 Value

ppu_ctl1:		    .res 1 ; PPU Control Register 2 Value

a_pressed_last_frame: .res 1

.segment "OAM"
oam: .res 256	; sprite OAM data

.segment "BSS"
palette: .res 32 ; current palette buffer
