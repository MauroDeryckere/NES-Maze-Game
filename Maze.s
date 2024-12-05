.include "Header.s"
.include "Macros.s"

;*****************************************************************
; Utility functions
;*****************************************************************
.segment "CODE"
.proc clear_changed_tiles_buffer
    LDY #0

    loop: 
    LDA #$FF
    STA changed_tiles_buffer, Y

    INY
    CPY #CHANGED_TILES_BUFFER_SIZE
    BNE loop

    RTS
.endproc

.segment "CODE"
.proc cleared_added_frontier_buffer
    LDY #0

    loop: 
    LDA #$FF
    STA added_frontier_buffer, Y

    INY
    CPY #ADDED_FRONTIER_BUFFER_SIZE
    BNE loop

    RTS
.endproc

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

.proc wait_frame
	INC nmi_ready
@loop:
	LDA nmi_ready
	BNE @loop
	RTS
.endproc

; ppu_update: waits until next NMI, turns rendering on (if not already), uploads OAM, palette, and nametable update to PPU
.proc ppu_update
    LDA ppu_ctl0
	ORA #VBLANK_NMI
	STA ppu_ctl0
	STA PPU_CONTROL
	LDA ppu_ctl1
	ORA #OBJ_ON|BG_ON
	STA ppu_ctl1
	JSR wait_frame
	RTS
.endproc

; ppu_off: waits until next NMI, turns rendering off (now safe to write PPU directly via PPU_VRAM_IO)
.proc ppu_off
    JSR wait_frame
	LDA ppu_ctl0
	AND #%01111111
	STA ppu_ctl0
	STA PPU_CONTROL
	LDA ppu_ctl1
	AND #%11100001
	STA ppu_ctl1
	STA PPU_MASK
	RTS
.endproc

.segment "CODE"
.proc reset
    SEI
    LDA #0
    STA PPU_CONTROL
    STA PPU_MASK
    ;sta APU_DM_CONTROL
    LDA #40
    STA JOYPAD2 

    CLD
    LDX #$FF
    TXS

wait_vblank:
    BIT PPU_STATUS
    BPL wait_vblank

    LDA #0
    LDX #0

clear_ram:
    STA $0000, x
    STA $0100, x
    STA $0200, x
    STA $0300, x
    STA $0400, x
    STA $0500, x
    STA $0600, x
    STA $0700, x
    INX
    BNE clear_ram

    LDA #255
    LDX #0

clear_oam:
    STA oam, x
    INX
    INX
    INX
    INX
    BNE clear_oam

wait_vblank2:
    BIT PPU_STATUS
    BPL wait_vblank2

    LDA #%10001000
    STA PPU_CONTROL

    JMP main
.endproc

.segment "CODE"
.proc clear_nametable
    LDA PPU_STATUS 
    LDA #$20
    STA PPU_VRAM_ADDRESS2
    LDA #$00
    STA PPU_VRAM_ADDRESS2

    LDA #0
    LDY #30
    rowloop:
        LDX #32
        columnloop:
            STA PPU_VRAM_IO
            DEX
            BNE columnloop
        DEY
        BNE rowloop

    LDX #64
    loop:
        STA PPU_VRAM_IO
        DEX
        BNE loop
    RTS
.endproc
;*****************************************************************

;*****************************************************************
; Interupts
;*****************************************************************
.segment "CODE"
irq:
	RTI

.proc nmi
    ;save registers
    PHA
    TXA
    PHA
    TYA
    PHA
    
    BIT PPU_STATUS

    LDA display_steps
    BEQ done_f

    ;update the frontier cells
    LDY #0
    LDA #0
    frontierloop: 
        CLC
        LDA #0
        STA high_byte

        ;row
        LDA added_frontier_buffer, y
        ;LDA #0
        CMP #$FF ;end of buffer
        BEQ done_f 

        STA low_byte

        ASL low_byte ;x2
        ROL high_byte
        ASL low_byte ;x2
        ROL high_byte
        ASL low_byte ;x2
        ROL high_byte
        ASL low_byte ;x2
        ROL high_byte
        ASL low_byte ;x2 == 32
        ROL high_byte

        LDA #$20 ;add high byte
        CLC
        ADC high_byte
        STA $2006
        
        ;col
        INY
        LDA added_frontier_buffer, y
        ;LDA #0
        
        CLC
        ADC low_byte
        STA $2006

        LDA #2
        STA PPU_VRAM_IO

        INY
        CPY #ADDED_FRONTIER_BUFFER_SIZE
        BNE frontierloop        
    done_f: 
        LDA display_steps
        BEQ done

    ;update the map tiles
    LDY #0
    LDA #0
    maploop: 
        CLC
        LDA #0
        STA high_byte

        ;row
        LDA changed_tiles_buffer, y
        ;LDA #0
        CMP #$FF ;end of buffer
        BEQ done 

        STA low_byte

        ASL low_byte ;x2
        ROL high_byte
        ASL low_byte ;x2
        ROL high_byte
        ASL low_byte ;x2
        ROL high_byte
        ASL low_byte ;x2
        ROL high_byte
        ASL low_byte ;x2 == 32
        ROL high_byte

        LDA #$20 ;add high byte
        CLC
        ADC high_byte
        STA $2006
        
        ;col
        INY
        LDA changed_tiles_buffer, y
        ;LDA #0
        
        CLC
        ADC low_byte
        STA $2006

        LDA #1
        STA PPU_VRAM_IO

        INY
        CPY #CHANGED_TILES_BUFFER_SIZE
        BNE maploop    
    done: 
        LDA #1
        STA should_clear_buffer

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


;subroutine to add a cell to the frontierlist after accessing the neighbor and checking if it is valid
.segment "CODE"
.proc add_cell
    STX x_val
    STY y_val

    add_to_Frontier y_val, x_val
    add_to_added_frontier_buffer y_val, x_val

    RTS
.endproc  

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
; Graphics
;*****************************************************************
.segment "CODE"
.proc display_map
    JSR ppu_off
    JSR clear_nametable
    
    vram_set_address (NAME_TABLE_0_ADDRESS) 
    assign_16i paddr, MAP_BUFFER_ADDRESS    ;load map into ppu

    LDY #0          ;reset value of y
    loop:
        LDA (paddr),y   ;get byte to load
        TAX
        LDA #8          ;8 bits in a byte
        STA byte_loop_couter

        byteloop:
        TXA             ;copy x into a to preform actions on a copy
        set_Carry_to_highest_bit_A  ;rol sets bit 0 to the value of the carry flag, so we make sure the carry flag is set to the value of bit 7 to rotate correctly
        ROL             ;rotate to get the correct bit on pos 0
        TAX             ;copy current rotation back to x
        AND #%00000001  ;and with 1, to check if tile is filled
        STA PPU_VRAM_IO ;write to ppu

        DEC byte_loop_couter    ;decrease counter
        LDA byte_loop_couter    ;get value into A
        BNE byteloop            ;repeat byteloop if not done with byte yet

        INY
            CPY #MAP_BUFFER_SIZE              ;the screen is 120 bytes in total, so check if 120 bytes have been displayed to know if we're done
            BNE loop

        JSR ppu_update

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

.proc test_frontier
;     loop: 
;         LDA frontier_listQ2_size
;         CMP #0
;         BEQ :+
;         JMP l2
;         :
;             add_to_Frontier #$FF, #$FF
;             JMP loop

;     l2:
;   ;  add_to_Frontier #$AA, #$AA

;     remove_from_Frontier #0, #10
;     remove_from_Frontier #1, #0

;     ;add_to_Frontier #$AA, #$AA

    add_to_Frontier #0, #1
    add_to_Frontier #4, #5
    add_to_Frontier #4, #5
    add_to_Frontier #5, #5
    add_to_Frontier #8, #5
    add_to_Frontier #1, #0

    LDA #0
    STA a_val

    exists_in_Frontier #0, #0
    STA a_val

    RTS

.endproc
;*****************************************************************