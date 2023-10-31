//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// VIRTUAL SEQUENCES - USED TO RUN MULTIPLE SEQUENCES IN PARALLEL
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class virtual_sequences extends uvm_sequence;
   `uvm_object_utils(virtual_sequences)
   `uvm_declare_p_sequencer(ip_codma_vsequencer)

   rand bit [31:0] dst_addr, src_addr, task_addr, len_bytes, task_type, stat_addr;

   function new(string name="");
      super.new(name);
   endfunction

   virtual function ip_codma_pass_configuration get_config(input int dst_addr, src_addr, task_addr, len_bytes, task_type, stat_addr);
      get_config = ip_codma_pass_configuration::type_id::create("pass_cfg");
      get_config.randomize();
      `uvm_info(get_type_name(),$sformatf("generated pass configuration\n%s", get_config.sprint()),UVM_FULL)
   endfunction

   task body;
      // Setup the mem with acceptable values
      ip_codma_pass_configuration pass_cfg;

      generic_sequence     m_mem_seq;
      cpu_simple_sequence  m_cpu_seq;

      m_mem_seq = generic_sequence     ::type_id::create("m_mem_seq");
      m_cpu_seq = cpu_simple_sequence  ::type_id::create("m_cpu_seq");

      pass_cfg = get_config(dst_addr, src_addr, task_addr, len_bytes, task_type, stat_addr);
      dst_addr    = pass_cfg.dst_addr;
      src_addr    = pass_cfg.src_addr;
      task_addr   = pass_cfg.task_addr;
      len_bytes   = pass_cfg.len_bytes;
      task_type   = pass_cfg.task_type;
      stat_addr   = pass_cfg.stat_addr;

      `ifdef UVM_POST_VERSION_1_1
         m_mem_seq.set_starting_phase(get_starting_phase());
         m_cpu_seq.set_starting_phase(get_starting_phase());
      `else
         m_mem_seq.starting_phase = starting_phase;
         m_cpu_seq.starting_phase = starting_phase;
      `endif
      
      // Randomize the mem content
      if (!m_mem_seq.randomize() with {i_dst_addr == pass_cfg.dst_addr;
                                       i_src_addr == pass_cfg.src_addr;
                                       i_task_addr == pass_cfg.task_addr;
                                       i_len_bytes == pass_cfg.len_bytes;
                                       i_task_type == pass_cfg.task_type;
                                       i_stat_addr == pass_cfg.stat_addr;})
         `uvm_fatal(get_type_name(),"Failed to randomize m_mem_seq from virtual sequence")
      
      // Send the status and task addr to the cpu instr sequence
      if(!m_cpu_seq.randomize() with   {i_status_pointer  == pass_cfg.stat_addr;
                                        i_task_pointer    == pass_cfg.task_addr;})
         `uvm_fatal(get_type_name(),"Failed to randomize m_cpu_seq from virtual sequence")
      // start the non-virtual sequences on the instantion of the respective sequencer in the virtual seqr
      fork
         m_mem_seq.start(p_sequencer.m_mem_seqr);
         m_cpu_seq.start(p_sequencer.m_cpu_seqr);
      join
   endtask

endclass