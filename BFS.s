.include "Queue.s"

;*****************************************************************
; Breadth first search algorithm code
;*****************************************************************
.macro set_tile_dir Direction
    set_direction frontier_row, frontier_col, Direction
.endmacro

.proc init_BFS
    ;set start values
    LDA #0
    STA move_count
    ; STA nodes_next_layer

    STA is_backtracking

    ; LDA #1
    ; STA nodes_left_layer


    ;clear the queue
    JSR clear_queue

    ;Initialize the visited cells buffer in memory as 0 (unvisited)
    LDX #0
    LDA #$00

    @clear_cell: 
        STA VISISTED_ADDRESS, x
        INX
        CPX #VISITED_BUFFER_SIZE
        BNE @clear_cell


    ;clear directions buffer
    LDX #0
    LDA #$00

    @clear_dir: 
        STA DIRECTIONS_ADDRESS, x
        INX
        CPX #DIRECTIONS_BUFFER_SIZE
        BNE @clear_dir
    RTS
.endproc

.proc start_BFS
    JSR init_BFS

    ; add start row and col to queue
    LDA player_row
    STA frontier_row
    JSR enqueue
    LDA player_collumn
    STA frontier_col
    JSR enqueue

    ; add start row and col to the visited buffer
    JSR visit_tile

    RTS
.endproc

.proc step_BFS
    ;algorithm ends when queue is empty
    LDA is_backtracking
    CMP #1
    BNE :+
        JMP @end_reached
    :

    JSR is_empty
    CMP #1
    BNE :+
        JMP @end_reached
    :

    JSR dequeue
    STA frontier_row

    JSR dequeue
    STA frontier_col

    ;check if we reached end
    CMP end_col
    BNE @next
    LDA frontier_row
    CMP end_row
    BNE @next

    JMP @end_reached

    @next: 
        ;explore neighbors
        @topn: 
            LDA frontier_row
            CMP #0
            BNE :+
                JMP @rightn
            :
                DEC frontier_row
                is_visited frontier_row, frontier_col
                CMP #0
                BEQ :+
                    JMP @inc_t
                :

                get_map_tile_state frontier_row, frontier_col
                CMP #0
                BEQ @inc_t
                    LDA frontier_row
                    JSR enqueue
                    LDA frontier_col
                    JSR enqueue
                    JSR visit_tile
                    
                    ; in case its a valid tile
                    ; set direction for the neewly visited cell (enqueued) to the direction of dequeued cell
                    set_tile_dir #BOTTOM_D

                    ; INC nodes_next_layer
                @inc_t: 
                INC frontier_row
        @rightn: 
            LDA frontier_col
            CMP #31
            BNE :+
                JMP @bottomn
            :
                INC frontier_col

                is_visited frontier_row, frontier_col
                CMP #0
                BEQ :+
                    JMP @dec_r
                :

                get_map_tile_state frontier_row, frontier_col
                CMP #0
                BEQ @dec_r
                    LDA frontier_row
                    JSR enqueue
                    LDA frontier_col
                    JSR enqueue
                    JSR visit_tile

                    ; in case its a valid tile
                    ; set direction for the neewly visited cell (enqueued) to the direction of dequeued cell
                    set_tile_dir #LEFT_D

                    ; INC nodes_next_layer

                @dec_r: 
                DEC frontier_col
        @bottomn: 
            LDA frontier_row
            CMP #29
            BNE :+
                JMP @leftn
            :
                INC frontier_row

                is_visited frontier_row, frontier_col
                CMP #0
                BEQ :+
                    JMP @inc_b
                :

                get_map_tile_state frontier_row, frontier_col
                CMP #0
                BEQ @inc_b
                    LDA frontier_row
                    JSR enqueue
                    LDA frontier_col
                    JSR enqueue
                    JSR visit_tile
                    ; in case its a valid tile
                    ; set direction for the neewly visited cell (enqueued) to the direction of dequeued cell
                    set_tile_dir #TOP_D

                    ; INC nodes_next_layer

                @inc_b:
                DEC frontier_row

        @leftn: 
            LDA frontier_col
            CMP #0
            BNE :+
                JMP @nnstep
            :
                DEC frontier_col

                is_visited frontier_row, frontier_col
                CMP #0
                BEQ :+
                    JMP @inc_l
                :

                get_map_tile_state frontier_row, frontier_col
                CMP #0
                BEQ @inc_l
                    LDA frontier_row
                    JSR enqueue
                    LDA frontier_col
                    JSR enqueue
                    JSR visit_tile
                    ; in case its a valid tile
                    ; set direction for the neewly visited cell (enqueued) to the direction of dequeued cell
                    set_tile_dir #RIGHT_D

                    ; INC nodes_next_layer

                @inc_l: 
                INC frontier_col

        @nnstep: 
            ; only necessary when using algorithm with possibility to have no solutions, out maze always has a solution
            ; DEC nodes_left_layer
            ; LDA nodes_left_layer
            ; CMP #0
            ; BNE :+
            ;     LDA nodes_next_layer
            ;     STA nodes_left_layer

            ;     LDA #0
            ;     STA nodes_next_layer

                INC move_count
            ; :

            RTS

    @end_reached: 
        ; start backtracking path
        LDA is_backtracking 
        CMP #0
        BEQ :+
            JMP skip_initial_step
        : 

        LDA #1
        STA is_backtracking

        add_to_changed_tiles_buffer end_row, end_col, #5
        get_direction end_row, end_col

        LDA end_row
        STA frontier_row
        LDA end_col
        STA frontier_col

        CMP #TOP_D
        BNE :+
            DEC frontier_row
            JMP end_step_1
        :
        CMP #RIGHT_D
        BNE :+
            INC frontier_col
            JMP end_step_1
        :
        CMP #BOTTOM_D
        BNE :+
            INC frontier_row
            JMP end_step_1
        :
        ;left direction
        DEC frontier_col

        end_step_1: 
            add_to_changed_tiles_buffer frontier_row, frontier_col, #5
            RTS

        skip_initial_step: 
            LDA player_row
            CMP frontier_row
            BNE :+
                
                LDA player_collumn
                CMP frontier_col
                BNE :+
                    ; LOAD in A TODO
                RTS
            :

            get_direction frontier_row, frontier_col
            CMP #TOP_D
            BNE :+
                DEC frontier_row
                JMP @end_step
            :
            CMP #RIGHT_D
            BNE :+
                INC frontier_col
                JMP @end_step
            :
            CMP #BOTTOM_D
            BNE :+
                INC frontier_row
                JMP @end_step
            :
            
            ;left direction
            DEC frontier_col

        @end_step: 
            add_to_changed_tiles_buffer frontier_row, frontier_col, #5
            RTS
.endproc

.proc visit_tile
    set_visited frontier_row, frontier_col
    add_to_changed_tiles_buffer frontier_row, frontier_col, #3
    RTS
.endproc

;*****************************************************************