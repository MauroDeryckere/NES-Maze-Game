;*****************************************************************
; Test code
;*****************************************************************
.proc test_frontier
;     loop: 
;         LDA frontier_listQ2_size
;         CMP #0
;         BEQ :+
;         JMP l2
;         :
;             add_to_Frontier #$FF, #$FF
;             JMP loop

;     l2:
;   ;  add_to_Frontier #$AA, #$AA

;     remove_from_Frontier #0, #10
;     remove_from_Frontier #1, #0

;     ;add_to_Frontier #$AA, #$AA

    add_to_Frontier #0, #1
    add_to_Frontier #4, #5
    add_to_Frontier #4, #5
    add_to_Frontier #5, #5
    add_to_Frontier #8, #5
    add_to_Frontier #1, #0

    LDA #0
    STA a_val

    exists_in_Frontier #0, #0
    STA a_val

    RTS

.endproc

.proc test_queue

    JSR clear_queue

    @l: 

    LDA #1
    JSR enqueue

    LDA queue_tail 
    CMP #$FE

    BEQ @done

    JMP @l

    @done: 
    JSR dequeue
    JSR dequeue
    JSR dequeue
    ; LDA #2
    ; JSR enqueue
    ; LDA #2
    ; JSR enqueue
    ; LDA #2
    ; JSR enqueue   
    ; LDA #2
    ; JSR enqueue
    ; LDA #2
    ; JSR enqueue

    RTS

.endproc
;*****************************************************************