;*****************************************************************
; Score system
;*****************************************************************
.macro add_score amount

    LDA score_low
    CLC 
    ADC amount
    STA score_low 
    CMP #100
    BCC skip
        
    ;modulo score_low, #100
    
    divide10 score_low
    STA score_low
    divide10 score_low

    STA score_high
    LDA Remainder
    STA score_low
.local skip
skip:

.endmacro
;*****************************************************************
