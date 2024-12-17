;*****************************************************************
; Hard mode related code
;*****************************************************************
.segment "CODE"
.proc start_hard_mode
    JSR random_number_generator
    modulo random_seed, #02
    ADC #04
    STA x_val


    add_to_changed_tiles_buffer player_row, player_collumn, x_val
    add_to_changed_tiles_buffer end_row, end_col, x_val
    LDA #0
    STA should_clear_buffer
.endproc

;whenever the character moves in hard mode we should add any invible tiles to the changed tiles buffer
.proc update_visibility
    LDA should_clear_buffer
    BEQ :+
        JSR clear_changed_tiles_buffer
        LDA #0
        STA should_clear_buffer
    :


    ; add_to_changed_tiles_buffer player_row, player_collumn

    above:
        LDA player_row
        CMP #0
        BNE :+
            JMP below
        :

        STA frontier_row
        DEC frontier_row

        ADC player_collumn
        STA temp
        modulo temp, #02
        ADC #04
        STA temp

        get_map_tile_state frontier_row, player_collumn
        BEQ a_wall
        add_to_changed_tiles_buffer frontier_row, player_collumn, temp
        JMP below
        a_wall: 
            add_to_changed_tiles_buffer frontier_row, player_collumn, #0
    below:
        LDA player_row
        CMP #MAP_ROWS - 1
        BNE :+
            JMP left
        :

        STA frontier_row
        INC frontier_row

        ADC player_collumn
        STA temp
        modulo temp, #02
        ADC #04
        STA temp

        get_map_tile_state frontier_row, player_collumn
        BEQ b_wall
        add_to_changed_tiles_buffer frontier_row, player_collumn, temp
        JMP left
        b_wall: 
            add_to_changed_tiles_buffer frontier_row, player_collumn, #0
    
    left: 
        LDA player_collumn
        CMP #0
        BNE :+
           JMP right
        :

        STA frontier_col
        DEC frontier_col

        ADC player_row
        STA temp
        modulo temp, #02
        ADC #04
        STA temp

        get_map_tile_state player_row, frontier_col
        BEQ l_wall
        add_to_changed_tiles_buffer player_row, frontier_col, temp
        JMP right
        l_wall: 
            add_to_changed_tiles_buffer player_row, frontier_col, #0

    right: 
        LDA player_collumn
        CMP #MAP_COLUMNS - 1
        BNE :+
            JMP end
        :

        STA frontier_col
        INC frontier_col

        ADC player_row
        STA temp
        modulo temp, #02
        ADC #04
        STA temp

        get_map_tile_state player_row, frontier_col
        BEQ r_wall
        add_to_changed_tiles_buffer player_row, frontier_col, temp
        JMP end
        r_wall: 
            add_to_changed_tiles_buffer player_row, frontier_col, #0
    end: 

    RTS
.endproc
;*****************************************************************
