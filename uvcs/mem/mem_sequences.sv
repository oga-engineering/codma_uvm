class generic_sequence extends uvm_sequence#(mem_transaction);

   `uvm_object_utils(generic_sequence)

   function new(string name="generic_sequence");
      super.new(name);
   endfunction

   rand bit [31:0] i_dst_addr, i_src_addr, i_task_addr, i_len_bytes, i_task_type, i_stat_addr;
   mem_transaction mb;
   
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

   task body;
      `ifdef UVM_POST_VERSION_1_1
         uvm_phase starting_phase = get_starting_phase();
      `endif
      if (starting_phase != null)
         starting_phase.raise_objection(this);
      begin
      `uvm_info(get_type_name(),$sformatf("Generic Sequence Generated:\nsrc: %d, dst:%d len:%d task_addr:%d stat_addr:%d type:%d",i_src_addr, i_dst_addr, i_len_bytes, i_task_addr, i_stat_addr, i_task_type),UVM_DEBUG)
      // send the mem block contents to the driver
      `uvm_do_with(mb,
                  {  mb.dst_addr  == i_dst_addr;
                     mb.src_addr  == i_src_addr;
                     mb.task_addr == i_task_addr;
                     mb.len_bytes == i_len_bytes;
                     mb.task_type == i_task_type;
                     mb.stat_addr == i_stat_addr;
                  })
      end
      if (starting_phase != null)
         starting_phase.drop_objection(this);
   endtask

endclass