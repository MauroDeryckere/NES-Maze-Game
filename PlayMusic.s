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
