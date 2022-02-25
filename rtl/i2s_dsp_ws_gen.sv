module i2s_dsp_ws_gen (
  input logic sck_i,
  input logic rstn_i,
  input logic cfg_ws_en_i,
  input logic [4:0] cfg_num_bits_i,
  input logic [3:0] cfg_num_words_i,
  input logic [15:0] cfg_dsp_setup_time_i,
  input logic   cfg_dsp_mode_i,
  output logic ws_o
);

  logic [15:0] limit;
  enum {IDLE,WAIT,PULSE,PERIOD} state, state_n, state_p, next_state;
  /*
  NB: This is the WS generator for DSP protocol and it has the following op mode
  cfg_dsp_mode_i  0 : drive SW line on the negedge sck_i --> RX fifo must sample data on posedge
  cfg_dsp_mode_i  1 : drive SW line on the posedge sck_i --> RX fifo must sample data on negedge

  IDLE: ws_o line not driven
  WAIT: ws_o line not driven for the setup time of the slave
  PULSE: ws_o line in high level for 1 sck_i
  PERIOD: ws_o line in low level for (cfg_num_bits_i * cfg_num_words_i)-1
*/
  logic [15:0] count;
  logic set;
  logic        sck_inverter;

  pulp_clock_inverter clk_inv_i2s_ws_dsp
    (
      .clk_i(sck_i),
      .clk_o(sck_inverter)
    );

  assign limit = ((cfg_num_bits_i+1) * (cfg_num_words_i+1)-1);
  
  assign state= cfg_dsp_mode_i? state_p: state_n;
  
  always_ff@ (posedge sck_inverter, negedge rstn_i)
    begin
      if (rstn_i == 1'b0)
        state_n <= IDLE;
      else begin
        if(cfg_dsp_mode_i==1'b0) 
          state_n <= next_state;      
      end
    end

  always_ff@ (posedge sck_i, negedge rstn_i)
    begin
      if (rstn_i == 1'b0) begin
        count <= 'h0;
        state_p <= IDLE;
      end else begin
     
        if(set==1'b1 || next_state==IDLE)
          count <= 'h0;
        else
          count <= count+1;
        
        if(cfg_dsp_mode_i==1'b1)
          state_p <= next_state; 
      end
    end

  always_comb
    begin
      set=1'b0;
      ws_o=1'b0;
      next_state = IDLE;

      case(state)
        IDLE:
          begin
            
            if(cfg_ws_en_i==1'b1)
              begin
                if(cfg_dsp_setup_time_i!= 'd0) begin
                  next_state = WAIT;
                  set=1'b1;
                end else
                  next_state = PULSE;
              end
            
          end

        WAIT:
          begin
            
            if(cfg_ws_en_i==1'b1)
              begin
                if(count<cfg_dsp_setup_time_i)
                  next_state = WAIT;
                else
                  begin
                    next_state = PULSE;
                  end
              end
            
          end

        PULSE:
          begin
            if(cfg_ws_en_i==1'b1)
              begin
                next_state = PERIOD;
                ws_o=1'b1;
                set=1'b1;
              end
            
          end

        PERIOD:
          begin
            
            if(cfg_ws_en_i==1'b1)
              begin
                if (cfg_dsp_mode_i==1'b0 ) begin
                  if(count<limit)
                    next_state = PERIOD;
                  else
                    next_state = PULSE;
                end else begin
                  if(count<limit-1)
                    next_state = PERIOD;
                  else
                    next_state = PULSE;
                end
              end 
          end

      endcase
    end
endmodule
