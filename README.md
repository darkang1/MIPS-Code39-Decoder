# MIPS-Code39-Decoder
A program written in the MIPS assembly language which decodes Code39 barcode.

## Code 39 description
Code 39 encodes 43 symbols. The start and stop symbol is *. It can not be used in encoded data. There are two widths of bars and spaces. The thickness ratio of wide and thin bars and spaces may vary from 2,2:1 to 3:1 (in a given barcode it is constant). Each symbol consists of five bars and four spaces. The size of the space between two characters is not defined – usually it equals the width of thin bar or space.

**Code 39 consists of**:
- Start symbol *
- Encoded data
- Check symbol
- Stop symbol

## Check Symbol
The check symbol is calculated according to the formula:

![image](https://user-images.githubusercontent.com/102079830/159357052-d32bf030-6037-45a1-ae1d-7ac3692e8dd3.png)

## Character Encoding
The encoding of characters is presented in Table 1. Last column contains relative widths of bars (B) and spaces (S). Digit 2 represents wide bar or space, digit 1 – thin bar or space.

![image](https://user-images.githubusercontent.com/102079830/159357133-916627fb-5dfd-42d5-b092-053c4067c893.png)
![image](https://user-images.githubusercontent.com/102079830/159357163-df7d2c3d-b562-474f-a7ff-a1f78d1971d5.png)


## Input
- BMP file containing the barcode image: 
  - Sub format: 24 bits RGB – no compression
  - Image size: 600x50 px
- File name: “source.bmp”

The bars are black and are paralel to vertical edge of the image. The background is white. There are no distortions in the image.
