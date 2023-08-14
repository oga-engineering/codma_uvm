//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
// This is used to create a memory array instead of using a register model
//~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
class mem_driver extends uvm_driver#(mem_block);

   `uvm_component_utils(mem_driver)

   function new (string name, uvm_component parent);
      super.new(name, parent);
   endfunction

   virtual mem_interface.slave  mem_vif;
   virtual cpu_interface.master cpu_vif;

   rand bit addr;
   bit [263:0][7:0][7:0] mem_array;
   bit [63:0]            task_info_p1;
   bit [63:0]            task_info_p2;
   
   // Grab the task data to feed it into the mem array
   task run_phase (uvm_phase phase);
      mem_block mb;
      #4;
      forever begin
         `uvm_info(get_type_name,"Mem Sequence next item",UVM_LOW)
         seq_item_port.get_next_item(mb);
         turn_to_mem(mb,mem_array);

         mem_vif.grant = 0;

         // Process read and write requests
         while (!cpu_vif.irq) begin
            fork
               wait(mem_vif.read) begin
                  `uvm_info(get_type_name(),$sformatf("READ REQ %d",mem_vif.read),UVM_LOW)
                  do_read(mem_array, mb);               
                  `uvm_info(get_type_name(),$sformatf("READ DONE %d",mem_vif.read),UVM_LOW)
               end
            begin
               wait(mem_vif.write && !mem_vif.read_valid) begin
                  // The design does not expect parallel rd/wr operations
                  `uvm_info(get_type_name(),$sformatf("WRITE REQ %d",mem_vif.write),UVM_LOW)
                  do_write(mem_array, mb);
                  `uvm_info(get_type_name(),$sformatf("WRITE DONE %d",mem_vif.write),UVM_LOW)
               end
            end
            join
         end

         // Move to the next sequence item once the interrupt is asserted
         //wait(cpu_vif.irq);
         seq_item_port.item_done(mb);
         for (int i = 0 ; i<264 ; i++) begin
            `uvm_info(get_type_name(),$sformatf("FINAL mem_array[%d] %h",i,mem_array[i]),UVM_DEBUG)
         end
      end
      
   endtask

   //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   // This function stores task data at the task pointer address (VERIFIED)
   //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   task turn_to_mem(mem_block mb, output bit [263:0][7:0][7:0] mem_array);
      `uvm_info(get_type_name(),$sformatf("Turning Sequence Item into Mem Array:\nsrc: %d, dst:%d len:%d task_addr:%d stat_addr:%d type:%d",mb.src_addr, mb.dst_addr, mb.len_bytes, mb.task_addr, mb.stat_addr, mb.task_type),UVM_LOW)
      task_info_p1 = {mb.src_addr,mb.task_type};
      task_info_p2 = {mb.len_bytes,mb.dst_addr};
      mem_array[mb.task_addr] = task_info_p1;
      mem_array[(mb.task_addr+1)] = task_info_p2;
      `uvm_info(get_type_name(),$sformatf("As it appear at task pointer in mem array %d:\n%h\n%h",mb.task_addr, task_info_p2,task_info_p1),UVM_DEBUG)
      // Visualise the resulting memory created for debug help
      for (int i = 0 ; i<264 ; i++) begin
         `uvm_info(get_type_name(),$sformatf("mem_array[%d] %h",i,mem_array[i]),UVM_DEBUG)
      end
   endtask

   //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
   // TODO: DEFINE MEM ARRAY ACCESS R/W PROTOCOLS THROUGH IF
   //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

   task do_read(bit [263:0][7:0][7:0] mem_array, mem_block mb);
      if(mem_vif.addr == mb.task_addr)
         `uvm_info(get_type_name(),$sformatf("Performing Task Read at %d",mem_vif.addr),UVM_LOW)
      else if(mem_vif.addr == mb.src_addr)
         `uvm_info(get_type_name(),$sformatf("Performing SRC Read at %d",mem_vif.addr),UVM_LOW)
      //else begin
      //   #8;
      //   `uvm_fatal(get_type_name(),"TEST ABORT DEBUG")
      //end

      wait(!mem_vif.write_valid);
      `uvm_info(get_type_name(),"Read in Process",UVM_LOW)
      // wait and grant for a cycle
      #4;
      mem_vif.grant = 1;
      #4;
      mem_vif.grant = 0;

      // assert the data valid for the size value
      // TODO: setup the clock better so this driver can count cycles
      // NOTE: The clock period is #4 and setup in tb top;
      if(mem_vif.size == 3) begin
         `uvm_info(get_type_name(),$sformatf("Read Size 3 = %d",mem_vif.size),UVM_DEBUG)
         mem_vif.read_valid = 1;
         assign_data(mem_array, mem_vif.addr);
         #8;
         mem_vif.read_valid = 0;
      end else if(mem_vif.size == 8)begin
         `uvm_info(get_type_name(),$sformatf("Read Size 8 = %d",mem_vif.size),UVM_DEBUG)
         mem_vif.read_valid = 1;
         assign_data(mem_array, mem_vif.addr);
         #4;
         assign_data(mem_array, (mem_vif.addr+1));
         #8;
         mem_vif.read_valid = 0;
      end else if(mem_vif.size == 9) begin
         `uvm_info(get_type_name(),$sformatf("Read Size 9 = %d",mem_vif.size),UVM_DEBUG)
         mem_vif.read_valid = 1;
         assign_data(mem_array, mem_vif.addr);
         #4;
         assign_data(mem_array, (mem_vif.addr+1));
         #4;
         assign_data(mem_array, mem_vif.addr+2);
         #4;
         assign_data(mem_array, (mem_vif.addr+3));
         #8;
         mem_vif.read_valid = 0;
      end else begin
         `uvm_info(get_type_name(),"Read size ERROR",UVM_LOW)
         mem_vif.error = 1;
         #4;
         mem_vif.error = 0;
      end
      #4;      
   endtask

   task do_write(bit [263:0][7:0][7:0] mem_array, mem_block mb);
      if(mem_vif.addr == mb.stat_addr)
         `uvm_info(get_type_name(),$sformatf("Doing Status write (%d) at %d",mem_vif.write, mem_vif.addr),UVM_LOW)
      #4;
      mem_vif.grant = 1;
      #4;
      mem_vif.grant = 0;
      mem_array[mem_vif.addr] = mem_vif.write_data;
      #4;
   endtask

   // Assigns the vif with the relevant read data
   task assign_data(bit [263:0][7:0][7:0] mem_array, bit [31:0] addr);
      mem_vif.read_data = mem_array[addr];
      `uvm_info(get_type_name(),$sformatf("Giving data at %d as: %h", addr, mem_array[addr]),UVM_DEBUG)
   endtask


endclass



   