#include <idc.idc>
static main() {
  Batch(0);
  Wait();
  RunPlugin( "binexport10", 2 );
  Exit(0);
}

