// Code your design here
// Code your design here
`timescale 1ns/1ps

module master(clk,rst,newd,addr,op,din,dout,busy,ack_err,done,sda,scl);
  input clk,rst,newd,op;
  inout sda;
  input [7:0] addr;
  input [15:0] din; // 8 bit data
  output reg [15:0] dout;
  output reg busy,ack_err,done;
  output scl;
  
  reg scl_t,sda_t;
  typedef enum bit[3:0] {IDLE, START, INITIALIZE, ACK_FOR_INIT, WRITE_ADDR_POINT_REG, ACK_ADDR_POINT_REG, READ_DATA, WRITE_DATA, ACK_DATA, MASTER_ACK, MASTER_NO_ACK, STOP} fsm;
  
  fsm state;
  
 // Registers 16 bytes
  parameter TEMP_VALUE = 8'h0;
  parameter TEMP_HIGH = 8'h04;
  parameter TEMP_LOW = 8'h06;
  parameter TEMP_CRIT = 8'h08;
  reg [7:0] initialize_w = 8'b10010000;
  reg [7:0] initialize_r = 8'b10010001;

  parameter sys_freq = 40000000; //40 MHz
  parameter i2c_freq = 1000000;  //// 1MHz
  parameter clk_count4 = (sys_freq/i2c_freq);/// 40
  parameter clk_count1 = clk_count4/4; ///10
  integer count;
  bit [3:0] bit_count;
  bit [3:0] data_bytes;
  
  reg [1:0] pulse;
  
  always @(posedge clk) begin
    if(rst) begin
      scl_t <= 1;
      sda_t <= 1;
      busy <= 0;
      ack_err <= 0;
      done <= 0;
      state <= IDLE;
      pulse <= 0;
      count <= 0;
      bit_count <= 0;
    end
    else begin
      if(busy == 1'b0) begin
        pulse <= 0;
        count <= 0;
      end
      else if(count == clk_count1-1) begin
        pulse <= 1;
        count <= count + 1;        
      end
      else if(count == (clk_count1*2)-1) begin
        pulse <= 2;
        count <= count + 1;
      end
      else if(count == (clk_count1*3)-1) begin
        pulse <= 3;
        count <= count + 1;
      end
      else if(count == (clk_count1*4)-1) begin
        pulse <= 0;
        count <= 0;
      end
      else begin
        count <= count + 1;
      end
    end
  end
  
  reg [7:0] addr_pointer;
  reg [15:0] data;
  reg sda_en,r_ack,read_write,num_bytes,read_repeat_start;
  
  always @(posedge clk) begin
    case(state) 
      IDLE: begin
        done <= 0;
        if(newd == 1) begin
          addr_pointer <= addr;
          read_write <= op; // 1 -> read, 0 -> write.
          if(addr == TEMP_VALUE || addr == TEMP_HIGH
             || addr == TEMP_LOW || addr == TEMP_CRIT) begin
            data_bytes <= 16'd15;
          end
          else begin
            data_bytes <= 16'd7;
          end
          data <= din;
          state <= START;
          ack_err <= 0;
          busy <= 1;
          dout <= 0;
          num_bytes <= 0;
          read_repeat_start <= 0;
        end
        else begin
          state <= IDLE;
          busy <= 0;
          ack_err <= 0;          
        end
      end
      
      START: begin
        sda_en <= 1;
        case(pulse)
          0: begin scl_t <= 1; sda_t <= 1; end
          1: begin scl_t <= 1; sda_t <= 1; end
          2: begin scl_t <= 1; sda_t <= 0; end
          3: begin scl_t <= 1; sda_t <= 0; end
        endcase
        if(count == (clk_count1*4)-1) begin
          state <= INITIALIZE;
        end
        else begin
          state <= START;
        end
      end
      
      INITIALIZE: begin
        sda_en <= 1;
        if(bit_count <= 7) begin
          case(pulse)
            0: begin scl_t <= 0; sda_t <=0; end
            1: begin scl_t <= 0; 
              if(read_repeat_start == 0) begin // always write into the addr point register. for both read and write.
                sda_t <= initialize_w[7-bit_count]; 
              end
              else begin
                sda_t <= initialize_r[7-bit_count];
              end
              end
            2: begin scl_t <= 1; end
            3: begin scl_t <= 1; end
          endcase
          if(count == (clk_count1*4)-1) begin
            state <= INITIALIZE;
            bit_count <= bit_count + 1;
          end
          else begin
            state <= INITIALIZE;
          end
        end
        else begin
          state <= ACK_FOR_INIT;
          bit_count <= 0;
          sda_en <= 0;
        end
      end
      
      ACK_FOR_INIT: begin
        sda_en <= 0;
        case(pulse)
          0: scl_t <= 0; 
          1: scl_t <= 0; 
          2: begin scl_t <= 1; r_ack <= sda; end
          3: scl_t <= 1; 
        endcase
        if(count == (clk_count1*4)-1) begin
          if(r_ack == 0) begin // data_addr changed from 0 to 7
            if(read_repeat_start == 0) begin // to stop repeat start not entering write addr pointer register state again.
              state <= WRITE_ADDR_POINT_REG;
            end
            else begin
              state <= READ_DATA;
              read_repeat_start <= 0;
            end
            sda_en <= 1;
            ack_err <= 0;
            r_ack <= 0;
          end
          else begin
            state <= STOP;
            sda_en <= 1;
            ack_err <= 1;
          end
        end
        else begin
          state <= ACK_FOR_INIT;
        end
      end
      
      WRITE_ADDR_POINT_REG: begin // write the address pointer register.
        sda_en <= 1;
        if(bit_count <= 7) begin
          case(pulse)
            0: begin scl_t <= 0; sda_t <=0; end
            1: begin scl_t <= 0; sda_t <= addr_pointer[7-bit_count]; end
            2: begin scl_t <= 1; end
            3: begin scl_t <= 1; end
          endcase
          if(count == (clk_count1*4)-1) begin
            state <= WRITE_ADDR_POINT_REG;
            bit_count <= bit_count + 1;
          end
          else begin
            state <= WRITE_ADDR_POINT_REG;
          end
        end
        else begin
          state <= ACK_ADDR_POINT_REG;
          bit_count <= 0;
          sda_en <= 0;
        end
      end
      
      ACK_ADDR_POINT_REG: begin  // ack from slave after writing addr point reg.
        sda_en <= 0;
        case(pulse)
          0: scl_t <= 0; 
          1: scl_t <= 0; 
          2: begin scl_t <= 1; r_ack <= sda; end
          3: scl_t <= 1; 
        endcase
        if(count == (clk_count1*4)-1) begin
          if(r_ack == 0 && read_write == 0) begin // write
            state <= WRITE_DATA;
            sda_en <= 1;
            ack_err <= 0;
            r_ack <= 0;
          end
          else if(r_ack == 0 && read_write == 1) begin // read
            read_repeat_start <= 1; 
            state <= START; // repeat start for the read operation .
            sda_en <= 1;
            ack_err <= 0;
            r_ack <= 0;
          end
          else begin
            state <= STOP;
            sda_en <= 1;
            ack_err <= 1;
          end
        end
        else begin
          state <= ACK_ADDR_POINT_REG;
        end
      end
      
           
      
      WRITE_DATA: begin // write 16 and 8 byte data. variable num byte and data byte used for this purpose.
        sda_en <= 1;
        if(bit_count <= 7) begin
          case(pulse)
            0: scl_t <= 0; 
            1: begin scl_t <= 0; 
              if(num_bytes == 0 && data_bytes == 16'd15) begin
                sda_t <= data[15-bit_count];
              end
              else
                sda_t <= data[7-bit_count];
            end
            2: scl_t <= 1; 
            3: scl_t <= 1; 
          endcase
          if(count == (clk_count1*4)-1) begin
            state <= WRITE_DATA;
            bit_count <= bit_count + 1;
          end
          else begin
            state <= WRITE_DATA;
          end
        end
        else begin
          state <= ACK_DATA;
          bit_count <= 0;
        end 
      end
      
      
      ACK_DATA: begin
        sda_en <= 0;
        case(pulse)
          0: scl_t <= 0; 
          1: scl_t <= 0; 
          2: begin scl_t <= 1; r_ack <= sda; end
          3: scl_t <= 1; 
        endcase
        
        if(count == (clk_count1*4)-1) begin
          if(r_ack == 0) begin
            if(num_bytes == 0 && data_bytes == 16'd15) begin // for 16 byte data writing 8 byte data -> wait for ack -> send lsb 8 byte data -> wait for ack -> stop.
              state <= WRITE_DATA; 
              num_bytes <= 1;
            end
            else begin
              state <= STOP;
            end
            sda_en <= 1;
            ack_err <= 0;
          end
          else begin
            state <= STOP;
            sda_en <= 1;
            ack_err <= 1;
          end
        end
        else begin
          state <= ACK_DATA;
        end
      end
      
      READ_DATA: begin // read 16 as well as 8 byte data.
        sda_en <= 0;
        if(bit_count <= 7) begin
          case(pulse)
            0: scl_t <= 0; 
            1: scl_t <= 0; 
            2: begin scl_t <= 1; 
              if(data_bytes == 15'd7) begin 
                dout<=(count==20)?({dout[6:0],sda}):dout;
              end
              else
                dout <= (count == 20)?{dout[14:0],sda}:dout;
            end
            3: scl_t <= 1; 
          endcase
          if(count == (clk_count1*4)-1) begin
            state <= READ_DATA;
            bit_count <= bit_count + 1;
          end
          else begin
            state <= READ_DATA;
          end
        end
        else begin
          if(num_bytes == 0 && data_bytes == 16'd15) begin
            state <= MASTER_ACK;
            num_bytes <= 1;
          end
          else begin
            state <= MASTER_NO_ACK;
          end
          bit_count <= 0;
        end 
      end
      
      
      MASTER_ACK: begin // require another 8 byte of data.
        sda_en <= 1;
        case(pulse)
          0: begin scl_t <= 0; sda_t <= 0; end
          1: scl_t <= 0; 
          2: scl_t <= 1; 
          3: scl_t <= 1; 
        endcase
        if(count == (clk_count1*4)-1) begin
          state <= READ_DATA;
          sda_t <= 0;
        end
        else begin
          state <= MASTER_ACK;
        end
      end
      
      MASTER_NO_ACK: begin // end of data transmission master send no ack.
        sda_en <= 1;
        case(pulse)
          0: begin scl_t <= 0; sda_t <= 1; end
          1: scl_t <= 0; 
          2: scl_t <= 1; 
          3: scl_t <= 1; 
        endcase
        if(count == (clk_count1*4)-1) begin
          state <= STOP;
          sda_t <= 0;
        end
        else begin
          state <= MASTER_NO_ACK;
        end
      end
      
      STOP: begin
        sda_en <= 1;
        
        case(pulse)
          0: begin scl_t <= 1; sda_t <= 0; end
          1: begin scl_t <= 1; sda_t <= 0; end 
          2: begin scl_t <= 1; sda_t <= 1; end
          3: begin scl_t <= 1; sda_t <= 1; end
        endcase
        
        if(count == (clk_count1*4)-1) begin
          state <= IDLE;
          done <= 1;
          busy <= 0;
        end
        else begin
          state <= STOP;
        end
        
      end
      
      default : state <= IDLE;
    endcase
    
  end
  
  assign sda = (sda_en==1)?(sda_t):1'bz;
  assign scl = scl_t;
  
endmodule
