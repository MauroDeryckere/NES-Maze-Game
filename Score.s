;*****************************************************************
; Score system
;*****************************************************************
.macro add_score amount

    LDA amount
    STA added_low

    LDA added_low
    CMP #100
    BCC :++

    SEC
    :
    INC added_high
    SBC #100
    CMP #100
    BCS :-

    :
    STA added_low
    CLC 
    ADC score_low
    ; BVC :+
    ; INC added_high
    ; :
    STA added_low

    LDA #100
    CMP added_low
    BCS :++


    SEC
    LDA added_low
    :
    INC added_high
    SBC #100
    CMP #100
    BCS :-
    STA added_low

    :
    LDA added_low
    STA score_low

    LDA added_high
    STA score_high

    ; LDA added_low
    ; ; CLC
    ; ; ADC score_low



    ; LDA score_low
    ; CLC 
    ; ADC amount
    ; STA score_low 
    ; CMP #100
    ; BCC skip
    
    ; LDA amount
    ; SEC
    ; :
    ; INC score_high
    ; SBC #100
    ; CMP #100
    ; BCS :-
    ; STA score_low

    ; ; LDY score_low
    ; divide10 score_low      ;divide amount by 10
    ; STA score_high          ;store in score high temporarily
    ; LDX Remainder           ;keep remainder 1 in X
    ; divide10 score_high     ;divide by 10 again (==amount / 100)
    ; STA score_high          ;store in score high (permanent)
    ; multiply10 Remainder    ;multiply remainder 2 by 10 (tientallen)
    ; STA score_low           ;store in score low temporarily
    ; TXA
    ; CLC
    ; ADC score_low           ;add remainder 1 to 10 times remainder 2
    ; STA score_low           ;store result in score low

    ;LDA #99
    ;STA score_low
    ; divide10 score_low  ;divide nr by 10
    ; STA score_high      ;store result of division in score_high
    ; LDA Remainder
    ; STA b_val           ;store Remainder in a_val
    ; divide10 score_high ;divide the result of first division again by 10
    ; STA score_high      ;store new result in score_high
    ; multiply10 Remainder;multiply remainder by 10 to get correct number
    ; ADC b_val
    ; STA score_low

.local skip
skip:

.endmacro
;*****************************************************************
