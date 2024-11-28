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

;*****************************************************************
; Map buffer macros
;*****************************************************************
;Example: 
;   BitID: 0123 4567  89...
;ByteID 0: 0000 0000  0000 0000   0000 0000   0000 0000   0000 0000
;ByteID 1: 0000 0000  0000 0000   0000 0000   0000 0000   0000 0000
;...

;sets a tile as passable for a given cell of the map
;byteID: Row index in the map buffer (0 to MAP_ROWS - 1)
;bitID:  Column index (0 to 31, across 4 bytes per row);
.macro set_map_tile_passable byteID, bitID
    ;Calculate the base address of the row (byteID * 4)
    LDA byteID
    ASL
    ASL
    CLC
    ADC #MAP_BUFFER_ADDRESS ; Add base address of the map buffer
    STA x_val

    ;Calculate the byte offset within the row (bitID / 8)
    LDA bitID
    LSR
    LSR
    LSR
    STA y_val

    ;Add the byte offset to the base row address
    LDA x_val
    CLC 
    ADC y_val
    STA temp_address
    
    ;Clamp the 0-31 bitID to 0-7 
    LDA bitID
    : ;Loop
    CMP #$08       ; Compare the number with 8 (i.e., check if it's greater than 7)
    BCC :+       ; If the number is less than or equal to 7, branch to Done
    SEC            ; Set the Carry flag before subtraction (since we're subtracting)
    SBC #$08       ; Subtract 8 from the number
    JMP :-

    : ;end clamp loop
    STA x_val

    LDA #%00000001
    STA y_val

    ;Calculate how many times we should shift
    LDA #7
    SEC
    SBC x_val    
    BEQ :++
    TAX
    
    LDA y_val
    :    
    ASL
    DEX
    BNE :-

    STA y_val
    :

    LDY #0
    LDA (temp_address), Y
    ORA y_val
    STA (temp_address), Y
.endmacro

;returns the value of the neighbor, byteID and bitID of the neighbor in X and Y register (useful to add to frontier afterwards)
;when there is no neighbor, the decimal flag is set | decimal flag is cleared at the start of this macro!
;byteID: Row index in the map buffer (0 to MAP_ROWS - 1)
;bitID:  Column index (0 to 31, across 4 bytes per row);
.macro access_map_neighbor byteID, bitID
.endmacro
;*****************************************************************

;*****************************************************************
; Frontier list macros
;*****************************************************************
;page 0 - 3 | offset 0-127
;loads the byte in the X register, bit in the Y register
.macro access_Frontier page, offset
    LDA page
    CMP #0
    BNE :+

    ; Calculate the address of the item in the list
    LDA offset
    ASL

    CLC 
    ADC #<FRONTIER_LISTQ1       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA paddr             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ1      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA paddr+1  

    ;Load the value from the pointer into X and Y
    LDY #0
    LDA (paddr),Y
    TAX         
    INY                    
    LDA (paddr),Y    
    TAY                   

    JMP :++++

    :
    CMP #1
    BNE :+

    ; Calculate the address of the item in the list
    LDA offset
    ASL

    CLC 
    ADC #<FRONTIER_LISTQ2       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA paddr             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ2      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA paddr+1  

    ;Load the value from the pointer into X and Y
    LDY #0
    LDA (paddr),Y
    TAX         
    INY                    
    LDA (paddr),Y    
    TAY                   

    JMP :+++

    :
    CMP #2
    BNE :+

        ; Calculate the address of the item in the list
    LDA offset
    ASL

    CLC 
    ADC #<FRONTIER_LISTQ3       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA paddr             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ3      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA paddr+1  

    ;Load the value from the pointer into X and Y
    LDY #0
    LDA (paddr),Y
    TAX         
    INY                    
    LDA (paddr),Y    
    TAY                   

    JMP :++

    :
    CMP #3
    BNE :+

        ; Calculate the address of the item in the list
    LDA offset
    ASL

    CLC 
    ADC #<FRONTIER_LISTQ4       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA paddr             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ4      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA paddr+1  

    ;Load the value from the pointer into X and Y
    LDY #0
    LDA (paddr),Y
    TAX         
    INY                    
    LDA (paddr),Y    
    TAY                   
    :

.endmacro

;page 0 - 3 | offset 0-127
.macro remove_from_Frontier page, offset
    LDA page
    CMP #0
    BNE :+

    ; Calculate the address of the last item in the list
    LDA frontier_listQ1_size

    TAX
    DEX
    TXA

    ASL

    CLC 
    ADC #<FRONTIER_LISTQ1       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA tempPadrToLast             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ1      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA tempPadrToLast+1  

    ; Calculate the address to be removed
    LDA offset
    ASL

    CLC 
    ADC #<FRONTIER_LISTQ1       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA paddr             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ1      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA paddr+1  

    ;write the last values to the location to be removed
    LDY #0
    LDA (tempPadrToLast),Y
    STA (paddr),Y 

    LDY #$1
    LDA (tempPadrToLast),Y
    STA (paddr),Y

    ;clear the last values
    LDA #0
    LDY #0
    STA (tempPadrToLast),Y 

    LDA #0
    LDY #$1
    STA (tempPadrToLast),Y

    DEC frontier_listQ1_size
    JMP :++++

    :
    CMP #1
    BNE :+

    ; Calculate the address of the last item in the list
    LDA frontier_listQ2_size

    TAX
    DEX
    TXA

    ASL

    CLC 
    ADC #<FRONTIER_LISTQ2       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA tempPadrToLast             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ2      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA tempPadrToLast+1  

    ; Calculate the address to be removed
    LDA offset
    ASL

    CLC 
    ADC #<FRONTIER_LISTQ2       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA paddr             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ2      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA paddr+1  

    ;write the last values to the location to be removed
    LDY #0
    LDA (tempPadrToLast),Y
    STA (paddr),Y 

    LDY #$1
    LDA (tempPadrToLast),Y
    STA (paddr),Y

    ;clear the last values
    LDA #0
    LDY #0
    STA (tempPadrToLast),Y 

    LDA #0
    LDY #$1
    STA (tempPadrToLast),Y

    DEC frontier_listQ2_size
    JMP :+++

    :
    CMP #2
    BNE :+

    ; Calculate the address of the last item in the list
    LDA frontier_listQ3_size

    TAX
    DEX
    TXA

    ASL

    CLC 
    ADC #<FRONTIER_LISTQ3       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA tempPadrToLast             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ3      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA tempPadrToLast+1  

    ; Calculate the address to be removed
    LDA offset
    ASL

    CLC 
    ADC #<FRONTIER_LISTQ3       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA paddr             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ3      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA paddr+1  

    ;write the last values to the location to be removed
    LDY #0
    LDA (tempPadrToLast),Y
    STA (paddr),Y 

    LDY #$1
    LDA (tempPadrToLast),Y
    STA (paddr),Y

    ;clear the last values
    LDA #0
    LDY #0
    STA (tempPadrToLast),Y 

    LDA #0
    LDY #$1
    STA (tempPadrToLast),Y

    DEC frontier_listQ3_size
    JMP :++

    :
    CMP #3
    BNE :+

    ; Calculate the address of the last item in the list
    LDA frontier_listQ4_size

    TAX
    DEX
    TXA

    ASL

    CLC 
    ADC #<FRONTIER_LISTQ4       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA tempPadrToLast             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ4      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA tempPadrToLast+1  

    ; Calculate the address to be removed
    LDA offset
    ASL

    CLC 
    ADC #<FRONTIER_LISTQ4       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA paddr             ; Store the low byte of the calculated address.

    LDA #>FRONTIER_LISTQ4      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA paddr+1  

    ;write the last values to the location to be removed
    LDY #0
    LDA (tempPadrToLast),Y
    STA (paddr),Y 

    LDY #$1
    LDA (tempPadrToLast),Y
    STA (paddr),Y

    ;clear the last values
    LDA #0
    LDY #0
    STA (tempPadrToLast),Y 

    LDA #0
    LDY #$1
    STA (tempPadrToLast),Y

    DEC frontier_listQ4_size
    :
.endmacro

;Defintion of byteID and bitID can be found in the map buffer section.
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
;*****************************************************************


; result = value % modulus
; => result is stored in the A register
.macro modulo value, modulus
    LDA value
    SEC
    :
    SBC modulus
    CMP modulus
    BPL :-

.endmacro