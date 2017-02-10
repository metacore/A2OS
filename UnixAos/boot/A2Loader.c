/* 
   G.F. 31.01.2017

   Loader for the statically linked A2 core.

   Compile command:
      gcc -m32 Solaris.A2Loader.c -ldl -o A2Loader.elf

   The command 'A2Loader.elf -h' shows the correct
   displacement of the A2 core.

   The A2 core has to be appended to the binary ot this 
   program by the A2 command:
      SolarisELF.Build ~

*/
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <string.h>
#include <dlfcn.h>

#define Offset 10*1024		/* beginning of the A2 core */
#define Bufsize 2*1024*1024

typedef void (*OberonProc)();
typedef void *addr;

typedef struct {
    char id[32];		/* must be coreID */
    void *displacement;		/* must be address of buf */
    OberonProc entry;		/* Glue.Init0 */
    addr *dlopenaddr;
    addr *dlsymaddr;
    int  *argc;
    addr *argv;
} *A2Header;

char *coreID = "Solaris32G.core";

int main( int argc, char *argv[] ) {
   int r, n, fd;
   size_t fsize;
   struct stat sb;
   void *buf;
   A2Header header;
   char path[64];
   addr a;

   r = posix_memalign( &buf, 64*1024, Bufsize );
   if ((argc == 2) && (strcmp(argv[1], "-h") == 0)) {
      printf("Core displacement must be 0x%x\n", buf );
      exit( 0 );
   }
   r = mprotect( buf, Bufsize, PROT_READ+PROT_WRITE+PROT_EXEC );
   a = realpath( argv[0], path );
   fd = open( path, O_RDONLY );
   r = fstat( fd, &sb );
   fsize = sb.st_size;
   r = lseek( fd, Offset, SEEK_SET );
   n = read( fd, buf, fsize - Offset );
   header = (A2Header)buf;
   if (strcmp(header->id, coreID) != 0) {
      printf( "bad headerId: %s, expected: %s\n", header->id, coreID );
      exit( 2 );
   }
   if (header->displacement != buf) {
      printf( "bad displacement: %x, expected: %x\n", header->displacement, buf );
      exit( 3 );
   }
   *(header->dlopenaddr) = dlopen;
   *(header->dlsymaddr) = dlsym;
   *(header->argc) = argc;
   *(header->argv) = argv;
   header->entry();
}
