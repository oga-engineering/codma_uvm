`ifndef __IP_CODMA_PASS_CONFIGURATION_LIB__
`define __IP_CODMA_PASS_CONFIGURATION_LIB__

class ip_codma_pass_configuration extends uvm_object;
   
   rand int src_addr;
   rand int dst_addr;
   rand int task_addr;
   rand int stat_addr;
   rand int len_bytes;
   rand int task_type;
   
   `uvm_object_utils_begin(ip_codma_pass_configuration)
      `uvm_field_int(src_addr,   UVM_DEFAULT    |UVM_BIN)
      `uvm_field_int(dst_addr,   UVM_DEFAULT    |UVM_BIN)
      `uvm_field_int(task_addr,  UVM_DEFAULT    |UVM_BIN)
      `uvm_field_int(stat_addr,  UVM_DEFAULT    |UVM_BIN)
      `uvm_field_int(len_bytes,  UVM_DEFAULT    |UVM_BIN)
      `uvm_field_int(task_type,  UVM_DEFAULT    |UVM_BIN)
   `uvm_object_utils_end

   const int MEM_BOUNDARY = 256;

   constraint valid_dst_easy  { dst_addr > 0 ; dst_addr < MEM_BOUNDARY-len_bytes ; }
   constraint valid_src_addr  { src_addr > 0 ; src_addr < MEM_BOUNDARY-len_bytes ; }
   constraint valid_task_addr { task_addr > 0 ; task_addr < MEM_BOUNDARY-31 ; }
   constraint valid_stat_addr {  stat_addr > 0 ; 
                                 stat_addr != src_addr ;
                                 stat_addr != dst_addr ;
                                 stat_addr < MEM_BOUNDARY-8 ;
                              }
   constraint valid_task_type { task_type inside {0,1,2}; }
   constraint valid_len_bytes {  len_bytes > 0 ; 
                                 len_bytes < MEM_BOUNDARY-src_addr ;
                              }
   constraint no_clash        {  dst_addr  inside {[0:src_addr]} ||
                                 dst_addr inside {[src_addr+len_bytes:MEM_BOUNDARY-len_bytes]};
                                 dst_addr != src_addr ;
                              }

   function new(string name="ip_codma_pass_configuration");
      super.new(name);
   endfunction

endclass

// Shorter len_bytes requirement for faster tests
class short_transaction_pass_configuration extends ip_codma_pass_configuration;
   `uvm_object_utils(short_transaction_pass_configuration)
   
   function new (string name="short_transaction_pass_configuration");
      super.new(name);
   endfunction
   
   constraint short_transaction_length {len_bytes <= 64 ; }
   constraint full_transaction_t0 { task_type == 0 -> len_bytes % 8 == 0 ;}
   constraint full_transaction_t2 { task_type == 1 -> len_bytes % 32 == 0 ;}
   constraint no_linking_task  { task_type != 2;}

endclass

`endif