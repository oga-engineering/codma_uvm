// THIS IS TO RECREATE A MORE HANDS-ON MEMORY BLOCK

class mem_agent extends uvm_agent;

   `uvm_component_utils(mem_agent)

   uvm_analysis_port #(mem_transaction) a_port;

   virtual mem_interface mem_vif;
   virtual cpu_interface cpu_vif;
   
   mem_driver     m_driver;
   mem_sequencer  m_sequencer;

   function new (string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      m_driver    = mem_driver   ::type_id::create("m_driver",this);
      m_sequencer = mem_sequencer::type_id::create("m_sequencer",this);
   endfunction

   function void connect_phase (uvm_phase phase);
      if(uvm_config_db#(virtual mem_interface)::get(this,"","mem_interface",mem_vif))
         m_driver.mem_vif = mem_vif;

      if(uvm_config_db#(virtual cpu_interface)::get(this,"","cpu_interface",cpu_vif))
         m_driver.cpu_vif = cpu_vif;
      
      m_driver.seq_item_port.connect(m_sequencer.seq_item_export);
   endfunction

endclass