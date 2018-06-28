/* 
   G.F. 31.01.2017

   Loader for statically linked oberon binaries.

   Compile command:
      gcc -m32 -s -O OberonLoader.c -ldl -o OberonLoader

      gcc -m64 -s -O OberonLoader.c -ldl -o OberonLoader


   The statically linked oberon binary 'oberon.bin' has to be
   appended to this loader by the following A2-command:

      UnixBinary.Build oberon.bin ->  <program name> ~

*/
#include <stdlib.h>
#include <stdio.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <sys/uio.h>
#include <unistd.h>
#include <sys/stat.h>
#include <string.h>
#include <dlfcn.h>

#define Offset 16*1024	/* startpos of the appended oberon binary */
#define BlkSize 4*1024

typedef void (*OberonProc)();
typedef void *addr;
typedef unsigned int uint;
typedef unsigned long ulong;

typedef struct {  /* cf. Unix.*.Glue.Mod */
    /* Oberon --> loader: */
    char id[24];		/* must match coreID */
    int  codesize;	
    int  relocations;
    OberonProc entry;		/* Glue.Init0 */
    /* loader --> Oberon: */
    addr *dlopenaddr;
    addr *dlcloseaddr;
    addr *dlsymaddr;
    int  *argc;
    addr *argv;
    addr *env;
    addr *cout;
} *Header;

#if defined(__LP64__) || defined(_LP64)
   char *coreID = "Oberon64G.binary";	/* cf. Unix.Glue.Mod */
#else
   char *coreID = "Oberon32G.binary";	/* cf. Unix.Glue.Mod */
#endif

addr heap;
uint heapsize;
int fd;

void cout( char c ) {
   char buf[8];
   buf[0] = c;
   write( 1, &buf, 1 );
}

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
      a = heap + ReadInteger();
      *a += (ulong)heap;
   }
}


char *which_path(const char *name) {

   char *tname, *tok, *path;

   path = strdup(getenv("PATH"));
   if (NULL == path) return NULL;

   tok = strtok(path, ":");
   while (tok) {
      tname = malloc(strlen(tok) + 2 + strlen(name));
      sprintf(tname, "%s/%s", tok, name);

      if (0 == access(tname, X_OK)) { free(path);  return tname; }

      free(tname);
      tok = strtok(NULL, ":");
   }
   free(path);
   return NULL;
}



int main( int argc, char *argv[], char *env[] ) {
   int r, n, binsize, relocations;
   size_t fsize;
   struct stat sb;
   Header header;
   char *path, *buf;

   fd = open( *argv, O_RDONLY );
   if (fd < 0) {
      /* find myself in PATH */
      path = which_path(*argv);
      fd = open(path, O_RDONLY);
   }
   r = fstat( fd, &sb );
   if ( sb.st_size < Offset+2048 ) {
      fprintf( stderr, "%s: missing appended Oberon binary\n", *argv );
      exit( 2 );
   }
   r = lseek( fd, Offset, SEEK_SET );
   buf = malloc( 512 );
   n = read( fd, buf, 256 );
   header = (Header)buf;
   if (strcmp(header->id, coreID) != 0) {
      fprintf( stderr, "wrong Oberon headerId: got '%s', expected '%s'\n", header->id, coreID );
      exit( 2 );
   }
   binsize = header->codesize;
   relocations = header->relocations;
   free( buf );

   heapsize = BlkSize;
   while (heapsize < binsize) heapsize += BlkSize;

   r = lseek( fd, Offset, SEEK_SET );
   r = posix_memalign( &heap, BlkSize, heapsize );
   if (mprotect( heap, heapsize, PROT_READ|PROT_WRITE|PROT_EXEC) != 0)
      perror("mprotect");
   n = read( fd, heap, binsize );

   Relocate( relocations );

   header = (Header)heap;
   *(header->dlopenaddr) = dlopen;
   *(header->dlcloseaddr) = dlclose;
   *(header->dlsymaddr) = dlsym;
   *(header->argc) = argc;
   *(header->argv) = argv;
   *(header->env)  = env;
   *(header->cout) = cout;

   header->entry();
   return (0);
}
