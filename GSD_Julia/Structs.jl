### copies class definitions from hoomd.py

import Base: size, getindex

mutable struct HOOMDTrajectory{I<:Integer}
    file::GSDFILE{I}
    initial_frame::I
    HOOMDTrajectory(gsdobj::GSDFILE{I}) = init_HOOMDTrajectory(gsdobj)
end
"""Read and write hoomd gsd files.

Args:
    file (`gsd.fl.GSDFile`): File to access.

Open hoomd GSD files with `open`.
"""

function init_HOOMDTrajectory(file::GSDFILE{I}) where {I<:Integer}
    if file.mode == "ab"
        throw(SystemError("Append mode not yet supported"))
    end

    trajectory = HOOMDTrajectory(file, nothing)

    #logger.info('opening HOOMDTrajectory: ' + str(self.file))

    if trajectory.file.schema != 'hoomd'
        throw(InitError('GSD file is not a hoomd schema file: '+ str(trajectory.file)))
    end

    valid = false
    version = trajectory.file.schema_version
    if (version < (2, 0) and version >= (1, 0))
        valid = true
    end
    if ~valid
        throw(InitError('Incompatible hoomd schema version '
                           + str(version) + ' in: ' + str(self.file)))

    #logger.info('found ' + str(len(self)) + ' frames')
    return trajectory
end

function size(traj::HOOMDTrajectory{Integer})
    """The number of frames in the trajectory."""
    traj.file.nframes
end

@inline function firstindex(traj::HOOMDTrajectory{Integer})    
    """ Lowers to begin in Array index A[begin:end] """    
    return 1
end

@inline function lastindex(traj::HOOMDTrajectory{Integer})
    """ Lowers to end in Array index A[begin:end] """    
    return traj.file.nframes
end

function getindex(traj::HOOMDTrajectory{Integer}, key::Integer) 
    """Index trajectory frames.

    The index can be a positive integer, negative integer, or slice and is
    interpreted the same as `list` indexing.

    Warning:
        As you loop over frames, each frame is read from the file when it is
        reached in the iteration. Multiple passes may lead to multiple disk
        reads if the file does not fit in cache.
    """

    if key < 1 || key > traj.file.nframes
        throw(BoundsError("Key $key not within bounds [1:$(traj.file.nframes)] of HOOMDTrajectory."))
    end

    return _read_frame(traj,key)

end


function _read_frame(traj::HOOMDTrajectory{Integer}, idx::Integer):
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
    if idx >= size(traj)
        throw(BoundsError("Key $key not within bounds [1:$(traj.file.nframes)] of HOOMDTrajectory."))
    end

    #logger.debug('reading frame ' + str(idx) + ' from: ' + str(self.file))

    if isnothing(traj.initial_frame) && idx != 0:
        read_frame(traj, 0)

    frame = Frame()
    # read configuration first
    if chunk_exists(traj.file, frame=idx, name="configuration/step"):
        step_arr = read_chunk(traj.file , frame=idx, name="configuration/step")
        frame.configuration.step = step_arr[0]
    else
        if ~isnothing(traj.initial_frame)
            frame.configuration.step = traj.initial_frame.configuration.step
        else
            frame.configuration.step = frame.configuration._default_value["step"]
        end
    end

    if chunk_exists(traj.file, frame=idx, name="configuration/dimensions")
        dimensions_arr = read_chunk(traj,frame=idx, name="configuration/dimensions")
        frame.configuration.dimensions = dimensions_arr[0]
    else
        if ~isnothing(traj.initial_frame)
            frame.configuration.dimensions = traj.initial_frame.configuration.dimensions
        else
            frame.configuration.dimensions = frame.configuration._default_value["dimensions"]
        end
    end

    if chunk_exists(traj.fileframe=idx, name="configuration/box")
        frame.configuration.box = read_chunk(traj.file,frame=idx, name="configuration/box")
    else
        if ~isnothing(traj.initial_frame)
            frame.configuration.box = traj.initial_frame.configuration.box
        else
            frame.configuration.box = frame.configuration._default_value["box"]
        end
    end

    # then read all groups that have N, types, etc...
    for path in ["particles","bonds","angles","dihedrals","impropers","constraints","pairs"]

        container = getproperty(frame, Symbol(path))
        if ~isnothing(traj_initial_frame)
            initial_frame_container = getproperty(traj.initial_frame, Symbol(path))
        end

        container.N = 0
        if chunk_exists(traj.file, frame=idx, name=path * '/N')
            N_arr = read_chunk(traj.file, frame=idx, name=path * '/N')
            container.N = N_arr[0]
        else
            if ~isnothing(traj.initial_frame)
                container.N = initial_frame_container.N
            end
        end

        # type names
        if 'types' in container._default_value:
            if chunk_exists(traj.file, frame=idx, name=path * "/types")
                tmp = read_chunk(traj.file, frame=idx, name=path * "/types")
                #tmp = tmp.view(dtype=numpy.dtype((bytes, tmp.shape[1])))
                #tmp = tmp.reshape([tmp.shape[0]])
                container.types = list(a.decode('UTF-8') for a in tmp)
            else
                if ~isnothing(traj.initial_frame)
                    container.types = initial_frame_container.types
                else
                    container.types = container._default_value["types"]
                end
            end
        end

        # type shapes
        if ("type_shapes" in container._default_value && path == "particles")
            if chunk_exists(traj.file, frame=idx, name=path * "/type_shapes")
                tmp = read_chunk(traj.file, frame=idx, name=path * "/type_shapes")
                #tmp = tmp.view(dtype=numpy.dtype((bytes, tmp.shape[1])))
                #tmp = tmp.reshape([tmp.shape[0]])
                #container.type_shapes =  list(json.loads(json_string.decode('UTF-8')     for json_string in tmp)
            else
                if ~isnothing(traj.initial_frame)
                    container.type_shapes = initial_frame_container.type_shapes
                else
                    container.type_shapes = container._default_value["type_shapes"]
                end
            end
        end

        for name in container._default_value
            if name in ("N", "types", "type_shapes") continue end

            # per particle/bond quantities
            if chunk_exists(traj.file, frame=idx, name=path * '/' + name)
                container.__dict__[name] = read_chunk(traj.file
                    frame=idx, name=path + '/' + name)
            else
                if isnothing(traj.initial_frame) &&  initial_frame_container.N == container.N
                    # read default from initial frame
                    container.__dict__[name] = \
                        initial_frame_container.__dict__[name]
                else
                    # initialize from default value
                    #tmp = numpy.array([container._default_value[name]])
                    tmp = zeros([container._default_value[name]])

                    s = list(tmp.shape)
                    s[0] = container.N
                    container.__dict__[name] = numpy.empty(shape=s, dtype=tmp.dtype)
                    container.__dict__[name][:] = tmp
                end
                container.__dict__[name].flags.writeable = false
            end
        end

    # read state data
    for state in frame._valid_state
        if chunk_exists(traj.file, frame=idx, name="state/" * state)
            frame.state[state] = read_chunk(traj.file, frame=idx, name="state/" * state)
        end
    end

    # read log data
    logged_data_names = find_matching_chunk_names(traj.file, "log/")
    for log in logged_data_names
        if chunk_exists(traj.file, frame=idx, name=log)
            frame.log[log[4:]] = self.file.read_chunk(frame=idx, name=log)
        else
            if ~isnothing(traj.initial_frame)
                frame.log[log[4:]] = self._initial_frame.log[log[4:]]
            end
        end
    end

    # store initial frame
    if ~isnothing(traj.initial_frame) && idx == 0:
        self._initial_frame = frame

    return frame
end