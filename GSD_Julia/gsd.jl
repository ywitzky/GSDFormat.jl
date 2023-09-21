include("./libgsd.jl")

mutable struct GSDFILE{I<:Integer}
    name::String
    mode::String
    gsd_version::Tuple{I, I}
    application::String
    schema_version::Tuple{I,I}
    nframes::Int64
    maximum_write_buffer_size::Int64
    index_entries_to_buffer::Int64
    c_name::Cstring
    c_application::Cstring
    c_schema::Cstring
    c_schema_version::Cstring
    schema_truncated::Cstring
    gsd_handle::libgsd.Gsd_handle
    is_open::Bool
end

removeNonASCII(str::AbstractString) = String([Char(c) for c in str if isascii(c)])

function raise_on_error(retval, extra)
    """Raise the appropriate error type.

    Args:
        retval: Return value from a gsd C API call
        extra: Extra string to pass along with the exception
    """
    if retval == libgsd.GSD_ERROR_IO
        throw(ErrorException("GSD_ERROR_IO:,python error: \"Return a tuple for constructing an IOError.\""))
    elseif retval == libgsd.GSD_ERROR_NOT_A_GSD_FILE
        throw(ErrorException("Not a GSD file: " + extra))
    elseif retval == libgsd.GSD_ERROR_INVALID_GSD_FILE_VERSION
        throw(ErrorException("Unsupported GSD file version: " + extra))
    elseif retval == libgsd.GSD_ERROR_FILE_CORRUPT
        throw(ErrorException("Corrupt GSD file: " + extra))
    elseif retval == libgsd.GSD_ERROR_MEMORY_ALLOCATION_FAILED
        throw(ErrorException("Memory allocation failed: " + extra))
    elseif retval == libgsd.GSD_ERROR_NAMELIST_FULL
        throw(ErrorException("GSD namelist is full: " + extra))
    elseif retval == libgsd.GSD_ERROR_FILE_MUST_BE_WRITABLE
        throw(ErrorException("File must be writable: " + extra))
    elseif retval == libgsd.GSD_ERROR_FILE_MUST_BE_READABLE
        throw(ErrorException("File must be readable: " + extra))
    elseif retval == libgsd.GSD_ERROR_INVALID_ARGUMENT
        throw(ErrorException("Invalid gsd argument: " + extra))
    elseif retval != 0
        throw(ErrorException("Unknown error: " + extra))
    end
end

function Init_GSDFILE(name::AbstractString,mode::AbstractString,application::AbstractString, schema::AbstractString, schema_version::Tuple{I,I}) where {I<:Integer}

    exclusive_create=false
    overwrite=false

    if mode == "w"
        c_flags = libgsd.GSD_OPEN_READWRITE
        overwrite = true
    elseif mode == "r"
        c_flags = libgsd.GSD_OPEN_READONLY
    elseif mode == "r+"
        c_flags = libgsd.GSD_OPEN_READWRITE
    elseif mode == "x"
        c_flags = libgsd.GSD_OPEN_READWRITE
        overwrite = 1
        exclusive_create = true
    elseif mode == "a"
        c_flags = libgsd.GSD_OPEN_READWRITE
        if ~isdir(name)
            overwrite = true
        end
    else
        throw(ArgumentError("Invalid mode: " * mode))
    end

    gsd_handle = libgsd.Gsd_handle()
    c_name = ""
    c_application = ""
    c_schema = ""
    c_schema_version = ""
    gsd_version =  (0,0) ### "???"

    if overwrite
        if application == Nothing
            throw(ArgumentError("Provide application when creating a file"))
        end
        if schema == Nothing 
            throw(ArgumentError("Provide schema when creating a file"))
        end
        if schema_version == Nothing
            throw(ArgumentError("Provide schema_version when creating a file"))
        end

        # create a new file or overwrite an existing one
        #=logger.info('overwriting file: ' + name + ' with mode: ' + mode
                    + ', application: ' + application
                    + ', schema: ' + schema
                    + ', and schema_version: ' + str(schema_version))=#
        #name_e = name.encode('utf-8')
        c_name = removeNonASCII(name)

        #application_e = application.encode('utf-8')
        c_application = removeNonASCII(application)

        #schema_e = schema.encode('utf-8')
        c_schema = removeNonASCII(schema)

        c_schema_version = libgsd.gsd_make_version(schema_version[0],
                                                    schema_version[1])

        #with nogil:
        println("pre $(gsd_handle)")
        retval = libgsd.gsd_create_and_open(gsd_handle, c_name,c_application,c_schema, c_schema_version,c_flags,exclusive_create)
        println("post $(gsd_handle)")

    else
        # open an existing file
        #logger.info('opening file: ' + name + ' with mode: ' + mode)
        #name_e = name.encode('utf-8')
        c_name = removeNonASCII(name)

        #with nogil:
        println("pre $(gsd_handle)")
        println("\n\n\n\n $(c_flags)")
        retval = libgsd.gsd_open(gsd_handle, c_name, c_flags)
        println("post $(gsd_handle)")
        println("\n\n\n\n $(c_flags)")
        println("retval = $(retval)")


    end
    raise_on_error(retval, name)

    if ~isnothing(schema)
        schema_truncated = schema
        if length(schema_truncated) > 64
            schema_truncated = schema_truncated[0:63]
        end
        if schema != schema_truncated
            throw(ErrorException("file $(name) has incorrect schema: $(schema)"))
        end
    end

    return GSDFILE{I}(name,mode,gsd_version,application,schema_version,0,0,0,    pointer(c_name),pointer(c_application),pointer(c_schema),pointer(c_schema_version),pointer(schema_truncated),gsd_handle, true)
end

function read_chunk(file::GSDFILE, frame::I, name::String) where {I<:Integer}
        """read_chunk(frame, name)

        Read a data chunk from the file and return it as a array.

        Args:
            frame (int): Index of the frame to read
            name (str): Name of the chunk

        Returns:
            ``(N,M)`` or ``(N,)`` `numpy.ndarray` of ``type``: Data read from
            file. ``N``, ``M``, and ``type`` are determined by the chunk
            metadata. If the data is NxM in the file and M > 1, return a 2D
            array. If the data is Nx1, return a 1D array.

        .. tip::
            Each call invokes a disk read and allocation of a
            new numpy array for storage. To avoid overhead, call
            :py:meth:`read_chunk()` on the same chunk only once.

        Example:
            .. ipython:: python
                :okexcept:

                with gsd.fl.open(name='file.gsd', mode='w',
                                 application="My application",
                                 schema="My Schema", schema_version=[1,0]) as f:
                    f.write_chunk(name='chunk1',
                                  data=numpy.array([1,2,3,4],
                                                   dtype=numpy.float32))
                    f.write_chunk(name='chunk2',
                                  data=numpy.array([[5,6],[7,8]],
                                                   dtype=numpy.float32))
                    f.end_frame()
                    f.write_chunk(name='chunk1',
                                  data=numpy.array([9,10,11,12],
                                                   dtype=numpy.float32))
                    f.write_chunk(name='chunk2',
                                  data=numpy.array([[13,14],[15,16]],
                                                   dtype=numpy.float32))
                    f.end_frame()

                f = gsd.fl.open(name='file.gsd', mode='r',
                                application="My application",
                                schema="My Schema", schema_version=[1,0])
                f.read_chunk(frame=0, name='chunk1')
                f.read_chunk(frame=1, name='chunk1')
                f.read_chunk(frame=2, name='chunk1')
                f.close()
        """
        
        if ~file.is_open
            throw(ErrorException("File is not open"))
        end

        #cdef const libgsd.gsd_index_entry* index_entry
        #cdef char * c_name
        c_name = removeNonASCII(name)


        #cdef int64_t c_frame
        #c_frame = Cinframe

        #with nogil:
        println(file.gsd_handle)
        index_entry = libgsd.gsd_find_chunk(file.gsd_handle,UInt64(frame),name) 

        if isnothing(index_entry)
            throw(ErrorException("frame $(frame) / chunk $(name) not found in: $(file.name)"))
        end

        #data = unsafe_wrap(Vector{Int64}, ap, (index_entry.N, index_entry.M), own=false)
        println(index_entry)
        gsd_type = index_entry.type
        println(gsd_type)
        println(index_entry.frame)
        if gsd_type == libgsd.GSD_TYPE_UINT8
            data_array = zeros(UInt8 ,(index_entry.N, index_entry.M))
        elseif gsd_type == libgsd.GSD_TYPE_UINT16
            data_array = zeros(UInt16,(index_entry.N, index_entry.M))
        elseif gsd_type == libgsd.GSD_TYPE_UINT32
            data_array = zeros(UInt32,(index_entry.N, index_entry.M))
        elseif gsd_type == libgsd.GSD_TYPE_UINT64
            data_array = zeros(UInt64,(index_entry.N, index_entry.M))
        elseif gsd_type == libgsd.GSD_TYPE_INT8
            data_array = zeros(Int8 ,(index_entry.N, index_entry.M))
        elseif gsd_type == libgsd.GSD_TYPE_INT16
            data_array = zeros(Int16,(index_entry.N, index_entry.M))
        elseif gsd_type == libgsd.GSD_TYPE_INT32
            data_array = zeros(Int32,(index_entry.N, index_entry.M))
        elseif gsd_type == libgsd.GSD_TYPE_INT64
            data_array = zeros(Int64,(index_entry.N, index_entry.M))
        elseif gsd_type == libgsd.GSD_TYPE_FLOAT
            data_array = zeros(Float32,(index_entry.N, index_entry.M))
        elseif gsd_type == libgsd.GSD_TYPE_DOUBLE
            data_array = zeros(Float64,(index_entry.N, index_entry.M))
        else
            throw(ErrorException("invalid type for chunk: $(name)"))
        end

        # only read chunk if we have data
        if index_entry.N != 0 && index_entry.M != 0
            data_ptr=Ptr{Cvoid}(pointer_from_objref(Ref(data_array)))
            #=if gsd_type == libgsd.GSD_TYPE_UINT8:
                data_ptr = __get_ptr_uint8(data_array)
            elif gsd_type == libgsd.GSD_TYPE_UINT16:
                data_ptr = __get_ptr_uint16(data_array)
            elif gsd_type == libgsd.GSD_TYPE_UINT32:
                data_ptr = __get_ptr_uint32(data_array)
            elif gsd_type == libgsd.GSD_TYPE_UINT64:
                data_ptr = __get_ptr_uint64(data_array)
            elif gsd_type == libgsd.GSD_TYPE_INT8:
                data_ptr = __get_ptr_int8(data_array)
            elif gsd_type == libgsd.GSD_TYPE_INT16:
                data_ptr = __get_ptr_int16(data_array)
            elif gsd_type == libgsd.GSD_TYPE_INT32:
                data_ptr = __get_ptr_int32(data_array)
            elif gsd_type == libgsd.GSD_TYPE_INT64:
                data_ptr = __get_ptr_int64(data_array)
            elif gsd_type == libgsd.GSD_TYPE_FLOAT:
                data_ptr = __get_ptr_float32(data_array)
            elif gsd_type == libgsd.GSD_TYPE_DOUBLE:
                data_ptr = __get_ptr_float64(data_array)
            else:
                raise ValueError("invalid type for chunk: " + name)
                =#

            #with nogil:
            retval = libgsd.gsd_read_chunk(file.gsd_handle,data_ptr,index_entry)

            raise_on_error(retval, self.name)
        end
        #=if index_entry.M == 1:
            return data_array.reshape([index_entry.N])
        else:
            return data_array=#
end

function open(name, mode; application=None, schema=None, schema_version=None)
    """open(name, mode, application=None, schema=None, schema_version=None)

    :py:func:`open` opens a GSD file and returns a :py:class:`GSDFile` instance.
    The return value of :py:func:`open` can be used as a context manager.

    Args:
        name (str): File name to open.

        mode (str): File access mode.

        application (str): Name of the application creating the file.

        schema (str): Name of the data schema.

        schema_version (tuple[int, int]): Schema version number
            (major, minor).

    Valid values for ``mode``:

    +------------------+---------------------------------------------+
    | mode             | description                                 |
    +==================+=============================================+
    | ``'r'``          | Open an existing file for reading.          |
    +------------------+---------------------------------------------+
    | ``'r+'``         | Open an existing file for reading and       |
    |                  | writing.                                    |
    +------------------+---------------------------------------------+
    | ``'w'``          | Open a file for reading and writing.        |
    |                  | Creates the file if needed, or overwrites   |
    |                  | an existing file.                           |
    +------------------+---------------------------------------------+
    | ``'x'``          | Create a gsd file exclusively and opens it  |
    |                  | for reading and writing.                    |
    |                  | Raise :py:exc:`FileExistsError`             |
    |                  | if it already exists.                       |
    +------------------+---------------------------------------------+
    | ``'a'``          | Open a file for reading and writing.        |
    |                  | Creates the file if it doesn't exist.       |
    +------------------+---------------------------------------------+

    When opening a file for reading (``'r'`` and ``'r+'`` modes):
    ``application`` and ``schema_version`` are ignored and may be ``None``.
    When ``schema`` is not ``None``, :py:func:`open` throws an exception if the
    file's schema does not match ``schema``.

    When opening a file for writing (``'w'``, ``'x'``, or ``'a'`` modes): The
    given ``application``, ``schema``, and ``schema_version`` must not be None.

    Example:

        .. ipython:: python

            with gsd.fl.open(name='file.gsd', mode='w',
                             application="My application", schema="My Schema",
                             schema_version=[1,0]) as f:
                f.write_chunk(name='chunk1',
                              data=numpy.array([1,2,3,4], dtype=numpy.float32))
                f.write_chunk(name='chunk2',
                              data=numpy.array([[5,6],[7,8]],
                                               dtype=numpy.float32))
                f.end_frame()
                f.write_chunk(name='chunk1',
                              data=numpy.array([9,10,11,12],
                                               dtype=numpy.float32))
                f.write_chunk(name='chunk2',
                              data=numpy.array([[13,14],[15,16]],
                                               dtype=numpy.float32))
                f.end_frame()

            f = gsd.fl.open(name='file.gsd', mode='r')
            if f.chunk_exists(frame=0, name='chunk1'):
                data = f.read_chunk(frame=0, name='chunk1')
            data
            f.close()
    """

    return Init_GSDFILE(String(name), mode, application, schema, schema_version)
end

function find_chunk(file, frame, name)

end