-sverilog
+acc +vpi -timescale=1ns/1ns 
+incdir+.
+incdir+${UVM_HOME}/src
${UVM_HOME}/src/uvm.sv

../rtl/ip_codma_interfaces.sv
../uvcs/cpu/cpu_pkg.sv	
../uvcs/mem/mem_pkg.sv					
../../rtl/ip_codma_pkg.sv					
../../rtl/ip_codma_main_machine.sv	
../../rtl/ip_codma_rd_machine.sv
../../rtl/ip_codma_wr_machine.sv
../../rtl/ip_codma_top.sv				
../../rtl/ip_codma_crc.sv
../env/ip_codma_env_pkg.sv						
../testbench/ip_codma_tb_top.sv
