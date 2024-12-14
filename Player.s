;*****************************************************************
; Player
;*****************************************************************
;update player position with player input
.proc update_player_sprite
    ;check is delay is reached
    modulo frame_counter, #PLAYER_MOVEMENT_DELAY
    CMP #0
    BEQ :+
        RTS
    :   

    lda gamepad
    and #PAD_D
    beq NOT_GAMEPAD_DOWN 
        ;gamepad down is pressed

        ;bounds check first
        LDA player_row
        CMP #MAP_ROWS - 1
        BNE :+
            JMP NOT_GAMEPAD_DOWN
        :  

        LDA #BOTTOM
        STA player_dir 

        ;--------------------------------------------------------------
        ;COLLISION DETECTION
        ;--------------------------------------------------------------
        INC player_row
        get_map_tile_state player_row, player_collumn ;figure out which row and colom is needed
        ; a register now holds if the sprite is in a non passable area (0) or passable area (non zero)

        BEQ HitDown
            LDA player_y
            CLC 
            ADC #8 ; set position
            STA player_y
            JMP NOT_GAMEPAD_DOWN

        HitDown: 
            ;sprite collided with wall
            DEC player_row
            JMP NOT_GAMEPAD_DOWN
        

    NOT_GAMEPAD_DOWN: 
    lda gamepad
    and #PAD_U
    beq NOT_GAMEPAD_UP

        ;bounds check first
        LDA player_row
        BNE :+
            JMP NOT_GAMEPAD_UP
        :   

        LDA #TOP
        STA player_dir

        ;--------------------------------------------------------------
        ;COLLISION DETECTION
        ;--------------------------------------------------------------
        DEC player_row
        get_map_tile_state player_row, player_collumn ;figure out which row and colom is needed
        ; a register now holds if the sprite is in a non passable area (0) or passable area (non zero)

        BEQ HitUp
        LDA player_y
        SEC 
        SBC #8 ; set position
        sta player_y
        JMP NOT_GAMEPAD_UP

        HitUp: 
            ;sprite collided with wall
            INC player_row
            JMP NOT_GAMEPAD_UP

    NOT_GAMEPAD_UP: 
    lda gamepad
    and #PAD_L
    beq NOT_GAMEPAD_LEFT
        ;gamepad left is pressed

        ;bounds check first
        LDA player_collumn
        BNE :+
            JMP NOT_GAMEPAD_LEFT
        :

        LDA #LEFT
        STA player_dir

        ;--------------------------------------------------------------
        ;COLLISION DETECTION
        ;--------------------------------------------------------------
        DEC player_collumn

        get_map_tile_state player_row, player_collumn ;figure out which row and colom is needed
        ; a register now holds if the sprite is in a non passable area (0) or passable area (non zero)

        BEQ HitLeft
            LDA player_x
            SEC 
            SBC #8 ; set position
            STA player_x
            JMP NOT_GAMEPAD_LEFT


        HitLeft: 
            ;sprite collided with wall
            INC player_collumn
            JMP NOT_GAMEPAD_LEFT


    NOT_GAMEPAD_LEFT: 
    lda gamepad
    and #PAD_R
    beq NOT_GAMEPAD_RIGHT
        ;bounds check first
        LDA player_collumn
        CMP #MAP_COLUMNS - 1
        BNE :+
            JMP NOT_GAMEPAD_RIGHT
        :

        LDA #RIGHT
        STA player_dir

        ;--------------------------------------------------------------
        ;COLLISION DETECTION
        ;--------------------------------------------------------------
        INC player_collumn
        
        get_map_tile_state player_row, player_collumn ;figure out which row and colom is needed
        ; a register now holds if the sprite is in a non passable area (0) or passable area (non zero)

        BEQ HitRight
            LDA player_x
            CLC 
            ADC #8 ; set position
            STA player_x
            JMP NOT_GAMEPAD_RIGHT

        HitRight: 
            ;sprite collided with wall
            DEC player_collumn
            JMP NOT_GAMEPAD_RIGHT


    NOT_GAMEPAD_RIGHT: 
        ;neither up, down, left, or right is pressed
    RTS
.endproc
;*****************************************************************