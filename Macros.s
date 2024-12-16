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

; Vblank buffer contains the row and column of the tile on the background
; Only tiles from the first 4 rows (0-3) and first 8 cols (0-7) can currently be set using this macro.
; Internal info:
; F: flag bit - not in use currently other than to check if it is an invalid or valid IDX in the buffer
; T: tile bit
; R: background row bit
; C: background col bit
; Row: FTTR RRRR
; Col: TTTC CCCC
;*****************************************************************
.macro add_to_changed_tiles_buffer Row, Col, TileID
    LDY #0
    .local loop
    loop:

        LDA changed_tiles_buffer, y
        CMP #$FF
        BEQ add_vals
        
        INY
        INY

        CPY #CHANGED_TILES_BUFFER_SIZE - 2
        BNE loop

    .local add_vals
    add_vals:
        LDA TileID

        ;convert tileID to row
        ;divide by 16 to get the row (16 tiles per row in sheet)
        ; (0011 1111) -> (0000 0011)
        ; LSR
        ; LSR
        ; LSR
        ; LSR
        
        ; ;shift to the correct location
        ; ; 0000 0011 -> 0110 0000
        ; ASL			
        ; ASL			
        ; ASL				
        ; ASL	
        ; ASL	

        ;but the optimised version allows us to just mask and shift once
        AND #%11111000
        ASL	

        ORA Row
        STA changed_tiles_buffer, y
        INY

        ;convert tileID to Column
        LDA TileID
        AND #%00000111
        ; shift to the correct location
        ; 0000 0111 -> 1110 0000
        ASL			
        ASL			
        ASL			
        ASL	
        ASL

        ORA Col
        STA changed_tiles_buffer, y
.endmacro
;*****************************************************************

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
;offset: the offset in the buffer for the requested row and colum
;e.g row 2, column 1 == $00 + $4 == $04
.macro calculate_tile_offset_and_mask Row, Column
    ;Calculate the base address of the row (Row * 4)
    LDA Row
    ASL             ;== times 2
    ASL             ;== times 2
    STA x_val

    ;Calculate the byte offset within the row (Column / 8)
    LDA Column
    LSR
    LSR
    LSR

    ;Add the byte offset to the base row address
    CLC
    ADC x_val
    STA temp_address
    
    ; bitmask: 
    ;Clamp the 0-31 Column to 0-7 
    LDA Column
    AND #%00000111

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

;loads the state for a given tile in the A register - 0 when not passable, or any bit is set when it is passable
;Row: Row index in the map buffer (0 to MAP_ROWS - 1)
;Column:  Column index (0 to 31, across 4 bytes per row);
.macro get_map_tile_state Row, Column
    calculate_tile_offset_and_mask Row, Column

    LDY temp_address
    LDA maze_buffer, Y   
    AND y_val
.endmacro

;sets the state for a given cell of the map to passage (1)
;Row: Row index in the map buffer (0 to MAP_ROWS - 1)
;Column:  Column index (0 to 31, across 4 bytes per row);
.macro set_map_tile Row, Column
    calculate_tile_offset_and_mask Row, Column
    
    LDY temp_address
    LDA maze_buffer, Y   
    ORA y_val
    STA maze_buffer, Y
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

; stores the new row and col in Y and X reg
.macro calculate_neighbor_position Direction, Row, Col
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

    ;top
    : 
    LDA Row
    SEC
    SBC #2
    TAY
    LDX Col
    JMP :++++

    ;right
    :
    LDA Col
    CLC
    ADC #2
    TAX
    LDY Row
    JMP :+++

    ;bottom
    :
    LDA Row
    CLC
    ADC #2
    TAY
    LDX Col
    JMP :++

    ;left
    :
    LDA Col
    SEC
    SBC #2
    TAX
    LDY Row

    ;end
    :
.endmacro

;When there is no valid neighbor, the A register will be set to 255, when there is a valid neighbor it will be set to 0 or 1; 0 when its a wall, 1 when its a passable tiles.
;Row (Y) and Column (X) of the neighbor in Y and X register (useful to add to frontier afterwards) note: these are not set when there is not a valid neighbor; check this first! 
;Direction: The direction of the neighbor we are polling (0-3, defines are stored in the header for this)
;Row: Row index in the map buffer (0 to MAP_ROWS - 1)
;Column: Column index (0 to 31, across 4 bytes per row)
.macro access_map_neighbor Direction, Row, Column
    bounds_check_neighbor Direction, Row, Column
    ;Check if A is valid (1)
    BNE :+ ;else return   
        JMP set_invalid
    :
    ;calculate the neighbors row and col
    calculate_neighbor_position Direction, Row, Column ;returns row in y and col in x register

    ;store before getting state of neighbor
    STX a_val ;col 
    STY b_val ;row

    ;store the new row and col on the stack
    TXA
    PHA
    TYA
    PHA 
        
    get_map_tile_state b_val, a_val
    BNE passable ;if the neighbor is not a wall (wall == 0) it is passable 
    
        ;wall neighbor
        ;restore the neighbors row and col
        PLA
        TAY
        PLA
        TAX

        LDA #0 ;the neighbor is a wall
        JMP return

    .local set_invalid
    set_invalid:
        LDA #%11111111 ;invalid -> max val
        JMP return

    ;in the case of no wall we still have to restore the stack
    .local passable
    passable:
        ;restore the neighbors row and col
        PLA
        TAY
        PLA
        TAX

        LDA #1

    .local return
    return:

.endmacro

    ;*****************************************************************
    ; Map buffer - visited list 
    ; same macros as maze buffer but not in zero page. read maze buffer documentation for info
    ;*****************************************************************
    .macro calculate_offset_and_mask_visited Row, Column
        ;Calculate the base address of the row (Row * 4)
        LDA Row
        ASL             ;== times 2
        ASL             ;== times 2
        STA x_val

        ;Calculate the byte offset within the row (Column / 8)
        LDA Column
        LSR
        LSR
        LSR

        ;Add the byte offset to the base row address
        CLC 
        ADC x_val
        STA temp_address ; == byte offset
        
        ; bitmask: 
        ;Clamp the 0-31 Column to 0-7 
        LDA Column
        AND #%00000111

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

    .macro set_visited Row, Col
        calculate_offset_and_mask_visited Row, Col
        
        LDY temp_address
        LDA VISISTED_ADDRESS, Y   
        ORA y_val
        STA VISISTED_ADDRESS, Y

    .endmacro

    .macro is_visited Row, Col
        calculate_offset_and_mask_visited Row, Col
        
        LDY temp_address
        LDA VISISTED_ADDRESS, Y   
        AND y_val

    .endmacro

    ;*****************************************************************

    ;*****************************************************************
    ; Map buffer - directions
    ; same macros as maze buffer but not in zero page
    ; additonally there are 2 bits per tile, direction 0-3
    ;*****************************************************************
    ; stores offset in temp address
    .macro calculate_offset_directions Row, Column
        ;Calculate the base address of the row (Row * 8)
        LDA Row
        ASL             ;== times 2
        ASL             ;== times 4
        ASL             ;== times 8
        STA x_val

        ;Calculate the byte offset within the row (Column / 4)
        LDA Column
        LSR
        LSR

        ;Add the byte offset to the base row address
        CLC 
        ADC x_val
        STA temp_address ; == byte offset
    .endmacro
    
    .macro set_direction Row, Col, Direction
        calculate_offset_directions Row, Col
        
        LDA Col
        AND #%00000011
        STA x_val

        LDA Direction
        TAY

        LDA #3
        SEC
        SBC x_val
        BEQ :++
        TAX

        ; shift direction to correct position in byte
        LDA Direction
        :
        ASL
        ASL
        DEX
        BNE :-
        
        TAY
        :

        TYA
        TAX

        LDY temp_address
        LDA DIRECTIONS_ADDRESS, Y   
        STX temp_address
        ORA temp_address
        STA DIRECTIONS_ADDRESS, Y
    .endmacro

    ; loads direction in A register
    .macro get_direction Row, Col
        calculate_offset_directions Row, Col

        LDY temp_address
        LDA DIRECTIONS_ADDRESS, Y 
        TAY

        ; direction from E.g 11 xx xx xx -> 00 00 00 11
        ; this ensure direction is in the 0-3 range when returning

        ; clamp col
        LDA Col
        AND #%00000011
        STA x_val

        ; how many times should we shift (3 - col)
        LDA #3
        SEC
        SBC x_val
        BEQ :++
        TAX

        TYA
        :
        LSR
        LSR
        DEX
        BNE :-
        TAY

        :
        TYA
        ; final result could still contain other direction bits we only want bit 0 and 1
        AND #%00000011
    .endmacro

    ;*****************************************************************

;*****************************************************************

;*****************************************************************
; Frontier list macros
;*****************************************************************
; offset 0-127
;loads the row in the X register, col in the Y register
.macro access_Frontier offset
    ; Calculate the address of the item in the list
    LDA offset
    ASL

    TAX

    ;row
    LDA FRONTIER_LISTQ1, X
    TAY
    INX

    ;col
    LDA FRONTIER_LISTQ1, X
    TAX

.endmacro

;returns whether or not the row and col pair exist in the frontier list in the X register (1 found, 0 not found)
.macro exists_in_Frontier Row, Col
    LDX #0
    STX temp

    .local loop_p0
    loop_p0:        
        LDX temp
        CPX frontier_listQ1_size
        BNE :+
            LDX #0
            STX temp
            JMP return_not_found
        :
        
        access_Frontier temp
        INC temp
        
        CPY Row
        BEQ :+
            JMP loop_p0
        :
        CPX Col
        BEQ :+
            JMP loop_p0
        :

        JMP return_found

    .local return_not_found
    return_not_found:
        LDX #0
        JMP n

    .local return_found
    return_found:
        LDX #1
        JMP n

    .local n
    n: 
.endmacro

; offset 0-127
; basically uses the "swap and pop" technique of a vector in C++
.macro remove_from_Frontier offset
    ; Calculate the address of the last item in the list
    LDA frontier_listQ1_size

    TAX
    DEX ;decrease size by 1 before multiplying (otherwise we will go out of bounds since size 1 == index 0 )
    TXA

    ASL
    TAX ;calculated address offset for last item in X

    LDA FRONTIER_LISTQ1, X ; store last items in temp values
    STA a_val

    INX
    LDA FRONTIER_LISTQ1, X ; store last items in temp values
    STA b_val

    ; Calculate the address to be removed
    LDA offset
    ASL
    TAX

    LDA a_val
    STA FRONTIER_LISTQ1, X
    INX 
    LDA b_val
    STA FRONTIER_LISTQ1, X


    ; ; in case you want to replace the garbage at end with FF for debugging (clear values)
    ; LDA frontier_listQ1_size

    ; TAX
    ; DEX ;decrease size by 1 before multiplying (otherwise we will go out of bounds since size 1 == index 0 )
    ; TXA

    ; ASL
    ; TAX ;calculated address offset for last item in X

    ; LDA #$FF
    ; STA FRONTIER_LISTQ1, X 
    ; INX
    ; LDA #$FF
    ; STA FRONTIER_LISTQ1, X


    DEC frontier_listQ1_size
.endmacro

;Defintion of row and col can be found in the map buffer section.
.macro add_to_Frontier Row, Col
    ;multiply current size of Q1 by 2, 2 bytes required per element in list
    LDA frontier_listQ1_size
    ASL

    CMP #%11111110      ;check if it should be added to Q1 or not
    BEQ :+
        
        TAX
        LDA Row
        STA FRONTIER_LISTQ1, X
        INX
        LDA Col
        STA FRONTIER_LISTQ1, X

        INC frontier_listQ1_size   
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
    BCS :-

.endmacro

;stores a random offset into b_val, then calls access_frontier on that tile
.macro get_random_frontier_tile
    ;random number for offset
    JSR random_number_generator

    ;clamp the offset
    modulo random_seed, frontier_listQ1_size
    STA b_val

    access_Frontier b_val
.endmacro


.macro multiply10 value
    LDA value
    CLC
    ROL ;x2
    TAX
    ROL ;x2
    ROL ;x2 = x8
    STA a_val
    TXA
    ADC a_val
.endmacro

;remainder currently not stored but can be stored if necessaery (check comment - done label) quotient in A
.macro divide10 value
        ;with help from chatGPT
        LDY #0          ; Initialize Y (Quotient) to 0

        LDA #9
        CLC
        CMP value       ; Check if smaller than 10
        BCS SkipDivide

        LDA value
        SEC             ; Set carry for subtraction
    .local DivideLoop
    DivideLoop:
        SBC #10         ; Subtract 10 from A
        BCC FinishLoop        ; If result is negative, exit loop
        INY             ; Increment Y (Quotient)
        JMP DivideLoop  ; Repeat the loop

    .local SkipDivide
    SkipDivide:
        LDA value
        JMP Done
    .local FinishLoop
    FinishLoop:
        ADC #10
    .local Done
    Done:
        ;TAX   ; Store the remainder (A)
        TYA     ; Store the quotient (Y)

.endmacro
