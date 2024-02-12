using CBinding, Libdl, Debugger#, Libc,
import Base: unsafe_convert, open
using Base.Threads

#unsafe_convert(::Type{Cptr{Nothing}}, _::Int64) =Cptr{Nothing}() ### assumption that this doesnt cause issues


include("./gsd.jl")

file = "/localscratch/shortdumps.gsd"

file="/localscratch/HPS_DATA/HPS-Alpha/HOOMD/ChargeTest/WithCharge/traj.gsd"
file="/localscratch/HPS_DATA/Debug/HOOMD_Restart_From_LAMMPS/RestartInHOOMD3_WithoutAngles/traj.gsd"
#@run begin
gsdfileobj = open_gsd(file)

N = libgsd.gsd_get_nframes(gsdfileobj.gsd_handle)

#data = read_chunk(gsdfileobj, 0, "configuration/step")
#println(data)

#=
@time for i in 0:999
    #data_ = read_chunk(gsdfileobj, i, "particles/image")
    if chunk_exists(gsdfileobj, i, "particles/image")
        data_ = read_chunk(gsdfileobj, i, "configuration/dimensions")
        println(" $i $(data_)")
    end
    #println(" $i $(data_[27400-10:end,:]) ")
end
=#
println("open: $(gsdfileobj.is_open)")
vals = find_matching_chunk_names(gsdfileobj,"configuration/dimensions")
println(vals)


