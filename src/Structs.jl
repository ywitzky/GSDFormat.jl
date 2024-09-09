import Base: ==

abstract type StructType end

@inline function ==(A::ST, B::ST)::Bool where {ST<:StructType}
    for field in fieldnames(A)
        if getproperty(A, field)!=getproperty(B, field)
            return false
        end
    end
    return true
end


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
    step::Union{UInt64, Nothing}
    dimensions::Union{UInt8, Nothing}
    box::Union{Vector{Float32}, Nothing}
    ConfigurationData() = new(nothing, nothing, nothing)
end

function get_container_names(data::ConfigurationData)
    return Symbol.(["step", "dimensions", "box"])
end

function set_box!(data::ConfigurationData, Box::Vector{Float32}) 
    if (length(Box)==6)
        data.box .=Box
        if isnothing(data.dimensions)
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
        data.box = numpy.ascontiguousarray(data.box, dtype=numpy.float32)
        data.box = data.box.reshape([6])
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
    types::Union{Vector{String}, Nothing}
    typeid::Union{Vector{UInt32}, Nothing}
    mass::Union{Vector{Float32}, Nothing}
    charge::Union{Vector{Float32}, Nothing}
    diameter::Union{Vector{Float32}, Nothing}
    body::Union{Vector{Int32}, Nothing}
    moment_inertia::Union{Array{Float32}, Nothing}
    position::Union{Array{Float32}, Nothing}
    orientation::Union{Array{Float32}, Nothing}
    velocity::Union{Array{Float32}, Nothing}
    angmom::Union{Array{Float32}, Nothing}
    image::Union{Array{Int32}, Nothing}
    type_shapes::Union{Vector{Any}, Nothing}### TODO: Fix this type
    ParticleData() = new(0, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing, nothing,nothing, nothing)
end

function get_container_names(data::ParticleData)
    return Symbol.(["N", "types", "typeid", "mass", "charge", "diameter", "body", "moment_inertia", "position", "orientation", "velocity", "angmom", "image"])
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

    if !isnothing(data.position) && size(data.position)!=(data.N, 3)
        data.position = reshape(data.position,(data.N, 3))
    end
    if !isnothing(data.orientation) && size(data.orientation)!=(data.N, 4)
        data.orientation = reshape(data.orientation,(data.N, 4))
    end
    ### TODO: These checks should be unnecessary
    #=if !isnothing(data.typeid)
        data.typeid = data.typeid.reshape([data.N])
    end
    if !isnothing(data.mass)
        data.mass = data.mass.reshape([data.N])
    if data.charge is not None:
        data.charge = data.charge.reshape([data.N])
    if data.diameter is not None:
        data.diameter = data.diameter.reshape([data.N])
    if data.body is not None:
        data.body = data.body.reshape([data.N])
    =#

    if !isnothing(data.moment_inertia) && size(data.moment_inertia)!=(data.N, 3)
        data.moment_inertia = reshape(data.moment_inertia, (data.N, 3))
    end
    if !isnothing(data.velocity) && size(data.velocity)!=(data.N, 3)
        data.velocity = reshape(data.velocity, (data.N, 3))
    end
    if !isnothing(data.angmom) && size(data.angmom)!=(data.N, 4)
        data.angmom = reshape(data.angmom, (data.N, 4))
    end
    if !isnothing(data.image) && size(data.image)!=(data.N, 3)
        data.image = reshape(data.image, (data.N, 3))
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
    #BondData(M::Integer)= new{Tuple{M}}(UInt32(0), ["a"], zeros(UInt32, 0),  zeros(UInt32, (0,4)))
    BondData(M::Integer)= new{Tuple{M}}(UInt32(0), nothing, nothing,  nothing)
end

function get_container_names(data::BondData{<:Tuple}) #where {A<:Tuple{<:Integer}}
    return Symbol.(["N", "typeid", "types", "group"])
end

function getM(data::BondData{<:Tuple})# where {M<:Integer}
    ### TODO: Simplify!!!
    T = typeof(data) ### this needs to know the information already
    tmp = Meta.parse(String(Symbol(T)))
    return tmp.args[2].args[2]
end

function validate(data::BondData{<:Tuple})# where {M<:Integer}
    """Validate all attributes.

    Convert every array attribute to a `numpy.ndarray` of the proper
    type and check that all attributes have the correct dimensions.

    Ignore any attributes that are ``None``.

    Warning:
        Array attributes that are not contiguous numpy arrays will be
        replaced with contiguous numpy arrays of the appropriate type.
    """
    #logger.debug('Validating BondData')
    ### not initialised data
    if isnothing(data.types) && isnothing(data.typeid) && isnothing(data.group)
        return nothing
    end
    ### TODO: Check should be unnecessary
    #if data.typeid is not None:
    #    data.typeid = data.typeid.reshape([data.N])

    if !isnothing(data.group) && size(data.group)!=(data.N, getM(data))
        data.group = reshape(data.group, (data.N, getM(data)))
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
    value::Union{Vector{Float32}, Nothing}
    group::Union{Array{Int32}, Nothing}
    ConstraintData() = new(2,0,nothing, nothing)
end

function get_container_names(data::ConstraintData)
    return Symbol.(["value", "group"])
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
    #if data.value is not None:
    #    data.value = data.value.reshape([data.N])
    if !isnothing(data.group)
        data.group = reshape(data.group, (data.N, data.M))
    end
    return nothing
end


#Union{SubType{StructType}, Nothing} , should remove first Any if possible
# the whole thing should cause type instability....
default_values = Dict{Tuple{String, Any}, Any}(
("step", nothing)=> UInt64(0),
("dimensions", nothing ) => zero(UInt8),
("box", nothing ) =>  [1f0, 1f0, 1f0, 0f0, 0f0, 0f0], 
("N", nothing ) => UInt32(0), 
("group", nothing) => zero(Int32), 
("group", BondData{Tuple{2}} ) => zeros(Int32,2), 
("group", BondData{Tuple{3}} ) => zeros(Int32,3), 
("group", BondData{Tuple{4}} ) => zeros(Int32,4), 
("types", ParticleData ) => "A", 
("typeid", ParticleData ) => zero(UInt32), 
("types", nothing ) => "A", 
("typeid", nothing ) => zero(UInt32), 
("mass", nothing ) => one(Float32), 
("charge", nothing ) => zero(Float32), 
("diameter", nothing ) => one(Float32), 
("body", nothing ) => -one(Int32), 
("moment_inertia", nothing ) => zero(Float32), 
("position", nothing ) =>  zero(Float32), 
("orientation", nothing ) => [1f0, 0f0, 0f0,0f0], 
("velocity", nothing ) => zeros(Float32, 3), 
("angmom", nothing ) => zeros(Float32, 4), 
("image", nothing ) => zeros(Float32, 3), 
("type_shapes", nothing ) => Vector{Dict{Any, Any}}(), 
("value", nothing ) => zero(Float32) 
)

function get_default(str::String, Struct::S, N::I) where {S<:Union{ParticleData, BondData, StructType, Nothing}, I<:Integer}
    def_val = get_default(str, Struct) 
    if typeof(def_val)==String 
        return [def_val for i in 1:N]
    elseif ndims(def_val) == 0
        return [def_val for i in 1:N]
    else
        return permutedims(hcat([def_val for i in 1:N]...))
    end
end

function get_default(str::String, Struct::S) where {S<:Union{ParticleData, BondData, StructType, Nothing}}
    ### getter that gets specialised default before universal default
    return get(default_values, (str, S), default_values[(str, nothing)])
end


default_valid_state = Vector{String}(["hpmc/integrate/d","hpmc/integrate/a","hpmc/sphere/radius","hpmc/sphere/orientable","hpmc/ellipsoid/a","hpmc/ellipsoid/b","hpmc/ellipsoid/c","hpmc/convex_polyhedron/N","hpmc/convex_polyhedron/vertices","hpmc/convex_spheropolyhedron/N","hpmc/convex_spheropolyhedron/vertices","hpmc/convex_spheropolyhedron/sweep_radius","hpmc/convex_polygon/N","hpmc/convex_polygon/vertices","hpmc/convex_spheropolygon/N","hpmc/convex_spheropolygon/vertices","hpmc/convex_spheropolygon/sweep_radius","hpmc/simple_polygon/N","hpmc/simple_polygon/vertices"])

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
    Frame() = new(ConfigurationData(), ParticleData(), BondData(2),  BondData(3),  BondData(4),  BondData(4), ConstraintData(), BondData(2), Dict{String, Any}(), Dict{String, Any}(), default_valid_state)
end


function validate(frame::Frame)
    """Validate all contained frame data."""
    #logger.debug('Validating Frame')

    validate(frame.configuration)
    validate(frame.particles)
    validate(frame.bonds)
    validate(frame.angles)
    validate(frame.dihedrals)
    validate(frame.impropers)
    validate(frame.constraints)
    validate(frame.pairs)

    # validate HPMC state
    if !isnothing(frame.particles.types)
        NT = length(frame.particles.types)
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
        frame.state["hpmc/sphere/radius"] = Float32.(frame.state["hpmc/sphere/radius"][1:NT])
    end

    if "hpmc/sphere/orientable" in keys(frame.state)
        frame.state["hpmc/sphere/orientable"] = UInt8.(frame.state["hpmc/sphere/orientable"][1:NT])
    end

    if "hpmc/ellipsoid/a" in keys(frame.state)
        frame.state["hpmc/ellipsoid/a"] = Float32.(frame.state["hpmc/ellipsoid/a"][1:NT])
        frame.state["hpmc/ellipsoid/b"] = Float32.(frame.state["hpmc/ellipsoid/b"][1:NT])
        frame.state["hpmc/ellipsoid/c"] = Float32.(frame.state["hpmc/ellipsoid/c"][1:NT])
    end

    if "hpmc/convex_polyhedron/N" in keys(frame.state)
        frame.state["hpmc/convex_polyhedron/N"] = UInt32.(frame.state["hpmcconvex_polyhedron/N"][1:NT])
        sumN = sum(frame.state["hpmc/convex_polyhedron/N"])
        frame.state["hpmc/convex_polyhedron/vertices"] = reshape(Float32.(frame.state["hpmc/convex_polyhedron/vertices"]), (sumN, 3))
    end

    if "hpmc/convex_spheropolyhedron/N" in keys(frame.state)
        frame.state["hpmc/convex_spheropolyhedron/N"] =  UInt32.(frame.state["hpmc/convex_spheropolyhedron/N"][1:NT])
        sumN = sum(frame.state["hpmc/convex_spheropolyhedron/N"])
        frame.state["hpmc/convex_spheropolyhedron/sweep_radius"] = Float32.(frame.state["hpmc/convex_spheropolyhedron/sweep_radius"][1:NT])
        frame.state["hpmc/convex_spheropolyhedron/vertices"] =reshape(Float32.(frame.state["hpmc/convex_spheropolyhedron/vertices"]), (sumN, 3))
    end

    if "hpmc/convex_polygon/N" in keys(frame.state)
        frame.state["hpmc/convex_polygon/N"] = UInt32.(frame.state["hpmc/convex_polygon/N"][1:NT])
        sumN = sum(frame.state["hpmc/convex_polygon/N"])
        frame.state["hpmc/convex_polygon/vertices"] =reshape(Float32.(frame.state["hpmc/convex_polygon/vertices"]),(sumN, 2))
    end

    if "hpmc/convex_spheropolygon/N" in keys(frame.state)
        frame.state["hpmc/convex_spheropolygon/N"] = UInt32.(frame.state["hpmc/convex_spheropolygon/N"][1:NT])
        sumN = sum(frame.state["hpmc/convex_spheropolygon/N"])
        frame.state["pmc/convex_spheropolygon/sweep_radius"] = Float32.(frame.state["hpmc/convex_spheropolygon/sweep_radius"][1:NT])
        frame.state["hpmc/convex_spheropolygon/vertices"] = reshape(Float32.(frame.state["hpmc/convex_spheropolygon/vertices"]), (sumN, 2))
    end

    if "hpmc/simple_polygon/N" in keys(frame.state)
        frame.state["hpmc/simple_polygon/N"] =UInt32.(frame.state["hpmc/simple_polygon/N"][1:NT])
        sumN = sum(frame.state["hpmc/simple_polygon/N"])
        frame.state["hpmc/simple_polygon/vertices"] = reshape(Float32.(frame.state["hpmc/simple_polygon/vertices"]),(sumN, 2))
    end

    for k in keys(frame.state)
        if !(k in keys(frame.state))
            throw(ArgumentError("Not a valid state: $k"))
        end
    end
end
