;****************************************************************
;MAZE SOLVER
;****************************************************************
.proc left_hand_rule
    ;---------------------------------------------------------------------------------------------------------------------------
    ;WHEN SOLVING, UPDATE PLAYER MOVEMENT OUTSIDE OF INPUT FROM PLAYER (WE SHOULD DISABLE THE PLAYER_UPDATE IN THIS MODE)
    ;---------------------------------------------------------------------------------------------------------------------------

    ;----------------------------------------------------------
    ;DRAW CELL
    ;----------------------------------------------------------
    add_to_changed_tiles_buffer player_row, player_collumn, #2 

    ;----------------------------------------------------------
    ;MAKE SURE LOCAL DIRECTION IS WITHIN RANGE 0-3
    ;----------------------------------------------------------
    lda solving_local_direction
    cmp #$FF        ; Check if A went below 0 (will become $FF due to underflow)
    bne SkipWrap    ; If not $FF, skip wrapping
    lda #$03        ; Wrap around to 3 if A is $FF
    sta solving_local_direction

    SkipWrap:
    ;solver_local_direction now contains a value between 0-3

    ;---------------------------------------------------------
    ;LOAD LOCAL DIRECTION OF TILE
    ;---------------------------------------------------------
    sta solving_local_direction ; direction is TOP
    cmp #TOP_D
    beq DIRECTION_IS_TOP
    cmp #BOTTOM_D
    beq dir_is_bottom_intermediate
    cmp #RIGHT_D
    beq dir_is_right_intermediate
    cmp #LEFT_D
    beq dir_is_left_intermediate

    dir_is_right_intermediate :
        jmp DIRECTION_IS_RIGHT ;intermediate jump cause of range error
    dir_is_left_intermediate :
        jmp DIRECTION_IS_LEFT ;intermediate jump cause of range error
    dir_is_bottom_intermediate : 
        jmp DIRECTION_IS_BOTTOM ; intermediate jump cause of range error

        
    ;**********************
    ;MAIN ALGORITHM START
    ;**********************
    DIRECTION_IS_TOP: 
    ;---------------------------------------
    ;CHECK LEFT TILE
    ;---------------------------------------
        lda player_collumn
        sec 
        sbc #1 ;tile to the left is current collumn - 1
        sta temp_player_collumn

        get_map_tile_state player_row, temp_player_collumn ; a register now holds passable (!0) or non passable (0)

        bne :+                           ; Branch to the intermediate jump if Z flag is not set
        jmp AFTER_BRANCH4            ; If Z flag is set, skip the jump and continue here
        :
        jmp LEFT_TILE_IS_PASSABLE_REL_TOP
        AFTER_BRANCH4:
        ;-------------------------------------------------------
        ;LEFT TILE NOT PASSABLE, CHECK IF WE CAN MOVE FORWARDS
        ;------------------------------------------------------
            lda player_row
            sec 
            sbc #1 ;tile to the top is row - 1
            sta temp_player_row; rotate local direction to the left
            get_map_tile_state temp_player_row, player_collumn ; a register now holds passable (!0) or non passable (0)

            bne FORWARDS_TOP_PASSABLE
            ;---------------------------------------------------------------
            ;MOVING FORWARDS NOT POSSIBLE, SO WE CHECK IF RIGHT IS POSSIBLE
            ;---------------------------------------------------------------
            moving_forward_not_possible_row: 
                lda player_collumn
                clc
                adc #1 ;tile to the right is collumn + 1
                sta temp_player_collumn; 
                get_map_tile_state player_row, temp_player_collumn ; a register now holds passable (!0) or non passable (0)

                bne RIGHT_TOP_PASSABLE
                    moving_right_not_possible: 
                    ;---------------------------------
                    ;RIGHT NOT POSSIBLE, SO WE ROTATE
                    ;---------------------------------
                    dec solving_local_direction
                    rts

                RIGHT_TOP_PASSABLE:
                    ;--------------------------------
                    ;RIGHT POSSIBLE, SO MOVE RIGHT
                    ;--------------------------------
                    LDA player_collumn        ; Load the value of player_collumn
                    CMP #31                   ; Compare player_collumn with 31
                    BEQ SkipMoveRight         ; If it's 31, skip the increment

                    INC player_collumn        ; Increment player_collumn (move right)
                    LDA #RIGHT_D              ; Update the local direction to RIGHT
                    STA solving_local_direction
                    RTS                        ; Return from subroutine

                SkipMoveRight:
                ; MOVING RIGHT IS NOT POSSIBLE
                    jmp moving_right_not_possible
                     

            FORWARDS_TOP_PASSABLE: 
            ;----------------------------------------------
            ;MOVING FORWARDS IS POSSIBLE, SO WE DO
            ;----------------------------------------------

                
                LDA player_row            ; Load the value of player_row
                BEQ SkipMoveForwardRow        ; If player_row is 0, skip the decrement

                DEC player_row            ; Decrement player_row (move forward)
                LDA #TOP_D                 ; Update the local direction to TOP
                STA solving_local_direction
                RTS                        ; Return from subroutine

                SkipMoveForwardRow:
                ; MOVING FORWARD NOT POSSIBLE
                jmp moving_forward_not_possible_row

        LEFT_TILE_IS_PASSABLE_REL_TOP: 
        ;----------------------------------------------
        ;LEFT TILE IS PASSABLE, SO WE MOVE LEFT
        ;----------------------------------------------

            LDA player_collumn        ; Load the value of player_collumn
            BEQ SkipMoveLeft           ; If player_collumn is 0, skip the decrement

            DEC player_collumn        ; Decrement player_collumn (move left)
            LDA #LEFT_D                ; Update the local direction to LEFT
            STA solving_local_direction
            RTS                        ; Return from subroutine

        SkipMoveLeft:
            ;LEFT TILE IS NOT PASSABLE
            jmp AFTER_BRANCH4
    DIRECTION_IS_BOTTOM: 
    ;----------------------------------------
    ;CHECK LEFT TILE
    ;----------------------------------------

    ;relative to rasterspace it is the right tile
        lda player_collumn
        clc 
        adc #1 ;tile to the left is current collum + 1
        sta temp_player_collumn
        get_map_tile_state player_row, temp_player_collumn ;passable (non zero) non passable (0)


       
        bne :+                           ; Branch to the intermediate jump if Z flag is not set
        jmp AFTER_BRANCH3             ; If Z flag is set, skip the jump and continue here
        :
        jmp LEFT_TILE_PASSABLE_REL_BOTTOM
        AFTER_BRANCH3:
        ;-------------------------------------------------------
        ;LEFT TILE NOT PASSABLE, CHECK IF WE CAN MOVE FORWARDS
        ;------------------------------------------------------
            lda player_row
            clc 
            adc #1 ;tile to the bottom is row + 1
            sta temp_player_row; rotate local direction to the left
            get_map_tile_state temp_player_row, player_collumn ; a register now holds passable (!0) or non passable (0)

            bne FORWARDS_BOTTOM_PASSABLE
           ;---------------------------------------------------------------
            ;MOVING FORWARDS NOT POSSIBLE, SO WE CHECK IF RIGHT IS POSSIBLE
            ;---------------------------------------------------------------
            moving_forward_not_possible_row2: 
                lda player_collumn
                sec
                sbc #1 
                sta temp_player_collumn; 
                get_map_tile_state player_row, temp_player_collumn ; a register now holds passable (!0) or non passable (0)

                bne RIGHT_BOTTOM_PASSABLE
                    ;---------------------------------
                    ;RIGHT NOT POSSIBLE, SO WE ROTATE
                    ;---------------------------------
                    right_not_possible: 
                    dec solving_local_direction
                    rts

                RIGHT_BOTTOM_PASSABLE:
                    ;--------------------------------
                    ;RIGHT POSSIBLE, SO MOVE RIGHT
                    ;--------------------------------

                    LDA player_collumn        ; Load the value of player_collumn
                    BEQ SkipMoveLeft1           ; If player_collumn is 0, skip the decrement

                    DEC player_collumn        ; Decrement player_collumn (move left)
                    LDA #LEFT_D                ; Update the local direction to LEFT
                    STA solving_local_direction
                    RTS                        ; Return from subroutine

                SkipMoveLeft1:
                    ;RIGHT NOT POSSIBLE
                    jmp right_not_possible

            FORWARDS_BOTTOM_PASSABLE: 
            ;----------------------------------------------
            ;MOVING FORWARDS IS POSSIBLE, SO WE DO
            ;----------------------------------------------

            LDA player_row            ; Load the value of player_row
            CMP #29                   ; Compare player_row with 29
            BEQ SkipMoveDown        ; If player_row is 29, skip the increment

            INC player_row            ; Increment player_row (move down)
            LDA #BOTTOM_D             ; Update the local direction to BOTTOM
            STA solving_local_direction
            RTS                        ; Return from subroutine

            SkipMoveDown:
            ;MOVING FORWARDS NOT POSSIBLE
            jmp moving_forward_not_possible_row2


    LEFT_TILE_PASSABLE_REL_BOTTOM: 
    ;-----------------------------------------------
    ;LEFT TILE IS PASSABLE, SO WE MOVE THERE
    ;-----------------------------------------------
            LDA player_collumn        ; Load the value of player_collumn
            CMP #31                   ; Compare player_collumn with 31
            BEQ SkipMoveRight1         ; If it's 31, skip the increment

            INC player_collumn        ; Increment player_collumn (move right)
            LDA #RIGHT_D              ; Update the local direction to RIGHT
            STA solving_local_direction
            RTS                        ; Return from subroutine

            SkipMoveRight1:
                ;LEFT TILE NOT PASSABLE
                jmp AFTER_BRANCH3

    DIRECTION_IS_RIGHT: 
    ;if direction is right then check top tile
        lda player_row
        sec
        sbc #1
        sta temp_player_row

        get_map_tile_state temp_player_row, player_collumn ;passable (0) non passable (!0)

        bne :+                          
        jmp AFTER_BRANCH2             
        :
        jmp LEFT_TILE_PASSABLE_REL_RIGHT
        AFTER_BRANCH2:
        ;-------------------------------------------------------
        ;LEFT TILE NOT PASSABLE, CHECK IF WE CAN MOVE FORWARDS
        ;------------------------------------------------------
            lda player_collumn
            clc 
            adc #1 ;tile to the top is row - 1
            sta temp_player_collumn; rotate local direction to the left
            get_map_tile_state player_row, temp_player_collumn ; a register now holds passable (!0) or non passable (0)

            bne FORWARDS_RIGHT_PASSABLE
            moving_forward_not_possible1: 
            ;---------------------------------------------------------------
            ;MOVING FORWARDS NOT POSSIBLE, SO WE CHECK IF RIGHT IS POSSIBLE
            ;---------------------------------------------------------------
                lda player_row
                clc
                adc #1 ;tile to the right is collumn + 1
                sta temp_player_row; 
                get_map_tile_state temp_player_row, player_collumn ; a register now holds passable (!0) or non passable (0)

                bne RIGHT_RIGHT_PASSABLE
                    ;---------------------------------
                    ;RIGHT NOT POSSIBLE, SO WE ROTATE
                    ;---------------------------------
                    right_not_possible3:
                    dec solving_local_direction
                    rts

                RIGHT_RIGHT_PASSABLE:
                    ;--------------------------------
                    ;RIGHT POSSIBLE, SO MOVE RIGHT
                    ;--------------------------------
                    LDA player_row          
                    CMP #29                   
                    BEQ SkipMoveDown2          

                    INC player_row            
                    LDA #BOTTOM_D             
                    STA solving_local_direction
                    RTS                        

                SkipMoveDown2:
                    ; RIGHT NOT POSSIBLE 
                    jmp right_not_possible3

            FORWARDS_RIGHT_PASSABLE: 
            ;----------------------------------------------
            ;MOVING FORWARDS IS POSSIBLE, SO WE DO
            ;----------------------------------------------

                LDA player_collumn        ; Load the value of player_collumn
                CMP #31                   ; Compare player_collumn with 31
                BEQ SkipMoveRight2         ; If it's 31, skip the increment

                INC player_collumn        ; Increment player_collumn (move right)
                LDA #RIGHT_D              ; Update the local direction to RIGHT
                STA solving_local_direction
                RTS                        ; Return from subroutine

            SkipMoveRight2:
             ; MOVING FORWARD IS NOT POSSIBLE 
             jmp moving_forward_not_possible1

        LEFT_TILE_PASSABLE_REL_RIGHT: 
            ;---------------------------------
            ;LEFT TILE PASSABLE
            ;---------------------------------
            ;move left relative to direction (up in rasterspace)

            LDA player_row            ; Load the value of player_row
            BEQ SkipMoveForwardRow2        ; If player_row is 0, skip the decrement

            DEC player_row            ; Decrement player_row (move forward)
            LDA #TOP_D                 ; Update the local direction to TOP
            STA solving_local_direction
            RTS                        ; Return from subroutine

        SkipMoveForwardRow2:
        ; LEFT TILE NOT PASSABLE
            jmp AFTER_BRANCH2

    DIRECTION_IS_LEFT: 
    ;if direction is left then check bottom tile
        lda player_row
        clc
        adc #1
        sta temp_player_row

        get_map_tile_state temp_player_row, player_collumn ; passable(0) non passable(!0)

        bne :+                          
        jmp AFTER_BRANCH             
        :
        jmp LEFT_TILE_PASSABLE_REL_LEFT 
        AFTER_BRANCH:
        ;-------------------------------------------------------
        ;LEFT TILE NOT PASSABLE, CHECK IF WE CAN MOVE FORWARDS
        ;------------------------------------------------------
            lda player_collumn
            sec 
            sbc #1 ;tile to the top is col - 1
            sta temp_player_collumn; rotate local direction to the left
            get_map_tile_state player_row, temp_player_collumn ; a register now holds passable (!0) or non passable (0)

            bne FORWARDS_LEFT_PASSABLE
            moving_forward_not_possible:
            ;---------------------------------------------------------------
            ;MOVING FORWARDS NOT POSSIBLE, SO WE CHECK IF RIGHT IS POSSIBLE
            ;---------------------------------------------------------------
                lda player_row
                sec
                sbc #1 
                sta temp_player_row; 
                get_map_tile_state temp_player_row, player_collumn ; a register now holds passable (!0) or non passable (0)

                bne RIGHT_LEFT_PASSABLE
                    ;---------------------------------
                    ;RIGHT NOT POSSIBLE, SO WE ROTATE
                    ;---------------------------------
                    right_not_possible2:
                    dec solving_local_direction
                    rts

                RIGHT_LEFT_PASSABLE:
                    ;--------------------------------
                    ;RIGHT POSSIBLE, SO MOVE RIGHT
                    ;--------------------------------
                    
                    LDA player_row            ; Load the value of player_row
                    BEQ SkipMoveForwardRow3        ; If player_row is 0, skip the decrement

                    DEC player_row            ; Decrement player_row (move forward)
                    LDA #TOP_D                 ; Update the local direction to TOP
                    STA solving_local_direction
                    RTS                        ; Return from subroutine

                    SkipMoveForwardRow3:
                    ;RIGHT NOT POSSIBLE
                    jmp right_not_possible2
            FORWARDS_LEFT_PASSABLE: 
            ;----------------------------------------------
            ;MOVING FORWARDS IS POSSIBLE, SO WE DO
            ;----------------------------------------------

                LDA player_collumn        ; Load the value of player_collumn
                BEQ SkipMoveLeft2           ; If player_collumn is 0, skip the decrement

                DEC player_collumn        ; Decrement player_collumn (move left)
                LDA #LEFT_D                ; Update the local direction to LEFT
                STA solving_local_direction
                RTS                        ; Return from subroutine

        SkipMoveLeft2:
                ;MOVING FORWARDS NOT POSSIBLE
                jmp moving_forward_not_possible

        LEFT_TILE_PASSABLE_REL_LEFT:
            ;--------------------------- 
            ;LEFT TILE PASSABLE
            ;----------------------------
            ;move left relative to direction (bottom in rasterspace)
            LDA player_row            ; Load the value of player_row
            CMP #29                   ; Compare player_row with 29
            BEQ SkipMoveDown3          ; If player_row is 29, skip the increment

            INC player_row            
            LDA #BOTTOM_D             
            STA solving_local_direction
            RTS                        ;

            SkipMoveDown3:
            ; LEFT TILE NOT PASSABLE
            jmp AFTER_BRANCH




.endproc
