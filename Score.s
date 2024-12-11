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
    
    divide10 score_low  ;divide nr by 10
    STA score_high      ;store result of division in score_high
    LDA Remainder
    STA b_val           ;store Remainder in a_val
    divide10 score_high ;divide the result of first division again by 10
    STA score_high      ;store new result in score_high
    multiply10 Remainder;multiply remainder by 10 to get correct number
    ADC b_val
    STA score_low

.local skip
skip:

.endmacro
;*****************************************************************
