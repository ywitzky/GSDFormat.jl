mutable struct TrajFile
    gsdfile::GSDFILE
    initial_frame::?????
end

function length(traj::TrajFile)
    """The number of frames in the trajectory."""
    return traj.gsdfile.nframes
end

function _read_frame(traj::TrajFile, idx::I) where {I<:Integer}
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
    if idx >= length(traj):
        throw(ErrorException("Index Error: tried to access $(idx) from gsd file with $(length(traj)) frames. "))
    end

    #logger.debug('reading frame ' + str(idx) + ' from: ' + str(self.file))

    if isnothing(traj._initial_frame) &&  idx != 0
        _read_frame(traj, 0)
    end

    frame = Frame()
    # read configuration first
    if self.file.chunk_exists(frame=idx, name='configuration/step'):
        step_arr = self.file.read_chunk(frame=idx,
                                        name='configuration/step')
        frame.configuration.step = step_arr[0]
    else:
        if self._initial_frame is not None:
            frame.configuration.step = \
                self._initial_frame.configuration.step
        else:
            frame.configuration.step = \
                frame.configuration._default_value['step']

    if self.file.chunk_exists(frame=idx, name='configuration/dimensions'):
        dimensions_arr = self.file.read_chunk(
            frame=idx, name='configuration/dimensions')
        frame.configuration.dimensions = dimensions_arr[0]
    else:
        if self._initial_frame is not None:
            frame.configuration.dimensions = \
                self._initial_frame.configuration.dimensions
        else:
            frame.configuration.dimensions = \
                frame.configuration._default_value['dimensions']

    if self.file.chunk_exists(frame=idx, name='configuration/box'):
        frame.configuration.box = self.file.read_chunk(
            frame=idx, name='configuration/box')
    else:
        if self._initial_frame is not None:
            frame.configuration.box = self._initial_frame.configuration.box
        else:
            frame.configuration.box = \
                frame.configuration._default_value['box']

    # then read all groups that have N, types, etc...
    for path in [
            'particles',
            'bonds',
            'angles',
            'dihedrals',
            'impropers',
            'constraints',
            'pairs',
    ]:
        container = getattr(frame, path)
        if self._initial_frame is not None:
            initial_frame_container = getattr(self._initial_frame, path)

        container.N = 0
        if self.file.chunk_exists(frame=idx, name=path + '/N'):
            N_arr = self.file.read_chunk(frame=idx, name=path + '/N')
            container.N = N_arr[0]
        else:
            if self._initial_frame is not None:
                container.N = initial_frame_container.N

        # type names
        if 'types' in container._default_value:
            if self.file.chunk_exists(frame=idx, name=path + '/types'):
                tmp = self.file.read_chunk(frame=idx, name=path + '/types')
                tmp = tmp.view(dtype=numpy.dtype((bytes, tmp.shape[1])))
                tmp = tmp.reshape([tmp.shape[0]])
                container.types = list(a.decode('UTF-8') for a in tmp)
            else:
                if self._initial_frame is not None:
                    container.types = initial_frame_container.types
                else:
                    container.types = container._default_value['types']

        # type shapes
        if ('type_shapes' in container._default_value
                and path == 'particles'):
            if self.file.chunk_exists(frame=idx,
                                    name=path + '/type_shapes'):
                tmp = self.file.read_chunk(frame=idx,
                                        name=path + '/type_shapes')
                tmp = tmp.view(dtype=numpy.dtype((bytes, tmp.shape[1])))
                tmp = tmp.reshape([tmp.shape[0]])
                container.type_shapes = \
                    list(json.loads(json_string.decode('UTF-8'))
                        for json_string in tmp)
            else:
                if self._initial_frame is not None:
                    container.type_shapes = \
                        initial_frame_container.type_shapes
                else:
                    container.type_shapes = \
                        container._default_value['type_shapes']

        for name in container._default_value:
            if name in ('N', 'types', 'type_shapes'):
                continue

            # per particle/bond quantities
            if self.file.chunk_exists(frame=idx, name=path + '/' + name):
                container.__dict__[name] = self.file.read_chunk(
                    frame=idx, name=path + '/' + name)
            else:
                if (self._initial_frame is not None
                        and initial_frame_container.N == container.N):
                    # read default from initial frame
                    container.__dict__[name] = \
                        initial_frame_container.__dict__[name]
                else:
                    # initialize from default value
                    tmp = numpy.array([container._default_value[name]])
                    s = list(tmp.shape)
                    s[0] = container.N
                    container.__dict__[name] = numpy.empty(shape=s,
                                                        dtype=tmp.dtype)
                    container.__dict__[name][:] = tmp

                container.__dict__[name].flags.writeable = False

    # read state data
    for state in frame._valid_state:
        if self.file.chunk_exists(frame=idx, name='state/' + state):
            frame.state[state] = self.file.read_chunk(frame=idx,
                                                    name='state/' + state)

    # read log data
    logged_data_names = self.file.find_matching_chunk_names('log/')
    for log in logged_data_names:
        if self.file.chunk_exists(frame=idx, name=log):
            frame.log[log[4:]] = self.file.read_chunk(frame=idx, name=log)
        else:
            if self._initial_frame is not None:
                frame.log[log[4:]] = self._initial_frame.log[log[4:]]

    # store initial frame
    if self._initial_frame is None and idx == 0:
        self._initial_frame = frame

    return frame
