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
; Include Sound Engine and Sound Effects Data
;*****************************************************************
.segment "CODE"


; CA65 specific config
.define FAMISTUDIO_CA65_ZP_SEGMENT   ZEROPAGE
.define FAMISTUDIO_CA65_RAM_SEGMENT  BSS
.define FAMISTUDIO_CA65_CODE_SEGMENT CODE

;FamiStudio Config
FAMISTUDIO_CFG_EXTERNAL = 1 

; One of these MUST be defined (PAL or NTSC playback). 
; Note that only NTSC support is supported when using any of the audio expansions.
FAMISTUDIO_CFG_PAL_SUPPORT   = 1
FAMISTUDIO_CFG_NTSC_SUPPORT  = 0

; FAMISTUDIO_CFG_DPCM_SUPPORT = 1 ;support samples, turning this on wont use memory if there are no samples being used 
FAMISTUDIO_CFG_SFX_SUPPORT = 1 ;support sound effects
FAMISTUDIO_CFG_SFX_STREAMS = 2 ; sound effects that can be played at once

FAMISTUDIO_USE_VIBRATO = 1 ;support vibrato

; Enables DPCM playback support.
FAMISTUDIO_CFG_DPCM_SUPPORT   = 1

; Must be enabled if you are calling sound effects from a different 
; thread than the sound engine update.
FAMISTUDIO_CFG_THREAD         = 1

; Must be enabled if the songs you will be importing have been created using FamiTracker tempo mode. If you are using
; FamiStudio tempo mode, this must be undefined. You cannot mix and match tempo modes, the engine can only run in one
; mode or the other. 
; More information at: https://famistudio.org/doc/song/#tempo-modes
FAMISTUDIO_USE_FAMITRACKER_TEMPO = 1

; Must be enabled if the songs uses delayed notes or delayed cuts. This is obviously only available when using
; FamiTracker tempo mode as FamiStudio tempo mode does not need this.
FAMISTUDIO_USE_FAMITRACKER_DELAYED_NOTES_OR_CUTS = 1

; Must be enabled if the songs uses release notes. 
; More information at: https://famistudio.org/doc/pianoroll/#release-point
FAMISTUDIO_USE_RELEASE_NOTES = 1

; Must be enabled if any song uses the volume track. The volume track allows manipulating the volume at the track level
; independently from instruments.
; More information at: https://famistudio.org/doc/pianoroll/#editing-volume-tracks-effects
FAMISTUDIO_USE_VOLUME_TRACK = 1

; Must be enabled if any song uses slides on the volume track. Volume track must be enabled too.
; More information at: https://famistudio.org/doc/pianoroll/#editing-volume-tracks-effects
FAMISTUDIO_USE_VOLUME_SLIDES = 1

; Must be enabled if any song uses the pitch track. The pitch track allows manipulating the pitch at the track level
; independently from instruments.
; More information at: https://famistudio.org/doc/pianoroll/#pitch
FAMISTUDIO_USE_PITCH_TRACK = 1

; Must be enabled if any song uses slide notes. Slide notes allows portamento and slide effects.
; More information at: https://famistudio.org/doc/pianoroll/#slide-notes
FAMISTUDIO_USE_SLIDE_NOTES = 1

; Must be enabled if any song uses slide notes on the noise channel too. 
; More information at: https://famistudio.org/doc/pianoroll/#slide-notes
FAMISTUDIO_USE_NOISE_SLIDE_NOTES = 1

; Must be enabled if any song uses arpeggios (not to be confused with instrument arpeggio envelopes, those are always
; supported).
; More information at: (TODO)
FAMISTUDIO_USE_ARPEGGIO = 1

; Must be enabled if any song uses the "Duty Cycle" effect (equivalent of FamiTracker Vxx, also called "Timbre").  
FAMISTUDIO_USE_DUTYCYCLE_EFFECT = 1

; Must be enabled if any song uses the DPCM delta counter. Only makes sense if DPCM samples
; are enabled (FAMISTUDIO_CFG_DPCM_SUPPORT).
; More information at: (TODO)
FAMISTUDIO_USE_DELTA_COUNTER = 1

; Must be enabled if your project uses the "Phase Reset" effect.
FAMISTUDIO_USE_PHASE_RESET = 1

; Must be enabled if your project uses the FDS expansion and at least one instrument with FDS Auto-Mod enabled.
FAMISTUDIO_USE_FDS_AUTOMOD  = 1



; ; Must be enabled if your project uses more than 1 bank of DPCM samples.
; ; When using this, you must implement the "famistudio_dpcm_bank_callback" callback 
; ; and switch to the correct bank every time a sample is played.
; FAMISTUDIO_USE_DPCM_BANKSWITCHING = 1

; ; Must be enabled if your project uses more than 63 unique DPCM mappings (a mapping is DPCM sample
; ; assigned to a note, with a specific pitch/loop, etc.). Implied when using FAMISTUDIO_USE_DPCM_BANKSWITCHING.
 ; FAMISTUDIO_USE_DPCM_EXTENDED_RANGE = 1

; Allows having up to 256 instrument at the cost of slightly higher CPU usage when switching instrument.
; When this is off, the limit is 64 for regular instruments and 32 for expansion instrumnets.
FAMISTUDIO_USE_INSTRUMENT_EXTENDED_RANGE = 1

; FAMISTUDIO_CFG_EQUALIZER = 1 ; allows relative volme control of sound channel
; FAMISTUDIO_USE_VOLUME_TRACK = 1 ;for when the effects/music control the volume 
; FAMISTUDIO_USE_PITCH_TRACK = 1 ;allows notes to control pitch
; FAMISTUDIO_USE_SLIDE_NOTES = 1 ;support slide notes
; FAMISTUDIO_USE_ARPEGGIO = 1 ; supports arpeggio
; FAMISTUDIO_CFG_SMOOTH_VIBRATO = 1 ; allows vibrato to have smoother sound
; FAMISTUDIO_USE_RELEASE_NOTES = 1 ; supports notes that have release notes configured
; FAMISTUDIO_DPCM_OFF = $e000 ; where the dpcm samples are located


.include "famistudio_ca65.s"
.include "SoundEffects.s"

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

    LDA current_game_mode
    CMP #0
    BEQ draw_start_screen

    JSR draw_background
    JSR draw_player_sprite
    JSR display_score
    JMP skip_start_screen
    
draw_start_screen:
    LDA has_started
    CMP #1
    BEQ :+
        INC temp_player_collumn ; tep var to maintain how many times weve executed
        JSR display_Start_screen
        JSR draw_title
    :   
        JSR draw_player_sprite
        JSR draw_title_settings
skip_start_screen:

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

    ;CALL SOUND PLAY ROUTINE
    jsr famistudio_update

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
; init
;*****************************************************************
.segment "CODE"
.proc init
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

    ;set an initial randomseed value - must be non zero
    LDA #$10
    STA random_seed

    ;player row and col on the startscreen
    LDA #18
    STA player_row
    LDA #13
    STA player_collumn

    LDA #2
    STA player_dir

    ;start with startscreen
    LDA #0
    STA current_game_mode
    STA has_started
    STA temp_player_collumn
    STA temp_player_row
            
    ;run test code
    ;JSR test_frontier ;test code
    ;JSR test_queue

    ;     000GHSSS
    LDA #%00000001
    ;EOR #HARD_MODE_MASK
    ;EOR #GAME_MODE_MASK
    STA input_game_mode

    LDA #1 
    STA display_BFS_directions

;-----------------------------------------
;INITIALIZE SOUND
;-----------------------------------------
    lda #1 
    ldx #0 
    ldy #0
    jsr famistudio_init

    ldx #.lobyte(sounds)
    ldy #.hibyte(sounds)
    jsr famistudio_sfx_init

    lda #FAMISTUDIO_SFX_CH0
    sta sfx_channel
    lda #0
    jsr play_sound_effect


    RTS
.endproc
;*****************************************************************

;*****************************************************************
; Main Gameloop
;*****************************************************************
.segment "CODE"
.proc main
    JSR init

    JSR title_screen

    mainloop:
        INC random_seed  ; Chnage the random seed as many times as possible per frame
        
        LDA current_game_mode
        ;------------;
        ;   PAUSE    ;
        ;------------;
        CMP #4
        BNE @GENERATING
            JSR input_logic
            JMP @END
        ;------------;
        ; GENERATING ;
        ;------------;
        @GENERATING: 
            CMP #1
            BNE @PLAYING

            ;JSR input_logic

            ; ONCE PER FRAME
            LDA checked_this_frame
            CMP #1
            BEQ mainloop
                LDA #1
                STA checked_this_frame ; set flag so that we only do this once per frame

                JSR poll_clear_buffer ; clear buffer if necessary

                ; Have we started the algorithm yet? if not, execute the start function once
                LDA has_started
                CMP #0
                BNE :+

                    JSR start_prims_maze
                    LDA #1
                    STA has_started
                :

                ;slow down generation if necessary
                modulo frame_counter, #MAZE_GENERATION_SPEED
                CMP #0
                BNE mainloop
                JSR run_prims_maze ; whether or not the algorithm is finished is stored in the A register (0 when not finished)

                ; Has the maze finished generating?
                CMP #0
                BEQ :++
                    JSR calculate_prims_start_end

                    ; reset some flags for the next game mode so that they could be reused
                    LDA #0
                    STA has_started

                    ; Select correct gamemode after generating  
                    LDA input_game_mode
                    AND #GAME_MODE_MASK
                    CMP #GAME_MODE_MASK
                    BEQ :+
                        LDA #2
                        STA current_game_mode
                        JMP @END
                    :
                    LDA #3
                    STA current_game_mode
                :

                JMP @END

        ;---------;
        ; PLAYING ;
        ;---------;
        @PLAYING: 
            CMP #2
            BNE @SOLVING
            
            JSR input_logic ; poll input as often as possible

            ; ONCE PER FRAME
            LDA checked_this_frame
            CMP #1
            BEQ mainloop
                LDA #1
                STA checked_this_frame ; set flag so that we only do this once per frame
                
                JSR poll_clear_buffer ; clear buffer if necessary

                ; Have we started the game yet? if not, execute the start function once
                LDA has_started
                CMP #0
                BNE :+ 
                    JSR start_game
                    LDA #1
                    STA has_started ;set started to 1 so that we start drawing the sprite
                :

                JSR update_player_sprite
                
                ; are we in hard mode?
                LDA input_game_mode
                AND #HARD_MODE_MASK
                CMP #0
                BEQ :+
                    JSR update_visibility
                :

                ; Has the player reached the end?
                    LDA player_row
                    CMP end_row
                    BNE @PLAYING
                    LDA player_collumn
                    CMP end_col
                    BNE @PLAYING

                ; ONLY EXECUTED WHEN END IS REACHED
                ; reset some flags for the next game mode so that they could be reused
                    LDA #0
                    STA has_started

                    LDA #1 ;set the gamemode to generating
                    STA current_game_mode
                    JSR reset_generation
                JMP @END

        ;---------;
        ; SOLVING ;
        ;---------;
        @SOLVING: 
            CMP #3
            BEQ :+
                JMP @END
            :
            JSR input_logic

            ; ONCE PER FRAME
            LDA checked_this_frame
            CMP #1
            BNE :+
                JMP @END
            :
                LDA #1
                STA checked_this_frame ; set flag so that we only do this once per frame

                JSR poll_clear_buffer ; clear buffer if necessary

                ; Have we started the solving algorithm yet? if not, execute the start function once
                LDA has_started
                CMP #0
                BNE :++++ 
                    ;select the solving mode based on hard mode or not
                    LDA input_game_mode
                    AND #CLEAR_SOLVING_MODE_MASK
                    STA input_game_mode

                    LDA input_game_mode
                    AND #HARD_MODE_MASK
                    CMP #0
                    BEQ :+
                        LDA input_game_mode
                        ORA #LHR_MODE_MASK
                        STA input_game_mode
                    :

                    ;which solve mode do we have to start in?
                    LDA input_game_mode
                    AND #SOLVE_MODE_MASK
                    CMP #0 ;BFS
                    BNE :+ 
                        JSR start_BFS
                        JMP :++
                    :
                    CMP #1 ;left hand
                    BNE :+
                        ;start left hand
                        ; are we in hard mode?
                        LDA input_game_mode
                        AND #HARD_MODE_MASK
                        CMP #0
                        BEQ :+
                            JSR display_clear_map
                            JSR start_hard_mode
                    :

                    LDA #1
                    STA has_started 
                :

                ; execute one step of the algorithm
                LDA input_game_mode
                AND #SOLVE_MODE_MASK
                @BFS_SOLVE: 
                    CMP #0 ;BFS
                    BNE @LFR_SOLVE
                    JSR step_BFS

                    LDA is_backtracking
                    CMP #$FF                 
                    BEQ @SOLVE_END_REACHED

                    JMP @END_SOLVE_MODES
                @LFR_SOLVE: 
                    CMP #1 ;LFR
                    BNE @END_SOLVE_MODES
                    JSR left_hand_rule

                    ; are we in hard mode?
                    LDA input_game_mode
                    AND #HARD_MODE_MASK
                    CMP #0
                    BEQ :+
                        JSR update_visibility
                    :

                    ; check if player reached end
                    LDA player_row
                    CMP end_row
                        BNE @END_SOLVE_MODES
                    LDA player_collumn 
                    CMP end_col
                        BNE @END_SOLVE_MODES

                    JMP @SOLVE_END_REACHED
                @END_SOLVE_MODES: 
                    JMP @END
                
                @SOLVE_END_REACHED: 
                    ; back to generating
                    LDA #1 ;set the gamemode to generating
                    STA current_game_mode
                    LDA #0
                    STA has_started

                    JSR reset_generation

                    JMP @END

        @END: 
            JMP mainloop
.endproc
;*****************************************************************

;*****************************************************************
; Input 
;*****************************************************************
.proc input_logic
    JSR gamepad_poll
    LDA gamepad
    AND #PAD_A
    BEQ A_NOT_PRESSED


    JMP START_CHECK
    A_NOT_PRESSED:

    START_CHECK:
        lda gamepad     
        and #PAD_START
        beq NOT_GAMEPAD_START

        lda gamepad_prev            
        and #PAD_START              
        bne NOT_GAMEPAD_START
            LDA current_game_mode
            CMP #4
            BNE is_not_paused
                LDA gamemode_store_for_paused
                STA current_game_mode
                JMP EXIT            
            is_not_paused:
                STA gamemode_store_for_paused
                LDA #4
                STA current_game_mode

    NOT_GAMEPAD_START:

    EXIT:

    lda gamepad
    sta gamepad_prev

    RTS
.endproc

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
.proc title_screen
    titleloop:

        ; UP/DOWN MOVEMENT OF SELECTION
        @UP_DOWN_MOVEMENT: 
            jsr gamepad_poll
            lda gamepad     
            and #PAD_D
            beq NOT_GAMEPAD_DOWN 

            lda gamepad_prev            
            and #PAD_D                  
            bne NOT_GAMEPAD_DOWN
                LDA player_row
                CMP #20
                BEQ :+
                    INC player_row
                :

            NOT_GAMEPAD_DOWN: 
            lda gamepad     
            and #PAD_U
            beq NOT_GAMEPAD_UP

            lda gamepad_prev            
            and #PAD_U           
            bne NOT_GAMEPAD_UP
                LDA player_row
                CMP #18
                BEQ :+
                    DEC player_row
                :
        ;---------------------

        ; SELECTION
        @SELECTION: 
            NOT_GAMEPAD_UP: 
            lda gamepad     
            and #PAD_SELECT
            beq NOT_GAMEPAD_SELECT

            ; select pressed
            lda gamepad_prev            
            and #PAD_SELECT  
            bne NOT_GAMEPAD_SELECT
                LDA player_row
                CMP #18
                BNE NOT_PLAY
                    JMP exit_title_loop
                NOT_PLAY: 
                LDA player_row
                CMP #19
                BNE NOT_AUTO
                    LDA input_game_mode
                    EOR #%00010000
                    STA input_game_mode
                    JMP NOT_GAMEPAD_SELECT
                NOT_AUTO:
                LDA player_row
                CMP #20
                BNE NOT_HARD
                    LDA input_game_mode
                    EOR #%00001000
                    STA input_game_mode
                    JMP NOT_GAMEPAD_SELECT
                NOT_HARD:
        ;---------------------------
        NOT_GAMEPAD_SELECT: 

        LDA #2
        STA player_dir

        lda gamepad
        sta gamepad_prev

        ; Pressing start starts the game
        and #PAD_START
        bne exit_title_loop
    
        JMP titleloop

    exit_title_loop:
        LDA #1
        STA current_game_mode ; back to generating

        LDA #0                      
        STA has_started
        JSR reset_generation
        RTS
.endproc

;*****************************************************************
; Gameplay
;*****************************************************************
; resets everything necessary so that the maze generation can start again
.proc reset_generation
    JSR hide_player_sprite
    JSR clear_changed_tiles_buffer
    JSR clear_maze
    JSR wait_frame
    JSR display_map
    
    RTS
.endproc

.proc start_game
    
    LDA input_game_mode
    AND #HARD_MODE_MASK
    CMP #0
    BEQ :+
        JSR display_clear_map
        JSR start_hard_mode
    :
    RTS
.endproc 

;----------------------------------
;ROUTINE TO PLAY SOUNDEFFECT
;----------------------------------
.proc play_sound_effect

    sta temp_sound
    tya 
    pha
    txa 
    pha 

    lda temp_sound
    ldx sfx_channel
    jsr famistudio_sfx_play

    pla 
    tax 
    pla 
    tay 
    rts
.endproc

;*****************************************************************
