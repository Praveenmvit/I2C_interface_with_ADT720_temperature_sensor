`timescale 1ns/1ps

module memory_slave(clk,rst,scl,sda,ack_err,done);
  
  input clk,rst,scl;
  inout sda;
  output reg ack_err;
  output reg done;
  
  
  typedef enum bit[3:0] {WAIT_FOR_START, WAIT_PULSE, READ_INIT, SEND_INIT_ACK, READ_ADDR_POINT_REG, SEND_ADDR_POINT_REG_ACK, STORE_DATA, EXPECT_RESTART, SEND_DATA, RECEIVE_MASTER_ACK, RECEIVE_MASTER_NO_ACK, STORE_DATA_ACK, DETECT_STOP} fsm;
  
  fsm state = WAIT_FOR_START;
  
  // Registers of 16 bytes with MSB register values.
  parameter TEMP_VALUE = 8'h0;
  parameter TEMP_HIGH = 8'h04;
  parameter TEMP_LOW = 8'h06;
  parameter TEMP_CRIT = 8'h08;
  
  bit [15:0] assoc_reg[byte]; // register map.
  bit [15:0] addr_pointer; // address pointer register 
  bit [7:0] init_arr;
  
  parameter sys_freq = 40000000; //40 MHz
  parameter i2c_freq = 1000000;  //// 1MHZ
  parameter clk_count4 = (sys_freq/i2c_freq);/// 40
  parameter clk_count1 = clk_count4/4; ///10
  integer count;
  
  reg busy,sda_en,r_ack,sda_t,restart,num_bytes;
  bit [15:0] bit_select,data_bytes;
  reg [3:0] bit_count;
  reg [1:0] pulse;
  
  
  always@(posedge clk) begin
    if(rst) begin
      done <= 0;
      busy <= 0;
      ack_err <= 0;
      pulse <= 0;
      bit_count <= 0;
      
    end
    else begin
      if(busy == 1'b0) begin
        pulse <= 2;
        count <= 21;
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
  
  always @(posedge clk) begin
    
    case(state) 
      WAIT_FOR_START: begin
        sda_en <= 0;
        restart <= 0;
        num_bytes <= 0;
        bit_select <= 0;
        if(scl == 1 && sda ==0) begin
          busy <= 1;
          state <= WAIT_PULSE;
        end
        else begin
          state <= WAIT_FOR_START;
        end
      end
      
      WAIT_PULSE: begin
        if(count == (clk_count1*4)-1) begin
          state <= READ_INIT;
        end
        else
          state <= WAIT_PULSE;
      end
      
      READ_INIT: begin
        if(bit_count <= 7) begin
          case(pulse)
            0: ;
            1: ;
            2: init_arr <= (count == 20)?            
               {init_arr[6:0],sda}:init_arr; 
            3: ;
          endcase
          if(count == (clk_count1*4)-1) begin
            state <= READ_INIT;
            bit_count <= bit_count + 1;
          end
          else
            state <= READ_INIT;
        end
        else begin
          state <= SEND_INIT_ACK;
          sda_en <= 1;
          bit_count <= 0;
        end
      end
      
      SEND_INIT_ACK: begin
        sda_en <= 1;
        case(pulse)
          0: sda_t <= 0;
          1: ;
          2: ;
          3: ;
        endcase
        
        if(count == (clk_count1*4)-1) begin
          if(init_arr[0] == 0) begin
            state <= READ_ADDR_POINT_REG;
            sda_en <= 0;
          end
          else begin
            state <= SEND_DATA;
            bit_select <= assoc_reg[addr_pointer];
          end
        end
        else begin
          state <= SEND_INIT_ACK;
        end
      end
      
      READ_ADDR_POINT_REG: begin
        sda_en <= 0;
        if(bit_count <= 7) begin
          case(pulse)
            0: ;
            1: ;
            2: addr_pointer <= (count == 20)?            
               {addr_pointer[6:0],sda}:addr_pointer; 
            3: ;
          endcase
          if(count == (clk_count1*4)-1) begin
            state <= READ_ADDR_POINT_REG;
            bit_count <= bit_count + 1;
          end
          else
            state <= READ_ADDR_POINT_REG;
        end
        else begin
          if(addr_pointer == TEMP_VALUE || addr_pointer == TEMP_HIGH
            || addr_pointer == TEMP_LOW || addr_pointer == TEMP_CRIT) begin // if addr falls in 16 byte register.
            data_bytes <= 16'd15;
          end
          else begin
            data_bytes <= 16'd7;
          end
          
          state <= SEND_ADDR_POINT_REG_ACK;
          bit_count <= 0;
        end
      end
      
      SEND_ADDR_POINT_REG_ACK: begin
        sda_en <= 1;
        case(pulse)
          0: sda_t <= 0;
          1: ;
          2: ;
          3: ;
        endcase
        
        if(count == (clk_count1*4)-1) begin
          state <= EXPECT_RESTART;
          sda_en <= 0;
        end
        else begin
          state <= SEND_ADDR_POINT_REG_ACK;
        end
      end
      
      EXPECT_RESTART: begin // if the ack followed by scl is one then it is read op. so, repeat start else write operation.
        sda_en <= 0;
        case(pulse)
          0: restart <= (count == 5)?(scl):restart;
          1: ;
          2: ;
          3: ;
        endcase
        
        if(count == (clk_count1-1)) begin
          if(restart == 1) begin 
            state <= WAIT_FOR_START;
          end
          else begin
            state <= STORE_DATA;
          end
        end       
        else begin
          state <= EXPECT_RESTART;
        end
       
      end
      
      
      SEND_DATA: begin
        sda_en <= 1;
        if(bit_count <= 7) begin
          case(pulse)
            0: ;
            1: begin
              
              if(num_bytes == 0 && data_bytes == 16'd15) begin
                sda_t <= bit_select[15-bit_count]; 
              end
              else begin
                sda_t <= bit_select[7-bit_count];
              end
            end
            2: ;
            3: ;
          endcase
          
          if(count == (clk_count1*4)-1) begin
            bit_count <= bit_count+1;
            state <= SEND_DATA;
          end
          else
            state <= SEND_DATA;
        end
        else begin
          if(data_bytes == 16'd15 && num_bytes == 0) begin
            state <= RECEIVE_MASTER_ACK;
          end
          else begin
            state <= RECEIVE_MASTER_NO_ACK;
          end
          bit_count <=0;
          sda_en <= 0;
        end
      end
      
      RECEIVE_MASTER_ACK: begin
        sda_en <= 0;
        case(pulse)
          0: ;
          1: ;
          2: r_ack <= sda;
          3: ;
        endcase
        if(count == (clk_count1*4)-1) begin // if master give ack if it need another byte of data.
          if(r_ack == 0) begin
            ack_err <= 0;
            sda_en <= 1;
            state <= SEND_DATA;
            num_bytes <= 1;
            //r_ack <= 0;
          end
          else begin
            ack_err <= 1;
            sda_en <= 0;
            state <= DETECT_STOP;
          end
        end
        else begin
          state <= RECEIVE_MASTER_ACK;
        end
        
      end
           
      RECEIVE_MASTER_NO_ACK: begin // ack for end of data transmission.
        sda_en <= 0;
        case(pulse)
          0: ;
          1: ;
          2: r_ack <= sda;
          3: ;
        endcase
        if(count == (clk_count1*4)-1) begin
          if(r_ack == 1) begin
            ack_err <= 0;
            sda_en <= 0;
            state <= DETECT_STOP;
            r_ack <= 0;
          end
          else begin
            ack_err <= 1;
            sda_en <= 0;
            state <= DETECT_STOP;
          end
        end
        else begin
          state <= RECEIVE_MASTER_NO_ACK;
        end
        
      end
      
      STORE_DATA: begin
        sda_en <= 0;
        if(bit_count <= 7) begin
          case(pulse)
            0: ;
            1: ;
            2: begin
              if(num_bytes == 0 && data_bytes == 16'd15) begin // for storing 16 byte register.
                bit_select[15-bit_count] <= (count==20) ? sda : bit_select[15-bit_count];
                
              end
              else begin
                bit_select[7-bit_count] <= (count==20) ? sda : bit_select[7-bit_count];
                
              end
             end
            3: ;
          endcase
          if(count == (clk_count1*4)-1) begin
            state <= STORE_DATA;
            bit_count <= bit_count + 1;
          end
          else
            state <= STORE_DATA;
        end
        else begin
          assoc_reg[addr_pointer] <= bit_select;
          
          state <= STORE_DATA_ACK;
          sda_en <= 1;
          bit_count <= 0;
        end
      end
      
      STORE_DATA_ACK: begin
        sda_en <= 1;
        case(pulse)
          0: sda_t <= 0;
          1: ;
          2: ;
          3: ;
        endcase
        
        if(count == (clk_count1*4)-1) begin
          if(num_bytes == 0 && data_bytes == 16'd15) begin // for 16 byte register. 8 byte store -> ack -> again byte store -> again ack -> stop.
            state <= STORE_DATA;
            num_bytes <= 1;
          end
          else begin
            state <= DETECT_STOP;
          end
          sda_en <= 0;
        end
        else
          state <= STORE_DATA_ACK;
      end
      
      DETECT_STOP: begin
        sda_en <= 0;
        if(pulse == 2'b10 && count == 20) begin
          busy <= 0;
          done <= 1;
          state <= WAIT_FOR_START;
          //$display("assoc:%0h",assoc_reg[addr_pointer]);
        end
        else
          state <= DETECT_STOP;
      end
      
      default: state <= WAIT_FOR_START;
    endcase
    
  end
  
  assign sda = (sda_en==1)?(sda_t):1'bz;
  
endmodule
