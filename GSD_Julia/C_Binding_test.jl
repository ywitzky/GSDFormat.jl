

using CBinding, Libdl#, Libc
import Base: unsafe_convert
#import Base.unsafe_convert

unsafe_convert(::Type{Cptr{Nothing}}, _::Int64) =Cptr{Nothing}() ### assumption that this doesnt cause issues
#unsafe_convert(::Type{Cptr{Nothing}}, _::Int64) = 0 ### assumption that this doesnt cause issues

#unsafe_convert(::Type{Cptr{Cconst{var"c\"struct gsd_index_entry\""}}}, ::String)

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

unsafe_convert(::Type{Cptr{Cconst{var"c\"struct gsd_index_entry\""}}}, a::String) = begin println(a * "test"); return Cptr{Cconst{var"c\"struct gsd_index_entry\""}}(pointer_from_objref(Ref(a))); end ### only for line 6something in gsd.c where he uses char* to define pointer position

unsafe_convert(::Type{Cptr{var"c\"struct gsd_handle\""}}, a::var"(c\"struct gsd_handle\")") = Cptr{var"c\"struct gsd_handle\""}(pointer_from_objref(Ref(a)))

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
#bla = (gsd_handle_var)
#println(typeof(bla))
# pointer_from_objref(Ref(gsd_handle_var))


#convert(::Type{Cptr{typof(gsd_handle_var)}}, x) = Ref(x)


retval = gsd_read_chunk(pointer_from_objref(Ref(gsd_handle_var)), 0,"configuration/dimensions")
#c"gsd_read_chunk"(gsd_handle2, Cint(0),"configuration/dimensions")

version =gsd_make_version(UInt32(1),UInt32(4))
retval = gsd_create("./test_here.gsd", "hoomd", "hoomd", version)
#println(retval)
#println(gsd_handle_var)

obj=gsd_handle()
flag = GSD_OPEN_READONLY

file = "/localscratch/HPS_DATA/HPS-Janka/RS31a/run1/MDhnRNPA1seqRS31a_M250_NP1_T300_Box40_40_40_s1000000000.gsd"
#println(gsd_create_and_open(obj, file, "application", "schema", UInt32(1), flag, Int32(1)))

#println(flag)
#println(gsd_close(obj))
retval =  gsd_open(obj, file, flag)
#println(typeof(new_handle))
#obj=gsd_handle()


#from fl.pyx : read_chunk
index_entry = gsd_index_entry()
index_entry = gsd_find_chunk(pointer_from_objref(Ref(obj)),1,"configuration/dimensions" )#dimensons
println(obj.fd)
println("index entry")
println(index_entry)
println(index_entry.type)
println(GSD_TYPE_UINT8)
println(UInt8(index_entry.type)   , " ", UInt8(c"GSD_TYPE_UINT8"))
println(UInt8(index_entry.type) >>> 4 == UInt8(c"GSD_TYPE_UINT8"))

println(index_entry.N, "  ", index_entry.M)
println(UInt64(index_entry.N))
println(UInt64((index_entry.M)))
println("asdh")
println(gsd_sizeof_type(c"enum gsd_type"(4)))

data=zeros(Float64 , (UInt64(index_entry.N), UInt32(index_entry.M)))
data_ptr = pointer_from_objref(Ref(data))
retval = gsd_read_chunk(pointer_from_objref(Ref(obj)), data_ptr, pointer_from_objref(Ref(index_entry)))

println(retval)
println(data)