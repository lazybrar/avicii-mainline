// pmem: read or write one 32-bit word of physical memory through /dev/mem.
// usage: pmem ADDR [VALUE]
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>

int main(int argc, char **argv)
{
	if (argc < 2)
		return 2;
	uint64_t addr = strtoull(argv[1], 0, 0);
	long pg = sysconf(_SC_PAGESIZE);
	int fd = open("/dev/mem", O_RDWR | O_SYNC);
	if (fd < 0) {
		perror("/dev/mem");
		return 1;
	}
	volatile uint8_t *m = mmap(0, pg, PROT_READ | PROT_WRITE, MAP_SHARED, fd, addr & ~(uint64_t)(pg - 1));
	if (m == MAP_FAILED) {
		perror("mmap");
		return 1;
	}
	volatile uint32_t *p = (volatile uint32_t *)(m + (addr & (pg - 1)));
	if (argc > 2)
		*p = strtoul(argv[2], 0, 0);
	printf("%#llx = %#x\n", (unsigned long long)addr, *p);
	return 0;
}
