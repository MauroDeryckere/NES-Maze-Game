;*****************************************************************
; Score system
;*****************************************************************
.macro add_score amount

    LDA score_low
    CLC 
    ADC amount
    STA score_low 
    BCC no_carry     
    LDA score_high
    ADC #$00 
    STA score_high

    .local no_carry
    no_carry:

.endmacro
;*****************************************************************
