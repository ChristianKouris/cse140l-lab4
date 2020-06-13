// CSE140L
module top_level #(parameter DW=8, AW=8, byte_count=2**AW)(
  input        clk, 
               init,
  output logic done);

// dat_mem interface
// you will need this to talk to the data memory
logic         write_en;        // data memory write enable        
logic[AW-1:0] raddr,           // read address pointer
              waddr;           // write address pointer
logic[DW-1:0] data_in;         // to dat_mem
wire [DW-1:0] data_out;        // from dat_mem
// LFSR control input and data output
logic         LFSR_en;         // 1: advance LFSR; 0: hold		
// taps, start, pre_len are constants loaded from dat_mem [61:63]
logic[   5:0] taps,            // LFSR feedback pattern temp register
              start;           // LFSR initial state temp register
logic[   7:0] pre_len;         // preamble (_____) length           
logic         taps_en,         // 1: load taps register; 0: hold
              start_en,        //   same for start temp register
              prelen_en;       //   same for preamble length temp
logic         load_LFSR;       // copy taps and start into LFSR
logic         data_en;         // reads encodes and writes the message
wire [   5:0] LFSR;            // LFSR current value            
logic[   7:0] scram;           // encrypted message
logic[   7:0] ct_inc;          // prog count step (default = +1)
// instantiate the data memory 
dat_mem dm1(.clk, .write_en, .raddr, .waddr,
            .data_in, .data_out);

// instantiate the LFSR
lfsr6 l6(.clk, .en(LFSR_en), .init(load_LFSR),
         .taps, .start, .state(LFSR));

logic[7:0] ct;
logic[7:0] mem_ct;
// first tasks to be done:
// 1) raddr = 61, prelen_en = 1
//    pre_len <= data_out  
// 1) raddr = 62, taps_en = 1
//    taps <= data_out
// 2) raddr = 63, start_en = 1
//    start <= data_out
  
// control decode logic (does work of instr. mem and control decode)
always_comb begin
// list defaults here; case needs list only exceptions
  done      = 'b0;
  write_en  = 'b0;         // data memory write enable  
  raddr     = mem_ct - pre_len;         
  waddr     = 'd64 + mem_ct;
  LFSR_en   = 'b0;         // 1: advance LFSR; 0: hold'
  data_in   = 'b0;
  scram     = 'b0;
// enables to load control constants read from dat_mem[61:63] 
  prelen_en = 'b0;         // 1: load pre_len temp register; 0: hold
  taps_en   = 'b0;         // 1: load taps temp register; 0: hold
  start_en  = 'b0;         // 1: load start temp register; 0: hold
  load_LFSR = 'b0;         // copy taps and start into LFSR
  data_en   = 'b0;         // reads encodes and writes to data
// PC normally advances by 1
// override to go back in a subroutine or forward/back in a branch
  ct_inc    = 'b1;         // PC normally advances by 1
  case(ct)
    0,1: begin   end       // no op to wait for things to settle from init
    2:   begin             // load pre_len temp register
           raddr      = 'd61;
           prelen_en  = 'b1;
         end
    3:   begin             // load taps temp reg
           raddr      = 'd62;   
           taps_en    = 'b1; 
         end               // load LFSR start temp reg
    4:   begin
           raddr      = 'd63;
           start_en   = 'b1;
         end
    6:   begin             // copy taps and start temps into LFSR
           load_LFSR  = 'b1;
         end
	 7:   begin
	        LFSR_en    = 'b1;
			  data_en    = 'b1;
			  write_en   = 'b1;
			  ct_inc		 = 'b0;
			  data_in    = 8'h5f ^ {2'b00,LFSR};
			  if( mem_ct == pre_len - 1 ) begin
			    ct_inc = 'b1;
			  end
			end
	 8:   begin
	        LFSR_en    = 'b1;
			  write_en   = 'b1;
			  data_en    = 'b1;
			  ct_inc	    = 'b0;
			  scram      = data_out ^ {2'b00,LFSR};
	        data_in    = scram;
			  if( raddr == 'd51 ) ct_inc = 'b1;
			end 
	 9:   begin
			  done       = 'b1;
			end
	 default: begin end
	 
  endcase
end 

// The sequential logic of the program, all in one so there's no multiple drivers
always @(posedge clk) begin
  //initialization and clock counter
  if(init) begin
    ct <= 0;
	 mem_ct <= 0; 
  end
  else 
	ct <= ct + ct_inc;     // default: next_ct = ct+1
	
  //instructions reading
  if(prelen_en)
    pre_len <= data_out;      // copy from data_mem[61] to pre_len reg.
  else if(taps_en)
    taps    <= data_out;      // copy from data_mem[62] to taps reg.
  else if(start_en)
    start   <= data_out;      // copy from data_mem[63] to start reg.
  
  //preamble writing and message writing counter
  if(data_en) begin
    mem_ct <= mem_ct + 'b1;
  end

end

endmodule