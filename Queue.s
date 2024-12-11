;*****************************************************************
; Queue code
;*****************************************************************
; The queue is a circular queue to avoid the moving of memory (limited possibility to do this in 6502)
; Make sure the queue capacity that is reserved is sufficient when using this for certain algorithms that require you to maintain all items in the queue.
; Note: the queue uses one extra byte at the end to be able to distinguish between full and empty without storing additonal flags / adding extra loggic (N-1 usable slots)

; Example of how the queue data structure works: 
; Initial state - empty: 
; queue_head = 0
; queue_tail = 0

; Enqueue 42
; queue_head = 0
; queue_tail = 1
; [ 42 ][ ?? ][ ?? ]

; Enqueue 43
; queue_head = 0
; queue_tail = 2
; [ 42 ][ 43 ][ ?? ]

; Dequeue 
; queue_head = 1
; queue_tail = 2
; [ ?? ][ 43 ][ ?? ]

; Example of what happens when we need to wrap around in the circular queue: 
; initial state: 
; queue_head = 1
; queue_tail = 4
; [ ?? ][ 43 ][ 50 ][ 60 ][ ?? ] 

; Enqueue 70 
; queue_head = 1 
; queue_tail = 0 - wrapped around to 0
; [ 70 ][ 43 ][ 50 ][ 60 ][ ?? ]  ; note: last slot remains [??] - reserve one to distinguish between empty and full


; stores is queue is empty or not in A register
.proc is_empty
    LDA queue_head 
    CMP queue_tail
    BEQ @empty
    LDA #0
    RTS

    @empty:
        LDA #1
        RTS 
.endproc

.proc clear_queue
    LDA #0
    STA queue_head
    STA queue_tail
    RTS    
.endproc

; Item to enqueue is taken from register A.
.proc enqueue
    TAY ;save input val in Y reg

    ; check if queue is full
    LDA queue_tail
    CLC
    ADC #1
    CMP #QUEUE_CAPACITY ; tail + 1 == size -> wrap around
    BNE @skip_wrap
        LDA #0 ;wrap around if we hit queue capacity

    @skip_wrap: 
        CMP queue_head
        BEQ @queue_full ;next position == head means the queue is full

        STA temp ;temporarily store the new tal

        TYA ;value to enqueue -> A reg
        LDX queue_tail
        STA QUEUE_START, X

        LDA temp
        STA queue_tail

    @queue_full: 
        ;do nothing when queue is full for now
        RTS
.endproc

; dequeued item is loaded into A register
.proc dequeue 
    ;check if queue is empty
    LDA queue_head
    CMP queue_tail
    BEQ @queue_empty
    ; load val from front of queue
    LDX queue_head
    LDA QUEUE_START, X
    TAY

    ;store clear value for debugging purposes
    LDA #$FF
    STA QUEUE_START, X

    ; update queue_head to point to next item
    LDA queue_head
    CLC
    ADC #1
    CMP #QUEUE_CAPACITY
    BNE @skip_wrap
        LDA #0 ;wrap around

    @skip_wrap:
        STA queue_head
        TYA
        RTS
    @queue_empty: 
        ; for now do nothing
        RTS

    RTS
.endproc

;*****************************************************************