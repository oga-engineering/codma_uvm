// Module for the compute CRC code implementation
import ip_codma_pkg::*;
module ip_codma_crc (
        input                       clk_i,
        input                       reset_n_i,
        input        [7:0][31:0]    data_reg,
        output logic                crc_complete_flag,
        output logic [7:0][31:0]    crc_output
    );

    // Create or use input for generator polynomial: x^16 + x^15 + x^2 + 1 (also known as CRC-16-CCITT).
    logic [16:0] generator_polynomial;
    //assign generator_polynomial = 'b0101010101010101;
    assign generator_polynomial   = 'b11000000000100001;

    // Dev purposes test message
    logic [15:0] test_msg;
    //assign test_msg = 'b11000010;
    assign test_msg = 'h69f2;
    //assign test_msg = 'hc2;

    // Used to assign zeros to the codeword(same length as remainder)
    logic [15:0] zeros;
    assign zeros = 'b00000000;
    
    // The codeword with message and appended zeros
    logic [31:0]codeword;
    assign codeword = {test_msg,zeros};
    
    // Assign the remainder
    logic [15:0] remainder;
    assign remainder = codeword % generator_polynomial;   

    // Will take the value of the shift reg once cycle has gone through
    logic [15:0] crc_result;

    // Index and Shift Register
    logic [7:0] index;
    logic [16:0] shift_reg;

    // Possibly make a state machine for this ?

    always_ff @(posedge clk_i, negedge reset_n_i) begin
        if(!reset_n_i)begin
            crc_output          <= 'd0;
            crc_complete_flag   <= 'd0;
            crc_result          <= 'd0;
            index               <= 'd31;
            shift_reg           <= 'd0;
        end else begin

            // In operation
            /* if (index == 'd31) begin
                shift_reg <= codeword[31:7];
                index <= index - 1;
            end else */ if (index != 'd0) begin
                /* 
                Flipping the bits with XOR. There must be a more
                effective and easier way than this ?  
                Binary Rep: 0101010101010101
                */
                if (shift_reg[16] == 'b1) begin
                    shift_reg[16] <= shift_reg[16] ^ 'b1;
                    shift_reg[15] <= shift_reg[15] ^ 'b1; 
                    shift_reg[2]  <= shift_reg[2] ^ 'b1; 
                    shift_reg[0]  <= shift_reg[0] ^ 'b1; 
                end else begin
                    // Shift register
                    shift_reg <= shift_reg << 1;
                    shift_reg[0] <= codeword[index];
                    index <= index - 1;
                end
            
            // Finished cycle
            end else begin
                crc_complete_flag <= 'b1;
                index       <= 'd31;
                crc_result  <= shift_reg;

                if (remainder == shift_reg) begin
                    //$display("pass - no errors");
                end else begin
                    //$display("fail - remainder and calc val are different");
                end

            end
        end
    end
endmodule