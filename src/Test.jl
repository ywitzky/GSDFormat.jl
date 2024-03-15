include("./HOOMDTrajectory.jl")

file = "/localscratch/traj.gsd"

traj = GSD.open(file)

println(size(traj))

for (i,frame) in enumerate(traj)
    println("$i, $(frame.particles.position[1,1])")
end

println("asdfg")
println(GSD.isdone(traj, 12))
println(Base.isdone(traj, 13))