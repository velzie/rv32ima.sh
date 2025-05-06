#include <stdint.h>
#include <stdio.h>
#include <stdarg.h>

// These are going to be bound to memory addresses in the linker script.
extern uint32_t SYSCON;
extern uint32_t TIMERL;

// This is just a definition for a symbol found in the .S file.
void asm_demo_func();

// These will not turn into function calls, but instead will find a way
// of writing the assembly in-line
static void lprint( const char * s )
{
	asm volatile( ".option norvc\ncsrrw x0, 0x138, %0\n" : : "r" (s));
}

static void pprint( intptr_t ptr )
{
	asm volatile( ".option norvc\ncsrrw x0, 0x137, %0\n" : : "r" (ptr));
}

static void nprint( intptr_t ptr )
{
	asm volatile( ".option norvc\ncsrrw x0, 0x136, %0\n" : : "r" (ptr));
}

static inline uint32_t get_cyc_count() {
	uint32_t ccount;
	asm volatile(".option norvc\ncsrr %0, 0xC00":"=r" (ccount));
	return ccount;
}

void printFib(int n) {

  	// If the number of terms is smaller than 1
    if (n < 1) {
        // printf("Invalid Number of terms\n");
        return;
    }

  	// First two terms of the series
    int prev1 = 1;
    int prev2 = 0;

    // for loop that prints n terms of fibonacci series
    for (int i = 1; i <= n; i++) {

      	// Print current term and update previous terms
        if (i > 2) {
            int curr = prev1 + prev2;
            prev2 = prev1;
            prev1 = curr;
            nprint(curr);
        }
		else if (i == 1)
            nprint(prev2);
        else if (i == 2)
            nprint(prev1);
    }
}

int main()
{
	// lprint("\n");
	lprint("Hello world from RV32 land.\n");
	lprint("main is at: ");
	pprint( (intptr_t)main );
	lprint("\n");
	// lprint("\nAssembly code: ");
	// asm_demo_func();
	lprint("printFib(100)\n");
	printFib(100);

	// Wait a while.
	uint32_t cyclecount_initial = get_cyc_count();
	uint32_t timer_initial = TIMERL;

	volatile int i;
	for( i = 0; i < 100; i++ )
	{
		asm volatile( "nop" );
	}

	// Gather the wall-clock time and # of cycles
	uint32_t cyclecount = get_cyc_count() - cyclecount_initial;
	uint32_t timer = TIMERL - timer_initial;

	lprint( "Processor effective speed: ");
	nprint( timer );
	lprint( " Mcyc/s\n");

	lprint("\n");
	SYSCON = 0x5555; // Power off
}
