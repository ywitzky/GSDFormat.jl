### copies class definitions from hoomd.py

include("./Structs.jl")
include("./gsd_base.jl")

using JSON
import .Base: size, getindex, isdone, iterate, length, eltype

mutable struct HOOMDTrajectory{I<:Integer}# where {I<:Integer}
    file::GSDFILE{I}
    initial_frame::Union{Frame, Nothing}
end
"""Read and write hoomd gsd files.

Args:
    file (`gsd.fl.GSDFile`): File to access.

Open hoomd GSD files with `open`.
"""

function HOOMDTrajectory(gsdobj::GSDFILE{<:Integer}) 
    return init_HOOMDTrajectory(gsdobj)
end

function init_HOOMDTrajectory(file::GSDFILE{I}) where {I<:Integer}
    if file.mode == "ab"
        throw(SystemError("Append mode not yet supported"))
    end

    trajectory = HOOMDTrajectory{I}(file, nothing)

    #logger.info('opening HOOMDTrajectory: ' + str(file))

    if trajectory.file.c_schema !=  Vector{UInt8}("hoomd")
        throw(ArgumentError("GSD file is not a hoomd schema file: $(trajectory.file.name)"))
    end

    valid = false
    version = trajectory.file.schema_version
    if (version < (2, 0) && version >= (1, 0))
        valid = true
    end
    if !valid
        throw(InitError("Incompatible hoomd schema version "* str(version) * " in: " * str(file)))
    end

    #logger.info('found ' + str(len(file)) + ' frames')
    return trajectory
end

@inline function size(traj::HOOMDTrajectory{<:Integer})
    """The number of frames in the trajectory."""
    return traj.file.nframes 
end

@inline function firstindex(traj::HOOMDTrajectory{<:Integer})    
    """ Lowers to begin in Array index A[begin:end] """    
    return 1
end

@inline function lastindex(traj::HOOMDTrajectory{<:Integer})
    """ Lowers to end in Array index A[begin:end] """    
    return traj.file.nframes
end

function getindex(traj::HOOMDTrajectory{<:Integer}, key::Integer) 
    """Index trajectory frames.

    The index can be a positive integer, negative integer, or slice and is
    interpreted the same as `list` indexing.

    Warning:
        As you loop over frames, each frame is read from the file when it is
        reached in the iteration. Multiple passes may lead to multiple disk
        reads if the file does not fit in cache.
    """

    if key < 1 || key > traj.file.nframes
        throw(BoundsError(traj, key))
    end

    return _read_frame(traj,key-1)
end

function iterate(traj::HOOMDTrajectory{<:Integer})
    if !traj.file.is_open
        return nothing
    else
        return (traj[1], 1)
    end
end

function iterate(traj::HOOMDTrajectory{<:Integer}, state::Integer)
    if size(traj)> state 
        state += 1
        return (traj[state], state)
    else
        return nothing
    end
end

@inline function length(traj::HOOMDTrajectory{<:Integer})
    return size(traj)
end

function eltype(traj::HOOMDTrajectory{<:Integer})
    return Type{Frame}
end

function Base.isdone(traj::HOOMDTrajectory{<:Integer}, state::Integer)
    return state==traj.file.nframes
end

function _read_frame(traj::HOOMDTrajectory{<:Integer}, idx::Integer) 
    """Read the frame at the given index from the file.

    Args:
        idx (int): Frame index to read.

    Returns:
        `Frame` with the frame data

    Replace any data chunks not present in the given frame with either data
    from frame 0, or initialize from default values if not in frame 0. Cache
    frame 0 data to avoid file read overhead. Return any default data as
    non-writable numpy arrays.
    """

    if idx >=  size(traj)
        throw(BoundsError([traj], [idx]))
    end

    #logger.debug('reading frame ' + str(idx) + ' from: ' + str(traj))

    if isnothing(traj.initial_frame) && idx != 0
        _read_frame(traj, 0)
    end

    frame = Frame()
    # read configuration first
    if chunk_exists(traj.file, frame=idx, name="configuration/step")
        step_arr = read_chunk(traj.file , frame=idx, name="configuration/step")
        frame.configuration.step = step_arr[1]
    else
        if ~isnothing(traj.initial_frame)
            frame.configuration.step = traj.initial_frame.configuration.step
        else
            frame.configuration.step = get_default("step", frame.configuration)
        end
    end

    if chunk_exists(traj.file, frame=idx, name="configuration/dimensions")
        dimensions_arr = read_chunk(traj.file,frame=idx, name="configuration/dimensions")
        frame.configuration.dimensions = dimensions_arr[1]
    else
        if ~isnothing(traj.initial_frame)
            frame.configuration.dimensions = traj.initial_frame.configuration.dimensions
        else
            frame.configuration.dimensions = get_default("dimensions", frame.configuration)
        end
    end

    if chunk_exists(traj.file, frame=idx, name="configuration/box")
        frame.configuration.box = read_chunk(traj.file,frame=idx, name="configuration/box")
    else
        if ~isnothing(traj.initial_frame)
            frame.configuration.box = traj.initial_frame.configuration.box
        else
            frame.configuration.box = get_default("box", frame.configuration)
        end
    end

    # then read all groups that have N, types, etc...
    for path in ["particles","bonds","angles","dihedrals","impropers","constraints","pairs"]

        initial_frame_container=nothing
        container = getproperty(frame, Symbol(path))
        if !isnothing(traj.initial_frame)
            initial_frame_container = getproperty(traj.initial_frame, Symbol(path))
        end

        container.N = 0
        if chunk_exists(traj.file, frame=idx, name=path * "/N")
            N_arr = read_chunk(traj.file, frame=idx, name=path * "/N")
            container.N = N_arr[1]
        else
            if ~isnothing(traj.initial_frame)
                container.N = initial_frame_container.N
            end
        end

        # type names; TODO test for BondDatA
        if typeof(container) ==ParticleData || typeof(container) <: BondData 
            if chunk_exists(traj.file, frame=idx, name="$path/types")
                container.types = [String(Char.(row[1:end-1])) for row in eachrow(read_chunk(traj.file, frame=idx, name="$path/types"))]
            else
                if ~isnothing(traj.initial_frame)
                    container.types = initial_frame_container.types
                else
                    N = getproperty(container,:N)
                    N = N==0 ? 1 : N
                    container.types = setproperty!(container, :types,get_default("types", container, N) )
                end
            end
        end

        # type shapes
        if typeof(container) == ParticleData && path == "particles"
            if chunk_exists(traj.file, frame=idx, name=path * "/type_shapes")
                container.type_shapes = JSON.parse.(read_chunk(traj.file, frame=idx, name=path * "/type_shapes"))
            else
                if ~isnothing(traj.initial_frame)
                    container.type_shapes = initial_frame_container.type_shapes
                else
                    container.type_shapes = get_default("type_shapes", container)
                end
            end
        end

        for name in get_container_names(container)
            if name in [:N, :types, :type_shapes]
                continue
            end

            # per particle/bond quantities
            if chunk_exists(traj.file, frame=idx, name="$path/$name")
                if name ==:N 
                    setproperty!(container, name, read_chunk(traj.file,frame=idx, name="$path/$name")[1])
                elseif name ==:types
                    setproperty!(container, name, [String(Char.(collect(row[1:end-1]))) for row in eachrow(read_chunk(traj.file, frame=idx, name="$path/types"))])
                else
                    setproperty!(container, name, read_chunk(traj.file,frame=idx, name="$path/$name"))
                end
            else
                if !isnothing(traj.initial_frame) &&  initial_frame_container.N == container.N
                    # read default from initial frame
                    setproperty!(container, name, getproperty(initial_frame_container, name))
                else
                    # initialize from default value
                    N = getproperty(container,:N)
                    N = N==0 ?  1 : N
                    setproperty!(container, name,get_default("$name", container, N) )
                end
            end
        end
    end

    # read state data
    for state in frame.valid_state
        if chunk_exists(traj.file, frame=idx, name="state/$state")
            frame.state[state] = read_chunk(traj.file, frame=idx, name="state/$state")
        end
    end

    # read log data
    logged_data_names = find_matching_chunk_names(traj.file, "log/")
    for log in logged_data_names
        if chunk_exists(traj.file, frame=idx, name=log)
            frame.log[log[4:end]] = read_chunk(traj.file, frame=idx, name=log)
        else
            if ~isnothing(traj.initial_frame)
                frame.log[log[4:end]] = traj._initial_frame.log[log[4:end]]
            end
        end
    end

    # store initial frame
    if isnothing(traj.initial_frame) && idx == 0
        traj.initial_frame = deepcopy(frame)
    end

    return frame
end

function open(name::AbstractString, mode="r")
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

    gsdfileobj = open_gsd(name, string(mode); application="gsd.hoomd " * gsd_version, schema="hoomd", schema_version=(1, 4))

    return HOOMDTrajectory(gsdfileobj)
end

function _should_write(file::HOOMDTrajectory{I}, path::String, name::Symbol, frame::Frame) where {I<:Integer}
    """Test if we should write a given data chunk.

    Args:
        path (str): Path part of the data chunk.
        name (str): Name part of the data chunk.
        frame (:py:class:`Frame`): Frame data is from.

    Returns:
        False if the data matches that in the initial frame. False
        if the data matches all default values. True otherwise.
    """        
    container = getproperty(frame, Symbol(path))
    data = getproperty(container, Symbol(name))

    if !isnothing(file.initial_frame)
        initial_container = getattr(file.initial_frame, Symbol(path))
        initial_data = getattr(initial_container, Symbol(name))
        if initial_data==data
            #logger.debug('skipping data chunk, matches frame 0: ' + path + '/' + name)
            return false
        end
    end

    matches_default_value = false
    if name == "types"
        matches_default_value = (data == get_default(String(name), container))
    else
        default = get_default(String(name), container)
        matches_default_value = sizeof(default) == sizeof(data)
        if matches_default_value
            matches_default_value = all( data .== get_default(String(name), container))
        end
    end

    if matches_default_value && !chunk_exists(file.file, frame=0, name="$path/$name")
        #logger.debug('skipping data chunk, default value: ' + path + '/' + name)
        return false
    end
    return true
end

function end_frame(traj::HOOMDTrajectory)
    """end_frame()

    Complete writing the current frame. After calling :py:meth:`end_frame()`
    future calls to :py:meth:`write_chunk()` will write to the **next**
    frame in the file.

    .. danger::
        Call :py:meth:`end_frame()` to complete the current frame
        **before** closing the file. If you fail to call
        :py:meth:`end_frame()`, the last frame will not be written
        to disk.

    Example:
        .. ipython:: python

            f = gsd.fl.open(name='file.gsd', mode='w',
                            application="My application",
                            schema="My Schema", schema_version=[1,0])

            f.write_chunk(name='chunk1',
                        data=numpy.array([1,2,3,4], dtype=numpy.float32))
            f.end_frame()
            f.write_chunk(name='chunk1',
                        data=numpy.array([9,10,11,12],
                                        dtype=numpy.float32))
            f.end_frame()
            f.write_chunk(name='chunk1',
                        data=numpy.array([13,14],
                                        dtype=numpy.float32))
            f.end_frame()
            f.nframes
            f.close()

    """

    if !traj.file.is_open
        throw(UndefRefError("File is not open"))
    end

    #logger.debug('end frame: ' + self.name)
    retval = libgsd.gsd_end_frame(traj.file.gsd_handle)

    raise_on_error(retval, traj.file.name)
    return nothing
end


function append(traj::HOOMDTrajectory, frame::Frame)
    """Append a frame to a hoomd gsd file.

    Args:
        frame (:py:class:`Frame`): Frame to append.

    Write the given frame to the file at the current frame and increase
    the frame counter. Do not write any fields that are ``None``. For all
    non-``None`` fields, scan them and see if they match the initial frame
    or the default value. If the given data differs, write it out to the
    frame. If it is the same, do not write it out as it can be instantiated
    either from the value at the initial frame or the default value.
    """
    #logger.debug('Appending frame to hoomd trajectory: ' + str(file))

    validate(frame)

    # want the initial frame specified as a reference to detect if chunks
    # need to be written
    if isnothing(traj.initial_frame) && length(traj) > 0
        _read_frame(traj, 0)
    end

    for path in ["configuration", "particles","bonds","angles","dihedrals","impropers","constraints","pairs"]
        container = getproperty(frame, Symbol(path))
        for name in get_container_names(container)
            if _should_write(traj, path, name, frame)
                #logger.debug('writing data chunk: ' + path + '/' + name)
                data = getproperty(container, Symbol(name))

                if name == "N"
                    data = Vector{UInt32}(data)
                end
                if name == "step"
                    data = Vector{UInt64}(data)
                end
                if name == "dimensions"
                    data = Vector{UInt8}(data)
                end
                if name in (Symbol("types"), Symbol("type_shapes"))
                    if !isnothing(data)
                        ### TODO needs to be tested for type_shapes
                        data = Vector{Vector{UInt8}}([Vector{UInt8}("$shape_dict ") for shape_dict in data]) ### need 0 termination for cstrings 
                        wid = maximum(length.(data))
                        new_data = zeros(UInt8, (length(data), wid))
                        for (i, d) in enumerate(data)
                            new_data[i,1:length(d)] .= d
                        end
                        data = new_data
                    end
                end
                write_chunk(traj.file, "$path/$name", data)
            end
        end
    end

    # write state data
    for (state, data) in frame.state
        write_chunk(traj.file, "state/$state", data)
    end

    # write log data
    for (log, data) in frame.log
        write_chunk(traj.file, "log/$log", data)
    end

    end_frame(traj)
end

function close(traj::HOOMDTrajectory)
    """Close the file."""

    close(traj.file)
    #del self._initial_frame
end


function get_chunk_names(traj::HOOMDTrajectory)
    start = Ptr{Int8}(((traj.file.gsd_handle[]).file_names.data.data))
    res = (traj.file.gsd_handle[]).file_names.data.reserved[]
    stop =start+res
    return split(strip(join([Char(Cptr{Cuchar}(ptr)[]) for ptr in start:stop]), '\0'), "\0")
end

