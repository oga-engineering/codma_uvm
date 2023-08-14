// Bus interface description
interface mem_interface;

	logic		read;			// Address phase signal for a read request
	logic		write;			// Address phase signal for a write request
//	logic		read_modify_write;	// Address phase signal to lock target from other requests (block other accesses) as we are doing a read followed by a write to the same target and need no interference - this signal is expected to be high on a read request and stay high until the write request
	logic	[31:0]	addr;			// Address phase signal for the target address
	logic	[3:0]	size;			// Address phase signal for the size (double-word, 2 double word bust and 4 double word burst) for the transaction 
//	logic		ignore;			// Address phase signal telling receiver to ignore the current request - treat read or write as zero
	logic		grant;			// This signals the end of the address phase - the transaction can now move on to the data phase
	logic	[63:0]	read_data;		// Data phase signal for returning the read data to the master (only valid when read_valid asserted)
	logic		read_valid;		// Data phase signal for signifying that the read data is valid for the current cycle - otherwise, read_data value is ignored
	logic	[63:0]	write_data;		// Data phase signal for passing the write data to the slave (only valid when write_valid asserted)
	logic		write_valid;		// Data phase signal for signifying the write data is valid in the current cycle (else slave should ignore the write_data)
	logic		error;			// Data phase signal saying the transaction has failed and data has not been written/read (for example, the address given is out of range or size is not suppoerted)

	// master modport
	modport master (
		output	read,
		output	write,
//		output	read_modify_write,
		output	addr,
		output	size,
//		output	ignore,
		input	grant,
		input	read_data,
		input	read_valid,
		output	write_data,
		output	write_valid,
		input	error
	);

	// slave modport
	modport slave (
		input	read,
		input	write,
//		input	read_modify_write,
		input	addr,
		input	size,
//		input	ignore,
		output	grant,
		output	read_data,
		output	read_valid,
		input	write_data,
		input	write_valid,
		output	error
	);

	// monitor modport may be useful for checking in testbench (maybe...)
	modport monitor (
		input	read,
		input	write,
//		input	read_modify_write,
		input	addr,
		input	size,
//		input	ignore,
		input	grant,
		input	read_data,
		input	read_valid,
		input	write_data,
		input	write_valid,
		input	error
	);

endinterface

interface cpu_interface;

	bit start, stop, irq, busy;
	logic [31:0] status_pointer, task_pointer;

	modport master(
		output 	status_pointer, task_pointer, start, stop,
		input 	irq, busy
	);
	modport slave (
		output irq, busy,
		input status_pointer, task_pointer, start, stop
	);
	modport monitor (
		output irq, busy,
		input status_pointer, task_pointer, start, stop
	);

endinterface
