////////////////////////////////////////////////////////////////////////
// GRAPHICS.C
//		Responsible for sending user input from serial input commands
//		Compile with gcc graphics.c -o graphics
// (Priya Kattappurath, Michael Rivera, Caitlin Stanton)
////////////////////////////////////////////////////////////////////////

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <math.h>
#include <sys/types.h>
#include <string.h>
// interprocess comm
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/mman.h>
#include <time.h>
// network stuff
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>

#include "address_map_arm_brl4.h"

// fixed point
#define float2fix30(a) ((int)((a)*1073741824)) // 2^30

#define SWAP(X, Y) \
	do               \
	{                \
		int temp = X;  \
		X = Y;         \
		Y = temp;      \
	} while (0)

// shift fraction to 32-bit sound
#define fix2audio28(a) (a << 4)
// shift fraction to 16-bit sound
#define fix2audio16(a) (a >> 12)

/* function prototypes */
void VGA_text(int, int, char *);
void VGA_text_clear();
void VGA_box(int, int, int, int, short);
void VGA_line(int, int, int, int, short);
void VGA_disc(int, int, int, short);
int VGA_read_pixel(int, int);
int video_in_read_pixel(int, int);
void draw_delay(void);

// 8-bit line color choices
#define pink (0xe6)
#define red (0xe1)
#define orange (0xf1)
#define green (0x59)
#define blue (0x32)
#define purple (0xaa)
#define white (0xff)
#define black (0x00)
int colors[] = {pink, red, orange, green, blue, purple, white, black};

// pixel macro
// !!!PACKED VGA MEMORY!!!
#define VGA_PIXEL(x, y, color)                           \
	do                                                     \
	{                                                      \
		char *pixel_ptr;                                     \
		pixel_ptr = (char *)vga_pixel_ptr + ((y)*640) + (x); \
		*(char *)pixel_ptr = (color);                        \
	} while (0)

// virtual to real address pointers

volatile unsigned int *reset_pio;
volatile unsigned int *lsystem_char;
volatile char *axiom;
volatile unsigned int *iterations;
volatile unsigned int *length;
volatile unsigned int *lsystem;
volatile unsigned int *start_x;
volatile unsigned int *start_y;
volatile unsigned int *timer_counter;
volatile char *color;

// phase accumulator

// fixed pt macros suitable for 32-bit sound
typedef signed int fix28;
// drum-specific multiply macros simulated by shifts
#define times0pt5(a) ((a) >> 1)
#define times0pt25(a) ((a) >> 2)
#define times2pt0(a) ((a) << 1)
#define times4pt0(a) ((a) << 2)
#define times0pt9998(a) ((a) - ((a) >> 12)) //>>10
#define times0pt9999(a) ((a) - ((a) >> 13)) //>>10
#define times0pt999(a) ((a) - ((a) >> 10))	//>>10
#define MIN(X, Y) (((X) < (Y)) ? (X) : (Y))

//multiply two fixed 4:28
#define multfix28(a, b) ((fix28)((((signed long long)(a)) * ((signed long long)(b))) >> 28))
//#define multfix28(a,b) ((fix28)((( ((short)((a)>>17)) * ((short)((b)>>17)) ))))
#define float2fix28(a) ((fix28)((a)*268435456.0f)) // 2^28
#define fix2float28(a) ((float)(a) / 268435456.0f)
#define int2fix28(a) ((a) << 28)
#define fix2int28(a) ((a) >> 28)
#define times_rho(a, b) (multfix28(a, float2fix28(MIN(0.49, 0.06 + fix2float28(multfix28((b >> 1), (b >> 1))))))) //>>2

// shift fraction to 32-bit sound
#define fix2audio28(a) (a << 4)

// reset pio
#define RESET_START 0x00000000
#define RESET_END 0x0000000f
#define RESET_SPAN 0x00000010

// lsystem char pio
#define LSYSTEM_CHAR_START 0x00000010
#define LSYSTEM_CHAR_END 0x0000001f
#define LSYSTEM_CHAR_SPAN 0x00000010

// axiom pio
#define AXIOM_START 0x00000030
#define AXIOM_END 0x0000003f
#define AXIOM_SPAN 0x00000010

// iterations pio
#define ITERATIONS_START 0x00000040
#define ITERATIONS_END 0x0000004f
#define ITERATIONS_SPAN 0x00000010

// length pio
#define LENGTH_START 0x00000050
#define LENGTH_END 0x0000005f
#define LENGTH_SPAN 0x00000010

// lsystem pio
#define LSYSTEM_START 0x00000060
#define LSYSTEM_END 0x0000006f
#define LSYSTEM_SPAN 0x00000010

// start_x pio
#define START_X_START 0x00000070
#define START_X_END 0x0000007f
#define START_X_SPAN 0x00000010

// start_y pio
#define START_Y_START 0x00000080
#define START_Y_END 0x0000008f
#define START_Y_SPAN 0x00000010

// timer counter pio
#define TIMER_START 0x00000090
#define TIMER_END 0x0000009f
#define TIMER_SPAN 0x00000010

// color pio
#define COLOR_START 0x00000100
#define COLOR_END 0x0000010f
#define COLOR_SPAN 0x00000010

// the light weight buss base
void *h2p_lw_virtual_base;

// pixel buffer
volatile unsigned int *vga_pixel_ptr = NULL;
void *vga_pixel_virtual_base;

// character buffer
volatile unsigned int *vga_char_ptr = NULL;
void *vga_char_virtual_base;

// /dev/mem file descriptor
int fd;

// shared memory
key_t mem_key = 0xf0;
int shared_mem_id;
int *shared_ptr;
///

int string_length(volatile char *s)
{
	int c = 0;
	while (*s != '\0')
	{
		c++;
		*s++;
	}
	return c;
}

int main(void)
{
	// Declare volatile pointers to I/O registers (volatile 	// means that IO load and store instructions will be used 	// to access these pointer locations,
	// instead of regular memory loads and stores)

	uint64_t diff;
	struct timespec start, end;
	//int i;

	// === shared memory =======================
	// with video process
	shared_mem_id = shmget(mem_key, 100, IPC_CREAT | 0666);
	shared_ptr = shmat(shared_mem_id, NULL, 0);

	// === need to mmap: =======================
	// FPGA_CHAR_BASE
	// FPGA_ONCHIP_BASE
	// HW_REGS_BASE

	// === get FPGA addresses ==================
	// Open /dev/mem
	if ((fd = open("/dev/mem", (O_RDWR | O_SYNC))) == -1)
	{
		printf("ERROR: could not open \"/dev/mem\"...\n");
		return (1);
	}

	// get virtual addr that maps to physical
	h2p_lw_virtual_base = mmap(NULL, HW_REGS_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, HW_REGS_BASE);
	if (h2p_lw_virtual_base == MAP_FAILED)
	{
		printf("ERROR: mmap1() failed...\n");
		close(fd);
		return (1);
	}

	//map reset PIO port
	reset_pio = (volatile unsigned int *)(h2p_lw_virtual_base + RESET_START);
	lsystem_char = (volatile unsigned int *)(h2p_lw_virtual_base + LSYSTEM_CHAR_START);
	axiom = (volatile char *)(h2p_lw_virtual_base + AXIOM_START);
	iterations = (volatile unsigned int *)(h2p_lw_virtual_base + ITERATIONS_START);
	length = (volatile unsigned int *)(h2p_lw_virtual_base + LENGTH_START);
	lsystem = (volatile unsigned int *)(h2p_lw_virtual_base + LSYSTEM_START);
	start_x = (volatile unsigned int *)(h2p_lw_virtual_base + START_X_START);
	start_y = (volatile unsigned int *)(h2p_lw_virtual_base + START_Y_START);
	timer_counter = (volatile unsigned int *)(h2p_lw_virtual_base + TIMER_START);
	color = (volatile char *)(h2p_lw_virtual_base + COLOR_START);

	// address to resolution register
	//res_reg_ptr =(unsigned int *)(h2p_lw_virtual_base +  	 	//		resOffset);

	//addr to vga status
	//stat_reg_ptr = (unsigned int *)(h2p_lw_virtual_base +  	 	//		statusOffset);

	// === get VGA char addr =====================
	// get virtual addr that maps to physical
	vga_char_virtual_base = mmap(NULL, FPGA_CHAR_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, FPGA_CHAR_BASE);
	if (vga_char_virtual_base == MAP_FAILED)
	{
		printf("ERROR: mmap2() failed...\n");
		close(fd);
		return (1);
	}

	// Get the address that maps to the FPGA LED control
	vga_char_ptr = (unsigned int *)(vga_char_virtual_base);

	// === get VGA pixel addr ====================
	// get virtual addr that maps to physical
	vga_pixel_virtual_base = mmap(NULL, FPGA_ONCHIP_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, FPGA_ONCHIP_BASE);
	if (vga_pixel_virtual_base == MAP_FAILED)
	{
		printf("ERROR: mmap3() failed...\n");
		close(fd);
		return (1);
	}

	// Get the address that maps to the FPGA pixel buffer
	vga_pixel_ptr = (unsigned int *)(vga_pixel_virtual_base);

	char buffer[256];
	//add a signal to help clear between new l-systems
	//high in TOP_RESET
	*length = 0;
	memset(axiom, 0, 4);
	while (1)
	{
		printf("What L-System would you like?\n"); //recommend default axiom, say what characters are available
		printf("0: Dragon Curve; 1: Sierpinski Arrowhead (1); 2: Koch Curve; 3: Sierpinski Arrowhead (2); 4: Koch Snowflake; 5: Cross; 6: Tessellated Triangle \n");
		printf("L-System: ");
		scanf("%i", lsystem);

		//print default axiom and available characters based on lsystem choice
		if (*lsystem == 0)
		{
			printf("The default axiom for the Dragon Curve is FX\n");
			printf("Rule-making characters: X,Y\n");
			printf("Drawing characters: F\n");
			printf("Available characters are: F,A,X,Y,+,-\n");
		}
		else if (*lsystem == 1)
		{
			printf("The default axiom for the Sierpinski Arrowhead (1) is YF\n");
			printf("Rule-making characters: X,Y\n");
			printf("Drawing characters: F\n");
			printf("Available characters are: F,A,X,Y,+,-\n");
		}
		else if (*lsystem == 2)
		{
			printf("The default axiom for the Koch Curve is F\n");
			printf("Rule-making characters: F\n");
			printf("Drawing characters: F\n");
			printf("Available characters are: F,A,X,Y,+,-\n");
		}
		else if (*lsystem == 3)
		{
			printf("The default axiom for the Sierpinski Arrowhead (2) is A\n");
			printf("Rule-making characters: A,F\n");
			printf("Drawing characters: A,F\n");
			printf("Available characters are: F,A,X,Y,+,-\n");
		}
		else if (*lsystem == 4)
		{
			printf("The default axiom for the Koch Snowflake is F++F++F\n");
			printf("Rule-making characters: F\n");
			printf("Drawing characters: F\n");
			printf("Available characters are: F,A,X,Y,+,-\n");
		}
		else if (*lsystem == 5)
		{
			printf("The default axiom for the Cross is F+F+F+F\n");
			printf("Rule-making characters: F\n");
			printf("Drawing characters: F\n");
			printf("Available characters are: F,A,X,Y,+,-\n");
		}
		else if (*lsystem == 6)
		{
			printf("The default axiom for the Tessellated Triangle is F+F+F\n");
			printf("Rule-making characters: F\n");
			printf("Drawing characters: F\n");
			printf("Available characters are: F,A,X,Y,+,-\n");
		}
		else
		{
			printf("Please input a valid L-System\n\n");
		}

		while (*lsystem > 6 || *length < 0)
		{
			printf("What L-System would you like?\n"); //recommend default axiom, say what characters are available
			printf("0: Dragon curve; 1: Sierpinski Arrowhead (1); 2: Koch Curve; 3: Sierpinski Arrowhead (2); 4: Koch Snowflake; 5: Cross; 6: Tessellated Triangle  \n");
			printf("L-System: ");
			scanf("%i", lsystem);

			//print default axiom and available characters based on lsystem choice
			if (*lsystem == 0)
			{
				printf("The default axiom for the Dragon Curve is FX\n");
				printf("Rule-making characters: X,Y\n");
				printf("Drawing characters: F\n");
				printf("Available characters are: F,A,X,Y,+,-\n");
			}
			else if (*lsystem == 1)
			{
				printf("The default axiom for the Sierpinski Arrowhead (1) is YF\n");
				printf("Rule-making characters: X,Y\n");
				printf("Drawing characters: F\n");
				printf("Available characters are: F,A,X,Y,+,-\n");
			}
			else if (*lsystem == 2)
			{
				printf("The default axiom for the Koch Curve is F\n");
				printf("Rule-making characters: F\n");
				printf("Drawing characters: F\n");
				printf("Available characters are: F,A,X,Y,+,-\n");
			}
			else if (*lsystem == 3)
			{
				printf("The default axiom for the Sierpinski Arrowhead (2) is A\n");
				printf("Rule-making characters: A,F\n");
				printf("Drawing characters: A,F\n");
				printf("Available characters are: F,A,X,Y,+,-\n");
			}
			else if (*lsystem == 4)
			{
				printf("The default axiom for the Koch Snowflake is F++F++F\n");
				printf("Rule-making characters: F\n");
				printf("Drawing characters: F\n");
				printf("Available characters are: F,A,X,Y,+,-\n");
			}
			else if (*lsystem == 5)
			{
				printf("The default axiom for the Cross is F+F+F+F\n");
				printf("Rule-making characters: F\n");
				printf("Drawing characters: F\n");
				printf("Available characters are: F,A,X,Y,+,-\n");
			}
			else if (*lsystem == 6)
			{
				printf("The default axiom for the Tessellated Triangle is F+F+F\n");
				printf("Rule-making characters: F\n");
				printf("Drawing characters: F\n");
				printf("Available characters are: F,A,X,Y,+,-\n");
			}
			else
			{
				printf("Please input a valid L-System\n\n");
			}
		}

		printf("Axiom: ");
		scanf("%s", &axiom[0]);

		printf("Number of iterations: ");
		scanf("%i", iterations);

		printf("Length of line: ");
		scanf("%i", length);
		if (*lsystem == 0)
		{
			while (*length < 3 || *length > 31)
			{
				printf("Length of line: ");
				scanf("%i", length);
			}
		}
		else if (*lsystem == 1 || *lsystem == 2 || *lsystem == 3)
		{
			while (*length < 7 || *length > 31)
			{
				printf("Length of line: ");
				scanf("%i", length);
			}
		}

		printf("What color would you like?\n");
		printf("Choices are: pink, red, orange, green, blue, purple, and white\n");
		printf("Line color: ");
		scanf("%s", &buffer[0]);
		if (strcmp(buffer, "pink") == 0)
		{
			*color = pink;
		}
		else if (strcmp(buffer, "red") == 0)
		{
			*color = red;
		}
		else if (strcmp(buffer, "orange") == 0)
		{
			*color = orange;
		}
		else if (strcmp(buffer, "green") == 0)
		{
			*color = green;
		}
		else if (strcmp(buffer, "blue") == 0)
		{
			*color = blue;
		}
		else if (strcmp(buffer, "purple") == 0)
		{
			*color = purple;
		}
		else if (strcmp(buffer, "white") == 0)
		{
			*color = white;
		}
		else
		{
			printf("Invalid color choice, default white chosen\n");
			*color = white;
		}

		printf("Starting x coordinate (between 1 and 638): ");
		scanf("%i", start_x);
		while (*start_x < 1 || *start_x > 638)
		{
			printf("Starting x coordinate (between 1 and 638): ");
			scanf("%i", start_x);
		}

		printf("Starting y coordinate (between 1 and 478): ");
		scanf("%i", start_y);
		while (*start_y < 1 || *start_y > 478)
		{
			printf("Starting y coordinate (between 1 and 478): ");
			scanf("%i", start_y);
		}

		VGA_box(0, 0, 639, 479, black);
		*reset_pio = 1;
		scanf("%s", &buffer[0]);
		*reset_pio = 0;
		printf("reset sent\n");

		int wait = 0;
		while (wait != *timer_counter)
		{
			wait = *timer_counter;
		};
		printf("Time to visualize: %f\n\n", (float)(*timer_counter * (pow(10, -9)) * 20));

		*buffer = 0;
		while (*buffer != 4)
		{

			printf("1: Zoom in; 2: Zoom out; 3: Pan to new coordinates; 4: Quit zoom/pan functionality\n");
			scanf("%i", buffer);

			if (*buffer == 4)
			{
				printf("\n");
				break;
			}
			else
			{
				if (*buffer == 1)
				{ //zoom in
					*length = *length * 2;
					if (*length <= 2)
					{
						*length == 3;
					}
					VGA_box(0, 0, 639, 479, black);
				}
				if (*buffer == 2)
				{ //zoom in
					*length = *length / 2;
					if (*length >= 32)
					{
						*length == 31;
					}
					VGA_box(0, 0, 639, 479, black);
				}
				if (*buffer == 3)
				{
					printf("Starting x coordinate (between 1 and 638): ");
					scanf("%i", start_x);
					while (*start_x < 1 || *start_x > 638)
					{
						printf("Starting x coordinate (between 1 and 638): ");
						scanf("%i", start_x);
					}

					printf("Starting y coordinate (between 1 and 478): ");
					scanf("%i", start_y);
					while (*start_y < 1 || *start_y > 478)
					{
						printf("Starting y coordinate (between 1 and 478): ");
						scanf("%i", start_y);
					}
					VGA_box(0, 0, 639, 479, black);
				}

				*reset_pio = 1;
				scanf("%s", &buffer[0]);
				*reset_pio = 0;
				printf("reset sent\n");

				wait = 0;
				while (wait != *timer_counter)
				{
					wait = *timer_counter;
				};
				printf("Time to visualize: %f\n\n", (float)(*timer_counter * (pow(10, -9)) * 20));

				*buffer = 0;
			}
		}
	} // end while(1)
} // end main

/****************************************************************************************
 * Subroutine to read a pixel from the VGA monitor 
****************************************************************************************/
int VGA_read_pixel(int x, int y)
{
	char *pixel_ptr;
	pixel_ptr = (char *)vga_pixel_ptr + ((y)*640) + (x);
	return *pixel_ptr;
}

/****************************************************************************************
 * Subroutine to send a string of text to the VGA monitor 
****************************************************************************************/
void VGA_text(int x, int y, char *text_ptr)
{
	volatile char *character_buffer = (char *)vga_char_ptr; // VGA character buffer
	int offset;
	/* assume that the text string fits on one line */
	offset = (y << 7) + x;
	while (*(text_ptr))
	{
		// write to the character buffer
		*(character_buffer + offset) = *(text_ptr);
		++text_ptr;
		++offset;
	}
}

/****************************************************************************************
 * Subroutine to clear text to the VGA monitor 
****************************************************************************************/
void VGA_text_clear()
{
	volatile char *character_buffer = (char *)vga_char_ptr; // VGA character buffer
	int offset, x, y;
	for (x = 0; x < 79; x++)
	{
		for (y = 0; y < 59; y++)
		{
			/* assume that the text string fits on one line */
			offset = (y << 7) + x;
			// write to the character buffer
			*(character_buffer + offset) = ' ';
		}
	}
}

/****************************************************************************************
 * Draw a filled rectangle on the VGA monitor 
****************************************************************************************/
#define SWAP(X, Y) \
	do               \
	{                \
		int temp = X;  \
		X = Y;         \
		Y = temp;      \
	} while (0)

void VGA_box(int x1, int y1, int x2, int y2, short pixel_color)
{
	char *pixel_ptr;
	int row, col;

	/* check and fix box coordinates to be valid */
	if (x1 > 639)
		x1 = 639;
	if (y1 > 479)
		y1 = 479;
	if (x2 > 639)
		x2 = 639;
	if (y2 > 479)
		y2 = 479;
	if (x1 < 0)
		x1 = 0;
	if (y1 < 0)
		y1 = 0;
	if (x2 < 0)
		x2 = 0;
	if (y2 < 0)
		y2 = 0;
	if (x1 > x2)
		SWAP(x1, x2);
	if (y1 > y2)
		SWAP(y1, y2);
	for (row = y1; row <= y2; row++)
		for (col = x1; col <= x2; ++col)
		{
			//640x480
			VGA_PIXEL(col, row, pixel_color);
			//pixel_ptr = (char *)vga_pixel_ptr + (row<<10)    + col ;
			// set pixel color
			//*(char *)pixel_ptr = pixel_color;
		}
}

/****************************************************************************************
 * Draw a filled circle on the VGA monitor 
****************************************************************************************/

void VGA_disc(int x, int y, int r, short pixel_color)
{
	char *pixel_ptr;
	int row, col, rsqr, xc, yc;

	rsqr = r * r;

	for (yc = -r; yc <= r; yc++)
		for (xc = -r; xc <= r; xc++)
		{
			col = xc;
			row = yc;
			// add the r to make the edge smoother
			if (col * col + row * row <= rsqr + r)
			{
				col += x; // add the center point
				row += y; // add the center point
				//check for valid 640x480
				if (col > 639)
					col = 639;
				if (row > 479)
					row = 479;
				if (col < 0)
					col = 0;
				if (row < 0)
					row = 0;
				VGA_PIXEL(col, row, pixel_color);
				//pixel_ptr = (char *)vga_pixel_ptr + (row<<10) + col ;
				// set pixel color
				//nanosleep(&delay_time, NULL);
				//draw_delay();
				//*(char *)pixel_ptr = pixel_color;
			}
		}
}

// =============================================
// === Draw a line
// =============================================
//plot a line
//at x1,y1 to x2,y2 with color
//Code is from David Rodgers,
//"Procedural Elements of Computer Graphics",1985
void VGA_line(int x1, int y1, int x2, int y2, short c)
{
	int e;
	signed int dx, dy, j, temp;
	signed int s1, s2, xchange;
	signed int x, y;
	char *pixel_ptr;

	/* check and fix line coordinates to be valid */
	if (x1 > 639)
		x1 = 639;
	if (y1 > 479)
		y1 = 479;
	if (x2 > 639)
		x2 = 639;
	if (y2 > 479)
		y2 = 479;
	if (x1 < 0)
		x1 = 0;
	if (y1 < 0)
		y1 = 0;
	if (x2 < 0)
		x2 = 0;
	if (y2 < 0)
		y2 = 0;

	x = x1;
	y = y1;

	//take absolute value
	if (x2 < x1)
	{
		dx = x1 - x2;
		s1 = -1;
	}

	else if (x2 == x1)
	{
		dx = 0;
		s1 = 0;
	}

	else
	{
		dx = x2 - x1;
		s1 = 1;
	}

	if (y2 < y1)
	{
		dy = y1 - y2;
		s2 = -1;
	}

	else if (y2 == y1)
	{
		dy = 0;
		s2 = 0;
	}

	else
	{
		dy = y2 - y1;
		s2 = 1;
	}

	xchange = 0;

	if (dy > dx)
	{
		temp = dx;
		dx = dy;
		dy = temp;
		xchange = 1;
	}

	e = ((int)dy << 1) - dx;

	for (j = 0; j <= dx; j++)
	{
		//video_pt(x,y,c); //640x480
		VGA_PIXEL(x, y, c);
		//pixel_ptr = (char *)vga_pixel_ptr + (y<<10)+ x;
		// set pixel color
		//*(char *)pixel_ptr = c;

		if (e >= 0)
		{
			if (xchange == 1)
				x = x + s1;
			else
				y = y + s2;
			e = e - ((int)dx << 1);
		}

		if (xchange == 1)
			y = y + s2;
		else
			x = x + s1;

		e = e + ((int)dy << 1);
	}
}

/////////////////////////////////////////////