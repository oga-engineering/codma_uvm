package ip_codma_env_pkg;

  timeunit 1ns;
  timeprecision 1ns;

  `include "uvm_macros.svh"
  import uvm_pkg::*;

  // Include the UVCs (already compiled by including them in the .f file)
  import cpu_pkg::*;
  import mem_pkg::*;

  `include "../env/ip_codma_pass_configuration.sv"
  `include "../env/ip_codma_mc_sequencer.sv"
  `include "../env/ip_codma_test_env.sv"
  `include "../env/ip_codma_mc_sequences.sv"
  `include "../env/ip_codma_scoreboard.sv"
  `include "../testbench/ip_codma_testlib.sv"

endpackage