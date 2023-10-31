class test_env extends uvm_env;

   `uvm_component_utils(test_env)

   // Add the uvcs agents to the env
   cpu_agent            m_cpu_agent;
   mem_agent            m_mem_agent;
   ip_codma_vsequencer  m_vsequencer;
   //ip_codma_scoreboard  m_scoreboard;
   
   function new(string name, uvm_component parent);
      super.new(name,parent);
      `uvm_info(get_type_name(),"Building the test environment",UVM_LOW)
   endfunction

   function void build_phase (uvm_phase phase);
      super.build_phase(phase);

      // create the UVCs
      m_cpu_agent       = cpu_agent          ::type_id::create("m_cpu_agent" ,this);
      m_mem_agent       = mem_agent          ::type_id::create("m_mem_agent" ,this);
      m_vsequencer      = ip_codma_vsequencer::type_id::create("m_vsequencer",this);
      //m_scoreboard      = ip_codma_scoreboard::type_id::create("m_scoreboard",this);
   endfunction

   // The virtual sequencer is connected to the UVC sequencers in the environment
   function void connect_phase(uvm_phase phase);
      m_vsequencer.m_mem_seqr = m_mem_agent.m_sequencer;
      m_vsequencer.m_cpu_seqr = m_cpu_agent.m_sequencer;
   endfunction

endclass

