# Copyright (c) 2016-2023 The Regents of the University of Michigan
# Part of GSD, released under the BSD 2-Clause License.

module libgsd

using Libdl
 
libgsdfile= Libdl.find_library("libgsd.so", vcat(Base.DL_LOAD_PATH, ["/uni-mainz.de/homes/ywitzky/phdscripts/GSD/GSD_Julia/gsd/"]) )


@enum GSD_ERROR_TYPE GSD_SUCCESS=0 GSD_ERROR_IO=-1 GSD_ERROR_INVALID_ARGUMENT=-2 GSD_ERROR_NOT_A_GSD_FILE=-3 GSD_ERROR_INVALID_GSD_FILE_VERSION=-4 GSD_ERROR_FILE_CORRUPT=-5 GSD_ERROR_MEMORY_ALLOCATION_FAILED=-6 GSD_ERROR_NAMELIST_FULL=-7 GSD_ERROR_FILE_MUST_BE_WRITABLE=-8 GSD_ERROR_FILE_MUST_BE_READABLE=-9

@enum  Gsd_type GSD_TYPE_UINT8=1 GSD_TYPE_UINT16 GSD_TYPE_UINT32 GSD_TYPE_UINT64 GSD_TYPE_INT8 GSD_TYPE_INT16 GSD_TYPE_INT32 GSD_TYPE_INT64 GSD_TYPE_FLOAT GSD_TYPE_DOUBLE


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
    Gsd_header() = new(0,0,zeros(Cuchar, 64),zeros(Cuchar, 64),0,0,0,0,0,zeros(Cuchar, 80),)
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

@enum Gsd_open_flag GSD_OPEN_READWRITE GSD_OPEN_READONLY GSD_OPEN_APPEND


mutable struct Gsd_name_id_map
    v::Ptr{Cvoid}
    size::Csize_t
    Gsd_name_id_map() = new(Ptr{Cvoid}(pointer_from_objref(Ref(Cdouble(0.0)))), 0.0)
end

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

gsd_make_version(major::UInt32,minor::UInt32) = @ccall libgsdfile.gsd_make_version(major::UInt32,minor::UInt32)::UInt32


gsd_create(filename::String, application::String, schema::String, schemaVersion::UInt32) = @ccall libgsdfile.gsd_create(filename::Cstring, application::Cstring, schema::Cstring, schemaVersion::Cuint)::Int32

gsd_create_and_open(gsd_handle::Gsd_handle, filename::String, application::String, schema::String, schemaVersion::UInt32,flags::Gsd_open_flag,exclusive_create::Int32) = @ccall libgsdfile.gsd_create_and_open(pointer_from_objref(Ref(gsd_handle))::Ptr{Gsd_handle}, filename::Cstring,application::Cstring,schema::Cstring, schemaVersion::Cuint,flags::Gsd_open_flag,exclusive_create::Int32)::Int32

gsd_open(gsd_handle::Gsd_handle, filename::String, flags::Gsd_open_flag) =  begin  
    test  = pointer_from_objref(Ref(gsd_handle))
    tmp = [Gsd_handle]
    #println("kyra")
    #println( unsafe_pointer_to_objref(test))
    @ccall libgsdfile.gsd_open(test::Ptr{Gsd_handle},filename::Cstring,flags::Gsd_open_flag)::Int32
    #ccall( (:gsd_open, libgsdfile), Int32, (Ptr{Gsd_handle}, Cstring, Gsd_open_flag), tmp, filename, flags)
   # println("post")
    #::Ptr{Gsd_handle}
    #println(unsafe_ref(test))
    gsd_handle2 = unsafe_pointer_to_objref(test)
    println(typeof(gsd_handle2))
    println(gsd_handle2[])
    println("Hallo")
end
#

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
println(gsd_open(obj, file, flag))
println(gsd_close(obj))

#bla = ccall( (:gsd_create, libgsdfile), UInt32, ("filename", "application", "schema", 1))
#println(bla)
#=module libgsd

    bla = ccall( (:gsd_create, libgsdfile), "filename", "application", "schema", 1)
    stat = ccall( (:read_xtc_natoms,libxdrffile), Int32, (Ptr{UInt8}, Ptr{Cint}), xtcfile, natoms)

end=#

end