#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
 
/* function prototypes */
/* function prototypes */
void VGA_text (int, int, char *);
void VGA_text_clear();
void VGA_box (int, int, int, int, short);
void VGA_line(int, int, int, int, short) ;
void VGA_disc (int, int, int, short);
int  VGA_read_pixel(int, int) ;
int  video_in_read_pixel(int, int);
void draw_delay(void) ;
 
/* x, y: coordinates of current point; dx, dy: direction of movement.
 * Think turtle graphics.  They are divided by scale, so as to keep
 * very small coords/increments without losing precission. clen is
 * the path length travelled, which should equal to scale at the end
 * of the curve.
 */
long long x, y, dx, dy, scale, clen;
typedef struct { double r, g, b; } rgb;
rgb ** pix;
 
/* for every depth increase, rotate 45 degrees and scale up by sqrt(2)
 * Note how coords can still be represented by integers.
 */
void sc_up()
{
	long long tmp = dx - dy; dy = dx + dy; dx = tmp;
	scale *= 2; x *= 2; y *= 2;
}
 
/* Hue changes from 0 to 360 degrees over entire length of path; Value
 * oscillates along the path to give some contrast between segments
 * close to each other spatially.  RGB derived from HSV gets *added*
 * to each pixel reached; they'll be dealt with later.
 */
void h_rgb(long long x, long long y)
{
	rgb *p = &pix[y][x];
 
#	define SAT 1
	double h = 6.0 * clen / scale;
	double VAL = 1 - (cos(3.141592653579 * 64 * clen / scale) - 1) / 4;
	double c = SAT * VAL;
	double X = c * (1 - fabs(fmod(h, 2) - 1));
 
	switch((int)h) {
	case 0: p->r += c; p->g += X; return;
	case 1:	p->r += X; p->g += c; return;
	case 2: p->g += c; p->b += X; return;
	case 3: p->g += X; p->b += c; return;
	case 4: p->r += X; p->b += c; return;
	default:
		p->r += c; p->b += X;
	}
}
 
/* string rewriting.  No need to keep the string itself, just execute
 * its instruction recursively.
 */
void iter_string(const char * str, int d)
{
	long tmp;
#	define LEFT  tmp = -dy; dy = dx; dx = tmp
#	define RIGHT tmp = dy; dy = -dx; dx = tmp
	while (*str != '\0') {
		switch(*(str++)) {
		case 'X':	if (d) iter_string("X+YF+", d - 1); continue;
		case 'Y':	if (d) iter_string("-FX-Y", d - 1); continue;
		case '+':	RIGHT; continue;
		case '-':	LEFT;  continue;
		case 'F':
                        /* draw: increment path length; add color; move. Here
                         * is why the code does not allow user to choose arbitrary
                         * image size: if it's not a power of two, aliasing will
                         * occur and grid-like bright or dark lines will result
                         * when normalized later.  It can be gotten rid of, but that
                         * involves computing multiplicative order and would be a huge
                         * bore.
                         */
				clen ++;
				h_rgb(x/scale, y/scale);
				x += dx; y += dy;
				continue;
		}
	}
}
 
void dragon(long leng, int depth)
{
	long i, d = leng / 3 + 1;
	long h = leng + 3, w = leng + d * 3 / 2 + 2;
 
	/* allocate pixel buffer */
	rgb *buf = malloc(sizeof(rgb) * w * h);
	pix = malloc(sizeof(rgb *) * h);
	for (i = 0; i < h; i++)
		pix[i] = buf + w * i;
	memset(buf, 0, sizeof(rgb) * w * h);
 
        /* init coords; scale up to desired; exec string */
	x = y = d; dx = leng; dy = 0; scale = 1; clen = 0;
	for (i = 0; i < depth; i++) sc_up();
	iter_string("FX", depth);
 
	/* write color PNM file */
	unsigned char *fpix = malloc(w * h * 3);
	double maxv = 0, *dbuf = (double*)buf;
 
        /* find highest value among pixels; normalize image according
         * to it.  Highest value would be at points most travelled, so
         * this ends up giving curve edge a nice fade -- it's more apparaent
         * if we increase iteration depth by one or two.
         */
	for (i = 3 * w * h - 1; i >= 0; i--)
		if (dbuf[i] > maxv) maxv = dbuf[i];
	for (i = 3 * h * w - 1; i >= 0; i--)
		fpix[i] = 255 * dbuf[i] / maxv;
 
	printf("P6\n%ld %ld\n255\n", w, h);
	fflush(stdout); /* printf and fwrite may treat buffer differently */
	fwrite(fpix, h * w * 3, 1, stdout);
}
 
int main(int c, char ** v)
{
	int size, depth;
 
	depth  = (c > 1) ? atoi(v[1]) : 10;
	size = 1 << depth;
 
	fprintf(stderr, "size: %d depth: %d\n", size, depth);
	dragon(size, depth * 2);
 
	return 0;
}

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
int  VGA_read_pixel(int x, int y){
	char  *pixel_ptr ;
	pixel_ptr = (char *)vga_pixel_ptr + ((y)*640) + (x) ;
	return *pixel_ptr ;
}

/****************************************************************************************
 * Subroutine to send a string of text to the VGA monitor 
****************************************************************************************/
void VGA_text(int x, int y, char * text_ptr)
{
  	volatile char * character_buffer = (char *) vga_char_ptr ;	// VGA character buffer
	int offset;
	/* assume that the text string fits on one line */
	offset = (y << 7) + x;
	while ( *(text_ptr) )
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
  	volatile char * character_buffer = (char *) vga_char_ptr ;	// VGA character buffer
	int offset, x, y;
	for (x=0; x<79; x++){
		for (y=0; y<59; y++){
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
#define SWAP(X,Y) do{int temp=X; X=Y; Y=temp;}while(0) 

void VGA_box(int x1, int y1, int x2, int y2, short pixel_color)
{
	char  *pixel_ptr ; 
	int row, col;

	/* check and fix box coordinates to be valid */
	if (x1>639) x1 = 639;
	if (y1>479) y1 = 479;
	if (x2>639) x2 = 639;
	if (y2>479) y2 = 479;
	if (x1<0) x1 = 0;
	if (y1<0) y1 = 0;
	if (x2<0) x2 = 0;
	if (y2<0) y2 = 0;
	if (x1>x2) SWAP(x1,x2);
	if (y1>y2) SWAP(y1,y2);
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
	char  *pixel_ptr ; 
	int row, col, rsqr, xc, yc;
	
	rsqr = r*r;
	
	for (yc = -r; yc <= r; yc++)
		for (xc = -r; xc <= r; xc++)
		{
			col = xc;
			row = yc;
			// add the r to make the edge smoother
			if(col*col+row*row <= rsqr+r){
				col += x; // add the center point
				row += y; // add the center point
				//check for valid 640x480
				if (col>639) col = 639;
				if (row>479) row = 479;
				if (col<0) col = 0;
				if (row<0) row = 0;
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
void VGA_line(int x1, int y1, int x2, int y2, short c) {
	int e;
	signed int dx,dy,j, temp;
	signed int s1,s2, xchange;
     signed int x,y;
	char *pixel_ptr ;
	
	/* check and fix line coordinates to be valid */
	if (x1>639) x1 = 639;
	if (y1>479) y1 = 479;
	if (x2>639) x2 = 639;
	if (y2>479) y2 = 479;
	if (x1<0) x1 = 0;
	if (y1<0) y1 = 0;
	if (x2<0) x2 = 0;
	if (y2<0) y2 = 0;
        
	x = x1;
	y = y1;
	
	//take absolute value
	if (x2 < x1) {
		dx = x1 - x2;
		s1 = -1;
	}

	else if (x2 == x1) {
		dx = 0;
		s1 = 0;
	}

	else {
		dx = x2 - x1;
		s1 = 1;
	}

	if (y2 < y1) {
		dy = y1 - y2;
		s2 = -1;
	}

	else if (y2 == y1) {
		dy = 0;
		s2 = 0;
	}

	else {
		dy = y2 - y1;
		s2 = 1;
	}

	xchange = 0;   

	if (dy>dx) {
		temp = dx;
		dx = dy;
		dy = temp;
		xchange = 1;
	} 

	e = ((int)dy<<1) - dx;  
	 
	for (j=0; j<=dx; j++) {
		//video_pt(x,y,c); //640x480
		VGA_PIXEL(x, y, c);
		//pixel_ptr = (char *)vga_pixel_ptr + (y<<10)+ x; 
		// set pixel color
		//*(char *)pixel_ptr = c;	
		 
		if (e>=0) {
			if (xchange==1) x = x + s1;
			else y = y + s2;
			e = e - ((int)dx<<1);
		}

		if (xchange==1) y = y + s2;
		else x = x + s1;

		e = e + ((int)dy<<1);
	}
}

/////////////////////////////////////////////

#define NOP10() asm("nop;nop;nop;nop;nop;nop;nop;nop;nop;nop")

void draw_delay(void){
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10(); //16
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10(); //32
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10(); //48
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10(); //64
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10();
	NOP10(); NOP10(); NOP10(); NOP10(); //68
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