//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// CPU SEQUENCE CLASS
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class cpu_simple_sequence extends uvm_sequence#(cpu_instruction);
   `uvm_object_utils(cpu_simple_sequence)

   rand bit [31:0] i_status_pointer, i_task_pointer;
   rand bit i_start, i_stop;
   cpu_instruction cpu_instr;

   function new(string name="cpu_simple_sequence");
      super.new(name);
   endfunction

   //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   // GENERIC OBJECTIONS
   //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   // End of simulation objection
   task pre_start;
      `ifdef UVM_POST_VERSION_1_1
         uvm_phase starting_phase = get_starting_phase();
      `endif
      if (starting_phase != null)
         starting_phase.raise_objection(this);
   endtask

   task post_start;
      `ifdef UVM_POST_VERSION_1_1
         uvm_phase starting_phase = get_starting_phase();
      `endif
      if (starting_phase != null)
         starting_phase.drop_objection(this);
   endtask

   //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   // BODY OF SIMPLE SEQUENCE
   //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   task body;
      `ifdef UVM_POST_VERSION_1_1
         uvm_phase starting_phase = get_starting_phase();
      `endif
      if (starting_phase != null)
         starting_phase.raise_objection(this);
      begin
         `uvm_info(get_type_name(),$sformatf("Running the sequence with:\nTask at: %d\nStatus at: %d\nStart: %d Stop: %d",i_task_pointer, i_status_pointer, 1, 0),UVM_DEBUG)
         `uvm_do_with(cpu_instr,{cpu_instr.task_pointer     == i_task_pointer;
                                 cpu_instr.status_pointer   == i_status_pointer;
                                 cpu_instr.m_stop             == 0; // TODO: define these in pass config so can be changed in tests
                                 cpu_instr.m_start            == 1; // TODO: Also find ways of driving these and changing them in a test with waits
                                 })                   
      end
      if (starting_phase != null)
         starting_phase.drop_objection(this);
   endtask


endclass