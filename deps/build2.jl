using BinDeps, CBinding, Libdl, CondaBinDeps
@BinDeps.setup
gsd = library_dependency("gsd", aliases = ["libgsd"])

provides(CondaBinDeps.Manager, "gsd", gsd)
println(gsd)

libpath= Libdl.find_library("libgsd.so" )

println(libpath)

libpath = CBinding.find_libpath("gsd")

c`-std=c17 -Wall -L$(libpath) -llibgsd.so`

c"""
#include <gsd.c>
#include <gsd.h>
"""ji