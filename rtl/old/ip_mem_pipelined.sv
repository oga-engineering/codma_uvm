module ip_mem_pipelined
#(

//=======================================================================================
// Parameter Defaults
//=======================================================================================

	parameter	MEM_DEPTH = 16,
	parameter	MEM_WIDTH = 8
)
(

//=======================================================================================
// Inputs/Outputs
//=======================================================================================

	// clock and reset
	input 		clk_i,
	input		reset_n_i,
	// bus interface
	BUS_IF.slave	bus_if
);

//=======================================================================================
// Local Signal Definition
//=======================================================================================

//--------------------------------------------------
// Memory
//--------------------------------------------------

logic	[MEM_DEPTH-1:0][MEM_WIDTH-1:0][7:0] mem_array;	// This is the actual array of memory, default is 16 double word lines (64-bits)

//--------------------------------------------------
// Address Phase Buffer FIFO
//--------------------------------------------------

// Define a type for holding Address Phase Information
typedef struct packed
{
  logic		read;
  logic		write;
  logic	[31:0]	addr;
  logic	[3:0]	size;
}
ap_info_t;

localparam NO_OF_AF_BUFFERS = 4;	// Number of FIFO buffers (min 1, max 7, value of 1 has same behaviour as previous memory version)

ap_info_t		ap_transaction_fifo_i;				// FIFO inputs
ap_info_t		ap_transaction_fifo_o;				// FIFO outputs
ap_info_t        	ap_transaction_fifo_r[NO_OF_AF_BUFFERS];	// FIFO internal buffers
ap_info_t        	ap_transaction_fifo_next_s[NO_OF_AF_BUFFERS];
logic               	ap_fifo_wr;					// Write to FIFO (push)
logic			ap_fifo_rd;					// Read from FIFO (pop)
logic 	[2:0]       	ap_rptr;					// FIFO read pointer
logic 	[2:0]       	ap_wptr;					// FIFO write pointer
logic 	[2:0]      	ap_wptr_next;
logic 	[2:0]      	ap_rptr_next;	
logic 	[2:0]		ap_fifo_count_r;				// FIFO count of stored transactions
logic 	[2:0]		ap_fifo_count_next_s;

//--------------------------------------------------
// Address Phase Logic & Error Checking 
//--------------------------------------------------

logic	[31:0]	ap_addr;
logic	[3:0] 	ap_txcnt;
logic 		ap_err;

//--------------------------------------------------
// Data Phase State Machine
//--------------------------------------------------

typedef enum logic [1:0]
{
  DP_IDLE	= 2'b00,			// No transaction in data phase 
  DP_RD_ACTIVE	= 2'b01,			// Read transaction currently in data phase
  DP_WR_ACTIVE	= 2'b10				// Write transaction currently in data phase
}
dp_state_t;
dp_state_t 		dp_state_r;		// Current data phase state
dp_state_t  		dp_state_next_s;	// Next data phase state
logic	[31:0]		dp_addr_r;		// Current address in memory being accessed
logic	[31:0]		dp_addr_next_s;		// Next address in memory to be accessed
logic	[3:0]		dp_txcnt_r;		// Number of double words left to read
logic	[3:0]		dp_txcnt_next_s;
logic			dp_err_r;		// Current error status
logic			dp_err_next_s;		// Next error status
logic			dp_busy_r;		// Flag to show data phase in progress
logic			dp_busy_next_s;
logic			dp_fifo_rd_r;			
logic			dp_fifo_rd_next_s;	// Flag to identify when fifo is read in order to pop it

//=======================================================================================
// Address Phase Buffer FIFO 
//=======================================================================================

//----------------------------------------------------------------------------------------------
// Input Assignment
//----------------------------------------------------------------------------------------------

// Package up inputs for fifo
assign ap_transaction_fifo_i.read 	= bus_if.read;
assign ap_transaction_fifo_i.write 	= bus_if.write;
assign ap_transaction_fifo_i.addr 	= bus_if.addr;
assign ap_transaction_fifo_i.size 	= bus_if.size;

//----------------------------------------------------------------------------------------------
// Fifo Counter
//----------------------------------------------------------------------------------------------

always_comb
begin
	if (ap_fifo_wr && ap_fifo_rd)
		ap_fifo_count_next_s		= ap_fifo_count_r; 			// wr and rd so count stays the same
	else if (ap_fifo_wr)
		ap_fifo_count_next_s		= ap_fifo_count_r + 3'b001; 		// wr only so increment count
	else if (ap_fifo_rd)
		ap_fifo_count_next_s		= ap_fifo_count_r - 3'b001; 		// rd only so decrement count
	else
		ap_fifo_count_next_s		= ap_fifo_count_r;			// default stays the same
end

//----------------------------------------------------------------------------------------------
// Fifo Write
//----------------------------------------------------------------------------------------------

// Need to use busy in order to keep same behaviour as previous mem version (compatible with our CPU) when NO_OF_AF_BUFFERS == 1
if (NO_OF_AF_BUFFERS == 1)
	assign ap_fifo_wr = ((ap_transaction_fifo_i.read || ap_transaction_fifo_i.write) && (ap_fifo_count_r < NO_OF_AF_BUFFERS) && (!bus_if.grant) && (!dp_busy_next_s));

// Otherwise busy is not required fifo with write and grant when there is space to store a transaction
else
	assign ap_fifo_wr = ((ap_transaction_fifo_i.read || ap_transaction_fifo_i.write) && (ap_fifo_count_r < NO_OF_AF_BUFFERS) && (!bus_if.grant));

always_comb
begin
	// defaults
	ap_transaction_fifo_next_s						= ap_transaction_fifo_r;
	ap_wptr_next								= ap_wptr;

	// fifo write
       	if  (ap_fifo_wr)
        begin
                ap_transaction_fifo_next_s[ap_wptr%NO_OF_AF_BUFFERS] 		= ap_transaction_fifo_i;		// write inputs into fifo
		ap_wptr_next          						= (ap_wptr+3'b001)%NO_OF_AF_BUFFERS;	// calculate next write pointer value
     	end
end

always_ff @(posedge clk_i or negedge reset_n_i)
begin
  	if (!reset_n_i)
    	begin
		for (int unsigned x = 0; x < NO_OF_AF_BUFFERS; x++)
      		ap_transaction_fifo_r[x]     	<= '0;
      		ap_fifo_count_r     		<= '0;
             	ap_wptr     			<= '0;
		bus_if.grant			<= '0;
    	end
  	else
    	begin
		ap_transaction_fifo_r		<= ap_transaction_fifo_next_s;
      		ap_fifo_count_r     		<= ap_fifo_count_next_s;
		ap_wptr				<= ap_wptr_next;
    	end 

	// Grant (implemented this way to keep the behaviour the same as the previous memory version)
	if (bus_if.grant)
		bus_if.grant			<= '0;	// reset grant if currently high
	else if (ap_fifo_wr)
		bus_if.grant			<= '1;	// otherwise grant on the cycle the address phase request is written to the FIFO
	else
		bus_if.grant			<= '0;	// otherwise reset grant (probably not required)
end  

//----------------------------------------------------------------------------------------------
// Fifo Read
//----------------------------------------------------------------------------------------------  

// The cycle the data phase state machine captures the current FIFO output the read is pulsed high to pop it ready for the next transaction
assign ap_fifo_rd = dp_fifo_rd_next_s;

always_comb
begin
	// default
	ap_rptr_next		= ap_rptr;
	
	// fifo read
	if (ap_fifo_rd)
	begin
		ap_rptr_next 	= (ap_rptr+3'b001)%NO_OF_AF_BUFFERS;	// calculate next read pointer value
	end
end

always_ff @ (posedge clk_i or negedge reset_n_i)
begin
  	if (!reset_n_i)
		ap_rptr     	<= '0;
  	else
		ap_rptr		<= ap_rptr_next;
end

//----------------------------------------------------------------------------------------------
// Fifo Outputs
//----------------------------------------------------------------------------------------------

assign ap_transaction_fifo_o.read 	= ap_transaction_fifo_r[ap_rptr%NO_OF_AF_BUFFERS].read;
assign ap_transaction_fifo_o.write 	= ap_transaction_fifo_r[ap_rptr%NO_OF_AF_BUFFERS].write;
assign ap_transaction_fifo_o.addr 	= ap_transaction_fifo_r[ap_rptr%NO_OF_AF_BUFFERS].addr;
assign ap_transaction_fifo_o.size 	= ap_transaction_fifo_r[ap_rptr%NO_OF_AF_BUFFERS].size;

//=======================================================================================
// Address Phase Logic & Error Checking 
//=======================================================================================

always_comb
begin
	// defaults
	ap_addr		= '0;
	ap_txcnt	= '0;
	ap_err		= '0;

	// Only active when there are transactions in the fifo to save power
	if (ap_fifo_count_r > 0)
	begin
		// Use size input to determine number of double words to write 
		if (ap_transaction_fifo_o.size == 3)
			ap_txcnt	= 4'b0001;	// 1 double word 
		else if (ap_transaction_fifo_o.size == 8)
			ap_txcnt	= 4'b0010;	// 2 double words
		else if (ap_transaction_fifo_o.size == 9)
			ap_txcnt	= 4'b0100;	// 4 double words
		else
			ap_err		= '1;		// Set error flag for unsupported size

		// Error if one of the write addresses is out of range
		if (ap_transaction_fifo_o.addr > ((MEM_DEPTH*MEM_WIDTH) - (ap_txcnt*MEM_WIDTH)))
			ap_err		= '1;				// Set error flag
		else
			ap_addr		= ap_transaction_fifo_o.addr;	// Only capture the starting write address if no error (power saving)
	end
end

//=======================================================================================
// Data Phase State Machine 
//=======================================================================================

always_comb
begin

//--------------------------------------------------
// Defaults Values to Retain Current State
//--------------------------------------------------

	// Defaults retain current state
	dp_state_next_s			= dp_state_r;
	dp_busy_next_s			= dp_busy_r;
	dp_txcnt_next_s			= dp_txcnt_r;
	dp_addr_next_s			= dp_addr_r;
	dp_err_next_s			= dp_err_r;
	dp_fifo_rd_next_s		= dp_fifo_rd_r;
	
//--------------------------------------------------
// Data Phase State Logic: Idle
//--------------------------------------------------

	case (dp_state_r)

		DP_IDLE:
		begin	
			// If the FIFO contrains at least 1 transaction
			if (ap_fifo_count_r > 0)
			begin
				dp_addr_next_s		= ap_addr;	// capture address
				dp_txcnt_next_s		= ap_txcnt;	// capture transaction count
				dp_err_next_s		= ap_err;	// capture error status
				dp_busy_next_s		= '1;		// activate busy (only used for FIFO size of 1 to keep same functionality as previous memory version)
				dp_fifo_rd_next_s	= '1;		// pulse read high for one cycle to pop captured outputs from FIFO
				
				if (ap_transaction_fifo_o.read)
					dp_state_next_s	= DP_RD_ACTIVE;	// move to read data phase if the captured transaction is a read
				else if (ap_transaction_fifo_o.write)
					dp_state_next_s = DP_WR_ACTIVE; // move to write data phase if the captured transaction is a write
			end
		end

//--------------------------------------------------
// Data Phase Logic: Read 
//--------------------------------------------------

		DP_RD_ACTIVE:
		begin
			dp_fifo_rd_next_s		= '0;

			// If there is an error
			if (dp_err_r)
			begin
				// See IDLE case for comments
				if (ap_fifo_count_r > 0)
				begin
					dp_addr_next_s		= ap_addr;
					dp_txcnt_next_s		= ap_txcnt;
					dp_err_next_s		= ap_err;
					dp_busy_next_s		= '1;
					dp_fifo_rd_next_s	= '1;
				
					if (ap_transaction_fifo_o.read)
						dp_state_next_s	= DP_RD_ACTIVE;
					else if (ap_transaction_fifo_o.write)
						dp_state_next_s = DP_WR_ACTIVE;
				end
				else
				begin
					dp_err_next_s		= '0;		// Reset error
					dp_busy_next_s		= '0;		// Reset busy ready for next transaction
					dp_state_next_s 	= DP_IDLE;	// Move read state back to idle ready for next transaction
				end
			end
			
			// If reads left is more than 0 and there is no read error
			else if (dp_txcnt_r > 0)
			begin
				dp_txcnt_next_s		= dp_txcnt_r - 4'b0001;		// Decrement number of reads left by 1
				dp_addr_next_s		= dp_addr_r + MEM_WIDTH;	// Increment address by MEM_WIDTH
				
				// If reads left is 1 then it is the last read
				if (dp_txcnt_next_s == 0)
				begin	
					// See IDLE case for comments
					if (ap_fifo_count_r > 0)
					begin
						dp_addr_next_s		= ap_addr;
						dp_txcnt_next_s		= ap_txcnt;
						dp_err_next_s		= ap_err;
						dp_busy_next_s		= '1;
						dp_fifo_rd_next_s	= '1;
				
						if (ap_transaction_fifo_o.read)
							dp_state_next_s	= DP_RD_ACTIVE;
						else if (ap_transaction_fifo_o.write)
							dp_state_next_s = DP_WR_ACTIVE;
					end
					else
					begin
						dp_busy_next_s		= '0;		// Reset busy ready for next transaction
						dp_state_next_s 	= DP_IDLE;	// Move read state back to idle ready for next transaction
					end
				end
			end
		end

//--------------------------------------------------
// Data Phase Logic: Write 
//--------------------------------------------------

		DP_WR_ACTIVE:
		begin
			dp_fifo_rd_next_s		= '0;
			
			// If there is an error
			if (dp_err_r)
			begin
				// See IDLE case for comments
				if (ap_fifo_count_r > 0)
				begin
					dp_addr_next_s		= ap_addr;
					dp_txcnt_next_s		= ap_txcnt;
					dp_err_next_s		= ap_err;
					dp_busy_next_s		= '1;
					dp_fifo_rd_next_s	= '1;
				
					if (ap_transaction_fifo_o.read)
						dp_state_next_s	= DP_RD_ACTIVE;
					else if (ap_transaction_fifo_o.write)
						dp_state_next_s = DP_WR_ACTIVE;
				end
				else
				begin
					dp_err_next_s		= '0;		// Reset error
					dp_busy_next_s		= '0;		// Reset busy ready for next transaction
					dp_state_next_s 	= DP_IDLE;	// Move read state back to idle ready for next transaction
				end
			end

			// If writes left is more than 0, write data is valid and there is no write error
			else if ((dp_txcnt_r > 0) && (bus_if.write_valid == 1))
			begin
				dp_txcnt_next_s		= dp_txcnt_r - 4'b0001;		// Decrement writes left by 1
				dp_addr_next_s		= dp_addr_r + MEM_WIDTH;	// Increment address by MEM_WIDTH
			end

			// If writes left is 0 then the last write has completed
			if (dp_txcnt_next_s == 0)
			begin
				// See IDLE case for comments
				if (ap_fifo_count_r > 0)
				begin
					dp_addr_next_s		= ap_addr;
					dp_txcnt_next_s		= ap_txcnt;
					dp_err_next_s		= ap_err;
					dp_busy_next_s		= '1;
					dp_fifo_rd_next_s	= '1;
			
					if (ap_transaction_fifo_o.read)
						dp_state_next_s	= DP_RD_ACTIVE;
					else if (ap_transaction_fifo_o.write)
						dp_state_next_s = DP_WR_ACTIVE;
				end
				else
				begin
					dp_busy_next_s		= '0;		// Reset busy ready for next transaction
					dp_state_next_s 	= DP_IDLE;	// Move read state back to idle ready for next transaction
				end
			end
		end
	endcase
end

//--------------------------------------------------
// Data Phase State Registers 
//--------------------------------------------------

always_ff @(posedge clk_i or negedge reset_n_i) 
begin
	if (!reset_n_i) 
	begin	
		// Reset values
		mem_array 			<= '0;
		dp_state_r			<= DP_IDLE;
		dp_busy_r			<= '0;
		dp_txcnt_r			<= '0;
		dp_addr_r			<= '0;
		dp_err_r			<= '0;
		dp_fifo_rd_r			<= '0;
		bus_if.read_data		<= '0;
		bus_if.read_valid		<= '0;
		bus_if.error			<= '0;
	end
	else 
	begin
		// Clock next value into registers
		dp_state_r			<= dp_state_next_s;
		dp_busy_r			<= dp_busy_next_s;
		dp_txcnt_r			<= dp_txcnt_next_s;
		dp_addr_r			<= dp_addr_next_s;
		dp_err_r			<= dp_err_next_s;
		dp_fifo_rd_r			<= dp_fifo_rd_next_s;

//--------------------------------------------------
// Write Data Phase Outputs 
//--------------------------------------------------

		// If data phase state is a write and write data is valid
		if ((dp_state_r == DP_WR_ACTIVE) && (bus_if.write_valid == 1))
		begin
			mem_array[dp_addr_r[31:3]]	<= bus_if.write_data;	// Write data to memory
		end

//--------------------------------------------------
// Read Data Phase Outputs 
//--------------------------------------------------

		// If data phase state is a read
		if (dp_state_next_s == DP_RD_ACTIVE)
		begin
			// If there is a read error no read data used
			if (dp_err_next_s)
				bus_if.read_valid	<= '1;					// Activate read valid signal when there is an error

			// Output read data as normal when no error present
			else
			begin
				bus_if.read_data	<= mem_array[dp_addr_next_s[31:3]];	// Output read data to bus
				bus_if.read_valid	<= '1;					// Activate read valid signal			
			end
		end
		// Data phase finished
		else
		begin
			bus_if.read_valid		<= '0;					// Reset read valid signal after read is finished	
		end

//--------------------------------------------------
// Error Data Phase Output 
//--------------------------------------------------

		bus_if.error				<= dp_err_next_s;
	end
end

endmodule
