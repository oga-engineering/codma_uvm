
module ip_codma_tb_top;


   timeunit 1ns;
   timeprecision 1ns;

   `include "uvm_macros.svh"
   import uvm_pkg::*;
   import ip_codma_env_pkg::*;

   //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   // Instantiate the static parts of the testbench
   //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

   bit clock, reset_n;

   mem_interface      mem_if();
   cpu_interface      cpu_if();

   ip_codma_top ip_codma_dut(
      clock, reset_n,
      cpu_if.slave,
      mem_if.master
   );

   // Clock and reset_n generator
   //
   initial begin

      // Configure the Agent VIF
      uvm_config_db#(virtual cpu_interface)::set(null, "*", "cpu_interface",cpu_if);
      uvm_config_db#(virtual mem_interface)::set(null, "*", "mem_interface",mem_if);

      $display("static reset sequence");
      reset_n = 0;
      clock = 0;
      
      fork begin
         run_test();
      end begin
         #8;
         //repeat(5) @(negedge clock);
         reset_n = 1;
         end
      join
      uvm_top.set_timeout(1000us);
   end
   //

   always #2 clock = ~clock;


endmodule
