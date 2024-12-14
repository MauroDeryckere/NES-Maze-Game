.include "Header.s"
.include "Macros.s"

; hardware
.include "Graphics.s"
.include "Util.s"
.include "TestCode.s"

; gameplay
.include "HardMode.s"
.include "Score.s"
.include "Player.s"

; algorithms
.include "Prims.s"
.include "LeftHandRule.s"
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
    JSR display_score

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
        
        ;only when not generating 
        LDA has_generation_started
        BNE @WHILE_GENERATING
            ;poll input and similar
            JSR start

            ;auto generation once maze is completed (useful for debugging)
            ; LDA #1
            ; STA has_generation_started

            ;once per frame
            LDA checked_this_frame
            CMP #1
            BEQ mainloop
            
                LDA #1
                STA checked_this_frame

                JSR poll_clear_buffer

                JSR update_player_sprite

                LDA is_BFS_solve
                CMP #1
                BNE @LEFT_HAND_RULE

                @BFS: 
                    LDA is_solving
                    CMP #1
                    BEQ @skip_start_BFS
                        JSR start_BFS

                        LDA #1
                        STA is_solving
                    @skip_start_BFS: 
                    
                    LDA is_solving
                    CMP #0
                    BEQ @skip_BFS_step
                        JSR step_BFS
                    @skip_BFS_step: 


                LDA is_BFS_solve
                CMP #1
                BEQ @skip_left_hand
                
                @LEFT_HAND_RULE: 
                    JSR left_hand_rule

                @skip_left_hand: 

                LDA is_hard_mode
                CMP #0
                BEQ :+
                    JSR update_visibility
                :   

                ;check if we reached the end
                LDA player_row
                CMP end_row
                BNE mainloop
                LDA player_collumn 
                CMP end_col
                BNE mainloop
                    add_score #10
                    LDA #1
                    STA has_generation_started

                JMP mainloop

        @WHILE_GENERATING: 
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

    ;set an initial randomseed value - must be non zero
    LDA #$10
    STA RandomSeed

    LDA #$FF
    STA player_row
    STA player_collumn
    
    ;run test code
    ;JSR test_frontier ;test code
    ; JSR test_queue

    ;start generation immediately
    LDA #1
    STA has_generation_started

    ;display maze generation step-by-step
    LDA #1
    STA display_steps

    ;set gamemode
    LDA #0
    STA is_hard_mode
        
    ;add_score #255

    LDA #0
    STA is_solving
    
    LDA #1
    STA is_BFS_solve

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