# I2C_interface_with_ADT7420_temperature_sensor  
**<ins>ABOUT ADT7420:</ins>**
The ADT7420 is a high accuracy digital temperature sensor offering breakthrough performance over a wide industrial range, housed in a 4 mm × 4 mm LFCSP package. It contains an internal band gap reference, a temperature sensor, and a 16-bit ADC to monitor and digitize the temperature to 0.0078°C resolution. The ADC resolution, by default, is set to 13 bits (0.0625°C). The ADC resolution is a user programmable mode that can be changed through the serial interface.  
                   | Part Number | Interface | Resolution | Accuracy | Notes                             |
                   | ----------- | --------- | ---------- | -------- | --------------------------------- |
                   | **ADT7410** | I²C       | 13-bit     | ±0.5°C   | Popular for general use           |
                   | **ADT7420** | I²C       | 16-bit     | ±0.25°C  | Higher precision, faster response |
                   | **ADT7411** | I²C       | 10-bit ADC | ±1.0°C   | Includes ADC & other features     |
                   | **ADT7310** | SPI       | 16-bit     | ±0.5°C   | SPI version of ADT7420            |
                   | **ADT7320** | SPI       | 16-bit     | ±0.25°C  | SPI version with higher accuracy  |

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
7.  If 16 bit, send 8 bit data (Msb) followed by master receive ack. then send another 8 bit data(Lsb).
8.  Ack will be send for this lsb data. After which master send stop to sensor.
<div align="center">
<image src = "https://github.com/user-attachments/assets/f718741b-ae3e-4eb1-ba03-ab4c3e88a6bf">  
</div>  

## READING DATA FROM ADT7420 REGISTER:
1.  Before reading we need writting into the address register.
2.  start -> initialization with write -> followed by 8 bit address pointer register write.
3.  Need to do Repeat start -> again initialization but this time with read -> wait for init ack.
4.  init ack send by sensor followed by 8 bit data.
5.  For receiving 8 bit data from sensor ( adt7420 ). master will send no ack.
6.  If it is the 16 bit data need to be send. then for first 8 bit data(msb), master will send ack.
7.  After getting next 8 bit data ( lsb). master will send no ack.
8.  And then stop.
<div align="center">
<image src = "https://github.com/user-attachments/assets/e133ee2b-ad05-4d40-8f70-565536cc3622">  
</div>  


