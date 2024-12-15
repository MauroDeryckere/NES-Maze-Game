;*****************************************************************
; Graphics utility functions
;*****************************************************************
.proc poll_clear_buffer
    LDA should_clear_buffer
    BEQ :+
        JSR clear_changed_tiles_buffer
        LDA #0
        STA should_clear_buffer
    :
    RTS
.endproc

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
    sta APU_DM_CONTROL
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
; Graphics 
;*****************************************************************
 ;Displays the map in one go
.segment "CODE"
.proc display_map
    JSR ppu_off
    JSR clear_nametable
    
    vram_set_address (NAME_TABLE_0_ADDRESS) 
    assign_16i paddr, maze_buffer    ;load map into ppu

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

;displays a clear map
.proc display_clear_map
    JSR ppu_off
    JSR clear_nametable

    ; Set PPU address to $2000 (nametable start)
    LDA #$20         ; High byte of address
    STA $2006
    LDA #$00         ; Low byte of address
    STA $2006

    LDA #07
    LDY #30
    rowloop:
        LDX #32
        columnloop:
            STA $2007        ; Write tile 0 to PPU data
            DEX
            BNE columnloop
        DEY
        BNE rowloop

    JSR ppu_update

    RTS
.endproc

;handles the background tiles during vblank using the buffers set in zero page
.proc draw_background
    ;update the map tiles
    LDY #0
    maploop: 
        LDX #0 ; flag wall or not
        LDA #0
        STA high_byte

        ;row
        LDA changed_tiles_buffer, y
        ;LDA #0
        CMP #$FF ;end of buffer
        BEQ done 
        STA low_byte

        ; clear the flag bit and row
        AND #%01100000
        TAX ;Store the 2-bit TileID in X (0-3) - not shifted yet  


        LDA low_byte
        AND #%00011111 ; Clear the tileID and flag from the row
        STA low_byte
        
        CLC
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
        AND #%00011111 ;clear tileID
        ADC low_byte 
        STA $2006

        ;extract the tileID  
        LDA changed_tiles_buffer, y
        AND #%11100000
        ;1110 0000 -> 0000 0111
        LSR
        LSR
        LSR
        LSR
        LSR
        STA low_byte ;temporarily store result

        ;extract the tileID  
        ; need to do row * 16 + col
        ;0110 0000 -> 0000 0011
        ; but the row is already stored in a significant enough bit so we can minimise amount of shifts
        TXA 
        LSR
        ADC low_byte
        STA PPU_VRAM_IO

        INY
        CPY #CHANGED_TILES_BUFFER_SIZE
        BNE maploop    
    done: 
        LDA #1
        STA should_clear_buffer
.endproc

; populate oam buffer with player sprite
.segment "CODE"
.proc draw_player_sprite
    ; only show sprite when not in generating mode or paused mode
    LDA current_game_mode
    CMP #1
    BEQ :++
    CMP #4
    BEQ :+++

    ldx #0 

    ;SPRITE 0
    lda player_row ;Y coordinate
    ASL
    ASL
    ASL
    sta oam, x
    inx

    CLC
    LDA #$D0   ;tile pattern index
    ADC player_dir

    sta oam, x
    inx 

    lda #%00000000 ;flip bits to set certain sprite attributes
    sta oam, x
    inx
    
    LDA player_collumn   ;X coordinate
    ASL
    ASL
    ASL
    TAY

    LDA current_game_mode
    CMP #0
    BNE :+
        TYA
        SEC
        SBC #4
        CLC
        TAY
    :
    TYA
    STA oam, x
    ;INX to go to the next sprite location 

    RTS

    :
    JSR hide_player_sprite
    :
    RTS

.endproc

;simply hides the sprite off screen
.proc hide_player_sprite
    LDX #0          ; Start at the first byte of the OAM (sprite 0 Y-coordinate)
    LDA #$F0        ; Y-coordinate off-screen
    STA oam, x      ; Write to OAM
    RTS
.endproc

;display the score
.proc display_score
    LDX #4

    LDA #SCORE_DIGIT_OFFSET
    ROL     ; x2
    ROL     ; x2 = x4
    STA temp
    
    LDA score_low

    CLC
    CMP #$0A
    BCC skip_modulo

    modulo score_low, #$0A  ;skip modulo if smaller than 10

    STA a_val               ;store remainder for later

    skip_modulo:

    JSR draw_digit
    CLC
    LDA temp
    SBC #SCORE_DIGIT_OFFSET
    STA temp    

    LDA score_low
    SEC
    SBC a_val

    divide10 score_low

    JSR draw_digit
    CLC
    LDA temp
    SBC #SCORE_DIGIT_OFFSET
    STA temp

    
    
    
    LDA score_high

    CLC
    CMP #$0A
    BCC skip_modulo2

    modulo score_high, #$0A  ;skip modulo if smaller than 10

    STA a_val               ;store remainder for later

    skip_modulo2:

    JSR draw_digit
    CLC
    LDA temp
    SBC #SCORE_DIGIT_OFFSET
    STA temp    

    LDA score_high
    SEC
    SBC a_val

    divide10 score_high

    JSR draw_digit
    CLC
    LDA temp
    SBC #SCORE_DIGIT_OFFSET
    STA temp

    ; JSR draw_digit
    ; CLC
    ; LDA temp
    ; ADC #SCORE_DIGIT_OFFSET     ;add 10 for x offset
    ; STA temp   
    
    
    ; divide10 score_high
    ; CLC
    ; CMP #$0A
    ; BCC skip_modulo

    ; modulo score_high, #$0A

    ; skip_modulo:

    ; JSR draw_digit
    ; CLC
    ; LDA temp
    ; ADC #SCORE_DIGIT_OFFSET
    ; STA temp    

    ; divide10 score_low

    ; JSR draw_digit
    ; CLC
    ; LDA temp
    ; ADC #SCORE_DIGIT_OFFSET     ;add 10 for x offset
    ; STA temp   
    
    
    ; divide10 score_low
    ; CLC
    ; CMP #$0A
    ; BCC skip_modulo2

    ; modulo score_low, #$0A

    ; skip_modulo2:

    ; JSR draw_digit
    ; CLC
    ; LDA temp
    ; ADC #SCORE_DIGIT_OFFSET
    ; STA temp    
    
    RTS
.endproc

;draws the digit stored in a reg
.proc draw_digit
    ;convert digit 0-9 to correct tile index
    CLC
    ADC #$10        ; get correct tile ID  
    TAY

    LDA #SCORE_DIGIT_OFFSET ;Y coordinate
    STA oam, x
    INX

    TYA
    STA oam, x
    INX 

    LDA #%00000001 ;flip bits to set certain sprite attributes
    STA oam, x
    INX

    LDA temp   ;X coordinate
    STA oam, x
    INX 

    RTS
.endproc

;*****************************************************************

;*****************************************************************
; startscreen
;*****************************************************************

.proc draw_title_settings
    LDA input_game_mode
    AND #GAME_MODE_MASK
    BNE AUTO_FALSE
        vram_set_address (NAME_TABLE_0_ADDRESS + 19 * 32 + 19)
        LDA #$6A
        STA PPU_VRAM_IO
        JMP HARD_CHECK
    AUTO_FALSE:
        vram_set_address (NAME_TABLE_0_ADDRESS + 19 * 32 + 19)
        LDA #$6B
        STA PPU_VRAM_IO
    HARD_CHECK:
    LDA input_game_mode
    AND #HARD_MODE_MASK
    BNE HARD_FALSE
        vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 19)
        LDA #$6A
        STA PPU_VRAM_IO
        JMP EXIT
    HARD_FALSE:
        vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 19)
        LDA #$6B
        STA PPU_VRAM_IO
    EXIT:
    RTS
.endproc

.segment "CODE"
.proc display_Start_screen
    LDA temp_player_collumn
    CMP #2
    BEQ @half_way
	; Write top border
	vram_set_address (NAME_TABLE_0_ADDRESS + 17 * 32 + 11)
	assign_16i paddr, top_border
	jsr write_text

	; Write play button
	vram_set_address (NAME_TABLE_0_ADDRESS + 18 * 32 + 11)
	assign_16i paddr, play_text
	jsr write_text

    RTS

    @half_way: 
	; Write auto button
	vram_set_address (NAME_TABLE_0_ADDRESS + 19 * 32 + 11)
	assign_16i paddr, auto_text
	jsr write_text

	; Write hard button
	vram_set_address (NAME_TABLE_0_ADDRESS + 20 * 32 + 11)
	assign_16i paddr, hard_text
	jsr write_text

	; Write bottom border
	vram_set_address (NAME_TABLE_0_ADDRESS + 21 * 32 + 11)
	assign_16i paddr, bottom_border
	jsr write_text

    LDA #1
    STA has_started
	rts
.endproc

.segment "CODE"
.proc write_text
	ldy #0
loop:
	lda (paddr),y ; get the byte at the current source address
	beq exit ; exit when we encounter a zero in the text
    SEC
    SBC #$11
	sta PPU_VRAM_IO ; write the byte to video memory
	iny
	jmp loop
exit:
	rts
.endproc

.proc draw_title
    LDA temp_player_collumn
    CMP #2
    BEQ @halfway

    vram_set_address (NAME_TABLE_0_ADDRESS + 1 * 32 + 1)
	assign_16i paddr, titlebox_line_1
	JSR write_text
    vram_set_address (NAME_TABLE_0_ADDRESS + 2 * 32 + 1)
	assign_16i paddr, titlebox_line_2
	JSR write_text


    vram_set_address (NAME_TABLE_0_ADDRESS + 3 * 32 + 1)
	assign_16i paddr, title_line_1
	JSR write_text
    vram_set_address (NAME_TABLE_0_ADDRESS + 4 * 32 + 1)
	assign_16i paddr, title_line_2
	JSR write_text
    vram_set_address (NAME_TABLE_0_ADDRESS + 5 * 32 + 1)
	assign_16i paddr, title_line_3
	JSR write_text

    RTS
    @halfway: 

    vram_set_address (NAME_TABLE_0_ADDRESS + 6 * 32 + 1)
	assign_16i paddr, title_line_4
	JSR write_text
    vram_set_address (NAME_TABLE_0_ADDRESS + 7 * 32 + 1)
	assign_16i paddr, title_line_5
	JSR write_text
    vram_set_address (NAME_TABLE_0_ADDRESS + 8 * 32 + 1)
	assign_16i paddr, title_line_6
	JSR write_text

    vram_set_address (NAME_TABLE_0_ADDRESS + 9 * 32 + 1)
	assign_16i paddr, titlebox_line_3
	JSR write_text
    vram_set_address (NAME_TABLE_0_ADDRESS + 10 * 32 + 1)
	assign_16i paddr, titlebox_line_4
	JSR write_text

    LDA #1
    STA has_started

    RTS
.endproc

top_border:
.byte $83, $82, $82, $82, $82, $82, $82, $82, $82, $86, 0
play_text:
.byte $81, $48, $48, "p", "l", "a", "y", $48, $48, $85, 0
auto_text:
.byte $81, $48, $48, "a", "u", "t", "o", $48, $7A, $85, 0
hard_text:
.byte $81, $48, $48, "h", "a", "r", "d", $48, $7A, $85, 0
bottom_border:
.byte $84, $87, $87, $87, $87, $87, $87, $87, $87, $88, 0

titlebox_line_1:
.byte $11,$15,  $11, $11, $17, $17, $17,  $11,$11,    $17, $17, $15, $15, $11,    $11,$11,    $15, $11, $11, $15, $15,    $11,$11,    $15, $11, $15, $11, $11,  $11,$11, 0
titlebox_line_2:
.byte $11,$15,  $15, $15, $15, $17, $17,  $15,$15,    $15, $17, $17, $15, $15,    $11,$11,    $15, $15, $15, $15, $15,    $15,$15,    $15, $16, $16, $15, $15,  $15,$11, 0

title_line_1: 
.byte $15,$15,  $14, $14, $15, $14, $14,  $15,$15,    $15, $14, $14, $14, $15,    $11,$15,    $14, $14, $14, $14, $14,    $15,$15,    $14, $14, $14, $14, $14,  $15,$11, 0
title_line_2: 
.byte $17,$15,  $14, $14, $14, $14, $14,  $17,$17,    $14, $14, $15, $14, $14,    $11,$15,    $14, $15, $15, $14, $14,    $17,$17,    $14, $14, $15, $15, $14,  $15,$15, 0
title_line_3: 
.byte $17,$15,  $14, $15, $14, $15, $14,  $15,$17,    $14, $15, $15, $15, $14,    $17,$15,    $16, $15, $14, $14, $15,    $15,$17,    $16, $14, $14, $15, $17,  $15,$15, 0
title_line_4: 
.byte $15,$17,  $14, $15, $15, $15, $14,  $15,$15,    $14, $14, $14, $14, $14,    $16,$16,    $16, $14, $14, $15, $15,    $15,$15,    $15, $14, $14, $17, $17,  $17,$15, 0
title_line_5: 
.byte $15,$15,  $14, $15, $15, $15, $14,  $15,$15,    $14, $15, $15, $16, $14,    $16,$16,    $14, $14, $15, $15, $14,    $15,$15,    $15, $14, $15, $15, $14,  $15,$11, 0
title_line_6: 
.byte $11,$16,  $14, $16, $15, $15, $14,  $15,$15,    $14, $15, $15, $15, $14,    $15,$16,    $14, $14, $14, $14, $14,    $15,$15,    $14, $14, $14, $14, $14,  $15,$11, 0

titlebox_line_3:
.byte $11,$16,  $16, $16, $11, $11, $15,  $15,$15,    $15, $15, $15, $15, $15,    $15,$15,    $15, $15, $15, $15, $15,    $15,$15,    $15, $17, $17, $17, $17,  $17,$11, 0
titlebox_line_4:
.byte $11,$11,  $11, $11, $11, $11, $11,  $15,$15,    $15, $15, $15, $15, $15,    $15,$15,    $15, $15, $11, $11, $11,    $11,$15,    $15, $15, $17, $17, $11,  $11,$11, 0
;*****************************************************************
