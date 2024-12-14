;*****************************************************************
; Maze Utility functions
;*****************************************************************
.segment "CODE"
.proc clear_maze
    LDY #0

    loop: 
    LDA #$0
    STA maze_buffer, Y

    INY
    CPY #120
    BNE loop
    
    RTS
.endproc

;subroutine to add a cell to the frontierlist after accessing the neighbor and checking if it is valid
.segment "CODE"
.proc add_cell
    STX x_val
    STY y_val
    
    add_to_Frontier y_val, x_val
    add_to_changed_tiles_buffer y_val, x_val, #3

    RTS
.endproc  
;*****************************************************************

;*****************************************************************
; Simple Random number generation
;*****************************************************************
.segment "CODE"
.proc random_number_generator
    RNG:
        LDA RandomSeed  ; Load the current seed
        set_Carry_to_highest_bit_A ;to make sure the rotation happens properly (makes odd numbers possible)
        ROL             ; Shift left
        BCC NoXor       ; Branch if no carry
        EOR #$B4        ; XOR with a feedback value (tweak as needed)

    NoXor:
        STA RandomSeed  ; Store the new seed
        RTS             ; Return

.endproc
;*****************************************************************