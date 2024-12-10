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


; Queue data structure constants
QUEUE_CAPACITY = $FF ; the maximum capacity of the queue - actual  available size is capacity - 1
QUEUE_START = $061A ; start address for the queue 

.proc clear_queue
    LDA #0
    STA queue_head
    STA queue_tail
    RTS    
.endproc

; Item to enqueue is taken from register A.
.proc enqueue
    TAX ;save input val in X reg

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

        STA temp

        LDA queue_tail
        CLC
        ADC #<QUEUE_START       ; Add the low byte of FRONTIER_LIST_ADDRESS.
        STA paddr             ; Store the low byte of the calculated address.

        LDA #>QUEUE_START      ; Load the high byte of FRONTIER_LIST_ADDRESS.
        ADC #$00              ; Add carry if crossing a page boundary.
        STA paddr+1  

        ;Load the value from the pointer into X and Y
        LDY #0
        TXA
        STA (paddr), Y     

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
    LDA queue_head
    CLC
    ADC #<QUEUE_START       ; Add the low byte of FRONTIER_LIST_ADDRESS.
    STA paddr             ; Store the low byte of the calculated address.

    LDA #>QUEUE_START      ; Load the high byte of FRONTIER_LIST_ADDRESS.
    ADC #$00              ; Add carry if crossing a page boundary.
    STA paddr+1  
    
    ; Load the value from the calculated address into A (dequeued item)
    LDY #0
    LDA (paddr), Y

    ; update queue_head to point to next item
    LDA queue_head
    CLC
    ADC #1
    CMP #QUEUE_CAPACITY
    BNE @skip_wrap
        LDA #0 ;wrap around

    @skip_wrap:
        STA queue_head
        RTS
    @queue_empty: 
        ; for now do nothing
        RTS

    RTS
.endproc

;*****************************************************************