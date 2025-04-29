`ifndef __IP_CODMA_VSEQUENCER__
`define __IP_CODMA_VSEQUENCER__

class ip_codma_vsequencer extends uvm_sequencer;
   `uvm_component_utils(ip_codma_vsequencer)

   mem_sequencer m_mem_seqr;
   cpu_sequencer m_cpu_seqr;

   function new(string name="ip_codma_vsequencer",uvm_component parent);
      super.new(name, parent);
   endfunction

endclass
`endif