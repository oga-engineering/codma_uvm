class cpu_agent extends uvm_agent;

   //uvm_analysis_port#() a_port;

   virtual cpu_interface cpu_vif;
   virtual mem_interface mem_vif;

   uvm_analysis_port #(cpu_instruction) a_port;

   cpu_monitor    m_monitor;
   cpu_driver     m_driver;
   cpu_sequencer  m_sequencer;

   `uvm_component_utils(cpu_agent)

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   function void build_phase (uvm_phase phase);
      super.build_phase(phase);
      m_monitor   = cpu_monitor  ::type_id::create("m_monitor"  ,this);      
      m_driver    = cpu_driver   ::type_id::create("m_driver"   ,this);
      m_sequencer = cpu_sequencer::type_id::create("m_sequencer",this); 
   endfunction

   function void connect_phase (uvm_phase phase);
      if(uvm_config_db#(virtual cpu_interface)::get(this,"","cpu_interface",cpu_vif))
         m_driver.cpu_vif = cpu_vif;

      m_driver.mem_vif = mem_vif;
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
   endfunction     

endclass