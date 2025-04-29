//class mem_sequencer extends uvm_sequencer;
//   `uvm_component_utils(mem_sequencer)
//
//   function new (string name, uvm_component parent);
//      super.new(name, parent);
//   endfunction
//
//endclass
typedef uvm_sequencer #(mem_transaction) mem_sequencer;