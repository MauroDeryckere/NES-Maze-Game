.include "Header.s"
.include "Macros.s"

.include "TestCode.s"
.include "Graphics.s"
.include "Util.s"

.include "HardMode.s"
.include "Score.s"

.include "BFS.s"

;*****************************************************************
; Interupts | Vblank
;*****************************************************************
.segment "CODE"
irq:
	RTI

;only caused by vblank right now
.proc nmi
    ;save registers
    PHA
    TXA
    PHA
    TYA
    PHA
    
    BIT PPU_STATUS

    ;increase our frame counter (one vblank occurs per frame)
    INC frame_counter
    LDA #0
    STA checked_this_frame

    JSR draw_background
    JSR draw_player_sprite
    ; JSR display_score

    ; transfer sprite OAM data using DMA
	LDX #0
	STX PPU_SPRRAM_ADDRESS
	LDA #>oam
	STA SPRITE_DMA

	; transfer current palette to PPU
	LDA #%10001000 ; set horizontal nametable increment
	STA PPU_CONTROL 
	LDA PPU_STATUS
	LDA #$3F ; set PPU address to $3F00
	STA PPU_VRAM_ADDRESS2
	STX PPU_VRAM_ADDRESS2
	LDX #0 ; transfer the 32 bytes to VRAM
	LDX #0 ; transfer the 32 bytes to VRAM

    @loop:
        LDA palette, x
        STA PPU_VRAM_IO
        INX
        CPX #32
        BCC @loop


    ; write current scroll and control settings
	LDA #0
	STA PPU_VRAM_ADDRESS1
	STA PPU_VRAM_ADDRESS1
	LDA ppu_ctl0
	STA PPU_CONTROL
	LDA ppu_ctl1
	STA PPU_MASK

	; flag PPU update complete
	LDX #0
	STX nmi_ready
    
	; restore registers and return
	PLA
	TAY
	PLA
	TAX
	PLA

	RTI
.endproc
;*****************************************************************

;*****************************************************************
; Main Gameloop
;*****************************************************************
.segment "CODE"
.proc main
    JSR Init

    mainloop:
        INC RandomSeed 

        ; once per frame: 
        LDA checked_this_frame
        CMP #0
        BEQ :+
            JSR poll_clear_buffer
        :
        
        ;only when not generating 
        LDA has_generation_started
        BNE :++
            ;poll input and similar
            JSR start

            ;auto generation once maze is completed (useful for debugging)
            ; LDA #1
            ; STA has_generation_started

            ;once per frame
            LDA checked_this_frame
            CMP #1
            BEQ mainloop
                JSR update_player_sprite

                LDA is_hard_mode
                CMP #0
                BEQ :+
                    JSR update_visibility
                :   

                LDA frame_counter ;sets last frame ct to the same as frame counter
                LDA #1
                STA checked_this_frame

                ;check if we reached the end
                LDA player_row
                CMP end_row
                BNE mainloop
                LDA player_collumn 
                CMP end_col
                BNE mainloop
                    LDA #1
                    STA has_generation_started

                JMP mainloop
        :

        ;only when generating
        LDA has_generation_started
        BEQ mainloop
            LDA #0
            STA has_game_started
            ;clear everything and display empty map at start of generation

            JSR clear_player_sprite

            JSR clear_maze
            JSR clear_changed_tiles_buffer
            JSR wait_frame
            JSR display_map

            JSR start_prims_maze

        LDA display_steps
        BEQ display_once

            step_by_step_generation_loop:
                JSR wait_frame ;wait until a vblank has happened

                modulo frame_counter, #MAZE_GENERATION_SPEED
                CMP #0
                BNE step_by_step_generation_loop

                JSR poll_clear_buffer
                JSR run_prims_maze
                
                LDA has_generation_started
                BEQ stop
                JMP step_by_step_generation_loop

            display_once: 
                JSR run_prims_maze
                LDA has_generation_started
                BNE display_once
                JSR display_map
                JMP stop

        stop:
            JSR calculate_prims_start_end
            JSR wait_frame

            JSR clear_changed_tiles_buffer
            LDA #0
            STA should_clear_buffer

            LDA is_hard_mode
            CMP #0
            BEQ :+
                JSR display_clear_map
                JSR start_hard_mode

            :

            LDA #1
            STA has_game_started

    JMP mainloop
.endproc
;*****************************************************************

;*****************************************************************
; Init
;*****************************************************************
.segment "CODE"
.proc Init
    LDX #0
    palette_loop:
        LDA default_palette, x  ;load palettes
        STA palette, x
        INX
        CPX #32
        BCC palette_loop

    ;clear stuff
    JSR ppu_off
    JSR clear_nametable
    JSR ppu_update

    JSR clear_changed_tiles_buffer
    JSR clear_maze
    JSR init_BFS

    ;set an initial randomseed value - must be non zero
    LDA #$10
    STA RandomSeed

    LDA #$FF
    STA player_row
    STA player_collumn
    
    ;run test code
    ;JSR test_frontier ;test code

    JSR test_queue

    ;start generation immediately
    LDA #1
    STA has_generation_started

    ;display maze generation step-by-step
    LDA #1
    STA display_steps

    ;set gamemode
    LDA #1
    STA is_hard_mode
    
 ;   add_score #$FF
    add_score #255
    add_score #255

    RTS
.endproc
;*****************************************************************

;*****************************************************************
; Start
;       Gets called multiple times per frame as long as the maze is not being generated 
;*****************************************************************
.proc start
    JSR gamepad_poll
    LDA gamepad
    AND #PAD_A
    BEQ A_NOT_PRESSED

        LDA #1
        STA has_generation_started

        JMP :+
    A_NOT_PRESSED:

    :
    RTS
.endproc
;*****************************************************************

;*****************************************************************
; Input
;*****************************************************************
.segment "CODE"
.proc gamepad_poll
	; strobe the gamepad to latch current button state
	LDA #1
	STA JOYPAD1
	LDA #0
	STA JOYPAD1
	; read 8 bytes from the interface at $4016
	LDX #8
loop:
    PHA
    LDA JOYPAD1
    ; combine low two bits and store in carry bit
	AND #%00000011
	CMP #%00000001
	PLA
	; rotate carry into gamepad variable
	ROR
	DEX
	BNE loop
	STA gamepad
	RTS
.endproc
;*****************************************************************

;*****************************************************************
; The main algorithm loop (prims)
;*****************************************************************
.segment "CODE"
.proc start_prims_maze
    ; step 0 of the maze generation, set a random cell as passage and calculate its frontier cells
    JSR random_number_generator
    modulo RandomSeed, #29
    ;LDA #29
    STA a_val
    STA frontier_row
    ;STA temp
    JSR random_number_generator
    modulo RandomSeed, #31
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
    loop:
    
    LDA execs
    CMP #3
    BNE :+
       RTS ;early return if debugging amt of execs is completed
    :
    ;calculate pages used to see if all are empty - if so the maze is finished
    calculate_pages_used
    LDA frontier_pages_used
    BNE :+

        LDA #0
        STA has_generation_started

        RTS ;early return if finished
    :

    ;useful for debugging but not necessary for algorithm    
    LDA #%11111111
    STA used_direction

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
    modulo RandomSeed, temp ;stores val in A reg
    
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
        modulo RandomSeed, #02
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
    modulo RandomSeed, #02
    ADC #04
    STA temp

    ; ;remove the chosen frontier cell from the list
    set_map_tile frontier_row, frontier_col
    add_to_changed_tiles_buffer frontier_row, frontier_col, temp
    remove_from_Frontier frontier_page, frontier_offset

    ;INC execs
    ;JMP loop

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
    modulo RandomSeed, #31
    STA temp

    get_map_tile_state #1, temp
    BEQ rowloop_ue

    set_map_tile #0, temp
    add_to_changed_tiles_buffer #0, temp, #1
    LDA #0
    STA player_row
    LDA temp
    STA player_collumn

    LDA #0
    STA player_y
    LDA player_collumn
    CLC
    ASL
    ASL
    ASL
    STA player_x

    JMP col_check

    ;even rows means black border at bottom, find a tile in row 30 with a white tile above to set as start pos
    even_rows:
        rowloop_e:
        JSR random_number_generator
        modulo RandomSeed, #31
        STA temp

        get_map_tile_state #28, temp
        BEQ rowloop_e

        set_map_tile #0, temp
        add_to_changed_tiles_buffer #29, temp, #1

        LDA #29
        STA player_row
        LDA temp
        STA player_collumn

        LDA player_row
        CLC
        ASL
        ASL
        ASL
        STA player_y
        LDA player_collumn
        CLC
        ASL
        ASL
        ASL
        STA player_x


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
        modulo RandomSeed, #29
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
        modulo RandomSeed, #29
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