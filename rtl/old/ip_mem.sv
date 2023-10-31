module ip_mem
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
// Read State Machine
//--------------------------------------------------

typedef enum logic [1:0]
{
  RD_IDLE	= 2'b00,				// No read transaction 
  RD_AP_ACTIVE 	= 2'b01,				// Read transaction currently in address phase
  RD_DP_ACTIVE	= 2'b10					// Read transaction currently in data phase
}
read_state_t;
read_state_t 		rd_state_r;			// Current read state
read_state_t  		rd_state_next_s;		// Next read state
logic	[3:0]		rd_txcnt_r;			// Number of double words left to read
logic	[3:0]		rd_txcnt_next_s;		
logic	[31:0]		rd_addr_r;			// Current address in memory being read
logic	[31:0]		rd_addr_next_s;			// Next address in memory to be read
logic			rd_err_r;			// Current read error status
logic			rd_err_next_s;			// Next read error status
logic			rd_gnt_r;			// Current read grant status
logic			rd_gnt_next_s;			// Next read grant status
logic			rd_busy_r;			// Flag to show read in progress
logic			rd_busy_next_s;

//--------------------------------------------------
// Write State Machine
//--------------------------------------------------

typedef enum logic [1:0]
{
  WR_IDLE	= 2'b00,				// No write transaction 
  WR_AP_ACTIVE 	= 2'b01,				// Write transaction currently in address phase
  WR_DP_ACTIVE	= 2'b10					// Write transaction currently in data phase
}
write_state_t;
write_state_t 		wr_state_r;			// Current write state
write_state_t  		wr_state_next_s;		// Next write state
logic	[3:0]		wr_txcnt_r;			// Number of double words left to write
logic	[3:0]		wr_txcnt_next_s;		
logic	[31:0]		wr_addr_r;			// Current address in memory being written
logic	[31:0]		wr_addr_next_s;			// Next address in memory to be written
logic			wr_err_r;			// Current write error status
logic			wr_err_next_s;			// Next write error status
logic			wr_gnt_r;			// Current write grant status
logic			wr_gnt_next_s;			// Next write grant status
logic			wr_busy_r;			// Flag to show write in progress
logic			wr_busy_next_s;

//--------------------------------------------------
// Other
//--------------------------------------------------

logic			busy_r;				// Flag to show read or write in progress
logic	[2:0]		grant_delay;			// Signal used to randomise grant timing for transactions to simulate a real system		

//=======================================================================================
// Read State Machine 
//=======================================================================================

always_comb
begin

//--------------------------------------------------
// Defaults Values to Retain Current State
//--------------------------------------------------

	// Defaults retain current state
	rd_state_next_s			= rd_state_r;
	rd_busy_next_s			= rd_busy_r;
	rd_txcnt_next_s			= rd_txcnt_r;
	rd_addr_next_s			= rd_addr_r;
	rd_err_next_s			= rd_err_r;
	rd_gnt_next_s			= rd_gnt_r; 
	
//--------------------------------------------------
// Read State Logic: Idle
//--------------------------------------------------

	case (rd_state_r)

		RD_IDLE:
		begin
			// If we see a read input on the bus and we are not currently busy doing a read or a write
			if (bus_if.read && !busy_r)
			begin
				rd_state_next_s 		= RD_AP_ACTIVE;	// Move to address phase state
				rd_busy_next_s			= '1;		// Set read busy high to prevent any more transactions being granted
			end
		end

//--------------------------------------------------
// Read State Logic: Address Phase 
//--------------------------------------------------

		RD_AP_ACTIVE:
		begin			
			// Only grant when grant delay is equal to 111
			if (grant_delay == 3'b111)
			begin
				// Use size input to determine number of double words to read
				if (bus_if.size == 3)
				begin
					rd_txcnt_next_s	= 4'b0001;	// 1 double word 
				end
				else if (bus_if.size == 8)
				begin
					rd_txcnt_next_s	= 4'b0010;	// 2 double words
				end
				else if (bus_if.size == 9)
				begin
					rd_txcnt_next_s	= 4'b0100;	// 4 double words
				end
				else
				begin
					rd_err_next_s	= '1;		// Set error flag for unsupported size
				end

				// Error if one of the read addresses is out of range
				if (bus_if.addr > ((MEM_DEPTH*MEM_WIDTH) - (rd_txcnt_next_s*MEM_WIDTH)))
				begin 
					rd_err_next_s	= '1;			// Set error flag for out of range address
				end
				else
				begin
					rd_addr_next_s	= bus_if.addr;		// Only capture the starting read address if no error (power saving)
				end
				
				rd_gnt_next_s		= '1;			// Grant read
				rd_state_next_s 	= RD_DP_ACTIVE;		// Move read state to data phase
			end
		end

//--------------------------------------------------
// Read State Logic: Data Phase 
//--------------------------------------------------

		RD_DP_ACTIVE:
		begin
			// Reset grant so it is only active for 1 cycle
			rd_gnt_next_s			= '0;

			// If there is a read error
			if (rd_err_r)
			begin
				rd_err_next_s		= '0;		// Reset error
				rd_busy_next_s		= '0;		// Reset busy ready for next transaction
				rd_state_next_s 	= RD_IDLE;	// Move read state back to idle ready for next transaction
			end
			
			// If reads left is more than 0 and there is no read error
			else if (rd_txcnt_r > 0)
			begin
				rd_txcnt_next_s		= rd_txcnt_r - 4'b0001;		// Decrement number of reads left by 1
				rd_addr_next_s		= rd_addr_r + MEM_WIDTH;	// Increment address by MEM_WIDTH
				
				// If reads left is 1 then it is the last read
				if (rd_txcnt_next_s == 0)
				begin
					// If there's another read waiting to be completed
					if (bus_if.read)
					begin
						rd_state_next_s 	= RD_AP_ACTIVE;		// Pipeline straight to read address phase
					end
					else
					begin
						rd_busy_next_s		= '0;			// Reset busy ready for next transaction
						rd_state_next_s 	= RD_IDLE;		// Move read state back to idle ready for next transaction
					end
				end
			end
		end
	endcase
end

//--------------------------------------------------
// Read State Registers 
//--------------------------------------------------

always_ff @(posedge clk_i or negedge reset_n_i) 
begin
	if (!reset_n_i) 
	begin	
		// Reset values
		rd_state_r			<= RD_IDLE;
		rd_busy_r			<= '0;
		rd_txcnt_r			<= '0;
		rd_addr_r			<= '0;
		rd_err_r			<= '0;
		rd_gnt_r			<= '0;
		bus_if.read_data		<= '0;
		bus_if.read_valid		<= '0;

	end
	else 
	begin
		// Clock next value into registers
		rd_state_r			<= rd_state_next_s;
		rd_busy_r			<= rd_busy_next_s;
		rd_txcnt_r			<= rd_txcnt_next_s;
		rd_addr_r			<= rd_addr_next_s;
		rd_err_r			<= rd_err_next_s;
		rd_gnt_r			<= rd_gnt_next_s;

//--------------------------------------------------
// Read Data Phase Outputs 
//--------------------------------------------------

		// If read state is in data phase
		if (rd_state_next_s == RD_DP_ACTIVE)
		begin
			// If there is a read error no read data used
			if (rd_err_next_s)
			begin
				bus_if.read_valid	<= '1;					// Activate read valid signal (with error signal)
			end

			// Output read data as normal when no error present
			else
			begin
				bus_if.read_data	<= mem_array[rd_addr_next_s[31:3]];	// Output read data to bus
				bus_if.read_valid	<= '1;					// Activate read valid signal			
			end
		end
		// Data phase finished
		else
		begin
			bus_if.read_valid	<= '0;						// Reset read valid signal	
		end
	end
end

//=======================================================================================
// Write State Machine 
//=======================================================================================

always_comb
begin

//--------------------------------------------------
// Defaults Values to Retain Current State
//--------------------------------------------------

	// Defaults retain current state
	wr_state_next_s			= wr_state_r;
	wr_busy_next_s			= wr_busy_r;
	wr_txcnt_next_s			= wr_txcnt_r;
	wr_addr_next_s			= wr_addr_r;
	wr_err_next_s			= wr_err_r;
	wr_gnt_next_s			= wr_gnt_r; 
	
//--------------------------------------------------
// Write State Logic: Idle
//--------------------------------------------------

	case (wr_state_r)

		WR_IDLE:
		begin
			// If we see a write input on the bus and we are not currently busy doing a read or a write
			if (bus_if.write && !busy_r)
			begin
				wr_state_next_s 		= WR_AP_ACTIVE;	// Move to address phase state
				wr_busy_next_s			= '1;		// Set write busy high to prevent any more transactions being granted
			end
		end

//--------------------------------------------------
// Write State Logic: Address Phase 
//--------------------------------------------------

		WR_AP_ACTIVE:
		begin
			// Only grant when grant delay is equal to 1111
			if (grant_delay == 3'b111)
			begin
				// Use size input to determine number of double words to write 
				if (bus_if.size == 3)
				begin
					wr_txcnt_next_s	= 4'b0001;	// 1 double word 
				end
				else if (bus_if.size == 8)
				begin
					wr_txcnt_next_s	= 4'b0010;	// 2 double words
				end
				else if (bus_if.size == 9)
				begin
					wr_txcnt_next_s	= 4'b0100;	// 4 double words
				end
				else
				begin
					wr_err_next_s	= '1;		// Set error flag for unsupported size
				end

				// Error if one of the write addresses is out of range
				if (bus_if.addr > ((MEM_DEPTH*MEM_WIDTH) - (wr_txcnt_next_s*MEM_WIDTH)))
				begin 
					wr_err_next_s	= '1;			// Set error flag
				end
				else
				begin
					wr_addr_next_s	= bus_if.addr;		// Only capture the starting write address if no error (power saving)	
				end
				
				wr_gnt_next_s		= '1;			// Grant write
				wr_state_next_s 	= WR_DP_ACTIVE;		// Move write state to data phase
			end
		end

//--------------------------------------------------
// Write State Logic: Data Phase 
//--------------------------------------------------

		WR_DP_ACTIVE:
		begin
			// Reset grant so it is only active for 1 cycle
			wr_gnt_next_s			= '0;

			// If there is a read error
			if (wr_err_r)
			begin
				wr_err_next_s		= '0;				// Reset error
				wr_busy_next_s		= '0;				// Reset busy ready for next transaction
				wr_state_next_s 	= WR_IDLE;			// Move write state back to idle ready for next transaction
			end

			// If writes left is more than 0, write data is valid and there is no write error
			else if ((wr_txcnt_r > 0) && (bus_if.write_valid == 1))
			begin
				wr_txcnt_next_s		= wr_txcnt_r - 4'b0001;		// Decrement writes left by 1
				wr_addr_next_s		= wr_addr_r + MEM_WIDTH;	// Increment address by MEM_WIDTH
			end

			// If writes left is 0 then the last write has completed
			if (wr_txcnt_next_s == 0)
			begin
				// If there's another write waiting to be completed
				if (bus_if.write)
				begin
					wr_state_next_s 	= WR_AP_ACTIVE;		// Pipeline straight to write address phase
				end
				else
				begin
					wr_busy_next_s		= '0;			// Reset busy ready for next transaction
					wr_state_next_s 	= WR_IDLE;		// Move write state back to idle ready for next transaction
				end
			end
		end
	endcase
end

//--------------------------------------------------
// Write State Registers 
//--------------------------------------------------

always_ff @(posedge clk_i or negedge reset_n_i) 
begin
	if (!reset_n_i) 
	begin	
		// Reset values
		mem_array 			<= '0;
		wr_state_r			<= WR_IDLE;
		wr_busy_r			<= '0;
		wr_txcnt_r			<= '0;
		wr_addr_r			<= '0;
		wr_err_r			<= '0;
		wr_gnt_r			<= '0;
	end
	else 
	begin
		// Clock next value into registers
		wr_state_r			<= wr_state_next_s;
		wr_busy_r			<= wr_busy_next_s;
		wr_txcnt_r			<= wr_txcnt_next_s;
		wr_addr_r			<= wr_addr_next_s;
		wr_err_r			<= wr_err_next_s;
		wr_gnt_r			<= wr_gnt_next_s;

//--------------------------------------------------
// Write Data Phase Memory Writes 
//--------------------------------------------------

		// If write state is in data phase and write data is valid
		if ((wr_state_r == WR_DP_ACTIVE) && (bus_if.write_valid == 1))
		begin
			mem_array[wr_addr_r[31:3]]	<= bus_if.write_data;	// Write data to memory
		end
	end
end

//=======================================================================================
// Error Data Phase Output 
//=======================================================================================

always_ff @(posedge clk_i or negedge reset_n_i) 
begin
	if (!reset_n_i) 
	begin	
		bus_if.error	<= '0;
	end
	else 
	begin
		bus_if.error	<= rd_err_next_s || wr_err_next_s;
	end
end

//=======================================================================================
// Grant Delay 
//=======================================================================================

always_ff @(posedge clk_i or negedge reset_n_i) 
begin
	if (!reset_n_i) 
	begin	
		grant_delay	<= '0;			// Reset grant_delay to 0
	end
	else 
	begin
		grant_delay	<= grant_delay + 1;	// Increment grant_delay by 1 every clock cycle (count will wrap round back to 000 after 111)
	end
end

//=======================================================================================
// Address Phase Output 
//=======================================================================================

assign bus_if.grant	= rd_gnt_next_s || wr_gnt_next_s;	// read or write grant so activate bus grant signal

//=======================================================================================
// Busy 
//=======================================================================================

assign busy_r 		= rd_busy_r || wr_busy_r;		// read or write in progress so activate busy signal

endmodule
