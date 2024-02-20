abstract type StructType end

mutable struct ConfigurationData <: StructType
    """Store configuration data.

    Use the `Frame.configuration` attribute of a to access the configuration.

    Attributes:
        step (int): Time step of this frame (:chunk:`configuration/step`).

        dimensions (int): Number of dimensions
            (:chunk:`configuration/dimensions`). When not set explicitly,
            dimensions will default to different values based on the value of
            :math:`L_z` in `box`. When :math:`L_z = 0` dimensions will default
            to 2, otherwise 3. User set values always take precedence.
    """
    step::UInt64
    dimensions::Vector{UInt8}
    box::Vector{Float32}
    ConfigurationData() = new(nothing, nothing, nothing)
end

function set_box!(data::ConfigurationData, Box::Vector{Float32}) 
    if (length(Box)==6)
        data.box .=Box
        if isnothing(self.dimensions)
            data.dimension = Box[3]==0 ? 2 : 3 
        end
    else
        throw(TypeError("Set Box expects Vector{Float32} of length 6."))
    end
    return nothing
end

function get_box(data::ConfigurationData)
    """((6, 1) `numpy.ndarray` of ``numpy.float32``): Box dimensions \
    (:chunk:`configuration/box`).

    [lx, ly, lz, xy, xz, yz].
    """
    return data.box
end

function validate(data::ConfigurationData)
    ### Julia types ensures all types validation done here.


    #="""Validate all attributes. 

    Convert every array attribute to a `numpy.ndarray` of the proper
    type and check that all attributes have the correct dimensions.

    Ignore any attributes that are ``None``.

    Warning:
        Array attributes that are not contiguous numpy arrays will be
        replaced with contiguous numpy arrays of the appropriate type.
    """=#
    #logger.debug('Validating ConfigurationData')
    #=
    if !isnothing(data.box)
        self.box = numpy.ascontiguousarray(self.box, dtype=numpy.float32)
        self.box = self.box.reshape([6])
    end=#
    return nothing
end


mutable struct ParticleData <: StructType
    """Store particle data chunks.

    Use the `Frame.particles` attribute of a to access the particles.

    Instances resulting from file read operations will always store array
    quantities in `numpy.ndarray` objects of the defined types. User created
    frames may provide input data that can be converted to a `numpy.ndarray`.

    See Also:
        `hoomd.State` for a full description of how HOOMD interprets this
        data.

    Attributes:
        N (int): Number of particles in the frame (:chunk:`particles/N`).

        types (tuple[str]):
            Names of the particle types (:chunk:`particles/types`).

        position ((*N*, 3) `numpy.ndarray` of ``numpy.float32``):
            Particle position (:chunk:`particles/position`).

        orientation ((*N*, 4) `numpy.ndarray` of ``numpy.float32``):
            Particle orientation. (:chunk:`particles/orientation`).

        typeid ((*N*, ) `numpy.ndarray` of ``numpy.uint32``):
            Particle type id (:chunk:`particles/typeid`).

        mass ((*N*, ) `numpy.ndarray` of ``numpy.float32``):
            Particle mass (:chunk:`particles/mass`).

        charge ((*N*, ) `numpy.ndarray` of ``numpy.float32``):
            Particle charge (:chunk:`particles/charge`).

        diameter ((*N*, ) `numpy.ndarray` of ``numpy.float32``):
            Particle diameter (:chunk:`particles/diameter`).

        body ((*N*, ) `numpy.ndarray` of ``numpy.int32``):
            Particle body (:chunk:`particles/body`).

        moment_inertia ((*N*, 3) `numpy.ndarray` of ``numpy.float32``):
            Particle moment of inertia (:chunk:`particles/moment_inertia`).

        velocity ((*N*, 3) `numpy.ndarray` of ``numpy.float32``):
            Particle velocity (:chunk:`particles/velocity`).

        angmom ((*N*, 4) `numpy.ndarray` of ``numpy.float32``):
            Particle angular momentum (:chunk:`particles/angmom`).

        image ((*N*, 3) `numpy.ndarray` of ``numpy.int32``):
            Particle image (:chunk:`particles/image`).

        type_shapes (tuple[dict]): Shape specifications for
            visualizing particle types (:chunk:`particles/type_shapes`).
    """
    N::UInt32
    types::Vector{String}
    typeid::Vector{UInt32}
    mass::Vector{Float32}
    charge::Vector{Float32}
    diameter::Vector{Float32}
    body::Vector{Int32}
    moment_inertia::Array{Float32}
    position::Array{Float32}
    orientation::Array{Float32}
    velocity::Array{Float32}
    angmom::Array{Float32}
    image::Array{Int32}
    type_shapes::Vector{Any}### TODO: Fix this type
    ConfigurationData() = new(0, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing)
end

function validate(data::ParticleData)
    """Validate all attributes.

    Convert every array attribute to a `numpy.ndarray` of the proper
    type and check that all attributes have the correct dimensions.

    Ignore any attributes that are ``None``.

    Warning:
        Array attributes that are not contiguous numpy arrays will be
        replaced with contiguous numpy arrays of the appropriate type.
    """
    #logger.debug('Validating ParticleData')

    if !isnothing(data.position) && size(data.position)!=(self.N, 3)
        self.position = reshape(data.position,(self.N, 3))
    end
    if !isnothing(data.orientation) && size(data.orientation)!=(self.N, 4)
        self.orientation = reshape(data.orientation,(self.N, 4))
    end
    ### TODO: These checks should be unnecessary
    #=if !isnothing(data.typeid)
        data.typeid = self.typeid.reshape([self.N])
    end
    if !isnothing(data.mass)
        self.mass = self.mass.reshape([self.N])
    if self.charge is not None:
        self.charge = self.charge.reshape([self.N])
    if self.diameter is not None:
        self.diameter = self.diameter.reshape([self.N])
    if self.body is not None:
        self.body = self.body.reshape([self.N])
    =#

    if !isnothing(data.moment_inertia) && size(data.moment_inertia)!=(self.N, 3)
        data.moment_inertia = reshape(data.moment_inertia, (self.N, 3))
    end
    if !isnothing(data.velocity) && size(data.velocity)!=(self.N, 3)
        data.velocity = reshape(data.velocity, (self.N, 3))
    end
    if !isnothing(data.velocity) && size(data.velocity)!=(self.N, 4)
        data.angmom = reshape(data.angmom, (self.N, 4))
    end
    if !isnothing(data.image) && size(data.image)!=(self.N, 3)
        data.image = reshape(data.image, (self.N, 3))
    end

    if !isnothing(data.types) && (length(Set(data.types))!= length(data.types)) 
        throw(ArgumentError("Type names must be unique in $(typeof(data))."))
    end
    return nothing
end

mutable struct BondData{M<:Tuple} <: StructType
    """Store bond data chunks.

    Use the `Frame.bonds`, `Frame.angles`, `Frame.dihedrals`,
    `Frame.impropers`, and `Frame.pairs` attributes to access the bond
    topology.

    Instances resulting from file read operations will always store array
    quantities in `numpy.ndarray` objects of the defined types. User created
    frames may provide input data that can be converted to a `numpy.ndarray`.

    See Also:
        `hoomd.State` for a full description of how HOOMD interprets this
        data.

    Note:

        *M* varies depending on the type of bond. `BondData` represents all
        types of topology connections.

        ======== ===
        Type     *M*
        ======== ===
        Bond      2
        Angle     3
        Dihedral  4
        Improper  4
        Pair      2
        ======== ===

    Attributes:
        N (int): Number of bonds/angles/dihedrals/impropers/pairs in the
          frame
          (:chunk:`bonds/N`, :chunk:`angles/N`, :chunk:`dihedrals/N`,
          :chunk:`impropers/N`, :chunk:`pairs/N`).

        types (list[str]): Names of the particle types
          (:chunk:`bonds/types`, :chunk:`angles/types`,
          :chunk:`dihedrals/types`, :chunk:`impropers/types`,
          :chunk:`pairs/types`).

        typeid ((*N*,) `numpy.ndarray` of ``numpy.uint32``):
          Bond type id (:chunk:`bonds/typeid`,
          :chunk:`angles/typeid`, :chunk:`dihedrals/typeid`,
          :chunk:`impropers/typeid`, :chunk:`pairs/types`).

        group ((*N*, *M*) `numpy.ndarray` of ``numpy.uint32``):
          Tags of the particles in the bond (:chunk:`bonds/group`,
          :chunk:`angles/group`, :chunk:`dihedrals/group`,
          :chunk:`impropers/group`, :chunk:`pairs/group`).
    """
    N::UInt32
    types::Union{Vector{String}, Nothing}
    typeid::Union{Vector{UInt32},Nothing}
    group::Union{Array{Int32}, Nothing}
    #BondData(M::Integer)= new{(M)}(UInt32(0), nothing, nothing, nothing)
end

function getM(data::BondData{Tuple{M}})
    ### TODO: Simplify!!!
    T = typeof(data) ### this needs to know the information already
    tmp = Meta.parse(String(Symbol(T)))
    return tmp.args[2].args[2]
end

function validate(data::BondData{M})
    """Validate all attributes.

    Convert every array attribute to a `numpy.ndarray` of the proper
    type and check that all attributes have the correct dimensions.

    Ignore any attributes that are ``None``.

    Warning:
        Array attributes that are not contiguous numpy arrays will be
        replaced with contiguous numpy arrays of the appropriate type.
    """
    #logger.debug('Validating BondData')

    ### TODO: Check should be unnecessary
    #if self.typeid is not None:
    #    self.typeid = self.typeid.reshape([self.N])
    
    if !isnothing(data.group) && size(data.group)!=(self.N, getM(data))
        data.group = reshape(data.group, (self.N, getM(data)))
    end
    if !isnothing(data.types) && (length(Set(data.types))!= length(data.types)) 
        throw(ArgumentError("Type names must be unique in $(typeof(data))."))
    end
    return nothing
end


mutable struct ConstraintData <: StructType
    """Store constraint data.

    Use the `Frame.constraints` attribute to access the constraints.

    Instances resulting from file read operations will always store array
    quantities in `numpy.ndarray` objects of the defined types. User created
    frames may provide input data that can be converted to a `numpy.ndarray`.

    See Also:
        `hoomd.State` for a full description of how HOOMD interprets this
        data.

    Attributes:
        N (int): Number of constraints in the frame (:chunk:`constraints/N`).

        value ((*N*, ) `numpy.ndarray` of ``numpy.float32``):
            Constraint length (:chunk:`constraints/value`).

        group ((*N*, *2*) `numpy.ndarray` of ``numpy.uint32``):
            Tags of the particles in the constraint
            (:chunk:`constraints/group`).
    """
    M::UInt32
    N::UInt32
    value::Vector{Float32}
    group::Union{Array{Int32}, Nothing}
    ConstraintData() = new(2,0,0, nothing)
end

function validate(data::ConstraintData)
    """Validate all attributes.

    Convert every array attribute to a `numpy.ndarray` of the proper
    type and check that all attributes have the correct dimensions.

    Ignore any attributes that are ``None``.

    Warning:
        Array attributes that are not contiguous numpy arrays will be
        replaced with contiguous numpy arrays of the appropriate type.
    """
    #logger.debug('Validating ConstraintData')
    # check should be unnecessary
    #if self.value is not None:
    #    self.value = self.value.reshape([self.N])
    if !isnothing(data.group)
        data.group = reshape(data.group, (data.N, data.M))
    end
    return nothing
end


#Union{SubType{StructType}, Nothing} , should remove first Any if possible
# the whole thing should cause type instability....
default_values = Dict{Tuple{String, Any}, Any}(
("step", nothing)=> UInt64(0),
("dimensions", nothing ) => zeros(UInt8, 3),
("box", nothing ) =>  [1f0, 1f0, 1f0, 0f0, 0f0, 0f0], 
("N", nothing ) => UInt32, 
("group", nothing) => zero(Int32), 
("group", BondData{Tuple{2}} ) => zeros(Int32,2), 
("group", BondData{Tuple{3}} ) => zeros(Int32,3), 
("group", BondData{Tuple{4}} ) => zeros(Int32,4), 
("types", ParticleData ) => ["A"], 
("typeid", ParticleData ) => zeros(Float32,1), 
("types", nothing ) => [], 
("typeid", nothing ) => zero(UInt32), 
("mass", nothing ) => one(Float32), 
("charge", nothing ) => zero(Float32), 
("diameter", nothing ) => one(Float32), 
("body", nothing ) => -one(Int32), 
("moment_inertia", nothing ) => zeros(Float32, 3), 
("position", nothing ) =>  zeros(Float32, 3), 
("orientation", nothing ) => [1f0, 0f0, 0f0,0f0], 
("velocity", nothing ) => zeros(Float32, 3), 
("angmom", nothing ) => zeros(Float32, 4), 
("image", nothing ) => zeros(Float32, 3), 
("type_shapes", nothing ) => Vector{Dict{Any, Any}}(), 
("value", nothing ) => zero(Float32) 
)


function get_default(str::String, Struct::S) where {S<:Union{StructType, Nothing}}
    ### getter that gets specialised default before universal default
    return get(default_values, (str, S), default_values[(str, nothing)])
end


default_valid_state = Vector{String}(['hpmc/integrate/d','hpmc/integrate/a','hpmc/sphere/radius','hpmc/sphere/orientable','hpmc/ellipsoid/a','hpmc/ellipsoid/b','hpmc/ellipsoid/c','hpmc/convex_polyhedron/N','hpmc/convex_polyhedron/vertices','hpmc/convex_spheropolyhedron/N','hpmc/convex_spheropolyhedron/vertices','hpmc/convex_spheropolyhedron/sweep_radius','hpmc/convex_polygon/N','hpmc/convex_polygon/vertices','hpmc/convex_spheropolygon/N','hpmc/convex_spheropolygon/vertices','hpmc/convex_spheropolygon/sweep_radius','hpmc/simple_polygon/N','hpmc/simple_polygon/vertices'])

mutable struct Frame
    """System state at one point in time.

    Attributes:
        configuration (`ConfigurationData`): Configuration data.

        particles (`ParticleData`): Particles.

        bonds (`BondData`): Bonds.

        angles (`BondData`): Angles.

        dihedrals (`BondData`): Dihedrals.

        impropers (`BondData`): Impropers.

        pairs (`BondData`): Special pair.

        constraints (`ConstraintData`): Distance constraints.

        state (dict): State data.

        log (dict): Logged data (values must be `numpy.ndarray` or
            `array_like`)
    """
    configuration::ConfigurationData
    particles::ParticleData
    bonds::BondData{Tuple{2}}
    angles::BondData{Tuple{3}}
    dihedrals::BondData{Tuple{4}}
    impropers::BondData{Tuple{4}}
    constraints::ConstraintData
    pairs::BondData{Tuple{2}}
    state::Dict{String, Any}
    log::Dict{String, Any}
    valid_state::Vector{String}
    Frame() = new(ConfigurationData(), ParticleData(), BondDate(2),  BondDate(3),  BondDate(4),  BondDate(4), ConstraintData(), BondData(2), Dict{String, Any}(), Dict{String, Any}(), default_valid_state)
end


function validate(frame::Frame)
        """Validate all contained frame data."""
        #logger.debug('Validating Frame')

        frame.configuration.validate()
        frame.particles.validate()
        frame.bonds.validate()
        frame.angles.validate()
        frame.dihedrals.validate()
        frame.impropers.validate()
        frame.constraints.validate()
        frame.pairs.validate()

        # validate HPMC state
        if !isnothing(frame.particles.types)
            NT = length(self.particles.types)
        else
            NT = 1
        end

        if "hpmc/integrate/d" in keys(frame.state)
            frame.state["hpmc/integrate/d"] = Float64(frame.state["hpmc/integrate/d"])
        end

        if "hpmc/integrate/a" in keys(frame.state)
            frame.state["hpmc/integrate/a"] = Float64(frame.state["hpmc/integrate/a"])
        end

        if "hpmc/sphere/radius" in keys(frame.state)
            frame.state["hpmc/sphere/radius"] = Float32.(frame.state["hpmc/sphere/radius"][:NT])
        end

        if "hpmc/sphere/orientable" in keys(frame.state)
            frame.state["hpmc/sphere/orientable"] = UInt8.(frame.state["hpmc/sphere/orientable"][:NT])
        end

        if "hpmc/ellipsoid/a" in keys(frame.state)
            frame.state["hpmc/ellipsoid/a"] = Float32.(frame.state["hpmc/ellipsoid/a"][:NT])
            frame.state["hpmc/ellipsoid/b"] = Float32.(frame.state["hpmc/ellipsoid/b"][:NT])
            frame.state["hpmc/ellipsoid/c"] = Float32.(frame.state["hpmc/ellipsoid/c"][:NT])
        end

        if "hpmc/convex_polyhedron/N" in keys(frame.state)
            frame.state["hpmc/convex_polyhedron/N"] = UInt32.(frame.state["hpmcconvex_polyhedron/N"][:NT])
            sumN = sum(frame.state["hpmc/convex_polyhedron/N"])
            frame.state["hpmc/convex_polyhedron/vertices"] = reshape(Float32.(frame.state['hpmc/convex_polyhedron/vertices']), (sumN, 3))
        end

        if 'hpmc/convex_spheropolyhedron/N' in self.state:
            self.state['hpmc/convex_spheropolyhedron/N'] = \
                numpy.ascontiguousarray(
                    self.state['hpmc/convex_spheropolyhedron/N'],
                    dtype=numpy.uint32)
            self.state['hpmc/convex_spheropolyhedron/N'] = \
                self.state['hpmc/convex_spheropolyhedron/N'].reshape([NT])
            sumN = numpy.sum(self.state['hpmc/convex_spheropolyhedron/N'])

            self.state['hpmc/convex_spheropolyhedron/sweep_radius'] = \
                numpy.ascontiguousarray(
                    self.state['hpmc/convex_spheropolyhedron/sweep_radius'],
                    dtype=numpy.float32)
            self.state['hpmc/convex_spheropolyhedron/sweep_radius'] = \
                self.state[
                    'hpmc/convex_spheropolyhedron/sweep_radius'].reshape([NT])

            self.state['hpmc/convex_spheropolyhedron/vertices'] = \
                numpy.ascontiguousarray(
                    self.state['hpmc/convex_spheropolyhedron/vertices'],
                    dtype=numpy.float32)
            self.state['hpmc/convex_spheropolyhedron/vertices'] = \
                self.state[
                    'hpmc/convex_spheropolyhedron/vertices'].reshape([sumN, 3])

        if 'hpmc/convex_polygon/N' in self.state:
            self.state['hpmc/convex_polygon/N'] = \
                numpy.ascontiguousarray(self.state['hpmc/convex_polygon/N'],
                                        dtype=numpy.uint32)
            self.state['hpmc/convex_polygon/N'] = \
                self.state['hpmc/convex_polygon/N'].reshape([NT])
            sumN = numpy.sum(self.state['hpmc/convex_polygon/N'])

            self.state['hpmc/convex_polygon/vertices'] = \
                numpy.ascontiguousarray(
                    self.state['hpmc/convex_polygon/vertices'],
                    dtype=numpy.float32)
            self.state['hpmc/convex_polygon/vertices'] = \
                self.state['hpmc/convex_polygon/vertices'].reshape([sumN, 2])

        if 'hpmc/convex_spheropolygon/N' in self.state:
            self.state['hpmc/convex_spheropolygon/N'] = \
                numpy.ascontiguousarray(
                    self.state['hpmc/convex_spheropolygon/N'],
                    dtype=numpy.uint32)
            self.state['hpmc/convex_spheropolygon/N'] = \
                self.state['hpmc/convex_spheropolygon/N'].reshape([NT])
            sumN = numpy.sum(self.state['hpmc/convex_spheropolygon/N'])

            self.state['hpmc/convex_spheropolygon/sweep_radius'] = \
                numpy.ascontiguousarray(
                    self.state['hpmc/convex_spheropolygon/sweep_radius'],
                    dtype=numpy.float32)
            self.state['hpmc/convex_spheropolygon/sweep_radius'] = \
                self.state[
                    'hpmc/convex_spheropolygon/sweep_radius'].reshape([NT])

            self.state['hpmc/convex_spheropolygon/vertices'] = \
                numpy.ascontiguousarray(
                    self.state['hpmc/convex_spheropolygon/vertices'],
                    dtype=numpy.float32)
            self.state['hpmc/convex_spheropolygon/vertices'] = \
                self.state[
                    'hpmc/convex_spheropolygon/vertices'].reshape([sumN, 2])

        if 'hpmc/simple_polygon/N' in self.state:
            self.state['hpmc/simple_polygon/N'] = \
                numpy.ascontiguousarray(self.state['hpmc/simple_polygon/N'],
                                        dtype=numpy.uint32)
            self.state['hpmc/simple_polygon/N'] = \
                self.state['hpmc/simple_polygon/N'].reshape([NT])
            sumN = numpy.sum(self.state['hpmc/simple_polygon/N'])

            self.state['hpmc/simple_polygon/vertices'] = \
                numpy.ascontiguousarray(
                    self.state['hpmc/simple_polygon/vertices'],
                    dtype=numpy.float32)
            self.state['hpmc/simple_polygon/vertices'] = \
                self.state[
                    'hpmc/simple_polygon/vertices'].reshape([sumN, 2])

        for k in self.state:
            if k not in self._valid_state:
                raise RuntimeError('Not a valid state: ' + k)
            end
        end
    end
end