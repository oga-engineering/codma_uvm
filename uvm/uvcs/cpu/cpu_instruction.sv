class cpu_instruction extends uvm_sequence_item;

   function new(string name="cpu_instruction");
      super.new(name);
   endfunction

   rand bit [31:0] status_pointer, task_pointer;
   rand bit m_start, m_stop;

   `uvm_object_utils_begin(cpu_instruction)
      `uvm_field_int(status_pointer ,UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(task_pointer   ,UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(m_start          ,UVM_ALL_ON | UVM_BIN)
      `uvm_field_int(m_stop           ,UVM_ALL_ON | UVM_BIN)      
   `uvm_object_utils_end
endclass
