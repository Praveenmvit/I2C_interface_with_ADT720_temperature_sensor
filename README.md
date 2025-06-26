# I2C_interface_with_ADT7420_temperature_sensor  
**<ins>ABOUT ADT7420:</ins>**
The ADT7420 is a high accuracy digital temperature sensor offering breakthrough performance over a wide industrial range, housed in a 4 mm × 4 mm LFCSP package. It contains an internal band gap reference, a temperature sensor, and a 16-bit ADC to monitor and digitize the temperature to 0.0078°C resolution. The ADC resolution, by default, is set to 13 bits (0.0625°C). The ADC resolution is a user programmable mode that can be changed through the serial interface.  
<div align="center">
<image src = "https://github.com/user-attachments/assets/92c9d85a-0bfd-47c6-86a0-28accd256a38">  
</div>

## REGISTERS IN ADT7420:
- Temperature registers -> 2 byte(R/W')
- A status register -> 1 byte(RO)
- An ID register -> 1 byte (RO)
- A configuration register -> 1 byte(R/W')
- An address pointer register -> 1 byte(W)
- A software reset -> 1byte(R/W')

## WRITING DATA INTO ADT7420 REGISTER:
1.  Master send start to temperature sensor and need to write address pointer register, which is used to point to the another registers.
2.  After start, send initialization byte 1001000 followed by R/W' bit.
3.  Slave will send the ack for this initialization byte.
4.  After this 8 bit address is send to the sensor.
5.  Ack will be send by the sensor, after the address is received.
6.  write data into the register that is pointed by the address pointer register.
7.  If 16 byte, send 8 bit data (Msb) followed by master receive ack. then send another 8 bit data(Lsb).
8.  Ack will be send for this lsb data. After which master send stop to sensor.
<div align="center">
<image src = "https://github.com/user-attachments/assets/f718741b-ae3e-4eb1-ba03-ab4c3e88a6bf">  
</div>



