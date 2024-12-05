.include "Header.s"
.include "Macros.s"

.include "TestCode.s"
.include "Graphics.s"
.include "Util.s"

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

    JSR draw_background

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

        LDA has_generation_started
        BNE :+
            JSR start

            ;auto generation once maze is completed (useful for debugging)
            ; LDA #1
            ; STA has_generation_started

            JMP mainloop
        :

        LDA has_generation_started
        BEQ stop
            ;clear everything and display empty map at start of generation
            JSR clear_maze
            JSR clear_changed_tiles_buffer
            JSR cleared_added_frontier_buffer
            JSR wait_frame
            JSR display_map

            JSR start_prims_maze

        LDA display_steps
        BEQ display_once

            step_by_step_generation_loop:
                JSR wait_frame ;wait until a vblank has happened

                LDA should_clear_buffer
                BEQ :+
                    JSR clear_changed_tiles_buffer
                    JSR cleared_added_frontier_buffer
                    LDA #0
                    STA should_clear_buffer
                :

                ;current version works up to 5x speed - TODO add a flag to adjust this speed
                ; JSR run_prims_maze
                ; JSR run_prims_maze
                ; JSR run_prims_maze
                ; JSR run_prims_maze
                JSR run_prims_maze
                
                LDA has_generation_started
                BEQ stop
                JMP step_by_step_generation_loop

            display_once: 
                JSR run_prims_maze
                LDA has_generation_started
                BNE display_once
                JSR display_map

        stop:

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
    JSR cleared_added_frontier_buffer
    JSR clear_maze

    ;set an initial randomseed value - must be non zero
    LDA #$10
    STA RandomSeed
    
    ;JSR test_frontier ;test code

    LDA #1
    STA has_generation_started
    LDA #1
    STA display_steps
    RTS
.endproc
;*****************************************************************

;*****************************************************************
; Start
;       Gets called until the generation of the maze starts
;*****************************************************************
.proc start
    JSR gamepad_poll
    LDA gamepad
    AND #PAD_A
    BEQ A_NOT_PRESSED
        ;code for button press here  
        LDA a_pressed_last_frame
        BNE A_NOT_PRESSED           ;check for pressed this frame

        LDA #1
        STA has_generation_started
        STA a_pressed_last_frame

        JMP :+
    A_NOT_PRESSED:
        ;code for other buttons etc here
        LDA #0
        STA a_pressed_last_frame
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

    set_map_tile a_val, b_val
    add_to_changed_tiles_buffer frontier_row, frontier_col

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
        set_map_tile temp_row, temp_col
        add_to_changed_tiles_buffer temp_row, temp_col

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
    ; ;remove the chosen frontier cell from the list
    set_map_tile frontier_row, frontier_col
    add_to_changed_tiles_buffer frontier_row, frontier_col
    remove_from_Frontier frontier_page, frontier_offset

    ;INC execs
    ;JMP loop

    RTS
.endproc
;*****************************************************************