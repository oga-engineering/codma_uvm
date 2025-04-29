// Component used to monitor the CPU transactions

class cpu_monitor extends uvm_monitor;

   `uvm_component_utils(cpu_monitor)

   function new(string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   virtual cpu_interface.monitor vif;

endclass