
module i2s_tx_dsp_channel (
  input  logic                    sck_i,
  input  logic                    rstn_i,
  output logic                    i2s_ch0_o,
  output logic                    i2s_ch1_o,
  input  logic                    i2s_ws_i,
  input  logic             [31:0] fifo_data_i,
  input  logic                    fifo_data_valid_i,
  output logic                    fifo_data_ready_o,
  output logic                    master_ready_to_send,
  output logic                    fifo_err_o,
  input  logic                    cfg_en_i,
  input  logic                    cfg_2ch_i,
  input  logic              [4:0] cfg_num_bits_i,
  input  logic              [3:0] cfg_num_word_i,
  input  logic                    cfg_lsb_first_i,
  input  logic                    cfg_master_dsp_mode_i,
  input  logic              [8:0] cfg_master_dsp_offset_i
);


  logic [31:0] r_shiftreg_ch0;
  logic [31:0] r_shiftreg_ch1;
  logic [31:0] s_shiftreg_ch0;
  logic [31:0] s_shiftreg_ch1;
  logic [31:0] r_shiftreg_shadow;
  logic [31:0] s_shiftreg_shadow;
  logic [31:0] r_shiftreg_shadow1;
  logic [31:0] s_shiftreg_shadow1;

  logic        s_data_ready;
  
  logic        set_offset;

  logic        s_en_offset, r_en_offset;
  logic        r_clear_offset, s_clear_offset;

  logic        check_offset;


  logic [4:0]  r_count_bit, s_count_bit;
  logic [8:0]  r_count_offset, s_count_offset;

  logic        s_word_done;
  logic        s_word_done_pre;


  logic        sck_inverter, sck_r;

  enum  {START,SAMPLE,WAIT,RUN} state, next_state;

  assign s_word_done     = cfg_lsb_first_i?  r_count_bit == cfg_num_bits_i  : r_count_bit == 'h0;
  assign s_word_done_pre = cfg_lsb_first_i?  r_count_bit == cfg_num_bits_i-4 : r_count_bit == 'h4;

  assign fifo_data_ready_o = s_data_ready;

  assign set_offset = (cfg_master_dsp_offset_i!='h0 )? 1'b1 : 1'b0;
  assign check_offset = set_offset ^ r_clear_offset;


  pulp_clock_inverter clk_inv_i2s_tx_dsp
    (
      .clk_i(sck_i),
      .clk_o(sck_inverter)
    );

  pulp_clock_mux2 clk_mux_i2s_tx_dsp
    (
      .clk0_i(sck_inverter),
      .clk1_i(sck_i),
      .clk_sel_i(cfg_master_dsp_mode_i),
      .clk_o(sck_r)
    );

  always_comb begin : proc_SM

    s_shiftreg_ch0    = r_shiftreg_ch0;
    s_shiftreg_ch1    = r_shiftreg_ch1;
    s_shiftreg_shadow = r_shiftreg_shadow;
    s_shiftreg_shadow1 = r_shiftreg_shadow1;

    s_data_ready = 1'b0;

    next_state = START;

    case(state)

      START:
        begin
          
          if(cfg_en_i==1'b0) begin
            next_state= START;
            s_shiftreg_ch0    = 'h0;
            s_shiftreg_ch1    = 'h0;
            s_shiftreg_shadow = 'h0;
            s_shiftreg_shadow1 = 'h0;
          end else begin
            if(fifo_data_valid_i == 1'b1)
              begin
                s_data_ready    = 1'b1;
                s_shiftreg_ch0 = fifo_data_i;
                next_state = SAMPLE;
              end else
                next_state = START;
          end
        end

      SAMPLE:
        begin

          if(cfg_en_i==1'b0) begin
            next_state= START;
            s_shiftreg_ch0    = 'h0;
            s_shiftreg_ch1    = 'h0;
            s_shiftreg_shadow = 'h0;
            s_shiftreg_shadow1 = 'h0;
          end else begin
            if(fifo_data_valid_i== 1'b1)
              begin
                s_data_ready    = 1'b1;
                s_shiftreg_ch1 = fifo_data_i;
                next_state = WAIT;
              end else
                next_state = SAMPLE;
          end
        end

      WAIT:
        begin

          if(cfg_en_i==1'b0) begin
            next_state= START;
            s_shiftreg_ch0    = 'h0;
            s_shiftreg_ch1    = 'h0;
            s_shiftreg_shadow = 'h0;
            s_shiftreg_shadow1 = 'h0;
          end else begin

            if(i2s_ws_i== 1'b1)
              next_state = RUN;
            else
              next_state = WAIT;
            
          end
        end

      RUN:
        begin
        
          if(cfg_en_i==1'b0) begin

            next_state= START;
            s_shiftreg_ch0    = 'h0;
            s_shiftreg_ch1    = 'h0;
            s_shiftreg_shadow = 'h0;
            s_shiftreg_shadow1 = 'h0;

          end else begin

            next_state= RUN;

            if(check_offset==1'b0)  begin

              if(s_word_done_pre== 1'b1)begin
                
                if(cfg_2ch_i== 1'b1) begin
                  s_data_ready    = 1'b1;

                  if(fifo_data_valid_i == 1'b1)
                    s_shiftreg_shadow = fifo_data_i;
                
                end 
              
              end else begin

                if(s_word_done== 1'b1)begin
                  
                  s_data_ready = 1'b1;
                  
                  if(cfg_2ch_i== 1'b1) begin
                    s_shiftreg_ch0 = r_shiftreg_shadow;
                    
                    if(fifo_data_valid_i == 1'b1)
                      s_shiftreg_ch1 = fifo_data_i;

                  end else begin
                    s_shiftreg_ch0 = r_shiftreg_ch1;

                    if (cfg_master_dsp_mode_i==1'b1) begin
                      if(fifo_data_valid_i == 1'b1)
                        s_shiftreg_ch1 = fifo_data_i;
                    end
                  end

                end else begin

                  if (cfg_master_dsp_mode_i==1'b0) begin               
                    if(fifo_data_valid_i == 1'b1) begin
                      if(cfg_2ch_i== 1'b0)
                        s_shiftreg_ch1 = fifo_data_i;
                      else
                        s_shiftreg_shadow = fifo_data_i;
                    end
                  end 

                end


              end

            end //close check_offset

          end//close else enable
        end

    endcase // state
  end

  always_ff  @(posedge sck_r, negedge rstn_i)
    begin
      if (rstn_i == 1'b0 ) begin
        state <= START;
        master_ready_to_send <= 1'b0;
      end else begin
        if (next_state==START)
          master_ready_to_send <= 1'b0;
        else
          if (next_state==WAIT)
            master_ready_to_send <= 1'b1;
          else
            master_ready_to_send <= master_ready_to_send;

        state <= next_state;

      end
    end

  always_ff  @(posedge sck_r, negedge rstn_i)
    begin
      if (rstn_i == 1'b0)
        begin
          r_shiftreg_ch0  <=  'h0;
          r_shiftreg_ch1  <=  'h0;
          r_shiftreg_shadow <= 'h0;
          r_shiftreg_shadow1 <= 'h0;
        end
      else
        begin   
          r_shiftreg_ch0  <= s_shiftreg_ch0;         
          r_shiftreg_ch1  <= s_shiftreg_ch1;         
          r_shiftreg_shadow  <= s_shiftreg_shadow;
          r_shiftreg_shadow1  <= s_shiftreg_shadow1;
        end
    end

  always_comb
    begin

      s_count_bit = r_count_bit;
      s_count_offset = r_count_offset;
      s_en_offset = r_en_offset;
      s_clear_offset = r_clear_offset;

      i2s_ch0_o = 1'b0;
      i2s_ch1_o = 1'b0;

      if (next_state== START) begin

        s_count_bit = 'h0;
        s_count_offset = 'h0;

        s_en_offset = 1'b0;
        s_clear_offset  = 1'b0;

        i2s_ch0_o = 1'b0;
        i2s_ch1_o = 1'b0;

      end else begin

        i2s_ch0_o = r_shiftreg_ch0[r_count_bit];
        
        if (cfg_2ch_i==1'b1)
          i2s_ch1_o = r_shiftreg_ch1[r_count_bit];

        if((next_state== RUN & i2s_ws_i== 1'b1 & cfg_master_dsp_offset_i!=9'b0 & check_offset==1'b1) | r_en_offset==1'b1) begin

          if (r_count_offset+1==cfg_master_dsp_offset_i) begin
            s_clear_offset = 1'b1;
            s_en_offset = 1'b0;

            if (cfg_lsb_first_i==1'b0)
              s_count_bit = cfg_num_bits_i;
            else
              s_count_bit = 1'b0;

          end else begin
            s_count_offset = r_count_offset + 1;
            s_en_offset = 1'b1;
            s_clear_offset = 1'b0;
          end

        end else begin
          s_clear_offset = r_clear_offset;

          if (next_state== RUN & i2s_ws_i== 1'b1 | state == RUN) begin

            if (cfg_lsb_first_i==1'b0) begin

              if (r_count_bit=='h0)
                s_count_bit = cfg_num_bits_i;
              else
                s_count_bit = r_count_bit - 1;

            end else begin

              if (r_count_bit==cfg_num_bits_i)
                s_count_bit = 'h0;
              else
                s_count_bit = r_count_bit + 1;

            end

          end else begin

            if (cfg_lsb_first_i==1'b0)
              s_count_bit = cfg_num_bits_i;
            else
              s_count_bit = 'h0;

          end
        end
      end
    end

  always_ff  @(posedge sck_r, negedge rstn_i)
    begin
      if (rstn_i == 1'b0 ) begin

        r_count_bit <= 'h0;
        r_count_offset <= 'h0;
        r_en_offset <= 'h0;
        r_clear_offset <= 'h0;

      end else begin

        r_count_bit <= s_count_bit;
        r_count_offset <= s_count_offset;
        r_en_offset <= s_en_offset;
        r_clear_offset <= s_clear_offset;

      end
    end

endmodule

