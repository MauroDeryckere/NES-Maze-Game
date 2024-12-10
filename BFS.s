.include "Queue.s"

;*****************************************************************
; Breadth first search algorithm code
;*****************************************************************
.proc init_BFS
    ;Initialize the visited cells buffer in memory as 0 (unvisited)

    LDX #VISITED_BUFFER_SIZE
    LDA #$FF

    @clear_cell: 
        STA VISISTED_ADDRESS, x
        DEX
        BNE @clear_cell

    RTS
.endproc

;*****************************************************************