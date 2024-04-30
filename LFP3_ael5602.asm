.data
	yBird: .word 0				# current y coordinate offset of bird
	yGap: .word 7				# y coridnate for top pixel of gap to be drawn between pipes
	xPipe: .word 28				# x coordinate for where pipes are drawn
	rng: .word 0				# random number generator ID
	seed: .word 0				# seed for rng
	score: .word 0				# player's score
	
	startText: .asciiz "Hit the W key to fly up. Avoid hitting the green pipes!" 		# message to display at start of game
	winText: .asciiz "\n\nYou win!"							# msg telling player they won
	loseText: .asciiz "\n\nYou lose!"							# msg telling player they lost
	
	# digit table: digits to draw on score board on display
	# each digit is 15 pixels, five rows of three pixels. 1 is black pixel, 0 is white pixel
	DigitTable:        
        .word   1,1,1,1,0,1,1,0,1,1,0,1,1,1,1	# 0
        .word   0,1,0,1,1,0,0,1,0,0,1,0,0,1,0	# 1
        .word   1,1,1,0,0,1,1,1,1,1,0,0,1,1,1	# 2
        .word   1,1,1,0,0,1,1,1,1,0,0,1,1,1,1	# 3
        .word   1,0,1,1,0,1,1,1,1,0,0,1,0,0,1	# 4
        .word   1,1,1,1,0,0,1,1,1,0,0,1,1,1,1	# 5
        .word   1,1,1,1,0,0,1,1,1,1,0,1,1,1,1	# 6
        .word   1,1,1,0,0,1,0,0,1,0,0,1,0,0,1	# 7
        .word   1,1,1,1,0,1,1,1,1,1,0,1,1,1,1	# 8
        .word   1,1,1,1,0,1,1,1,1,0,0,1,1,1,1	# 9
        
	# color table: hold hex for each color
	ColorTable:	.word	0xffff00	# yellow (0)
			.word 	0xffac1c	# orange (1)
			.word	0x000000	# black (2)
			.word 	0x87ceeb	# sky blue (3)
			.word 	0x228B22	# green (4)
			.word	0xffffff	# white (5)


	# bird parts info: gives x coordinate, y coordinate, color num (from color table), and size for different parts that make up the bird
	BirdPartsInfo:	.word 3, 12, 0, 4	# body 
			.word 2, 13, 0, 3	# back
			.word 1, 15, 0, 1	# tail
			.word 7, 14, 1, 1	# beak
			.word 5, 13, 2, 1	# eye
			
	# pipe info: gives x coordinate, y coordinate, color num (from color table), and size for different pipes
	PipeInfo:	.word 26, 0, 4, 3	# green part of pipe, starting at top of display
			.word 26, 5, 3, 3	# blue part of pipe drawing (the gap between pipes)
		
.text
Main:
	# initialize display
	jal ClearDisplay		# clear display by drawing sky blue box over everything
	jal DrawPipes			# draw pipe obstacles
	jal DrawBird			# draw player character bird
	
	li $a0, 14			# x for DrawScore
	li $a1, 0			# y for DrawScore
	jal DrawScore			# draw score board number over display
	
	# print start msg
	la $a0, startText		# load start text
	li $v0, 4			# syscall 4 - print string
	syscall				# print start text string
	
	li $s2, 0			# initialize counter for MainLoop
	
	# don't start gameplay until user hits a key:
	# startLoop: stalls by pausing then checks IsCharThere. If player hits a key, we move on to MainLoop
	startLoop:
	# pause for 100 ms
	li $a0, 100			# a0 = 100 ms
	li $v0, 32			# syscall 32 - sleep
	syscall				# sleep for 100 ms
	jal IsCharThere			# jump and link to IsCharThere
	beqz $v0, startLoop		# if no data, try later
	
	# MainLoop: loops through gameplay frame by frame
	MainLoop:
	# check if bird should fly up or down
	jal CheckUserInput		# check if user hit key to fly
	
	# update display
	jal ClearDisplay		# clear screen with sky blue color
	jal DrawPipes			# draw pipes 
	jal DrawBird			# draw bird (in new position each loop)
	
	li $a0, 14			# x for DrawScore
	li $a1, 0			# y for DrawScore
	jal DrawScore			# draw score board number over display
	
	# change x position of pipe for next loop
	la $t0, xPipe			# load addr of xPipe
	lw $t1, 0($t0)			# get current x coordinate
	subi $t1, $t1, 2		# subract 2 from current x coordinate
	sw $t1, 0($t0)			# store new x coridnate into xPipe
	
	# check if pipe x coordinate is close enough to hit bird
	blt $s2, 11, continueMain
	
	######################### below code executes when pipe x coordinate is close enough to bird to hit #######################
	jal CheckCollision		# check if bird collides with pipe this loop
	
	# continueMain: branch here if pipe x coordinate is not in range to collide with bird
	continueMain:
	# check if pipe is leaving screen
	addi $s2, $s2, 1		# increment counter
	bne $s2, 15, continueMain2	# if counter is 15 (15th time pipe has moved towards bird), execute following code to change yGap position and reset counter
	
	######################### below code executes [the loop before] each time new set of pipes are "spawned" on right side of display #######################
	# change y position of pipe gap for next loop
	# get new random position for gap in pipe
	la $a0, rng			# load address of rng into a0
	la $a1, seed			# load address of seed into a1
	jal GetRandomPosition		# jump and link to GetRandomPosition
	
	# store new position in yGap
	la $t0, yGap			# load addr of yGap
	sw $v0, 0($t0)			# store new y coridnate into yGap
	
	#reset xPipe position
	la $t1, xPipe			# load xPipe addr
	li $t0, 28			# reset xPipe to 28 (fully rightside of display)
	sw $t0, 0($t1) 			# store 28 into mem for xPipe
	
	li $s2, 0			# reset counter to 0
	
	# increase score
	la $s4, score
	lw $t0, 0($s4)
	addi $t0, $t0, 1
	sw $t0, 0($s4)
	
	# if score is 10, go to win 
	beq $t0, 10, Win
	
	# play tone when player gets a point
	li $a0,	70			# pitch
	li $a1, 1000 			# duration
	li $a2, 123			# instrument
	li $a3, 127			# volume is 127 (maximum volume)
	li $v0, 31			# syscall 31 - MIDI out 
	syscall				# play tone
	
	#continueMain2: branch here to skip above code if counter is not 16 (above is only executed every few loops, when pipe reaches end of screen)
	continueMain2:	
	li $v0, 32			# sleep, then repeat loop
	li $a0, 200
	syscall
	
	j MainLoop			# loop until player wins or loses
	
	li $v0, 10 			# exit program
	syscall
	
#Procedure: Lose 
# if player hits pipe, they lose and program exits
Lose:
	# print lose msg
	la $a0, loseText		# load lose text
	li $v0, 4			# syscall 4 - print string
	syscall				# print lose text string
	
	#play tone
	li $a0,	50			# pitch
	li $a1, 850 			# duration
	li $a2, 74			# instrument
	li $a3, 127			# volume is 127 (maximum volume)
	li $v0, 31			# syscall 31 - MIDI out 
	syscall				# play tone
	
	# sleep
	li $v0, 32			# syscall 32 - sleep	
	li $a0, 875			# sleep slightly longer than first tone - manual alternative to syscall 33
	syscall

	# play next tone
	li $a0,	50			# pitch
	li $a1, 1500			# duration
	li $v0, 31			# syscall 31 - MIDI out 
	syscall
	
	li $v0, 10 			# exit program
	syscall
	
# Procedure: Win
#if player wins, do win actions and exit program
Win:	
	# set up stack
	addi $sp, $sp, -20		# make room on stack for arguments and ra
	sw $ra, 12($sp)			# ra = stack[3]

	### print win msg
	la $a0, winText			# load win text
	li $v0, 4			# syscall 4 - print string
	syscall				# print win text string

	### play win applause
	li $a0,	255			# pitch
	li $a1, 3500 			# duration
	li $a2, 126			# instrument
	li $a3, 127			# volume is 127 (maximum volume)
	li $v0, 31			# syscall 31 - MIDI out 
	syscall				# play tone
	
	### clear display and draw bird wherever it left off (this removes the pipes and old score form the display)
	jal ClearDisplay
	jal DrawBird
	
	### write score in middle of screen 
	# draw 1 (for 10)
	la $t2, score			# load score from mem
	li $t3, 1			# change score to 1 (first part of 10)
	sw $t3, 0($t2) 			# store 1 into score
	
	# set arguments for draw score
	li $a0, 13			# initial x coordinate for DrawScore
	li $a1, 12			# initial y
	jal DrawScore			# draw 1 digit in middle of screen
	
	# draw 0 (for 10)
	li $t3, 0			# change score to 0 (second part of 10)
	sw $t3, 0($t2) 			# store 0 into score
	
	# set arguments for draw score
	li $a0, 16			# initial x coordinate for DrawScore
	li $a1, 12			# initial y
	jal DrawScore			# draw 0 digit in middle of screen
	
	### end program
	li $v0, 10 			# exit program
	syscall
	
#Procedure: CheckCollision
# checks if bird's y coordinates align with pipe's y cooridnates to detect collision. branches to exit program if collision occurs
CheckCollision:
	#check if top of bird is colliding
	# get top of bird y coordinate:
	la $t2, BirdPartsInfo		# load bird parts info addr
	lw $t4, 4($t2)			# load y coordinate from bird parts info
	la $t2, yBird			# load current bird y coordinate offset addr
	lw $t3, 0($t2)			# load current bird y coordinate offset
	add $t2, $t3, $t4		# store top of bird y coordinate (y from BirdPartsInfo + offset from yBird) into t2
	
	# get top pipe y coordinate
	la $t3, yGap			# load yGap addr
	lw $t4, 0($t3)			# load y coordinate of gap betweeen pipes
	subi $t3, $t4, 1		# subtract 1 to get y coordinate of green part of pipe
	
	blt $t2, $t3, Lose		# if top of bird collides with pipe, jump to lose and exit program
	beq $t2, $t3, Lose
	
	#check if bottom of bird is colliding
	addi $t2, $t2, 4		# add 4 pixels to get bottom of bird y coordinate
	addi $t3, $t3, 11		# add 11 pixels to get bottom pipe y coordinate
	
	bgt $t2, $t3, Lose		# if bottom of bird collides with pipe, jump to lose and exit program
	beq $t2, $t3, Lose
	
	jr $ra

#Procedure: CheckUserInput
# checks if user hit key to "fly" up or not, and adjusts bird's y cooridnate offset in memory
CheckUserInput:
	addiu $sp, $sp, -4 		# make room in stack for arguments
	sw $ra, 0($sp)			# ra = stack[0]
	
	jal GetChar			# check if key was hit
	
	# restore stack
	lw $ra, 0($sp)			# restore ra from stack
	
	la $t5, yBird			# load current bird y coordinate offset addr
	lw $t4, 0($t5)			# load current bird y coordinate offset
	
	beq $v0, 'w', flyUp		# branch to flyUp if key was hit, otherwise flyDown
		
	# fly down subtracts 2 to offset
	flyDown:
	li $t3, 2			# to move pixels down screen, we will need to add 2 to y coordinate when drawing
	beq $t4, 16, dontAdd		# if bird is at bottom of screen, dont add more movement to offset
	j addOffset			# jump to add offset
	
	#fly up adds 2 to offset
	flyUp:
	li $t3, -2			# to move pixels up screen, we will need to subtract 2 from y coordinate when drawing
	beq $t4, -12, dontAdd 		# if bird is at top of screen, dont add more movement to offset
	
	# add offset: saves amount to adjust bird to memory
	addOffset:
	add $t4, $t4, $t3		# add flyUp or flyDown ammount to offset
	sw $t4, 0($t5)			# store value back in memory
	
	# dontAdd is branched to when y coordinate for bird is too close to the floor/ceiling to add to. returns procedure without adding to offset
	dontAdd:
	jr $ra
	
#Procedure: DrawScore
# draws numbers in top middle of screen for current score
# input: a0 is x coordinate
# input: a1 is y coordinate
DrawScore:
	# set up stack
	addi $sp, $sp, -20		# make room on stack for arguments and ra
	sw $ra, 12($sp)			# ra = stack[3]
	
	# set counter
	li $s1, 0			# counter for score loop
	
	# get correct digit to draw for current score
	la $s3, DigitTable		# load didgit table addr
	la $s4, score			# load score addr
	lw $t0, 0($s4)			# use score to adjust s3 based on saved score from mem
	mul $t0, $t0, 60		# score * 60 (15 words in digit table)
	add $s3, $s3, $t0		# score * 60 + addr of digit table = new digit table addr
		
	# score loop: loops through 15 different pixels that make up score number
	scoreLoop:
	sw $a0, 0($sp)			# a0 = stack[0]
	sw $a1, 4($sp)			# a1 = stack[1]
	sw $a2, 8($sp)			# a2 = stack[2]
	sw $a3, 16($sp)			# a3 = stack[4]
	
	lw $t0, 0($s3)			# load pixel from digit table
	beq $t0, 0, setColorWhite	# if 0 in digit table, set pixel color to white
	li $a2, 2			# otherwise, set pixel color to black
	
	# contine score loop: rturn here after setColorWhite
	continueScoreLoop:
	jal DrawDot
	
	# restore stack values to their registers (except ra)
	lw $a0, 0($sp)		
	lw $a1, 4($sp)		
	lw $a2, 8($sp)	
	lw $a3, 16($sp)
	
	addi $a0, $a0, 1		# increment x by 1
	
	# if third pixel of line has been drawn, set reset arguments in nextLine
	beq $s1, 2, nextLine		
	beq $s1, 5, nextLine
	beq $s1, 8, nextLine
	beq $s1, 11, nextLine
	
	# manage loop: return here after nectLine branch. manages loop counters and incrments addr
	manageLoop:
	addi $s3, $s3, 4		# increment digit table addr
	addi $s1, $s1, 1		# increment counter
	bne $s1, 15, scoreLoop		# loop 15 times to draw each pixel of digit
	
	# restore registers and stack		
	lw $ra, 12($sp)			# restore ra from stack
	addi $sp, $sp, 20		# readjust stack space
	jr $ra				# return
	
	# reset x and y coordinates for next line of digit on display
	nextLine:
	addi $a1, $a1, 1		# move down one pixel to next line
	subi $a0, $a0, 3		# move back thre pixels to initial x position
	j manageLoop			# continue in manage loop part of score loop
	
	# set pixel color argument for DrawDot to white
	setColorWhite:
	li $a2, 5			# white is color num 5 from table
	j continueScoreLoop		# continue in score loop
	
#Procedure: DrawPipes
# draws two pipes on top of each other with a space between them 
DrawPipes:
	addiu $sp, $sp, -4 		# make room in stack for arguments
	sw $ra, 0($sp)			# ra = stack[0]
	
	li $s1, 0			# counter for draw pipes loop
	# drawPipesLoop: draw green part of pipes
	drawPipesLoop:
	# load arguments and boxes to draw pipes
	la $t0, PipeInfo		# get info from pipe info table, and set x, y, color num and size
	jal LoadBoxInfo			# jump and link to LoadBoxInfo - sets arguments for DrawBox	
	
	mul $t1, $s1, 2			# move y coordinate down 2 pixels to draw vertical pipe across display -> (counter * 2) + addr
	add $a1, $a1, $t1		# (counter * 2) + addr
	
	la $t1, xPipe			# change x cooridnate to xPipe saved in mem
	lw $a0, 0($t1)			# set argument a0 to xPipe value
	
	jal DrawBox			# jump and link to DrawBox
	
	# manage draw pipes loop
	addi $s1, $s1, 1		# increment counter
	bne $s1, 16, drawPipesLoop	# loop 16 times to cover whole screen top to bottom
	
	li $s1, 0			# counter for draw gap loop
	# drawGapLoop: draw blue part between pipes at random y cooridnate
	drawGapLoop:
	# load arguments and boxes to draw pipes
	la $t0, PipeInfo		# get info from pipe info table, and set x, y, color num and size
	add $t0, $t0, 16		# move addr to gap part of pipe info table
	jal LoadBoxInfo			# jump and link to LoadBoxInfo - sets arguments for DrawBox	
	
	la $t2, yGap			# load yGap addr (holds y coordinate where gap should start)
	lw $a1, 0($t2)			# load new y coordinate for gap from memory
	mul $t1, $s1, 2			# move down 2 pixels to draw vertical pipe across display -> (counter * 2) + addr
	add $a1, $a1, $t1		# (counter * 2) + addr
	
	la $t1, xPipe			# change x cooridnate to xPipe saved in mem
	lw $a0, 0($t1)			# set argument a0 to xPipe value
	
	jal DrawBox			# jump and link to DrawBox
	
	# manage draw gap loop
	addi $s1, $s1, 1		# increment counter
	bne $s1, 4, drawGapLoop		# loop four times to draw 8 pixel gap in pipe
	
	# restore stack and return
	lw $ra, 0($sp)			# restore ra from stack
	jr $ra				# return

#Procedure: DrawBird
# draws all boxes that make up bird
DrawBird:
	addiu $sp, $sp, -4 		# make room in stack for arguments
	sw $ra, 0($sp)			# ra = stack[0]
	
	li $s1, 0			# counter for draw bird loop
	# drawBirdLoop: draw all parts of bird
	drawBirdLoop:
	# load arguments and boxes to draw bird
	la $t0, BirdPartsInfo		# get info from bird parts info table, and set x, y, color num and size
	mul $t1, $s1, 16		# adjust bord parts info adddress by equation (counter * 16) + addr
	add $t0, $t0, $t1		# adjusted addr = counter * 16) + addr 
	jal LoadBoxInfo			# jump and link to LoadBoxInfo - sets arguments for DrawBox
	la $t5, yBird			# load yBird offset addr
	lw $t3, 0($t5)			# load y coordinate offset
	add $a1, $a1, $t3		# adjust bird y coordinate
	
	jal DrawBox			# jump and link to DrawBox
	
	# manage draw bird loop
	addi $s1, $s1, 1		# increment counter
	bne $s1, 5, drawBirdLoop	# loop 5 times to draw all parts of bird
	
	# restore stack and return
	lw $ra, 0($sp)			# restore ra from stack
	jr $ra				# return
	
#Procedure: GetRandomPosition
# generates random y coordinate position and returns it in $v0
# input: a0 points to word address that stores random number generator ID (rng)
# input: a1 points to word address that stores seed for the rng
GetRandomPosition:
	sw $0, 0($a0)		# initialize rng ID to 0

	# copy addresses to temp to return them later
	move $t0, $a0		# copy address of rng to t0
	move $t1, $a1		# copy address of seed to t1
		
	# get system time for seed
	li $v0, 30		# syscall 30 - system time
	syscall			# get system time
	sw $a0, 0($t1)		# store system time into seed
	
	# set seed using system time
	lw $a0, ($t0)		# set argument a0 to rng
	lw $a1, ($t1)		# set argument a1 to seed
	li $v0, 40		# syscall 40 - set seed
	syscall			# set seed for rng
	sw $a1, 0($t1)		# store generated seed
		
	# set random range to be 6-13
	lw $a0, ($t0)		# set argument a0 to rng
	li $a1, 13		# set argument a1 = upper bound of range = 13
	li $v0, 42		# syscall 42 - random int range
	syscall			# set random range
	addi $a0, $a0, 6	# add 6 to a0 to make range 6-13
	move $v0, $a0		# copy random num to v0
	
	# reset addresses back to originals
	move $a0, $t0		# copy address of rng to a0
	move $a1, $t1		# copy address of seed to a1
	
	# exit procedure
	jr $ra			# return to main
	
#Procedure: GetChar
# poll the keyboard, wait for input character
# output: v0 is ascii character
GetChar:
	addiu $sp, $sp, -4		# make room on stack
	sw $ra, 0($sp)			# ra = stack[0]
	li $s5, 0			# counter to handle timeout
	
	j check				# jump to check
	
	# cloop: stalls for check by pausing. also checks for timeout
	cloop:
	# pause for 100 ms
	li $a0, 100			# a0 = 100 ms
	li $v0, 32			# syscall 32 - sleep
	syscall				# sleep for 100 ms
	
	# check for timeout
	addi $s5, $s5, 1		# increment counter
	beq $s5, 4, timeout		# if counter reaches 4 (400 ms have passed), timeout occurs and bird will fall this loop
	
	# check: get char from queue and returns it
	check:
	jal IsCharThere			# jump and link to IsCharThere
	beqz $v0, cloop			# if no data, try later
	
	lui $t0, 0xffff			# char in 0xffff0004
	lw $v0, 4($t0)			# store char in v0
	
	lw $ra, 0($sp)			# restore ra
	addiu $sp, $sp, 4		# readjust stack
	jr $ra				# return
	
	# timeout: sets up return value for user to lose upon return
	timeout:
	li $v0, '0'			# store always-wrong char into v0 (return value)
	lw $ra, 0($sp)			# restore ra
	addiu $sp, $sp, 4		# readjust stack
	jr $ra				# return
		
#Procedure: IsCharThere
# check if char is present in buffer
# output: v0 is 0 if no data or 1 if char is in buffer
IsCharThere:
	lui $t0, 0xffff			# reg at 0xffff0000
	lw $t1, 0($t0)			# get control
	andi $v0, $t1, 1		# look at lsb
	jr $ra				# return
	
#Procedure: ClearDisplay
# draw blue box over display to "clear" it
ClearDisplay:
	# set up stack
	addi $sp, $sp, -4		# make room on stack for ra
	sw $ra, 0($sp)			# ra = stack[0]
	
	# load arguments for "clearing"
	la $a0, 0			# x coordinate = 0
	la $a1, 0			# y coordinate = 0
	la $a2, 3			# color = sky blue (3 from color table)
	la $a3, 32			# size of box = 32
	
	jal DrawBox			# draw blue box ("clear" the display)
	
	# restore ra and stack
	lw $ra, 0($sp)			# restore ra from stack
	addi $sp, $sp, 4		# readjust stack space
	
	jr $ra				# return

#Procedure: LoadBoxInfo
# loads arguments for draw box based on color info table
# input: t0 = temporary variable holding adjusted address of BirdPartsInfo table ased on color to draw
# output: a0 is x coordinate
# output: a1 is y cordinate
# output: a2 is color number from color table
# output: a3 is size of box
LoadBoxInfo:
	lw $a0, 0($t0)			# x coordinate
	lw $a1, 4($t0)			# y coordinate
	lw $a2, 8($t0)			# color num
	lw $a3, 12($t0)			# square size 
	
	jr $ra				# return

#Procedure: DrawBox
# draws filled in box in given coordinates of bitmap, in given color
# input: a0 is x coordinate
# input: a1 is y cordinate
# input: a2 is color number from color table
# input: a3 is size of box
DrawBox:
	# set up stack
	addi $sp, $sp, -24		# make room on stack for arguments, temp variable, and ra
	sw $ra, 20($sp)			# ra = stack[5]
	sw $a0, 0($sp)			# a0 = stack[0]
	sw $a1, 4($sp)			# a1 = stack[1]
	sw $a2, 8($sp)			# a2 = stack[2]
	sw $a3, 12($sp)			# a3 = stack[3]
	move $s0, $a3			# copy a3 to temp register s0 (counter)
	sw $s0, 16($sp)			# store s0 on stack[4]
	
	# boxLoop: draw horizontal lines until full box is complete
	boxLoop: 
	jal DrawHorzLine		# jump and link to drawHorzLine
	
	# restore stack values to their registers (except ra)
	lw $a0, 0($sp)		
	lw $a1, 4($sp)		
	lw $a2, 8($sp)		
	lw $a3, 12($sp)		
	lw $s0, 16($sp)		
	
	# manage loop
	addi $a1, $a1, 1		# increment y 
	sw $a1, 4($sp)			# update a1 (y coordinate) in stack[1]
	subi $s0, $s0, 1		# decrement counter
	sw $s0, 16($sp)			# update s0 (counter) in stack[4]
	bnez $s0, boxLoop		# loop if counter is not 0
	
	# restore ra and stack
	lw $ra, 20($sp)			# restore ra from stack
	addi $sp, $sp, 24		# readjust stack space
	li $s0, 0			# reset counter 
	
	jr $ra				# return 
		
#Procedure: DrawDot
# draw a dot on the bitmap display
# input: a0 is x coordinate
# input: a1 is y cordinate
# input: a2 is color number from color table
# output: v0 is address of pixel
# output: v1 is color
DrawDot:
	# set up stack
	addi $sp, $sp, -8		# make room on stack for arguments and ra
	sw $ra, 4($sp)			# ra = stack[1]
	sw $a2, 0($sp)			# a2 = stack[0]
	
	# calculate address
	jal CalcAddress			# jump and link to CalcAddress. returns v0 = address of pixel/dot
	lw $a2, 0($sp)			# restore a2 from stack
	sw $v0, 0($sp)			# save v0 = stack[0]. v0 holds address of pixel
	
	# get color
	jal GetColor			# jump and link to GetColor. returns v1 = color
	lw $v0, 0($sp)			# Restores v0 from stack
	
	# draw dot
	sw $v1, 0($v0)			# draw dot (set color at address of pixel)
	
	# restore ra and stack
	lw $ra, 4($sp)			# restore ra from stack
	addi $sp, $sp, 8		# readjust stack space
	
	jr $ra				# return
	
#Procedure: CalcAddress:
# convert x, y coordinates to pixel address
# input: a0 is x coordinate
# input: a1 is y cordinate
# output: v0 is memory address of pixel
CalcAddress:
	# base addr + a0 * 4 + a1 * 32 * 4 = v0
	sll $a0, $a0, 2			# a0 * 4
	sll $a1, $a1, 5			# a1 * 32
	sll $a1, $a1, 2			# (a1 * 32) * 4
	add $a0, $a0, $a1		# (a0 * 4) + (a1 * 32 * 4)
	addi $v0, $a0, 0x10040000	#  base addr + ((a0 * 4) + (a1 * 32 * 4)) = v0
	
	jr $ra				# return
	
#Procedure: GetColor:
# gets color based on a2
# input: a2 is color number from color table
# output: v1 is actual number to write to display
GetColor:	
	la $t0, ColorTable		# load base from color table
	sll $a2, $a2, 2			# index x4 is offset
	add $a2, $a2, $t0		# address = base + offset
	
	lw $v1, 0($a2)			# get actual color from memory, return in v1

	jr $ra				# return
	
#Procedure: DrawHorzLine:
# draw a horizontal line on the bitmap display
# input: a0 is x coordinate
# input: a1 is y cordinate
# input: a2 is color number from color table
# input: a3 is size of box (length of line)
DrawHorzLine:
	# set up stack
	addi $sp, $sp, -20		# make room on stack for arguments and ra
	sw $ra, 12($sp)			# ra = stack[3]
	sw $a0, 0($sp)			# a0 = stack[0]
	sw $a1, 4($sp)			# a1 = stack[1]
	sw $a2, 8($sp)			# a2 = stack[2]
	sw $a3, 16($sp)			# a3 = stack[4]
	
	# horzLoop: draw dots until line is complete
	horzLoop:
	jal DrawDot			# jump and link to DrawDot
	
	# restore stack values to their registers (except ra)
	lw $a0, 0($sp)		
	lw $a1, 4($sp)		
	lw $a2, 8($sp)		
	
	# manage loop
	addi $a0, $a0, 1		# increment x 
	sw $a0, 0($sp)			# update a0 in stack[0]
	subi $a3, $a3, 1		# decrement length of line
	bnez $a3, horzLoop		# loop if length is not 0
	
	# restore ra and stack
	lw $a3, 16($sp)	
	lw $ra, 12($sp)			# restore ra from stack
	addi $sp, $sp, 20		# readjust stack space
	
	jr $ra				# return
