;*****************************************************************
; Score system
;*****************************************************************
.macro add_score amount

    LDA amount
    STA added_low

    JSR private_add_score

.endmacro

.segment "CODE"
.proc private_add_score
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
    RTS
.endproc
;*****************************************************************
