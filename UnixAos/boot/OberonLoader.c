/* 
   G.F. 31.01.2017

   Loader for statically linked oberon binaries.

   Compile command:
      gcc -m32 OberonLoader.c -ldl -o OberonLoader

   The filename of the statically linked oberon binary is 'oberon.bin'.
   The oberon binary may be joined with the loader to create a Unix program:
   This is done in A2 by the following command:

      UnixBinary.Build oberon.bin ->  <program name> ~

*/
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/uio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <string.h>
#include <dlfcn.h>

#define Offset 10*1024	/* startpos of oberon.bin if it is appended to the loader binary */
#define Bufsize 2*1024*1024

typedef void (*OberonProc)();
typedef void *addr;
typedef unsigned int uint;

typedef struct {  /* cf. Generic.Unix.I386.Glue.Mod */
    /* Oberon --> loader: */
    char id[24];		/* must match coreID */
    int  codesize;	
    int  relocations;		/* if base = 0 */
    addr base;			/* must be 0 or match the address of buf */
    OberonProc entry;		/* Glue.Init0 */
    /* loader --> Oberon: */
    addr *dlopenaddr;
    addr *dlcloseaddr;
    addr *dlsymaddr;
    int  *argc;
    addr *argv;
    addr *env;
} *Header;

char *coreID = "Oberon32G.binary";

addr buf;
int fd;

uint ReadInteger( ) {
   union {
      char buf[4];
      uint i;
   } u;
   read( fd, &u.buf, 4 );
   return (u.i);
}


void Relocate( uint relocations ) {
   addr *a;
   uint i;

   for (i=0; i<relocations; i++) {
      a = buf + ReadInteger();
      *a = buf+(uint)(*a);
   }
}


int main( int argc, char *argv[], char *env[] ) {
   int r, n, binsize, relocations;
   size_t fsize;
   struct stat sb;
   Header header;
   char path[64];
   addr a;
   uint binpos;

   r = posix_memalign( &buf, 64*1024, Bufsize );
   a = realpath( argv[0], path );
   fd = open( path, O_RDONLY );
   r = fstat( fd, &sb );
   fsize = sb.st_size;
   if (fsize > Offset) {
      binpos = Offset;
      r = lseek( fd, binpos, SEEK_SET );
   } else {
      binpos = 0;
      fd = open( "oberon.bin", O_RDONLY );
   }
   n = read( fd, buf, 256 );
   header = (Header)buf;
   if (strcmp(header->id, coreID) != 0) {
      printf( "bad headerId: %s, expected: %s\n", header->id, coreID );
      exit( 2 );
   }
   if ((header->base != 0) & (header->base != buf)) {
      printf( "bad displacement: %x, expected: %x\n", header->base, buf );
      exit( 3 );
   }
   binsize = header->codesize;
   relocations = header->relocations;

   r = lseek( fd, binpos, SEEK_SET );
   n = read( fd, buf, binsize );


   Relocate( relocations );

   *(header->dlopenaddr) = dlopen;
   *(header->dlcloseaddr) = dlclose;
   *(header->dlsymaddr) = dlsym;
   *(header->argc) = argc;
   *(header->argv) = argv;
   *(header->env) = env;

   header->entry();
   return (0);
}
