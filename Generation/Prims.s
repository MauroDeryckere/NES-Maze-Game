;*****************************************************************
; The main algorithm loop (prims)
;*****************************************************************
.segment "CODE"
.proc start_prims_maze
    ; step 0 of the maze generation, set a random cell as passage and calculate its frontier cells
    JSR random_number_generator
    modulo random_seed, #29
    ;LDA #29
    STA a_val
    STA frontier_row
    ;STA temp
    JSR random_number_generator
    modulo random_seed, #31
    ;LDA #31
    STA b_val
    STA frontier_col
    ;STA temp


    ;set the even / uneven row and col flag
    LDA #0
    STA odd_frontiers
    
    LDA frontier_row
    CMP #0
    BEQ end_row ;when zero were even
    
    modulo frontier_row, #2
    CMP #0
    BEQ end_row
        LDA #%11110000
        STA odd_frontiers 
    end_row:

    LDA frontier_col
    CMP #0
    BEQ end_col ;when zero were even  

    modulo frontier_col, #2
    CMP #0
    BEQ end_col
        LDA odd_frontiers 
        ORA #%00001111
        STA odd_frontiers
    end_col:

    set_map_tile a_val, b_val
    add_to_changed_tiles_buffer frontier_row, frontier_col, #1

        access_map_neighbor #LEFT_N, frontier_row, frontier_col
        CMP #0 
        BNE TopN

        JSR add_cell

    TopN: ;top neighbor
        access_map_neighbor #TOP_N, frontier_row, frontier_col
        CMP #0 
        BNE RightN

        JSR add_cell

    RightN: ;right neighbor
        access_map_neighbor #RIGHT_N, frontier_row, frontier_col
        CMP #0 
        BNE BottomN

        JSR add_cell

    BottomN: ;bottom neighbor
        access_map_neighbor #BOTTOM_N, frontier_row, frontier_col
        CMP #0
        BNE End

        JSR add_cell
 
    End: ;end

   RTS
.endproc

.segment "CODE"
.proc run_prims_maze
    LDA frontier_listQ1_size ; if empty end algorithm
    BNE :+
        ;return with FF in A reg to show we are done with algorithm
        LDA #$FF
        RTS ;early return if finished
    :

    ;useful for debugging but not necessary for algorithm    
    ; LDA #%11111111
    ; STA used_direction

    ;step one of the agorithm: pick a random frontier cell of the list
    get_random_frontier_tile ;returns col and row in x and y reg respectively | page and offset are maintained in a and b val
    
    ;store row and col in zero page to use in the access function.
    STX frontier_col
    STY frontier_row

    ;store a and b val in a new value since a and b will be overwritten in the access map neighbor function
    LDA a_val
    STA frontier_page
    LDA b_val
    STA frontier_offset


    ;pick a random neighbor of the frontier cell that's in state passage
    ;start a counter for the amt of dirs we can use on temp val (since its not used in any of the macros we call during this section)
    LDA #0
    STA temp

    access_map_neighbor #TOP_N, frontier_row, frontier_col
    CMP #1 ;we want something in state passage
    BNE :+
        ;valid cell, Jump to next step
        LDA #TOP_N 
        PHA ;push direction on stack
        INC temp
    : ;right
    access_map_neighbor #RIGHT_N, frontier_row, frontier_col
    CMP #1 ;we want something in state passage
    BNE :+
        ;valid cell, Jump to next step
        LDA #RIGHT_N 
        PHA ;push direction on stack
        INC temp

    : ;bottom
    access_map_neighbor #BOTTOM_N, frontier_row, frontier_col
    CMP #1 ;we want something in state passage
    BNE :+
        ;valid cell, Jump to next step
        LDA #BOTTOM_N 
        PHA ;push direction on stack
        INC temp        
    : ;left
    access_map_neighbor #LEFT_N, frontier_row, frontier_col
    CMP #1 ;we want something in state passage
    BNE :+
        ;valid cell, Jump to next step
        LDA #LEFT_N 
        PHA ;push direction on stack
        INC temp
    
    ;pick a random direction based on the temp counter
    :
    JSR random_number_generator
    modulo random_seed, temp ;stores val in A reg
    
    ;the total amt of pulls from stack is stored in X    
    LDX temp
    ;the direction idx we want to use is stored in A
    STA temp
    dirloop: 
        PLA
        
        DEX 

        CPX temp
        BNE :+
            STA used_direction
        :

        CPX #0
        BNE dirloop

    ;calculate the cell between picked frontier and passage cell and set this to a passage 
    nextstep: 
    LDA used_direction
    CMP #TOP_N
    BNE :+
        LDA frontier_row
        STA temp_row
        DEC temp_row

        LDA frontier_col
        STA temp_col
        JMP nextnextstep

    :; right
    CMP #RIGHT_N
    BNE :+
        LDA frontier_row
        STA temp_row

        LDA frontier_col
        STA temp_col
        INC temp_col
        JMP nextnextstep

    :; bottom
    CMP #BOTTOM_N
    BNE :+
        LDA frontier_row
        STA temp_row
        INC temp_row

        LDA frontier_col
        STA temp_col
        JMP nextnextstep

    : ;left
    CMP #LEFT_N
    BNE :+
        LDA frontier_row
        STA temp_row

        LDA frontier_col
        STA temp_col
        DEC temp_col
        JMP nextnextstep
    :
    ;wont reach this label in algorithm but useful for debugging 
    

    nextnextstep: 
        JSR random_number_generator
        modulo random_seed, #02
        ADC #04
        STA temp

        set_map_tile temp_row, temp_col
        add_to_changed_tiles_buffer temp_row, temp_col, temp

    ;calculate the new frontier cells for the chosen frontier cell and add them
        access_map_neighbor #LEFT_N, frontier_row, frontier_col
        CMP #0 
        BEQ :+
            JMP TopN
        :

        ;if exists check
        STY temp_row        
        STX temp_col
        exists_in_Frontier temp_row, temp_col
        CPX #1
        BEQ TopN 

        LDY temp_row
        LDX temp_col

        JSR add_cell

    TopN: ;top neighbor
        access_map_neighbor #TOP_N, frontier_row, frontier_col
        CMP #0 
        BEQ :+
            JMP RightN
        :

        ;if exists check
        STY temp_row        
        STX temp_col
        exists_in_Frontier temp_row, temp_col
        CPX #1
        BEQ RightN 

        LDY temp_row
        LDX temp_col

        JSR add_cell

    RightN: ;right neighbor
        access_map_neighbor #RIGHT_N, frontier_row, frontier_col
        CMP #0 
        BEQ :+
            JMP BottomN
        :

        ;if exists check
        STY temp_row        
        STX temp_col
        exists_in_Frontier temp_row, temp_col
        CPX #1
        BEQ BottomN

        LDY temp_row
        LDX temp_col

        JSR add_cell

    BottomN: ;bottom neighbor
        access_map_neighbor #BOTTOM_N, frontier_row, frontier_col
        CMP #0 
        BEQ :+
            JMP end
        :

        ;if exists check
        STY temp_row        
        STX temp_col
        exists_in_Frontier temp_row, temp_col
        CPX #1
        BEQ end

        LDY temp_row
        LDX temp_col

        JSR add_cell
    end: 

    JSR random_number_generator
    modulo random_seed, #02
    ADC #04
    STA temp

    ;remove the chosen frontier cell from the list
    set_map_tile frontier_row, frontier_col
    add_to_changed_tiles_buffer frontier_row, frontier_col, temp
    remove_from_Frontier frontier_offset

    ;return with 0 in A reg to show we are not done with algorithm yet
    LDA #0

    RTS
.endproc

.proc calculate_prims_start_end
    LDA odd_frontiers
    ;are rows even
    AND %11110000

    LDA odd_frontiers      
    AND #%11110000
    CMP #%11110000 
    BEQ :+
        JMP even_rows
    :
    ;uneven row means black border at top
    rowloop_ue:
    JSR random_number_generator
    modulo random_seed, #31
    STA temp

    get_map_tile_state #1, temp
    BEQ rowloop_ue

    set_map_tile #0, temp
    add_to_changed_tiles_buffer #0, temp, #1
    LDA #0
    STA player_row
    LDA temp
    STA player_collumn

    JMP col_check

    ;even rows means black border at bottom, find a tile in row 30 with a white tile above to set as start pos
    even_rows:
        rowloop_e:
        JSR random_number_generator
        modulo random_seed, #31
        STA temp

        get_map_tile_state #28, temp
        BEQ rowloop_e

        set_map_tile #0, temp
        add_to_changed_tiles_buffer #29, temp, #1

        LDA #29
        STA player_row
        LDA temp
        STA player_collumn

    col_check: 
        LDA odd_frontiers
        ;are cols even
        AND 00001111

        LDA odd_frontiers      
        AND #%00001111
        CMP #%00001111 
        BEQ :+
            JMP even_cols
        :

        colloop_ue:
        JSR random_number_generator
        modulo random_seed, #29
        STA temp

        get_map_tile_state temp, #1
        BEQ colloop_ue

        set_map_tile temp, #0
        add_to_changed_tiles_buffer temp, #0, #1
        
        LDA temp
        STA end_row
        LDA #0
        STA end_col

        JMP end

    even_cols:
        colloop_e:
        JSR random_number_generator
        modulo random_seed, #29
        STA temp

        get_map_tile_state temp, #30
        BEQ colloop_e

        set_map_tile temp, #31
        add_to_changed_tiles_buffer temp, #31, #1

        LDA temp
        STA end_row
        LDA #31
        STA end_col

    end: 

    RTS
.endproc
;*****************************************************************