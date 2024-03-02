include("./HOOMDTrajectory.jl")

file = "/localscratch/test.gsd"

gsdfileobj = GSD.open(file)

println(gsdfileobj[1].particles.position)

