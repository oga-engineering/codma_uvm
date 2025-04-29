// IP CODMA TB SCOREBOARD
//
// Scoreboard to check the transactions are successful
// by looking at the final memory array
// need to use a proper mem setup first perhaps

class ip_codma_scoreboard extends uvm_scoreboard;
   
   `uvm_component_utils(ip_codma_scoreboard)

   // TLM Port Declarations
   `uvm_analysis_imp_decl(_cpu_instr)
   `uvm_analysis_imp_decl(_mem_blk)

   uvm_analysis_imp_cpu_instr #(cpu_instruction, ip_codma_scoreboard) sb_cpu_instr;
   uvm_analysis_imp_mem_blk   #(mem_transaction      , ip_codma_scoreboard) sb_mem_transaction;

   function new (string name, uvm_component parent);
      super.new(name, parent);
      sb_cpu_instr = new("sb_cpu_instr",this);
      sb_mem_transaction = new("sb_mem_transaction",this);
   endfunction : new

   function void check_phase(uvm_phase phase);
      `uvm_info(get_type_name(),"Scoreboard check phase",UVM_LOW)
   endfunction : check_phase

   // Required functions
   virtual function void write_cpu_instr(cpu_instruction cpu_instr);
      `uvm_info(get_type_name(),$sformatf("CPU INSTR WRITE - %h",cpu_instr),UVM_LOW)
   endfunction : write_cpu_instr

   virtual function void write_mem_blk(mem_transaction m_array);
      `uvm_info(get_type_name(),$sformatf("MEM BLOCK WRITE - %h",m_array),UVM_LOW)
   endfunction : write_mem_blk


endclass : ip_codma_scoreboard