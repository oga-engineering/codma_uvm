//=======================================================================================
// WRITE MACHINE
//=======================================================================================
module ip_codma_write_machine
import ip_codma_pkg::*;
(
        input                   clk_i,
        input                   reset_n_i,

        output logic            wr_state_error,

        input                   need_write_i,
        output logic            need_write_o,

        input                   stop_i,

        output logic [7:0]      word_count_wr,

        mem_interface.master    bus_if,

        input read_state_t      rd_state_r,
        input read_state_t      rd_state_next_s,
        output write_state_t    wr_state_r,
        output write_state_t    wr_state_next_s,
        input dma_state_t       dma_state_r,
        input dma_state_t       dma_state_next_s
    );

    //--------------------------------------------------
    // FINITE STATE MACHINE
    //--------------------------------------------------
    always_comb begin
        wr_state_next_s = wr_state_r;
        if (stop_i)begin
            wr_state_next_s = WR_IDLE;
        end
        case(wr_state_r)
           WR_IDLE:
           begin
               if (need_write_i) begin
                   wr_state_next_s = WR_ASK;
               end
           end
           WR_ASK:
           begin
               if (bus_if.grant) begin
                   wr_state_next_s = WR_GRANTED;
               end
           end
           WR_GRANTED:
           begin
               // write completed - look at words counted
               if (bus_if.size == 9 && word_count_wr == 6) begin
                   wr_state_next_s = WR_IDLE;
               end else if (bus_if.size == 8 && word_count_wr == 2)begin
                    wr_state_next_s = WR_IDLE;
               end else if (bus_if.size == 3 && word_count_wr == 0)begin
                    wr_state_next_s = WR_IDLE;
               end
           end
           // Broken state return to idle
           WR_UNUSED:
           begin
                wr_state_next_s = WR_IDLE;
           end
        endcase
    end

    //--------------------------------------------------
    // REGISTER OPERATIONS
    //--------------------------------------------------
    logic [31:0] debug_counter;
    always_ff @(posedge clk_i, negedge reset_n_i) begin

        //if(debug_counter<30) begin
        //    $display("DUT: write machine is in %s - going to %s",wr_state_r, wr_state_next_s);
        //    debug_counter++;
        //end

        if (!reset_n_i) begin
            debug_counter   <= 0;
            need_write_o    <= 'd0;
            wr_state_error  <= 'd0;
            wr_state_r      <= WR_IDLE;
        //--------------------------------------------------
        // ERROR HANDLING (FROM BUS)
        //--------------------------------------------------
        // Do not send to idle at dma error - must update status pointer addr
        end else if (bus_if.error) begin
            wr_state_r <= WR_IDLE;

        //--------------------------------------------------
        // NORMAL CONDITIONS
        //--------------------------------------------------
        end else begin
            wr_state_r  <= wr_state_next_s;
            if (wr_state_next_s == WR_IDLE) begin
                word_count_wr   <= 'd0;
                need_write_o    <= 'd0;
            end else if (wr_state_next_s == WR_ASK) begin
                need_write_o    <= 'd0;
            end else if (wr_state_r == WR_GRANTED) begin
                need_write_o    <= 'd0;
                word_count_wr   <= word_count_wr + 2; // used to track the data written in top level
                //$display("wr counter %d ; bus size %d",word_count_wr, bus_if.size);
            end else if (wr_state_next_s == WR_UNUSED) begin
                wr_state_error  <= 'd1;
            end
        end
    end
endmodule