######################################
# Computer Architecture MIPS Project  #
# Task: Code39 Barcode Decoder        #
# Author: Bogdan Dovgopol             #
# Date: 10.05.2021                    #
######################################

.data
.include		"data.asm"
.include		"data_ascii.asm"

buffer:				.space	2
header:				.space	54 # Num of bytes before pixel data begins
width:				.word	600
height:				.word	50
output:				.space 	100

dsc_error_msg: 			.asciiz "Bad file descriptor!"
bitmap_error_msg: 		.asciiz	"Loaded file is not a bitmap!"
size_error_msg:			.asciiz	"Wrong file size! Allowed size is 600x50."
format_error_msg:		.asciiz "Loaded BMP file resolution is not 24-bit!"
checksum_error_msg:		.asciiz "[Warning]: Wrong checksum value! Checksum character might not be present or invalid!\n"
char_code_error_msg:            .asciiz "Some character codes not found!\nBarcode might be invalid or corrupted!"
invalid_barcode_error_msg:	.asciiz "There is no proper barcode in the picture!"
bar_size_error_msg:		.asciiz "Maximal bar width exceeded! (3:1)"

no_black_pixel_found:		.asciiz "There is no barcode in the bitmap!"
decoded_text:			.asciiz "Text decoded from barcode: "

filepath:			.asciiz	"source.bmp"

.text
open_file:

	# Openning file
	li	$v0, 13
	la	$a0, filepath
	li	$a1, 0
	li	$a2, 0
	syscall
	
	# Checking for openning errors
	bltz	$v0, dsc_file_error # If file handle value from syscall contains negative number, throwing file opening error
	move	$s0, $v0
	
	# Reading header
	li	$v0, 14
	move	$a0, $s0
	la	$a1, header # Reading header (first 54 bytes) section
	li	$a2, 54 # Setting max number of characters to read = 54
	syscall
	
	# Checking bitmap file signature
	li	$t0, 0x4D42 # Setting bitmap file signature (4D 42) to t0
	lhu	$t1, header # lhu - load halfword unsigned - loading first 2 bytes to t1
	bne	$t0, $t1, bitmap_error # If first two bytes of file do not contain bitmap file signature, going to bitmap_error
	
	# Checking width from header
	lw	$t0, width # Setting width (600) to t0
	lw	$s1, header+18 # Reading file width from header at offset of 18 and setting it to s1; Need to read only 2 bytes
	bne	$t0, $s1, size_error # If pre-defined width != width of bitmap file, going to size_error function
	
	# Checking height from header
	lw	$t0, height # Setting height (50) to t0
	lw	$s2, header+22 # Reading file width from header at offset of 22 and setting it to s2; Need to read only 2 bytes
	bne	$t0, $s2, size_error # If pre-defined height != height of bitmap file, going to size_error function
	
	# Checking file format (is 24-bit?)
	li	$t0, 24 # Setting 24 to t0 to verify if our file is 24-bit bitmap
	lb	$t1, header+28 # Reading file bmp bits info from header at offset of 28 and setting it to t1
	bne	$t0, $t1, format_error # If file is not a 24-bit bitmap, going to format_error function

	# Allocating heap memory
	li	$v0, 9
	lw	$s3, header+34 # Reading file size from header at offset of 34 and setting it to s3
	move	$a0, $s3 # Loading size of data section (file size)
	syscall
	move	$s4, $v0 # Storing file handle to s4
	
	# Reading entire file
	li	$v0, 14
	move	$a0, $s0 # Loading file descriptor from s0 to a0
	move	$a1, $s4 # Loading file handle from s4 to a1
	move	$a2, $s3 # Loading size of data section from s3 to a2
	syscall

# Closing file	
close_file:
	li	$v0, 16
	move	$a0, $s0
	syscall

# Setting up the point from which we are going to scan the line
bmp_setup:
	move	$t9, $s4 # Setting address of allocated memory from s4 to t9
	li	$s4, 0 # Setting s4 to 0
	li	$t7, 30 # Setting line_number to t7 (starting from bottom left going 30 lines up)
	li	$t6, 1800 # 3*600 bytes per row (line)
	mul	$t7, $t7, $t6 # Multiplying 30*1800 = 54000 and storing in t7
	addu	$t9, $t9, $t7 # Using 54000 as an offset for allocated memory address stored in t9
	la	$a3, output # output = 100 bytes
	
	# Setting counter for '*' symbols
	li	$s6, 2

# Looking for black pixel
look_for_black: 
	lb	$t0, ($t9) # Setting initial pixel address (mem_address+54000) from t9 to t0. After adding 3 bytes in 'iterate' loop to iterate through BMP
	beqz	$t0, black_found # If t0 = 0, going to black_found. If not, going forward to 'iterate'

# Iterating through line to find black pixel	
iterate: 
	addiu	$t9, $t9, 3 # Adding 3 bytes to t9 (Each pixel = 3 bytes (RGB))
	addiu	$t8, $t8, 1 # t8 is our counter. Adding 1 each time we iterate
	beq	$t8, 599, invalid_barcode # If reached 599, means no black pixel was found, so throwing no barcode message
	j	look_for_black # Iterating with help of look_for_black function

# Setting up registers for finding bar of the smallest width
black_found: 
	li	$t1, 1 # Setting 1 to t1
	la	$t7, ($t9) # Setting offset of black pixel found (54000+offset) to t7
	li	$t8, 30 # Setting t8 to maximal bar width of 30

# Finding bar of the smallest width
# (Every Code39 begins with '*' symbol which has smallest bar as its first element, so measuring size of the first bar)
find_smallest_width:
	addiu	$t7, $t7, 3 # Adding 3 bytes to our black pixel at t7 to find out what color is next pixels
	lb	$t0, ($t7) # Loading offset of next pixel from t7 to t0
	bnez	$t0, thinnest_bar # If (next) pixel at t0 != 0, going to thinnest_bar function (means our next pixel at t0 is white)
	addiu	$t1, $t1, 1 # Using t1 as a new counter to check how many times we iterate in find_smallest_width function.
	beq	$t1, $t8, invalid_barcode #Eventually, if t1=30 means all consecutive pixels were black, so no barcode found
	j	find_smallest_width # Iterating over find_smallest_width function untill find white pixel

# Storing width of the thinnest bar in pixels in t7 register
thinnest_bar:
	move	$t7, $t1 # t1 = width of the thinest bar in pixels. By definition of Code39 every barcode begins and ends with '*' symbol. In barcode representation, '*' symbol begins with the thinnest black bar size of 1. Storing this value in t7

	
#### STARTING FROM HERE BEGINNING DECODING PIXELS ####	

# Performing initial setup of registers for each new character
initial_setup:
	xor	$s0, $s0, $s0 # XORing to reset s0 and use it as decoded character in binary representation
	xor	$s1, $s1, $s1 # XORing to reset s0 and use it as counter of left shifts
	li	$s2, 1 # Setting 1 to s2
	li	$s3, 0 # Setting 0 to s3

# Setting up registers for each new spaces/bars
prepare_pixel:
	li	$t1, 0 # Setting t0 to 0
	lb	$t2, ($t9) # Setting offset of current pixel to t2.(t9 is offset of black pixel found (54009+offset))

# Iterating untill we get a bar
get_bar:
	addiu	$t1, $t1, 1 # Adding 1 to t1. (Increasing width counter)
	addiu	$t9, $t9, 3 # Adding 3 bytes to t9 to get next pixel color
	beq	$t1, $t7, bar_obtained # If t1 equals to width of the thinest bar, then go to bar_obtained
	j	get_bar # Iterating over get_bar untill get proper size (width) of the bar

# After bar is obained, checking what color the bar is
bar_obtained:
	beq	$t2, 0xffffff, white_bar # If current pixel color = white, go to white_bar
	beq	$t2, 0x000000, black_bar # Else, go to black_bar

# Performing required shifts to registers if its space
white_bar:
	or	$s0, $s0, $s3 # Initially, s3 was set to 0 in initial_setup function. Performing OR operation s3 (0) on s0 (0) and storing result in s0
	addiu	$s1, $s1, 1 # s1 = counter of left shifts initiallized in initial_setup. Adding 1 to number of shifts
	beq	$s1, 12, pattern_finished # In Code39 we have 12 units (thinnest bars and spaces) per character, so after we complete a full character, go to pattern_finished
	sll	$s0, $s0, 1 # Shifting left our s0 register by 1, meaning we add 0 to LSB of s0 value
	j	prepare_pixel # Going back to 'prepare_pixel' to get next space/bar to finish the character pattern

# Performing required shifts to registers if its black bar
black_bar:
	or	$s0, $s0, $s2 # Initially, s2 was set to 1 in initial_setup function. Performing OR operation s2 (1) on s0 (0) and storing result in s0
	addiu	$s1, $s1, 1 # s1 = counter of left shifts initiallized in initial_setup. Adding 1 to number of shifts
	beq	$s1, 12, pattern_finished # In Code39 we have 12 units (thinnest bars and spaces) per character, so after we complete a full character, go to pattern_finished
	sll	$s0, $s0, 1 # Shifting left our s0 register by 1, meaning we add 0 to LSB of s0 value
	j	prepare_pixel # Going back to 'prepare_pixel' to get next space/bar to finish the character pattern

# After pattern for one character is completed, preparing registers for further decoding
pattern_finished:
	li	$t1, 0 # Setting 0 to t1
	mulu	$t1, $t7, 3 # Multiplying thinnest bar defined in t7 by 3 and storing result in t1
	addu	$t9, $t9, $t1 # Adding thinnes_bar*3 bytes to t9 to get next pixel color on the next black bar
	li	$t1, 0 # Resetting t1 once again
	la	$t5, codes_array # Loading address of character codes in data.asm to t5	

# Comparing our obtained binary bar sequence with character codes from codes_array	
compare_to_code:
	lw	$t4, ($t5) # Loading character code at current offset to t4; Initially loaded first word (code) in the array. Later will be added offset to go to the next ones.
	beq	$s0, $t4, equal # If binary representation of s0 character equal to t4, go to 'equal'
	bne	$s0, $t4, not_equal # If binary representation of s0 doesn't equal to t4, go to 'not_equal'

# If bar pattern corresponds to any character codes, storing its value in s7 register for checksum calculation and adding its value on output
equal:
	beq	$t1, 43, star_counter # If t1 = '*' symbol, going to star_counter
	move	$s4, $s5 # Storing previous character value. Used for calculating checksum
	move	$s5, $t1 # Setting current character value (character code number) from t1 to s5
	
	addu	$s7, $s7, $s4 # Adding each decoded character
	
	mulu	$t1, $t1, 4 # Multiplying our char value by size of word (4 bytes) to get ASCII word from ASCII_codes array
	la	$t3, ASCII_codes # Setting address of ASCII_codes to t3
	addu	$t3, $t3, $t1 # Adding calculated offset from t1 to t3
	lw	$t3, 0($t3) # Storing character value at given offset to t3
	
	sb	$t3, ($a3) # Storing ASCII character code onto 'output' memory space. (a3 was set in set_up function with 'output' label which = 100 bytes)
	addiu	$a3, $a3, 1 # Adding 1 to a3 (initially a3 = 100) to move to next byte to later store next character
	j	initial_setup # Going back to initial_setup to decode next character

# If bar pattern does not corresponds to any character codes, iterating untill we find proper code or 
# untill we exceed amount of codes to be checked, resulting in exiting with error
not_equal:
	slti	$t2, $t1, 43 # Checking that no value in t1 exceeds 43 to only check valid characters from array
	beqz	$t2, char_code_error # If value exceeds 43, going to wrong_code function
	
	addiu	$t1, $t1, 1 # Adding 1 to t1 (initially t1 = 0)
	addiu	$t5, $t5, 4 # Adding 4 bytes as an offset to t5 (initially t5 = address of character codes in data.asm) to get the next word (code)
	j	compare_to_code # Going back to 'compare_to_code' to compare_to_code our binary character with the rest of the codes in array.

# Counting how many times star appeared in barcode. After we got two stars we put their value on output and going to checksum calculations	
star_counter:
	subiu	$s6, $s6, 1 # Subtracting 1 from star_counter
	
	# Here we put our star on output, as in 'equal' function, but not on checksum string
	la	$t3, ASCII_codes
	mulu	$t1, $t1, 4 
	addu	$t3, $t3, $t1
	lw	$t3, 0($t3)
	
	sb	$t3, ($a3) # Storing decimal ASCII character code onto 'output' memory space. (a3 was set in set_up function with 'output' label which = 100 bytes)
	addiu	$a3, $a3, 1 # Adding 1 to a3 (initially a3 = 100) to move to next byte to later store next character
	
	beqz	$s6, calc_checksum # If both stars were detected, going to calc_checksum function
	j	initial_setup # Going back to initial_setup to decode next character

# Calculating checksum. Obviously, we do not include value of both stars and check character	
calc_checksum:
	li	$t4, 43 # Setting 43 to t4 to use it as modulus value
	divu	$s7, $t4 # Dividing s7 (checksum string) by t4 (43)
	mfhi	$t4 # Moving remainder from 'hi' register to t4 to get our 43 modulus for checksum
	bne	$t4, $s5, wrong_checksum # If our remainder t4 doesn't equal to s5 (last decoded character = checksum char), then going to wrong_checksum function; Else, going to 'finish' function

# Finilazing our ouptup string by adding null character at the end.
# (Might not be neccessary, but added just in case)
finalize:
	li	$t3, '\0' # Loading null character '\0' to t3
	sb	$t3, ($a3) # Making output string null-terminated 

# Printing our final decoded string		
print_decoded_string:
	li	$v0, 4
	la	$a0, decoded_text
	syscall # Syscall to print 'decoded_text' string
	la	$a0, output
	syscall # Syscal to print our final decoded string stored in 'output' memory region
	j	exit # Exiting program...
	
	
##### POSSIBLE ERROR MESSAGES #####		
	
invalid_barcode:
	li	$v0, 4
	la	$a0, invalid_barcode_error_msg
	syscall
	j	exit
	
wrong_checksum:
	li	$v0, 4
	la	$a0, checksum_error_msg
	syscall
	j	finalize

wrong_bar_size:
	li	$v0, 4
	la	$a0, bar_size_error_msg
	syscall
	j	exit

black_not_found:
	li	$v0, 4
	la	$a0, no_black_pixel_found
	syscall
	j	exit
		
dsc_file_error:
	li	$v0, 4
	la	$a0, dsc_error_msg
	syscall
	j	exit
	
char_code_error:
	li	$v0, 4
	la	$a0, char_code_error_msg
	syscall
	j	exit
	
bitmap_error:
	li	$v0, 4
	la	$a0, bitmap_error_msg
	syscall
	j	exit
	
format_error:
	li	$v0, 4
	la	$a0, format_error_msg
	syscall
	j	exit
	
size_error:
	li	$v0, 4
	la	$a0, size_error_msg
	syscall
	j	exit

exit:
	li	$v0, 10
	syscall
