;*****************************************************************
; Score system
; high byte and low byte are manually capped to #99, not #$99
; low byte represents the tens and single digits, while high byte represents the hundreds and thousands
; max value of is the max 4 digit decimal number 9999
;*****************************************************************
.macro add_score amount

    LDA amount           ; Load the amount to be added
    JSR private_add_score
.endmacro

.segment "CODE"
.proc private_add_score
    CMP #100                ;check if amount is lower than 100 
    BCC @skip_hundreds      ;skip subtracting 100 if amount is lower than 100

    SEC
@hundreds_loop:
    INC added_high          ;subtract 100 from low byte to calculate carry into high byte
    SBC #100
    CMP #100
    BCS @hundreds_loop      ;subtract again if not yet smaller than 100

@skip_hundreds:
    STA added_low           
    CLC 
    ADC score_low           ;add our temp low byte value to the stored low byte
    STA added_low

    LDA added_low           ;check if it is bigger than 100 to do another carry subtraction
    CMP #100
    BCC @skip_hundreds_2

    SEC
    LDA added_low
@hundreds_loop_2:
    INC added_high
    SBC #100
    CMP #100
    BCS @hundreds_loop_2
    STA added_low

@skip_hundreds_2:
    LDA added_low           ;store end result
    STA score_low

    LDA added_high
    STA score_high

    RTS
.endproc
;*****************************************************************
