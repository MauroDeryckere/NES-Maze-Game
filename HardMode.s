;*****************************************************************
; Hard mode related code
;*****************************************************************
.segment "CODE"
.proc start_hard_mode
    add_to_changed_tiles_buffer end_row, end_col
    LDA #0
    STA should_clear_buffer
.endproc

;whenever the character moves in hard mode we should add any invible tiles to the changed tiles buffer
.proc update_visibility
    LDA should_clear_buffer
    BEQ :+
        JSR clear_changed_tiles_buffer
        JSR cleared_added_frontier_buffer
        LDA #0
        STA should_clear_buffer
    :

    add_to_changed_tiles_buffer player_row, player_collumn

    above:
        LDA player_row
        CMP #0
        BEQ below

        STA frontier_row
        DEC frontier_row

        get_map_tile_state frontier_row, player_collumn
        BEQ below
        add_to_changed_tiles_buffer frontier_row, player_collumn

    below:
        LDA player_row
        CMP #MAP_ROWS - 1
        BEQ left

        STA frontier_row
        INC frontier_row

        get_map_tile_state frontier_row, player_collumn
        BEQ left
        add_to_changed_tiles_buffer frontier_row, player_collumn
    
    left: 
        LDA player_collumn
        CMP #0
        BEQ right

        STA frontier_col
        DEC frontier_col

        get_map_tile_state player_row, frontier_col
        BEQ right
        add_to_changed_tiles_buffer player_row, frontier_col

    right: 
        LDA player_collumn
        CMP #MAP_COLUMNS - 1
        BEQ end

        STA frontier_col
        INC frontier_col

        get_map_tile_state player_row, frontier_col
        BEQ end
        add_to_changed_tiles_buffer player_row, frontier_col
    end: 

    RTS
.endproc
;*****************************************************************
