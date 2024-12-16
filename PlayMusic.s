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

;----------------------------------
;ROUTINE TO PLAY MUSIC
;----------------------------------
.proc play_music
    sta temp_sound
    tya 
    pha
    txa 
    pha 

    lda temp_sound
    ldx sfx_channel
    jsr famistudio_music_play

    pla 
    tax 
    pla 
    tay 
    rts
.endproc
;----------------------------------
;ROUTINE TO STOP MUSIC
;----------------------------------
.proc stop_music
    sta temp_sound
    tya 
    pha
    txa 
    pha 

    lda temp_sound
    ldx sfx_channel
    jsr famistudio_music_stop

    pla 
    tax 
    pla 
    tay 
    rts
.endproc
;----------------------------------
;ROUTINE TO PAUSE MUSIC
;----------------------------------
.proc pause_music
    sta temp_sound
    tya 
    pha
    txa 
    pha 

    lda temp_sound
    ldx sfx_channel
    jsr famistudio_music_pause

    pla 
    tax 
    pla 
    tay 
    rts
.endproc
.proc play_when_backtracking
    lda is_backtracking
    beq not_backtracking
    ;------------------------
    ;PAUSE TITLE SCREEN MUSIC
    ;------------------------
    lda #2
    jsr stop_music
                    
    ;------------------------
    ; PLAY SOUND EFFECT ONCE
    ;------------------------
    lda sound_played2  ; Check if the sound has been played
    beq play_sound         ; If not, branch to play the sound
    rts                    ; If already played, return

    play_sound:
        lda #1                 ; Load the sound ID
        jsr play_sound_effect  ; Play the sound effect
        lda #1                 ; Set the flag to indicate the sound has been played
        sta sound_played2  ; Store the flag

    not_backtracking: 
    rts
.endproc