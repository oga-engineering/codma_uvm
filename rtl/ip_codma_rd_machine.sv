/*
Oliver Anderson
Univeristy of Bath
codma FYP 2023

This file contains the modules used for the read and write machines. 
I have attempted to keep all signals and states relative to these modules in this file
for better clarity. For hardware optimisation the two could be combined, however I am not sure
if this would allow for pipelining.
*/



//=======================================================================================
// READ MACHINE
//=======================================================================================
module ip_codma_read_machine
import ip_codma_pkg::*;
(
        input                       clk_i,
        input                       reset_n_i,
        output logic                rd_state_error,
        input                       need_read_i,
        output logic                need_read_o,
        input                       stop_i,
        output logic [7:0][31:0]    data_reg_o,
        mem_interface.master        bus_if,
        output  read_state_t        rd_state_r,
        output  read_state_t        rd_state_next_s,
        input   write_state_t       wr_state_r,
        input   write_state_t       wr_state_next_s,
        input   dma_state_t         dma_state_r,
        input   dma_state_t         dma_state_next_s        
    );
    
    
    
    logic [7:0]  word_count_rd;
    logic [63:0] old_data;
    logic [3:0]  rd_size;

    //--------------------------------------------------
    // FINITE STATE MACHINE
    //--------------------------------------------------
    always_comb begin
        rd_state_next_s = rd_state_r;

        if (stop_i) begin
            rd_state_next_s = RD_IDLE;
        end

        case(rd_state_r)
            RD_IDLE:
            begin
                if (need_read_i) begin
                    rd_state_next_s = RD_ASK;
                end
            end
            RD_ASK:
            begin
                if (bus_if.grant) begin
                    rd_state_next_s = RD_GRANTED;
                end
            end
            RD_GRANTED:
            begin
                // Looking for the word count to match expected words
                if (rd_size == 9 && word_count_rd == 8) begin
                    rd_state_next_s = RD_IDLE;
                end else if (rd_size == 8 && word_count_rd == 6) begin
                    rd_state_next_s = RD_IDLE;
                end else if (rd_size == 3 && word_count_rd == 2) begin
                    rd_state_next_s = RD_IDLE;
                end
            end
            // If in this state return to idle
            RD_UNUSED:
            begin
                rd_state_next_s = RD_IDLE;
            end
        endcase
    end
    
    //--------------------------------------------------
    // REGISTER OPERATIONS
    //--------------------------------------------------
    logic [31:0] debug_counter;
    always_ff @(posedge clk_i, negedge reset_n_i) begin
        
        //if (debug_counter < 20) begin
        //    $display("DUT: read machine is in %s - goin to %s",rd_state_r, rd_state_next_s);
        //    debug_counter++;
        //end
        if (!reset_n_i) begin
            debug_counter <= 0;
            rd_state_error <= 'd0;
            need_read_o   <= 'd0;
            data_reg_o    <= 'd0;
            word_count_rd <= 'd0;
            rd_size       <= 'd0;
            rd_state_r    <= RD_IDLE;

        //--------------------------------------------------
        // ERROR HANDLING (FROM BUS)
        //--------------------------------------------------
        end else if (bus_if.error || dma_state_r == DMA_ERROR) begin
            rd_state_r <= RD_IDLE;

        //--------------------------------------------------
        // NORMAL CONDITIONS
        //--------------------------------------------------
        end else begin
            rd_state_r  <= rd_state_next_s;
            if (rd_state_next_s == RD_IDLE) begin
                word_count_rd   <= 'd0;
                rd_size         <= 'd0;
                rd_state_error  <= 'd0;
            end else if (rd_state_next_s == RD_ASK) begin
                //$display("READ ASK");
                rd_size     <= bus_if.size;
                need_read_o   <= 'd0;
            
            end else if (rd_state_next_s == RD_GRANTED) begin
                need_read_o   <= 'd0;
                // count each valid
                if (bus_if.read_valid) begin
                    data_reg_o[word_count_rd]    <= bus_if.read_data[31:0];
                    data_reg_o[word_count_rd+1]  <= bus_if.read_data[63:32];
                    word_count_rd <= word_count_rd + 2;
                    //$display("Read in process, Word count at %d\nData Value: %h",word_count_rd, bus_if.read_data);
                end


            end else if (rd_state_next_s == RD_UNUSED) begin
                rd_state_error <= 'd1;
            end
        end
    end
endmodule


