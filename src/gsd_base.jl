include("./libgsd_wrapper.jl")

using Base.Libc, CBinding
import Base.close

gsd_version = "3.1.1"

### basically a julia copy of fl.pyx in the github of the glotzlab gsd code

mutable struct GSDFILE{I<:Integer}
    name::String
    mode::String
    gsd_version::Tuple{I, I}
    application::String
    schema_version::Tuple{I,I}
    nframes::Int64
    maximum_write_buffer_size::Int64
    index_entries_to_buffer::Int64
    c_name::Vector{UInt8}
    c_application::Vector{UInt8}
    c_schema::Vector{UInt8}
    c_schema_version::UInt32
    schema_truncated::Vector{UInt8}
    gsd_handle::Base.RefValue{typeof(libgsd.gsd_handle())} ### Base.RefValue{libgsd.gsd_handle} is different for whatever reason.
    is_open::Bool
end



removeNonASCII(str::AbstractString) = Vector{UInt8}(String([Char(c) for c in str if isascii(c)]))

function raise_on_error(retval, extra)
    """Raise the appropriate error type.

    Args:
        retval: Return value from a gsd C API call
        extra: Extra string to pass along with the exception
    """
    if retval == libgsd.GSD_ERROR_IO
        throw(ErrorException("GSD_ERROR_IO:,python error: \"Return a tuple for constructing an IOError.\""))
    elseif retval == libgsd.GSD_ERROR_NOT_A_GSD_FILE
        throw(ErrorException("Not a GSD file: " * extra))
    elseif retval == libgsd.GSD_ERROR_INVALID_GSD_FILE_VERSION
        throw(ErrorException("Unsupported GSD file version: " * extra))
    elseif retval == libgsd.GSD_ERROR_FILE_CORRUPT
        throw(ErrorException("Corrupt GSD file: " + extra))
    elseif retval == libgsd.GSD_ERROR_MEMORY_ALLOCATION_FAILED
        throw(ErrorException("Memory allocation failed: " * extra))
    elseif retval == libgsd.GSD_ERROR_NAMELIST_FULL
        throw(ErrorException("GSD namelist is full: " * extra))
    elseif retval == libgsd.GSD_ERROR_FILE_MUST_BE_WRITABLE
        throw(ErrorException("File must be writable: " * extra))
    elseif retval == libgsd.GSD_ERROR_FILE_MUST_BE_READABLE
        throw(ErrorException("File must be readable: " * extra))
    elseif retval == libgsd.GSD_ERROR_INVALID_ARGUMENT
        throw(ErrorException("Invalid gsd argument: " * extra))
    elseif retval != 0
        throw(ErrorException("Unknown error $(retval): " * extra))
    end
end

function Init_GSDFILE(name::AbstractString,mode::AbstractString,application::AbstractString, schema::AbstractString, schema_version::Tuple{I,I}) where {I<:Integer}

    exclusive_create=false
    overwrite=false
    c_flags= libgsd.GSD_OPEN_READONLY
    if mode == "w"
        c_flags = libgsd.GSD_OPEN_READWRITE
        overwrite = true
    elseif mode == "r"
        c_flags = libgsd.GSD_OPEN_READONLY
    elseif mode == "r+"
        c_flags = libgsd.GSD_OPEN_READWRITE
    elseif mode == "x"
        c_flags = libgsd.GSD_OPEN_READWRITE
        overwrite = true
        exclusive_create = true
    elseif mode == "a"
        c_flags = libgsd.GSD_OPEN_READWRITE
        if ~isdir(name)
            overwrite = true
        end
    else
        throw(ArgumentError("Invalid mode: " * mode))
    end
    
    gsd_handle =  Ref(libgsd.gsd_handle())

    c_name = ""
    c_application = ""
    c_schema = removeNonASCII(schema)
    c_schema_version = libgsd.gsd_make_version(schema_version[1],schema_version[2]) ### returns UInt32
    gsd_version = schema_version #(0,0) ### "???"


    if overwrite
        if isnothing(application)
            throw(ArgumentError("Provide application when creating a file"))
        end
        if isnothing(schema) 
            throw(ArgumentError("Provide schema when creating a file"))
        end
        if isnothing(schema_version)
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

        #with nogil:
        retval = libgsd.gsd_create_and_open(gsd_handle, c_name,c_application,c_schema, c_schema_version,c_flags,exclusive_create)

    else
        c_name = removeNonASCII(name)

        retval = libgsd.gsd_open(gsd_handle,c_name,c_flags)
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

    schema_truncated = Vector{UInt8}(schema_truncated )
    c_application    = Vector{UInt8}(c_application )
    c_schema         = Vector{UInt8}(c_schema )
    c_schema_version = c_schema_version

    nframes = libgsd.gsd_get_nframes(gsd_handle)

    return GSDFILE{I}(name,mode,gsd_version,application,schema_version,nframes,0,0,  c_name,c_application,c_schema,c_schema_version,schema_truncated,gsd_handle, true)
end

function read_chunk(file::GSDFILE{I}; frame::I, name::String) where {I<:Integer}
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

    c_name = removeNonASCII(name)

    index_entry_ptr = libgsd.gsd_find_chunk(file.gsd_handle,UInt64(frame),name)
    index_entry = index_entry_ptr[]

    #GC.@preserve index_entry_ptr index_entry begin

        if isnothing(index_entry)
        throw(ErrorException("frame $(frame) / chunk $(name) not found in: $(file.name)"))
    end

    gsd_type = index_entry.type
    
    if gsd_type == libgsd.GSD_TYPE_UINT8
        data_type=UInt8
    elseif gsd_type == libgsd.GSD_TYPE_UINT16
        data_type=UInt16
    elseif gsd_type == libgsd.GSD_TYPE_UINT32
        data_type=UInt32
    elseif gsd_type == libgsd.GSD_TYPE_UINT64
        data_type=UInt64
    elseif gsd_type == libgsd.GSD_TYPE_INT8
        data_type=Int8
    elseif gsd_type == libgsd.GSD_TYPE_INT16
        data_type=Int16
    elseif gsd_type == libgsd.GSD_TYPE_INT32
        data_type=Int32
    elseif gsd_type == libgsd.GSD_TYPE_INT64
        data_type=Int64
    elseif gsd_type == libgsd.GSD_TYPE_FLOAT
        data_type=Float32
    elseif gsd_type == libgsd.GSD_TYPE_DOUBLE
        data_type=Float64
    else
        throw(ErrorException("invalid type for chunk: $(name)"))
    end

    data_ptr = Libc.calloc(index_entry.N*index_entry.M, sizeof(data_type)) ### allocate zeroed memory in c-style

    # only read chunk if we have data
    if index_entry.N != 0 && index_entry.M != 0

        retval = libgsd.gsd_read_chunk(file.gsd_handle,data_ptr,index_entry_ptr)::Int32

        raise_on_error(retval, name)

        data_array = copy(permutedims( unsafe_wrap(Matrix{data_type}, reinterpret(Ptr{data_type}, data_ptr),(UInt64(index_entry.M), UInt64(index_entry.N)); own=false), (2,1))) ###retrieve data from pointer and convert from cstyle to julia/fortran-style order; command is messy since Cbinding cant deal with void pointer for the data array
        ### TODO Potentially optimise
    end
    Libc.free(data_ptr) ### free alloc

    if index_entry.M == 1
        return reshape(data_array, Int64(index_entry.N) )
    else
        return data_array
    end
end

function chunk_exists(file::GSDFILE{I}; frame::I, name::String) where {I<:Integer}
    """chunk_exists(frame, name)

    Test if a chunk exists.

    Args:
        frame (int): Index of the frame to check
        name (str): Name of the chunk

    Returns:
        bool: ``True`` if the chunk exists in the file at the given frame.\
            ``False`` if it does not.

    Example:
        .. ipython:: python

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

            f.chunk_exists(frame=0, name='chunk1')
            f.chunk_exists(frame=0, name='chunk2')
            f.chunk_exists(frame=0, name='chunk3')
            f.chunk_exists(frame=10, name='chunk1')
            f.close()
    """

    index_entry_ptr = libgsd.gsd_find_chunk(file.gsd_handle,UInt64(frame),name)

    return ~libgsd.isNULL(index_entry_ptr)

end

#=
function open_gsd(name, mode="r")
    """Open a hoomd schema GSD file.

    The return value of `open` can be used as a context manager.

    Args:
        name (str): File name to open.
        mode (str): File open mode.

    Returns:
        `HOOMDTrajectory` instance that accesses the file **name** with the
        given **mode**.

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

    """

    gsdfileobj = open_gsd_(String(name),mode; application="gsd.hoomd ", schema="hoomd", schema_version=(1, 4))
    return gsdfileobj
end=#


function open_gsd(name::AbstractString, mode::AbstractString; application=nothing, schema=nothing, schema_version=nothing)
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


function find_matching_chunk_names(file::GSDFILE, match::AbstractString)
    """find_matching_chunk_names(match)

    Find all the chunk names in the file that start with the string *match*.

    Args:
        match (str): Start of the chunk name to match

    Returns:
        array[str]: Matching chunk names

    Example:
        .. ipython:: python

            with gsd.fl.open(name='file.gsd', mode='w',
                            application="My application",
                            schema="My Schema", schema_version=[1,0]) as f:
                f.write_chunk(name='data/chunk1',
                            data=numpy.array([1,2,3,4],
                                            dtype=numpy.float32))
                f.write_chunk(name='data/chunk2',
                            data=numpy.array([[5,6],[7,8]],
                                            dtype=numpy.float32))
                f.write_chunk(name='input/chunk3',
                            data=numpy.array([9, 10],
                                            dtype=numpy.float32))
                f.end_frame()
                f.write_chunk(name='input/chunk4',
                            data=numpy.array([11, 12, 13, 14],
                                            dtype=numpy.float32))
                f.end_frame()

            f = gsd.fl.open(name='file.gsd', mode='r',
                            application="My application",
                            schema="My Schema", schema_version=[1,0])

            f.find_matching_chunk_names('')
            f.find_matching_chunk_names('data')
            f.find_matching_chunk_names('input')
            f.find_matching_chunk_names('other')
            f.close()
    """

    if ~file.is_open throw(SystemError("File is not open")) end

    retval = zeros(UInt32,0)

    c_found = libgsd.gsd_find_matching_chunk_name(file.gsd_handle,match,libgsd.getNULL())

    while  ~libgsd.isNULL(c_found)
        push!(retval, c_found)
        c_found = libgsd.gsd_find_matching_chunk_name(file.gsd_handle,match,c_found)
    end

    return retval
end


function close(file::GSDFILE)
    """close()

    Close the file.

    Once closed, any other operation on the file object will result in a
    `ValueError`. :py:meth:`close()` may be called more than once.
    The file is automatically closed when garbage collected or when
    the context manager exits.

    Example:
        .. ipython:: python
            :okexcept:

            f = gsd.fl.open(name='file.gsd', mode='w',
                            application="My application",
                            schema="My Schema", schema_version=[1,0])
            f.write_chunk(name='chunk1',
                        data=numpy.array([1,2,3,4], dtype=numpy.float32))
            f.end_frame()
            data = f.read_chunk(frame=0, name='chunk1')

            f.close()
            # Read fails because the file is closed
            data = f.read_chunk(frame=0, name='chunk1')

    """
    if file.is_open
        ##logger.info('closing file: ' + self.name)
        retval = libgsd.gsd_close(file.gsd_handle)
        file.is_open = false
        raise_on_error(retval, file.name)
    end

    return nothing
end



function get_nframes(gsdfileobj::GSDFILE)
    return libgsd.gsd_get_nframes(gsdfileobj.gsd_handle)
end
#function find_chunk(file, frame, name)

#end
