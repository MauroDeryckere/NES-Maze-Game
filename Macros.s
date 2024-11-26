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

;page 0 - 3
.macro remove_from_Frontier page, offset

LDA page
CMP #0
BNE :+

LDA offset
ASL

; Calculate the address
CLC 
ADC #<FRONTIER_LISTQ1       ; Add the low byte of FRONTIER_LIST_ADDRESS.
STA paddr             ; Store the low byte of the calculated address.

LDA #>FRONTIER_LISTQ1      ; Load the high byte of FRONTIER_LIST_ADDRESS.
ADC #$00              ; Add carry if crossing a page boundary.
STA paddr+1  

;temporarily just clear what is on this location
LDA #0
LDY #0
STA (paddr),Y 

LDA #0
LDY #$1
STA (paddr),Y


JMP :+

:
;next page
.endmacro

.macro add_to_Frontier byteID, bitID
;multiply by 2, 2 bytes required per element in list
LDA frontier_listQ1_size
ASL

CMP #%11111110
BEQ :+

; Calculate the new address
CLC 
ADC #<FRONTIER_LISTQ1       ; Add the low byte of FRONTIER_LIST_ADDRESS.
STA paddr             ; Store the low byte of the calculated address.

LDA #>FRONTIER_LISTQ1      ; Load the high byte of FRONTIER_LIST_ADDRESS.
ADC #$00              ; Add carry if crossing a page boundary.
STA paddr+1           ; Store the high byte of the calculated address.

; Store the values into the calculated address
LDA byteID
LDY #0
STA (paddr),Y 

LDA bitID
LDY #$1
STA (paddr),Y

INC frontier_listQ1_size 
JMP :++++

:
;multiply by 2, 2 bytes required per element in list
LDA frontier_listQ2_size
ASL

CMP #%11111110
BEQ :+

; Calculate the new address
CLC 
ADC #<FRONTIER_LISTQ2    ; Add the low byte of FRONTIER_LIST_ADDRESS.
STA paddr             ; Store the low byte of the calculated address.

LDA #>FRONTIER_LISTQ2      ; Load the high byte of FRONTIER_LIST_ADDRESS.
ADC #$00              ; Add carry if crossing a page boundary.
STA paddr+1           ; Store the high byte of the calculated address.

; Store the values into the calculated address
LDA byteID
LDY #0
STA (paddr),Y 

LDA bitID
LDY #$1
STA (paddr),Y

INC frontier_listQ2_size
JMP :+++

:
;multiply by 2, 2 bytes required per element in list
LDA frontier_listQ3_size
ASL

CMP #%11111110
BEQ :+

; Calculate the new address
CLC 
ADC #<FRONTIER_LISTQ3    ; Add the low byte of FRONTIER_LIST_ADDRESS.
STA paddr             ; Store the low byte of the calculated address.

LDA #>FRONTIER_LISTQ3      ; Load the high byte of FRONTIER_LIST_ADDRESS.
ADC #$00              ; Add carry if crossing a page boundary.
STA paddr+1           ; Store the high byte of the calculated address.

; Store the values into the calculated address
LDA byteID
LDY #0
STA (paddr),Y 

LDA bitID
LDY #$1
STA (paddr),Y

INC frontier_listQ3_size
JMP :++

:
;multiply by 2, 2 bytes required per element in list
LDA frontier_listQ4_size
ASL

CMP #%11111110
BEQ :+

; Calculate the new address
CLC 
ADC #<FRONTIER_LISTQ4   ; Add the low byte of FRONTIER_LIST_ADDRESS.
STA paddr             ; Store the low byte of the calculated address.

LDA #>FRONTIER_LISTQ4      ; Load the high byte of FRONTIER_LIST_ADDRESS.
ADC #$00              ; Add carry if crossing a page boundary.
STA paddr+1           ; Store the high byte of the calculated address.

; Store the values into the calculated address
LDA byteID
LDY #0
STA (paddr),Y 

LDA bitID
LDY #$1
STA (paddr),Y

INC frontier_listQ4_size
JMP :+
:
.endmacro