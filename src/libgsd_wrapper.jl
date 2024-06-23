module libgsd

using Libdl, CBinding, libgsd_jll#,  Scratch, BinaryBuilder

### use same unique id as in build step

#global cpp_dir = get_scratch!(Base.UUID(0), "gsd_cpp")
#path="$cpp_dir/gsd/"
libpath= Libdl.find_library("$(libgsd_jll.artifact_dir)/lib/", Base.DL_LOAD_PATH)#[cpp_dir]) )

const c"int8_t" = Int8
const c"int16_t" = Int16
const c"int32_t" = Int32
const c"int64_t" = Int64
const c"uint8_t" = UInt8
const c"uint16_t" = UInt16
const c"uint32_t" = UInt32
const c"uint64_t" = UInt64
const c"size_t" = Csize_t
const c"ssize_t" = Cssize_t
const c"NULL"= Nothing


#c`-std=c17 -Wall -I$(path) -L$(path) -I$(path)gsd.c -L$(libpath) -llibgsd.so`
c`-std=c17 -Wall "-I$(libgsd_jll.artifact_dir)/include"  -l$(libgsd_jll.artifact_dir)/lib/libgsd.so`


c"""
#include <gsd.h>
"""ji

#include <gsd.c>

function getNULL()::Cptr{Cvoid}
    return Cptr{Cvoid}(0x0000000000000000)
end

function isNULL(ptr::Cptr{T}) where {T<:Any}
    return ptr==Cptr{Cvoid}(0x0000000000000000)
end


#@enum Gsd_error_type GSD_SUCCESS=0 GSD_ERROR_IO=-1 GSD_ERROR_INVALID_ARGUMENT=-2 GSD_ERROR_NOT_A_GSD_FILE=-3 GSD_ERROR_INVALID_GSD_FILE_VERSION=-4 GSD_ERROR_FILE_CORRUPT=-5 GSD_ERROR_MEMORY_ALLOCATION_FAILED=-6 GSD_ERROR_NAMELIST_FULL=-7 GSD_ERROR_FILE_MUST_BE_WRITABLE=-8 GSD_ERROR_FILE_MUST_BE_READABLE=-9

#@enum Gsd_type GSD_TYPE_UINT8=1 GSD_TYPE_UINT16 GSD_TYPE_UINT32 GSD_TYPE_UINT64 GSD_TYPE_INT8 GSD_TYPE_INT16 GSD_TYPE_INT32 GSD_TYPE_INT64 GSD_TYPE_FLOAT GSD_TYPE_DOUBLE
#=
mutable struct Gsd_header
    magic::UInt64
    gsd_version::UInt32
    application::Vector{Cuchar}
    schema::Vector{Cuchar}
    schema_version::UInt32
    index_location::UInt64
    index_allocated_entries::UInt64
    namelist_location::UInt64
    namelist_allocated_entries::UInt64
    reserved::Vector{Cuchar}
    Gsd_header() = new(0x65DF65DF65DF65DF,3,zeros(Cuchar, 64),zeros(Cuchar, 64),0,0,0,0,0,zeros(Cuchar, 80),)
end=#
#=
mutable struct Gsd_header
    magic::UInt64
    index_location::UInt64
    index_allocated_entries::UInt64
    namelist_location::UInt64
    namelist_allocated_entries::UInt64
    schema_version::UInt32
    gsd_version::UInt32
    application::SVector{64, Cuchar}
    schema::SVector{64, Cuchar}
    reserved::SVector{80, Cuchar}
    Gsd_header() = new(0x65DF65DF65DF65DF,0,0,0,0,0,3,zeros(Cuchar, 64),zeros(Cuchar, 64),zeros(Cuchar, 80))
end

mutable struct Gsd_index_entry
    frame::UInt64
    N::UInt64
    location::Int64
    M::UInt64
    id::UInt16
    type::UInt8
    flags::UInt8
    Gsd_index_entry() = new(0,0,0,0,0,0,0)
end

mutable struct Gsd_index_buffer
    data::Ptr{Gsd_index_entry}
    size::Csize_t
    reserved::Csize_t
    mapped_data::Ptr{Cvoid}
    mapped_len::Csize_t
    Gsd_index_buffer()=new(pointer_from_objref(Ref(Gsd_index_entry())), 0,0,Ptr{Cvoid}(pointer_from_objref(Ref(Cdouble(0.0)))), 0)
end

mutable struct Gsd_namelist_entry
    name::Vector{Cuchar}
    Gsd_namelist_entry() = new(zeros(Cuchar, 64))
end

#@enum Gsd_open_flag GSD_OPEN_READWRITE=1 GSD_OPEN_READONLY=2 GSD_OPEN_APPEND=3


mutable struct Gsd_name_id_pair
    name::Ptr{Cuchar} # Pointer to name (actual name storage is allocated in gsd_handle)
    next::Ptr{Gsd_name_id_pair} #Next name/id pair with the same hash
    id::UInt16 # Entry id
    Gsd_name_id_map() = new(Ptr{Cuchar}(pointer_from_objref(Ref(Cdouble(0.0)))),Ptr{Gsd_name_id_pair}(pointer_from_objref(Ref(Cdouble(0.0)))), 0)
end

mutable struct Gsd_name_id_map
    v::Ptr{Gsd_name_id_pair}
    size::Csize_t
    Gsd_name_id_map() = new(Ptr{Gsd_name_id_pair}(pointer_from_objref(Ref(Cdouble(0.0)))), 0.0)
end


mutable struct Gsd_byte_buffer
    data::Ptr{Cuchar} # Data
    size::Csize_t  # Number of bytes in the buffer
    reserved::Csize_t  #Number of bytes available in the buffer
    Gsd_byte_buffer() = new(Ptr{Cuchar}(pointer_from_objref(Ref(Cdouble(0.0)))), 0, 0)
end

mutable struct Gsd_name_buffer
    gsd_byte_buffer::Gsd_byte_buffer   # Data
    n_names::Csize_t # Number of names in the list
    Gsd_name_buffer() = new(Gsd_byte_buffer(),  0)
 end

#=
mutable struct Gsd_handle
    fd::Int32
    header::Gsd_header
    file_index::Gsd_index_buffer
    frame_index::Gsd_index_buffer
    buffer_index::Gsd_index_buffer
    write_buffer::Gsd_index_buffer
    namelist::Ptr{Gsd_namelist_entry}
    namelist_num_entries::UInt64
    cur_frame::UInt64
    file_size::Int64
    open_flags::Gsd_open_flag
    name_map::Gsd_name_id_map
    namelist_written_entries::UInt64
    Gsd_handle() = new(0, Gsd_header(),Gsd_index_buffer(), Gsd_index_buffer(), Gsd_index_buffer(), Gsd_index_buffer(), pointer_from_objref(Ref(Gsd_namelist_entry())), 0, 0, 0, GSD_OPEN_READWRITE,Gsd_name_id_map(), 0 )
end
=#

mutable struct Gsd_handle
    fd::Int32
    header::Gsd_header
    file_index::Gsd_index_buffer
    frame_index::Gsd_index_buffer
    buffer_index::Gsd_index_buffer
    write_buffer::Gsd_index_buffer
    file_names::Gsd_name_buffer #Ptr{Gsd_namelist_entry}
    frame_names::Gsd_name_buffer
    cur_frame::UInt64
    file_size::Int64
    open_flags::Gsd_open_flag
    name_map::Gsd_name_id_map
    pending_index_entries::UInt64
    maximum_write_buffer_size::UInt64
    index_entries_to_buffer::UInt64
    Gsd_handle() = new(0, Gsd_header(),Gsd_index_buffer(), Gsd_index_buffer(), Gsd_index_buffer(), Gsd_index_buffer(),Gsd_name_buffer() ,Gsd_name_buffer() , 0, 0,  GSD_OPEN_READWRITE,Gsd_name_id_map(), 0 ,0,0)
end

=#
#=
gsd_make_version(major::UInt32,minor::UInt32) = @ccall libgsdfile.gsd_make_version(major::UInt32,minor::UInt32)::UInt32


gsd_create(filename::String, application::String, schema::String, schemaVersion::UInt32) = @ccall libgsdfile.gsd_create(filename::Cstring, application::Cstring, schema::Cstring, schemaVersion::Cuint)::Int32

gsd_create_and_open(gsd_handle::Gsd_handle, filename::String, application::String, schema::String, schemaVersion::UInt32,flags::Gsd_open_flag,exclusive_create::Int32) = @ccall libgsdfile.gsd_create_and_open(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle}, filename::Cstring,application::Cstring,schema::Cstring, schemaVersion::Cuint,flags::Gsd_open_flag,exclusive_create::Int32)::Int32
=#

#using Printf

removeNonASCII_(str::AbstractString) = String([Char(c) for c in str if isascii(c)])
#=
gsd_open_(gsd_handle::gsd_handle, filename::String, flags::gsd_open_flag) =  begin 
#gsd_open(gsd_handle::Cptr{Main.libgsd.Gsd_handle}, filename::Cstring, flags::Gsd_open_flag) =  begin  
 
    #test  = pointer_from_objref(Ref(gsd_handle))
    #test2  = pointer_from_objref(Ref(gsd_handle.header))

    #tmp = [Gsd_handle()]

    #Main.libgsd.Gsd_handle
    #=
    println("Blub pre: $(sizeof(gsd_handle))")
    println("Blub fd: $(sizeof(gsd_handle.fd))")
    println("Blub header: $(sizeof(gsd_handle.header))")
    =#
    #tmp = Base.unsafe_convert(::Type{Ptr{Main.libgsd.Gsd_handle}}, ::Main.libgsd.Gsd_handle)
    #=
    bla = Ref(gsd_handle)
    blub = Base.unsafe_convert(Ptr{Main.libgsd.Gsd_handle},bla)
    bla2 = Ref(gsd_handle.header)
    println(bla2)
    blub2 = Base.unsafe_convert(Ptr{Main.libgsd.Gsd_header},bla2)
    println("ptr: $(blub2)")
    =#

    #retval = @ccall libgsdfile.gsd_open(gsd_handle::Ptr{Main.libgsd.Gsd_handle},filename::Cstring,Int32(flags)::Cint)::Int32
    println("test")
    #println(Base.unsafe_convert())
    bla = Ref(gsd_handle)
    println(bla)
    println("flags : $flags  $(Int(flags))" )
    println("filename $filename , $(string(filename))")
    filename="/localscratch/shortdumps.gsd"
    #filename= Base.unsafe_convert(Cstring,removeNonASCII_(filename))
    #println(Vector{UInt8}("/localscratch/shortdumps.gsd"))
    retval = gsd_open(bla,Vector{UInt8}(filename),flags)::Int32

    println("asdfgh")
    println("Blub post: $(bla)")
    println("Blub fd: $(sizeof(gsd_handle.fd))")
    #=
    #println("Blub header: $(sizeof(gsd_handle.header))")
    println("ptr: $(blub)")
    println("ptr: $(blub2)")

    println(bla)
    println(bla2)

    println("ptr: $(Base.unsafe_pointer_to_objref(blub2))")
    println(blub2)
    =#


    #=println("XXXXXXXXXXXXXXXXXX: in  gsd_open ")
    println("in  $(gsd_handle.fd) ")
    println("header  $(Int(gsd_handle.header)) ")
    println("in  $(Int(gsd_handle.file_size)) ")

    #println("in  $(gsd_handle.header) ")

    ptr=Base.unsafe_convert(Ptr{Gsd_header}, Ref(gsd_handle.header))
    println(Base.unsafe_pointer_to_objref(ptr))
    println("in  $(ptr[1]) ")

    println("\n\n\n")
    =#
    #retval = ccall( libgsdfile.gsd_open, Int32, (Gsd_handle, Cstring,libgsdfile.GSD_OPEN_READWRITE ), gsd_handle,filename, libgsdfile.gsd_open_flag)

    #ccall( (:gsd_open, libgsdfile), Int32, (Ptr{Gsd_handle}, Cstring, Gsd_open_flag), tmp, filename, flags)

    #gsd_handle2 = unsafe_pointer_to_objref(test)

    return retval
end
#
=#
#=
gsd_truncate(gsd_handle::Gsd_handle) = @ccall libgsdfile.gsd_truncate(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle})::Int32

gsd_close(gsd_handle::Gsd_handle) =  @ccall libgsdfile.gsd_close(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle})::Int32

gsd_end_frame(gsd_handle::Gsd_handle) = @ccall libgsdfile.gsd_end_frame(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle})::Int32

gsd_flush(gsd_handle::Gsd_handle) = @ccall libgsdfile.gsd_flush(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle})::Int32

gsd_write_chunk(gsd_handle::Gsd_handle,name::String,type::Gsd_type, N::UInt64,M::UInt8, flags::UInt8, data::Ptr{Cvoid}) = @ccall libgsdfile.gsd_write_chunk(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle}, name::Cstring, type::Gsd_type,N::UInt64, M::UInt8, flags::UInt8, data::Ptr{Cvoid})::Int32

gsd_find_chunk(gsd_handle::Gsd_handle,frame::UInt64,name::String) = @ccall libgsdfile.gsd_find_chunk(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle},frame::UInt64,name::Cstring)::Gsd_index_entry

gsd_read_chunk(gsd_handle::Gsd_handle, data::Ptr{Cvoid},chunk::Gsd_index_entry) = @ccall libgsdfile.gsd_read_chunk(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle},data::Ptr{Cvoid}, chunk::Gsd_index_entry )::Int32

gsd_get_nframes(gsd_handle::Gsd_handle) = @ccall libgsdfile.gsd_get_nframes(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle})::UInt64

gsd_sizeof_type(type::Gsd_type) = @ccall libgsdfile.gsd_sizeof_type(type::Gsd_type)::UInt

gsd_find_matching_chunk_name(gsd_handle::Gsd_handle,match::String, prev::String) = @ccall libgsdfile.gsd_find_matching_chunk_name(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle}, match::Cstring,prev::Cstring)::Cstring

gsd_upgrade(gsd_handle::Gsd_handle) = @ccall libgsdfile.gsd_upgrade(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle})::Int32

gsd_get_maximum_write_buffer_size(gsd_handle::Gsd_handle) = @ccall libgsdfile.gsd_get_maximum_write_buffer_size(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle})::UInt64

gsd_set_maximum_write_buffer_size(gsd_handle::Gsd_handle, size::UInt64) = @ccall libgsdfile.gsd_set_maximum_write_buffer_size(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle}, size::UInt64)::Int32

gsd_get_index_entries_to_buffer(gsd_handle::Gsd_handle) =  @ccall libgsdfile.gsd_get_index_entries_to_buffer(gsd_handle::Gsd_handle)::UInt64

gsd_set_index_entries_to_buffer(gsd_handle::Gsd_handle, number::UInt64) = @ccall libgsdfile.gsd_set_index_entries_to_buffer(gsd_handle::Gsd_handle, number::UInt64)::Int32


obj=Gsd_handle()
flag = GSD_OPEN_READONLY

file = "/localscratch/HPS_DATA/HPS-Janka/RS31a/run1/MDhnRNPA1seqRS31a_IDR1_M17_NP1_T300_Box10_10_10_s1000000000.gsd"
#println(gsd_create_and_open(obj, file, "application", "schema", UInt32(1), flag, Int32(1)))

#println(flag)
#println(gsd_close(obj))
#println(gsd_open(obj, file, flag))
#println(gsd_close(obj))

#bla = ccall( (:gsd_create, libgsdfile), UInt32, ("filename", "application", "schema", 1))
#println(bla)
#=module libgsd

    bla = ccall( (:gsd_create, libgsdfile), "filename", "application", "schema", 1)
    stat = ccall( (:read_xtc_natoms,libxdrffile), Int32, (Ptr{UInt8}, Ptr{Cint}), xtcfile, natoms)

end=#
=#
end
