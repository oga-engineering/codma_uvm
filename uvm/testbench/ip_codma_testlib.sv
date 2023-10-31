

class ip_codma_generic_test extends uvm_test;

   `uvm_component_utils(ip_codma_generic_test)

   test_env             m_env;
   ip_codma_scoreboard  m_sb;

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   virtual function void build_phase (uvm_phase phase);
      super.build_phase(phase);
      m_env = test_env           ::type_id::create("m_env",this);
      m_sb  = ip_codma_scoreboard::type_id::create("m_sb" ,this);
   endfunction

   // Print the hierarchy of the TB
   function void end_of_elaboration_phase(uvm_phase phase);
      uvm_factory factory = uvm_factory::get();
      factory.print();
      uvm_top.print_topology();
   endfunction

   virtual task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      begin
         //generic_sequence m_seq;
         virtual_sequences v_seq;
         `uvm_info(get_type_name(),"Running sanity test",UVM_LOW)

         // Create the sequence
         //m_seq = generic_sequence::type_id::create("m_seq");
         v_seq = virtual_sequences::type_id::create("v_seq");

         // Fail message if randomization fails
         if (!v_seq.randomize())
            `uvm_fatal(get_type_name(), "Randomization of sequence FAIL")

         // Start the sequencer - this starts the sequencer
         `uvm_info(get_type_name(),"Starting the sequencer(s)",UVM_LOW)
         v_seq.start(m_env.m_vsequencer);
      end
      phase.drop_objection(this);
      `uvm_info(get_type_name(),"Test Done",UVM_LOW)
   endtask   

endclass

//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// SPECIFIC TESTS USING MODIFICATIONS TO THE GENERIC PASS CONFIGURATION
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

class sanity_test extends ip_codma_generic_test;
   `uvm_component_utils(sanity_test)

   function new (string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   virtual function void build_phase(uvm_phase phase);
      `uvm_info(get_type_name(),"Building the sanity test",UVM_LOW)
      super.build_phase(phase);
      set_type_override_by_type( ip_codma_pass_configuration::get_type(),
                                 short_transaction_pass_configuration::get_type());
   endfunction

endclass