////////////////////////////////////////////////////////////////////////
// TRANSLATED_PYTHON.C
//		Baseline C code from lsystem.py
//		Computes and graphs entire L-Systems
//		Compile with gcc translated_python.c -o fp1 -lm
//			Must have ECE 5760 GPU with FAST display from SRAM project loaded onto board
// (Priya Kattappurath, Michael Rivera, Caitlin Stanton)
////////////////////////////////////////////////////////////////////////

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/mman.h>
#include <sys/time.h>
#include <math.h>

#include "address_map_arm_brl4.h"

/* function prototypes */
void VGA_text(int, int, char *);
void VGA_text_clear();
void VGA_box(int, int, int, int, short);
void VGA_line(int, int, int, int, short);
void VGA_disc(int, int, int, short);
int VGA_read_pixel(int, int);
int video_in_read_pixel(int, int);
void draw_delay(void);

// 16-bit primary colors
#define red (0 + (0 << 5) + (31 << 11))
#define dark_red (0 + (0 << 5) + (15 << 11))
#define green (0 + (63 << 5) + (0 << 11))
#define dark_green (0 + (31 << 5) + (0 << 11))
#define blue (31 + (0 << 5) + (0 << 11))
#define dark_blue (15 + (0 << 5) + (0 << 11))
#define yellow (0 + (63 << 5) + (31 << 11))
#define cyan (31 + (63 << 5) + (0 << 11))
#define magenta (31 + (0 << 5) + (31 << 11))
#define black (0x0000)
#define gray (15 + (31 << 5) + (51 << 11))
#define white (0xffff)
int colors[] = {red, dark_red, green, dark_green, blue, dark_blue,
								yellow, cyan, magenta, gray, black, white};

// the light weight buss base
void *h2p_lw_virtual_base;

// RAM FPGA command buffer
volatile unsigned int *sram_ptr = NULL;
void *sram_virtual_base;

// pixel buffer
volatile unsigned int *vga_pixel_ptr = NULL;
void *vga_pixel_virtual_base;

// character buffer
volatile unsigned int *vga_char_ptr = NULL;
void *vga_char_virtual_base;

// /dev/mem file id
int fd;

// pixel macro
// !!!PACKED VGA MEMORY!!!
#define VGA_PIXEL(x, y, color)                           \
	do                                                     \
	{                                                      \
		char *pixel_ptr;                                     \
		pixel_ptr = (char *)vga_pixel_ptr + ((y)*640) + (x); \
		*(char *)pixel_ptr = (color);                        \
	} while (0)

char *applyRule_DragonCurve(char input)
{
	char tmp[1000000];
	switch (input)
	{
	case 'X':
	{
		strcpy(tmp, "X+YF+");
		break;
	}
	case 'Y':
	{
		strcpy(tmp, "-FX-Y");
		break;
	}
	default:
	{
		strcpy(tmp, (char[2]){(char)input, '\0'});
		break;
	}
	}
	return tmp;
}

char *processString_DragonCurve(char *prev)
{
	int i = 0;
	char *tmp;
	char *check;
	int length = strlen(prev);
	for (i = 0; i < length; i++)
	{
		check = prev;
		tmp = applyRule_DragonCurve(prev[i]);
		strcat(prev, tmp);
	}
	return prev;
}

char *createSystem_DragonCurve(int numIters, char *axiom)
{
	char start[1000000];
	strcpy(start, axiom);
	char end[1000000];
	*end = "";
	int i = 0;
	char *check;
	for (i = 0; i < numIters; i++)
	{
		check = processString_DragonCurve(start);
		*start = end;
	}
	return start;
}

void draw_DragonCurve(char *input, int old_x, int old_y)
{
	int a = 0; // 0 degrees is straight up vertically
	int length = 10;
	int new_x = old_x;
	int new_y = old_y;
	int i = 0;
	char *check = input;
	printf("GRAPHING STRING: ");
	while (*check != '\0')
		printf("%c", *check++);
	printf("\n");
	for (i = 0; i < strlen(input); i++)
	{
		if (input[i] == 'X')
		{
			continue;
		}
		else if (input[i] == 'Y')
		{
			continue;
		}
		else if (input[i] == 'F')
		{
			if (a % 360 == 0)
			{
				VGA_line(new_x, new_y, new_x, new_y - length, red);
				new_x = new_x;
				new_y = new_y - length;
			}
			else if (a % 270 == 0)
			{
				VGA_line(new_x, new_y, new_x - length, new_y, yellow);
				new_x = new_x - length;
				new_y = new_y;
			}
			else if (a % 180 == 0)
			{
				VGA_line(new_x, new_y, new_x, new_y + length, red);
				new_x = new_x;
				new_y = new_y + length;
			}
			else if (a % 90 == 0)
			{
				VGA_line(new_x, new_y, new_x + length, new_y, yellow);
				new_x = new_x + length;
				new_y = new_y;
			}
		}
		else if (input[i] == '+')
		{
			a = a + 90;
		}
		else if (input[i] == '-')
		{
			a = a - 90;
		}
	}
}

// measure time
struct timeval t1, t2;
double elapsedTime;
struct timespec delay_time;

int main(void)
{
	delay_time.tv_nsec = 10;
	delay_time.tv_sec = 0;

	// Declare volatile pointers to I/O registers (volatile 	// means that IO load and store instructions will be used 	// to access these pointer locations,
	// instead of regular memory loads and stores)

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
	// for light weight bus
	h2p_lw_virtual_base = mmap(NULL, HW_REGS_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, HW_REGS_BASE);
	if (h2p_lw_virtual_base == MAP_FAILED)
	{
		printf("ERROR: mmap1() failed...\n");
		close(fd);
		return (1);
	}

	// === get VGA char addr =====================
	// get virtual addr that maps to physical
	vga_char_virtual_base = mmap(NULL, FPGA_CHAR_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, FPGA_CHAR_BASE);
	if (vga_char_virtual_base == MAP_FAILED)
	{
		printf("ERROR: mmap2() failed...\n");
		close(fd);
		return (1);
	}

	// Get the address that maps to the character
	vga_char_ptr = (unsigned int *)(vga_char_virtual_base);

	// === get VGA pixel addr ====================
	// get virtual addr that maps to physical
	// SDRAM
	vga_pixel_virtual_base = mmap(NULL, FPGA_ONCHIP_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, SDRAM_BASE); //SDRAM_BASE

	if (vga_pixel_virtual_base == MAP_FAILED)
	{
		printf("ERROR: mmap3() failed...\n");
		close(fd);
		return (1);
	}
	// Get the address that maps to the FPGA pixel buffer
	vga_pixel_ptr = (unsigned int *)(vga_pixel_virtual_base);

	// === get RAM FPGA parameter addr =========
	sram_virtual_base = mmap(NULL, FPGA_ONCHIP_SPAN, (PROT_READ | PROT_WRITE), MAP_SHARED, fd, FPGA_ONCHIP_BASE); //fp

	if (sram_virtual_base == MAP_FAILED)
	{
		printf("ERROR: mmap3() failed...\n");
		close(fd);
		return (1);
	}
	// Get the address that maps to the RAM buffer
	sram_ptr = (unsigned int *)(sram_virtual_base);

	// ===========================================

	// clear the screen
	VGA_box(0, 0, 639, 479, 0x03);
	printf("start\n");
	char input[100] = "FX";
	char *tree = createSystem_DragonCurve(9, input);
	draw_DragonCurve(tree, 100, 500);
} // end main

/****************************************************************************************
 * Subroutine to read a pixel from the video input 
****************************************************************************************/
// int  video_in_read_pixel(int x, int y){
// char  *pixel_ptr ;
// pixel_ptr = (char *)video_in_ptr + ((y)<<9) + (x) ;
// return *pixel_ptr ;
// }

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

#define NOP10() asm("nop;nop;nop;nop;nop;nop;nop;nop;nop;nop")

void draw_delay(void)
{
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10(); //16
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10(); //32
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10(); //48
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10(); //64
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10();
	NOP10(); //68
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10(); //80
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10();
					 // NOP10(); NOP10(); NOP10(); NOP10(); //96
}

/// /// /////////////////////////////////////
/// end /////////////////////////////////////