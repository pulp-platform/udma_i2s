`define PDM_MODE_1CH     2'b00
`define PDM_MODE_2CH_RF  2'b01
`define PDM_MODE_2CH_SEP 2'b10
`define PDM_MODE_4CH     2'b11

module pdm_top (
	input  logic          clk_i,
	input  logic          rstn_i,
    input  logic  [1:0]   cfg_pdm_ch_mode_i,
    input  logic  [9:0]   cfg_pdm_decimation_i,
    input  logic  [2:0]   cfg_pdm_shift_i,
    input  logic          cfg_pdm_en_i,
	input  logic          pdm_ch0_i,
	input  logic          pdm_ch1_i,
	output logic   [15:0] pcm_data_o,
	output logic          pcm_data_valid_o,
	input  logic          pcm_data_ready_i
);

	logic [1:0] r_ch_nr;
	logic [1:0] r_ch_nr_dly;
	logic [1:0] s_ch_target;
	logic       s_target_reached;
	logic       s_data;
	logic       s_data_valid;
	logic       r_store_ch0;
	logic       r_store_ch1;
	logic       r_store_ch2;
	logic       r_store_ch3;
	logic       r_valid;
	logic       r_clk;

	varcic #( 
  		.STAGES(5),
  		.ACC_WIDTH(51)
	) i_varcic (
  		.clk_i            ( clk_i                ),
  		.rstn_i           ( rstn_i               ),
  		.cfg_en_i         ( cfg_pdm_en_i         ),
  		.cfg_ch_num_i     ( s_ch_target          ),
  		.cfg_decimation_i ( cfg_pdm_decimation_i ),
  		.cfg_shift_i      ( cfg_pdm_shift_i      ),
  		.data_i           ( s_data               ),
  		.data_valid_i     ( s_data_valid         ),
  		.data_o           ( pcm_data_o           ),
  		.data_valid_o     ( pcm_data_valid_o     )
	);

	always_comb begin : proc_s_ch_target
		s_ch_target = 0;
		case(cfg_pdm_ch_mode_i)
			`PDM_MODE_1CH:
				s_ch_target = 0;
			`PDM_MODE_2CH_RF:
				s_ch_target = 1;
			`PDM_MODE_2CH_SEP:
				s_ch_target = 1;
			`PDM_MODE_4CH:
				s_ch_target = 3;
		endcase // cfg_pdm_ch_mode_i
	end

	assign s_target_reached = (r_ch_nr == s_ch_target );

	always_ff @(posedge clk_i or negedge rstn_i)
	begin
	  	if(~rstn_i)
	    	r_clk      <=  1'b0;
	  	else
	  	begin
	  		if(cfg_pdm_en_i)
	  		begin
	    		if (r_ch_nr == 0 )
	      			r_clk <= 1'b1;
	    		else if((r_ch_nr == 2 ) || s_target_reached)
        			r_clk <= 1'b0;
        	end
        	else
        	begin
        		r_clk <= 1'b0;
        	end
	  	end
	end

	always_ff @(posedge clk_i or negedge rstn_i)
	begin
	  	if(~rstn_i)
	    	r_ch_nr      <=  'h0;
	  	else
	  	begin
	  		if(cfg_pdm_en_i)
	  		begin
		    	if (s_target_reached)
		      		r_ch_nr      <= 0;
	    		else 
        			r_ch_nr <= r_ch_nr + 1;
        	end
        	else
        	begin
        		r_ch_nr <= 0;
        	end
	  	end
	end

	always_ff @(posedge clk_i or negedge rstn_i)
	begin
	  	if(~rstn_i)
	    	r_ch_nr_dly      <=  'h0;
	  	else
	  		if(cfg_pdm_en_i)
		    	r_ch_nr_dly      <=  r_ch_nr;
		    else
		    	r_ch_nr_dly  <= 'h0;
	end

	always_ff @(posedge clk_i or negedge rstn_i) begin : proc_r_store
		if(~rstn_i) begin
			r_store_ch0 <= 0;
			r_store_ch1 <= 0;
			r_store_ch2 <= 0;
			r_store_ch3 <= 0;
			r_valid     <= 0;
		end else begin
	  		if(cfg_pdm_en_i)
	  		begin
				r_valid <= 1'b1;
				if (r_ch_nr == 0)
				begin
					r_store_ch0 <= pdm_ch0_i;
					r_store_ch1 <= pdm_ch1_i;
				end
				else if (r_ch_nr == 1)
				begin
					if(cfg_pdm_ch_mode_i == `PDM_MODE_2CH_RF)
						r_store_ch1 <= pdm_ch0_i;
				end
				else if (r_ch_nr == 2)
				begin
					r_store_ch2 <= pdm_ch0_i;
					r_store_ch3 <= pdm_ch1_i;
				end
			end	
			else
			begin
				r_store_ch0 <= 0;
				r_store_ch1 <= 0;
				r_store_ch2 <= 0;
				r_store_ch3 <= 0;
				r_valid     <= 0;
			end
		end
	end

	always_comb begin : proc_s_data
		case(r_ch_nr_dly)
			0:
				s_data = r_store_ch0;
			1:
				s_data = r_store_ch1;
			2:
				s_data = r_store_ch2;
			3:
				s_data = r_store_ch3;
		endcase
	end

	assign s_data_valid = r_valid;

endmodule