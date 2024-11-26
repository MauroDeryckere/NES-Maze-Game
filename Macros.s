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

.macro set_Carry_to_highest_bit_A
    cmp #%10000000
    bmi :+
    sec
    jmp :++
    :
    clc
    :
.endmacro

.macro add_to_Frontier byteID, bitID
LDA FRONTIER_LIST_ADDRESS
ASL

; Need to offset by 1 for the size stored at start of list
TAX
INX
INX
INX
INX
TXA

CMP #%11111010
BEQ :+

; Calculate the new address
CLC 
ADC #<FRONTIER_LIST_ADDRESS       ; Add the low byte of FRONTIER_LIST_ADDRESS.
STA paddr             ; Store the low byte of the calculated address.

LDA #>FRONTIER_LIST_ADDRESS       ; Load the high byte of FRONTIER_LIST_ADDRESS.
ADC #$00              ; Add carry if crossing a page boundary.
STA paddr+1           ; Store the high byte of the calculated address.

; Store the values into the calculated address
LDA byteID
LDY #0
STA (paddr),Y 

LDA bitID
LDY #$1
STA (paddr),Y

INC FRONTIER_LIST_ADDRESS 

JMP :++
:
LDA FRONTIER_LIST_ADDRESS+1
CMP #%01111100
BEQ :+

; Calculate the new address
CLC 
ADC #<FRONTIER_LIST_Q1    ; Add the low byte of FRONTIER_LIST_ADDRESS.
STA paddr             ; Store the low byte of the calculated address.

LDA #>FRONTIER_LIST_Q1      ; Load the high byte of FRONTIER_LIST_ADDRESS.
ADC #$00              ; Add carry if crossing a page boundary.
STA paddr+1           ; Store the high byte of the calculated address.

; Store the values into the calculated address
LDA byteID
LDY #0
STA (paddr),Y 

LDA bitID
LDY #$1
STA (paddr),Y

INC FRONTIER_LIST_ADDRESS+1

:
.endmacro