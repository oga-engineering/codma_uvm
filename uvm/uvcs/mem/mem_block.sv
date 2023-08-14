//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// this is the format the task informatino will take
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class mem_block extends uvm_sequence_item;

   function new(string name="mem_block");
      super.new(name);
   endfunction

   rand bit [31:0] dst_addr, src_addr, task_addr, stat_addr, len_bytes, task_type;

   `uvm_object_utils_begin(mem_block)
      `uvm_field_int(dst_addr,   UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(src_addr,   UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(task_addr,  UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(stat_addr,  UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(len_bytes,  UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(task_type,  UVM_ALL_ON | UVM_BIN)
   `uvm_object_utils_end

endclass