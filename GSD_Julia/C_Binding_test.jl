using CBinding, Libdl#, Libc

libpath= Libdl.find_library("libgsd.so", vcat(Base.DL_LOAD_PATH, ["/uni-mainz.de/homes/ywitzky/phdscripts/GSD/GSD_Julia/gsd/"]) )

const c"int8_t" = Int8
const c"int16_t" = Int16
const c"int32_t" = Int32
const c"int64_t" = Int64
const c"uint8_t" = UInt8
const c"uint16_t" = UInt16
const c"uint32_t" = UInt32
const c"uint64_t" = UInt64

const c"size_t" = Csize_t
path="/uni-mainz.de/homes/ywitzky/phdscripts/GSD/GSD_Julia/gsd/"
c`-std=c17 -Wall -I$(path) -L$(path) -I$(path)gsd.c -L$(libpath) -llibgsd.so`
# 
c"""
#include "/uni-mainz.de/homes/ywitzky/phdscripts/GSD/GSD_Julia/gsd/gsd.c"
#include "/uni-mainz.de/homes/ywitzky/phdscripts/GSD/GSD_Julia/gsd/gsd.h"
"""j



header = c"struct gsd_header"(magic = 1)

println(header.magic)

gsd_handle_var = gsd_handle(fd = 0 )#, header=gsd_header(), file_index=gsd_index_buffer(), frame_index=gsd_index_buffer(), buffer_index=gsd_index_buffer(), write_buffer=gsd_byte_buffer(), file_names=gsd_name_buffer(), frame_names=gsd_name_buffer(), cur_frame=0, file_size=0, open_flags=1, name_map=gsd_name_id_map(), pending_index_entries=0,maximum_write_buffer_size=0,  index_entries_to_buffer=0)
#gsd_handle2 = c"struct gsd_handle * "(); #(fd = 0)
bla = [gsd_handle_var]
#ptr_gsd = Libc.malloc(gsd_handle);
#println(gsd_handle)
#c"gsd_read_chunk"([gsd_handle], Cint(0),"configuration/dimensions")
#println(gsd_handle_var)
#ptr  = c"struct gsd_handle * " gsd_handle_var
#retval = gsd_read_chunk(bla, 0,"configuration/dimensions")
retval = gsd_read_chunk(pointer_from_objref(Ref(gsd_handle_var)), 0,"configuration/dimensions")
#c"gsd_read_chunk"(gsd_handle2, Cint(0),"configuration/dimensions")

version =gsd_make_version(UInt32(1),UInt32(4))
retval = gsd_create("./test_here.gsd", "hoomd", "hoomd", version)
println(retval)
println(gsd_handle_var)

