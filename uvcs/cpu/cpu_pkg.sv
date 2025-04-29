// Package to be added to the test environment to include the CPU VC.

package cpu_pkg;

   `include "uvm_macros.svh"
   import uvm_pkg::*;

   `include "../uvcs/cpu/cpu_instruction.sv"
   `include "../uvcs/cpu/cpu_sequences.sv"
   `include "../uvcs/cpu/cpu_sequencer.sv"
   `include "../uvcs/cpu/cpu_driver.sv"
   `include "../uvcs/cpu/cpu_monitor.sv"   
   `include "../uvcs/cpu/cpu_agent.sv"

endpackage