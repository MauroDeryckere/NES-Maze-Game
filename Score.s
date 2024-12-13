;*****************************************************************
; Score system
;*****************************************************************
.macro add_score amount

    LDA amount           ; Load the amount to be added
    JSR private_add_score
.endmacro

.segment "CODE"
.proc private_add_score
    CLC 
    ADC score_low
    STA score_low

    LDA score_low
    CMP #100             ; Check if score_low is >= 100
    BCC @no_carry        ; If less than 100, skip to no_carry

    SBC #100             ; Subtract 100 from score_low
    STA score_low        ; Update score_low with the new 10s and 1s
    INC score_high       ; Increment score_high (100s and 1000s)
@no_carry:

    ; LDA added_low
    ; CMP #100

    ; BCC :++

    ; SEC
    ; :
    ; INC added_high
    ; SBC #100
    ; CMP #100
    ; BCS :-

    ; :
    ; STA added_low
    ; CLC 
    ; ADC score_low
    ; ; BVC :+
    ; ; INC added_high
    ; ; :
    ; STA added_low

    ; LDA #100
    ; CMP added_low
    ; BCS :++


    ; SEC
    ; LDA added_low
    ; :
    ; INC added_high
    ; SBC #100
    ; CMP #100
    ; BCS :-
    ; STA added_low

    ; :
    ; LDA added_low
    ; STA score_low

    ; LDA added_high
    ; STA score_high
    RTS
.endproc
;*****************************************************************
