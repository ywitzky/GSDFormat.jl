### copies class definitions from hoomd.py

include("./Structs.jl")
include("./gsd.jl")

using JSON
import Base: size, getindex

mutable struct HOOMDTrajectory{I<:Integer}# where {I<:Integer}
    file::GSDFILE{I}
    initial_frame::Union{I, Nothing}
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

    #logger.info('opening HOOMDTrajectory: ' + str(self.file))

    if trajectory.file.c_schema !=  Vector{UInt8}("hoomd")
        throw(ArgumentError("GSD file is not a hoomd schema file: $(trajectory.file.name)"))
    end

    valid = false
    version = trajectory.file.schema_version
    if (version < (2, 0) && version >= (1, 0))
        valid = true
    end
    if !valid
        throw(InitError("Incompatible hoomd schema version "* str(version) * " in: " * str(self.file)))
    end

    #logger.info('found ' + str(len(self)) + ' frames')
    return trajectory
end

function size(traj::HOOMDTrajectory{<:Integer})
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

    #logger.debug('reading frame ' + str(idx) + ' from: ' + str(self.file))

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
        if typeof(container) ==ParticleData || typeof(container) <: BondData{<:Integer}  
            if chunk_exists(traj.file, frame=idx, name="$path/types")
                container.types = Char.(read_chunk(traj.file, frame=idx, name="$path/types")[:,1]) ### seems like weird behaviour. always second column which is empty
            else
                if ~isnothing(traj.initial_frame)
                    container.types = initial_frame_container.types
                else
                    container.types = get_default("types", container)
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
            # per particle/bond quantities
            if chunk_exists(traj.file, frame=idx, name="$path/$name")
                setproperty!(container, name, read_chunk(traj.file,frame=idx, name="$path/$name"))
            else
                if !isnothing(traj.initial_frame) &&  initial_frame_container.N == container.N
                    # read default from initial frame
                    setproperty!(container, name, getproperty(initial_frame_container, name))
                else
                    # initialize from default value
                    setproperty!(container, name, copy(get_default("$name", container)) )
                end
                #getproperty(container, name).flags.writable=false
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
            frame.log[log[4:end]] = self.file.read_chunk(frame=idx, name=log)
        else
            if ~isnothing(traj.initial_frame)
                frame.log[log[4:end]] = self._initial_frame.log[log[4:end]]
            end
        end
    end

    # store initial frame
    if ~isnothing(traj.initial_frame) && idx == 0
        self._initial_frame = frame
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

    gsdfileobj = open_gsd(name, string(mode); application="gsd.hoomd" * gsd_version, schema="hoomd", schema_version=(1, 4))

    return HOOMDTrajectory(gsdfileobj)
end