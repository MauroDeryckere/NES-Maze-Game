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
;Column: 0123 4567  89...
; Row 0: 0000 0000  0000 0000   0000 0000   0000 0000   0000 0000
; Row 1: 0000 0000  0000 0000   0000 0000   0000 0000   0000 0000
;...

;util macro to calculate the mask and address for a given tile
;mask: the bitmask for the requested row and column
;e.g row 0, column 1 == 0100 0000
;address: the address in the buffer for the requested row and column
;e.g row 2, column 1 == $00 + $4 == $04
.macro calculate_tile_address_and_mask Row, Column
    ;Calculate the base address of the row (Row * 4)
    LDA Row
    ASL             ;== times 2
    ASL             ;== times 2
    CLC
    ADC #MAP_BUFFER_ADDRESS ; Add base address of the map buffer
    STA x_val

    ;Calculate the byte offset within the row (Column / 8)
    LDA Column
    LSR
    LSR
    LSR
    STA y_val

    ;Add the byte offset to the base row address
    LDA x_val
    CLC 
    ADC y_val
    STA temp_address
    
    ;Clamp the 0-31 Column to 0-7 
    LDA Column
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
.endmacro

;loads the state for a given tile in the Y register - 0 when not passable, or any bit is set when it is passable
;Row: Row index in the map buffer (0 to MAP_ROWS - 1)
;Column:  Column index (0 to 31, across 4 bytes per row);
.macro get_map_tile_state Row, Column
    calculate_tile_address_and_mask Row, Column

    LDY #0
    LDA (temp_address), Y   
    AND y_val
    TAY
.endmacro

;sets a tile as passable for a given cell of the map
;Row: Row index in the map buffer (0 to MAP_ROWS - 1)
;Column:  Column index (0 to 31, across 4 bytes per row);
.macro toggle_map_tile Row, Column
    calculate_tile_address_and_mask Row, Column
    
    LDY #0
    LDA (temp_address), Y   
    EOR y_val
    STA (temp_address), Y
.endmacro

.macro bounds_check_neighbor Direction, Row, Col
    ;Jump to the correct direction check
    LDA Direction
    CMP #TOP_N
    BEQ :+

    CMP #RIGHT_N
    BEQ :++

    CMP #BOTTOM_N
    BEQ :+++

    CMP #LEFT_N
    BEQ :++++

    JMP :+++++ ;no valid direction, invalid neighbor

    : ;top check
    ; If Row is 0 or 1, it's out of bounds
    LDA Row
    CMP #2 
    BCC :++++ ; row < 2
    JMP :+++++ 

    : ;right check
    ; If col is 31 or 30, it's out of bounds
    LDA Col
    CMP #30
    BCS :+++ ; col >= 30
    JMP :++++ 

    : ;bottom check
    ; If Row is 28 or 29, it's out of bounds
    LDA Row
    CMP #28
    BCS :++ ; row >= 28
    JMP :+++ 

    : ;left check
    ; If col is 0 or 1, it's out of bounds
    LDA Col
    CMP #2 
    BCC :+ ; col < 2
    JMP :++ 

    : ;out of bounds
    LDA #$0 ;0 indicates invalid neighbor
    JMP :++

    : ;in bounds
    LDA #$1 ;1 indicates valid neighbor 

    : ;end
.endmacro

;returns the value of the neighbor, Row and Column of the neighbor in X and Y register (useful to add to frontier afterwards)
;when there is no neighbor, the decimal flag is set | decimal flag is cleared at the start of this macro!
;Direction: The direction of the neighbor we are polling (0-3, defines are stored in the header for this)
;Row: Row index in the map buffer (0 to MAP_ROWS - 1)
;Column:  Column index (0 to 31, across 4 bytes per row);
.macro access_map_neighbor Direction, Row, Column
    CLD
    
    bounds_check_neighbor Direction, Row, Column

    STA x_val

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
    BNE :+      ;remove from page 0? (Q1)

        ; Calculate the address of the last item in the list
        LDA frontier_listQ1_size

        TAX
        DEX         ;decrease size
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
        JMP :++++     ;jump to end

    :
    CMP #1
    BNE :+      ;remove from page 1? (Q2)

        ; Calculate the address of the last item in the list
        LDA frontier_listQ2_size

        TAX
        DEX         ;decrease size
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
        JMP :+++     ;jump to end

    :
    CMP #2
    BNE :+      ;remove from page 2? (Q3)

        ; Calculate the address of the last item in the list
        LDA frontier_listQ3_size

        TAX
        DEX         ;decrease size
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
        JMP :++     ;jump to end

    :
    CMP #3
    BNE :+      ;remove from page 3? (Q4)

        ; Calculate the address of the last item in the list
        LDA frontier_listQ4_size

        TAX
        DEX         ;decrease size
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
    ;multiply current size of Q1 by 2, 2 bytes required per element in list
    LDA frontier_listQ1_size
    ASL

    CMP #%11111110      ;check if it should be added to Q1 or not
    BEQ :+

        ; Calculate the new address
        CLC 
        ADC #<FRONTIER_LISTQ1       ; Add the low byte of FRONTIER_LIST_ADDRESS with the current size of this segment.
        STA paddr             ; Store the low byte of the calculated address.

        LDA #>FRONTIER_LISTQ1      ; Load the high byte of FRONTIER_LIST_ADDRESS.
        ADC #$00              ; Add carry if crossing a page boundary.
        STA paddr+1           ; Store the high byte of the calculated address.

        ;=> address of next item in list is now stored in paddr

        ; Store the values into the calculated address
        LDA byteID
        LDY #$0             
        STA (paddr),Y

        LDA bitID
        LDY #$1
        STA (paddr),Y

        INC frontier_listQ1_size 
        JMP :++++                   ;jump to end

    :
    ;multiply current size of Q2 by 2, 2 bytes required per element in list
    LDA frontier_listQ2_size
    ASL

    CMP #%11111110      ;check if it should be added to Q2 or not
    BEQ :+

        ; Calculate the new address
        CLC 
        ADC #<FRONTIER_LISTQ2    ; Add the low byte of FRONTIER_LIST_ADDRESS with the current size of this segment.
        STA paddr             ; Store the low byte of the calculated address.

        LDA #>FRONTIER_LISTQ2      ; Load the high byte of FRONTIER_LIST_ADDRESS.
        ADC #$00              ; Add carry if crossing a page boundary.
        STA paddr+1           ; Store the high byte of the calculated address.

        ;=> address of next item in list is now stored in paddr

        ; Store the values into the calculated address
        LDA byteID
        LDY #0
        STA (paddr),Y 

        LDA bitID
        LDY #$1
        STA (paddr),Y

        INC frontier_listQ2_size
        JMP :+++                   ;jump to end

    :
    ;multiply current size of Q3 by 2, 2 bytes required per element in list
    LDA frontier_listQ3_size
    ASL

    CMP #%11111110      ;check if it should be added to Q3 or not
    BEQ :+

        ; Calculate the new address
        CLC 
        ADC #<FRONTIER_LISTQ3    ; Add the low byte of FRONTIER_LIST_ADDRESS with the current size of this segment.
        STA paddr             ; Store the low byte of the calculated address.

        LDA #>FRONTIER_LISTQ3      ; Load the high byte of FRONTIER_LIST_ADDRESS.
        ADC #$00              ; Add carry if crossing a page boundary.
        STA paddr+1           ; Store the high byte of the calculated address.

        ;=> address of next item in list is now stored in paddr

        ; Store the values into the calculated address
        LDA byteID
        LDY #0
        STA (paddr),Y 

        LDA bitID
        LDY #$1
        STA (paddr),Y

        INC frontier_listQ3_size
        JMP :++                   ;jump to end

    :
    ;multiply current size of Q4 by 2, 2 bytes required per element in list
    LDA frontier_listQ4_size
    ASL

    CMP #%11111110      ;check if it should be added to Q4 or not
    BEQ :+

        ; Calculate the new address
        CLC 
        ADC #<FRONTIER_LISTQ4   ; Add the low byte of FRONTIER_LIST_ADDRESS with the current size of this segment.
        STA paddr             ; Store the low byte of the calculated address.

        LDA #>FRONTIER_LISTQ4      ; Load the high byte of FRONTIER_LIST_ADDRESS.
        ADC #$00              ; Add carry if crossing a page boundary.
        STA paddr+1           ; Store the high byte of the calculated address.

        ;=> address of next item in list is now stored in paddr

        ; Store the values into the calculated address
        LDA byteID
        LDY #0
        STA (paddr),Y 

        LDA bitID
        LDY #$1
        STA (paddr),Y

        INC frontier_listQ4_size
        JMP :+                   ;jump to end
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