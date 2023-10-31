
module ip_codma_main_machine
import ip_codma_pkg::*;
(
        // controls and flags   
        input               clk_i,
        input               reset_n_i,    
        input               start_i,
        input               stop_i,
        output logic        busy_o,
        output logic        irq_o,
        input               rd_state_error,
        input               wr_state_error,        
        input [31:0]        task_pointer_i,
        input [31:0]        status_pointer_i,

        mem_interface.master bus_if,

        // Read Machine Req
        output logic [31:0] reg_addr,
        output logic [7:0]  reg_size,
        output logic        need_read_i,
        input               need_read_o,
        input [7:0][31:0]   data_reg,

        // Write Machine Req
        output logic [31:0]      reg_addr_wr,
        output logic [7:0]       reg_size_wr,       
        output logic             need_write_i,
        input                    need_write_o,
        output logic [7:0][31:0] write_data,

        // CRC flag
        input                    crc_flag_i,
        input read_state_t       rd_state_r,
        input read_state_t       rd_state_next_s,
        input write_state_t      wr_state_r,
        input write_state_t      wr_state_next_s,
        output dma_state_t       dma_state_r,
        output dma_state_t       dma_state_next_s               
    );
    
    
    
    // internal registers
    logic [3:0][31:0] task_dependant_data;
    logic [31:0] task_type;
    logic [31:0] destin_addr;
    logic [31:0] source_addr;
    logic [31:0] len_bytes;
    logic [31:0] task_pointer_s;

    always_comb begin
        dma_state_next_s    = dma_state_r;
        if (stop_i) begin
            dma_state_next_s = DMA_IDLE;
        end

        case(dma_state_r)

            //--------------------------------------------------
            // DMA IDLING
            //--------------------------------------------------
            DMA_IDLE:
            begin
                if (!busy_o && start_i) begin
                    dma_state_next_s = DMA_PENDING;
                end
            end

            //--------------------------------------------------
            // DMA READING THE POINTER ADDR (PENDING)
            //--------------------------------------------------
            DMA_PENDING:
            begin
                // once the task has been read from the pointer & status updated
                if (rd_state_next_s == RD_IDLE && wr_state_next_s == WR_IDLE) begin
                    dma_state_next_s = DMA_DATA_READ;
                end
            end

            
            //--------------------------------------------------
            // DMA READING THE INFO AT THE SECOND POINTER (LINK TASK)
            //--------------------------------------------------
            DMA_TASK_READ:
            begin
                if (rd_state_next_s == RD_IDLE) begin
                    dma_state_next_s = DMA_DATA_READ;
                end
            end

            
            //--------------------------------------------------
            // READING THE DATA AT THE SOURCE ADDR
            //--------------------------------------------------
            DMA_DATA_READ: // reads the source data
            begin
                // move operation
                if (rd_state_next_s == RD_IDLE) begin
                    if (task_type != 'd3) begin
                        dma_state_next_s = DMA_WRITING;
                    end else if (task_type == 'd3) begin
                        dma_state_next_s = DMA_CRC;
                    end
                end
            end

            
            //--------------------------------------------------
            // WRITING THE DATA TO THE DEST ADDR
            //--------------------------------------------------
            DMA_WRITING:
            begin
                if (wr_state_next_s == WR_IDLE) begin
                    if(len_bytes > 'd0 ) begin
                        dma_state_next_s = DMA_DATA_READ;
                    end else if(task_type != 'd2) begin
                        dma_state_next_s = DMA_IDLE;
                    end else if (task_type == 'd2) begin
                        dma_state_next_s = DMA_TASK_READ;
                    end
                end
            end

            
            //--------------------------------------------------
            // DMA COMPUTE PROVISIONS
            //--------------------------------------------------
            DMA_CRC:
            begin
                if(crc_flag_i) begin
                    dma_state_next_s = DMA_IDLE;
                end
            end

            
            //--------------------------------------------------
            // ERROR CASE FOR THE DMA
            //--------------------------------------------------
            DMA_ERROR:
            begin
                // once status has been updated to failed, return to Idle
                //if(wr_state_next_s == WR_IDLE)begin
                    dma_state_next_s = DMA_IDLE;
                //end
            end
            
            //--------------------------------------------------
            // UNUSED CASE FOR THE DMA
            //--------------------------------------------------
            DMA_UNUSED:
            begin
                dma_state_next_s = DMA_ERROR;
            end

        endcase
    end
    logic [31:0] debug_counter;
    always_ff @(posedge clk_i, negedge reset_n_i) begin
        //if(debug_counter<20) begin
        //    $display("DUT in %s - going to %s",dma_state_r, dma_state_next_s);
        //    debug_counter++;
        //end
        //--------------------------------------------------
        // RESET CONDITIONS
        //--------------------------------------------------
        if (!reset_n_i) begin
            debug_counter       <= 'd0;
            dma_state_r         <= DMA_IDLE;
            busy_o              <= 'd0;
            irq_o               <= 'd0;
            destin_addr         <= 'd0;
            len_bytes           <= 'd0;
            reg_addr            <= 'd0;
            task_dependant_data <= 'd0;
            reg_size            <= 'd0;
            reg_size_wr         <= 'd0;
            reg_addr_wr         <= 'd0;
            write_data          <= 'd0;
            need_read_i         <= 'd0;
            need_write_i        <= 'd0;
            source_addr         <= 'd0;   
            task_type           <= 'd0;
            task_pointer_s      <= 'd0; 

        //--------------------------------------------------
        // ERROR HANDLING (FROM BUS)
        //--------------------------------------------------
        end else if (bus_if.error || wr_state_error || rd_state_error || dma_state_next_s == DMA_UNUSED) begin
            dma_state_r     <= DMA_ERROR;
            need_read_i     <= 'd0;
            need_write_i    <= 'd1;
            write_data      <= 'd1;
            reg_size_wr     <= 'd3;
            reg_addr_wr     <= status_pointer_i;

        //--------------------------------------------------
        // RUNTIME OPERATIONS
        //--------------------------------------------------
        end else begin
            // MACHINE STATES
            dma_state_r <= dma_state_next_s;
            need_read_i <= need_read_o;
            need_write_i <= need_write_o;
    
            
            //------------------------------------------------------------------------
            // DMA IDLING
            //------------------------------------------------------------------------
            if (dma_state_next_s == DMA_IDLE) begin
                destin_addr <= 'd0;
                len_bytes   <= 'd0;
                irq_o       <= 'd0;
                
                //update the pointer (perhaps add an extra state or do this in writing state ?)
                /* if (dma_state_r == DMA_CRC || dma_state_r == DMA_WRITING) begin
                    need_write_i    <= 'd1;
                    write_data      <= 'h0;
                    reg_size_wr     <= 'd3;
                    reg_addr_wr     <= status_pointer_i;
                // Deassert busy and interrupt when done
                end else */ if (/*wr_state_next_s == WR_IDLE && */ busy_o) begin
                    irq_o   <= 'd1;
                    busy_o  <= 'd0;
                end

            //------------------------------------------------------------------------
            // DMA PENDING (update status ; queue a write) ; DMA LAUNCH (READING NEW TASK AT POINTER)
            //------------------------------------------------------------------------
            end else if (dma_state_next_s == DMA_PENDING) begin
                
                // When the dma first moves to the pending state
                if (dma_state_r == DMA_IDLE) begin
                busy_o          <= 'd1;            
                reg_addr        <= task_pointer_i;
                task_pointer_s  <= task_pointer_i;
                reg_size        <= 'd9;
                need_read_i     <= 'd1;
                // Queue the status write
                end else if (rd_state_r == RD_GRANTED) begin
                    need_write_i    <= 'd1;
                    write_data      <= 'hf;
                    reg_size_wr     <= 'd3;
                    reg_addr_wr     <= status_pointer_i;
                end               

            //------------------------------------------------------------------------
            // TASK 2 SPECIFIC STATE: READING LAST POINTER + 'd32
            //------------------------------------------------------------------------
            end else if (dma_state_next_s == DMA_TASK_READ) begin
                need_read_i     <= 'd1;
                reg_size        <= 'd9;
                reg_addr        <= task_pointer_s;
                if (dma_state_r == DMA_WRITING) begin
                    task_pointer_s  <= task_pointer_s + 'd32;
                end

            //------------------------------------------------------------------------
            // READING THE INFO AT THE SOURCE ADDR
            //------------------------------------------------------------------------
            end else if (dma_state_next_s == DMA_DATA_READ) begin
                
                need_read_i <= 'd1;
                // mid write cycle
                if (dma_state_r == DMA_WRITING && task_type == 'd0) begin
                    reg_addr    <= source_addr + 'd8;
                    source_addr <= source_addr + 'd8;
                    destin_addr <= destin_addr + 'd8;
                    // other values stay the same

                end else if (dma_state_r == DMA_WRITING && task_type != 'd0) begin
                    reg_addr    <= source_addr + 'd32;
                    source_addr <= source_addr + 'd32;
                    destin_addr <= destin_addr + 'd32;
                    // other values stay the same
            
                // first write cycle
                end else if (dma_state_r == DMA_PENDING || dma_state_r == DMA_TASK_READ) begin
                    task_type   <= data_reg[0];
                    reg_addr    <= data_reg[1];
                    source_addr <= data_reg[1];
                    destin_addr <= data_reg[2];
                    len_bytes   <= data_reg[3];
                    $display("DUT: task_type: %d src_addr: %d dst_addr:%d len_bytes: %d", data_reg[0], data_reg[1], data_reg[2], data_reg[3]);
                    // define burst size
                    // function of task type
                    if (data_reg[0] == 'd0) begin
                        reg_size_wr <= 'd3;

                    // Store task dependant data for CRC
                    end else if (data_reg[0] == 'd3) begin
                        task_dependant_data <= {data_reg[4],data_reg[5],data_reg[6],data_reg[7]};
                    
                    // Assuming anything other than task type 0 will require a quad-burst wr                        
                    end else if (data_reg[0] != 'd0) begin
                        reg_size_wr <= 'd9;
                    end
                end

                // Error Check
                if (task_type > 'd3) begin
                    // error - unrecognised task type
                    dma_state_r <= DMA_ERROR;
                    need_read_i     <= 'd0;
                    need_write_i    <= 'd1;
                    write_data      <= 'd1;
                    reg_size_wr     <= 'd3;
                    reg_addr_wr     <= status_pointer_i;
                end

            //------------------------------------------------------------------------
            // PERFORM THE WRITE OPERATION
            //------------------------------------------------------------------------
            end else if (dma_state_next_s == DMA_WRITING) begin
                need_read_i  <= 'd0;
                need_write_i <= 'd1;
                write_data   <= data_reg;
                reg_addr_wr   <= destin_addr;
                // reg_size stays the same
                if (wr_state_next_s == WR_IDLE) begin
                    if (reg_size_wr == 'd3) begin
                        len_bytes <= len_bytes - 'd8;
                    end else if (reg_size_wr == 'd8) begin
                        len_bytes <= len_bytes - 'd16;
                    end else if (reg_size_wr == 'd9) begin
                        len_bytes <= len_bytes - 'd32;
                    end
                    $display("len_bytes reduced to %d",len_bytes);
                end
            
            //------------------------------------------------------------------------
            // PERFORM THE DMA COMPUTE OPERATION (DIFFERENT MODULE)
            //------------------------------------------------------------------------
            end else if (dma_state_next_s == DMA_CRC) begin
                need_write_i <= 'd0;
                need_read_i  <= 'd0;
            end
        end
    end

endmodule