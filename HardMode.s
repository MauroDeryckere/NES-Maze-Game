;*****************************************************************
; Hard mode related code
;*****************************************************************
.segment "CODE"
.proc start_hard_mode
    
.endproc

;whenever the character moves in hard mode we should add any invible tiles to the changed tiles buffer
.proc update_visibility
    ;get_map_tile_state player_row, player_collumn
    add_to_changed_tiles_buffer player_row, player_collumn
    RTS
.endproc
;*****************************************************************
