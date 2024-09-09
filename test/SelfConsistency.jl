using GSDFormat, Test

### test (nearly) empty file once
traj = GSDFormat.open("./tmp/test.gsd","w")
frame = GSDFormat.Frame()
frame.configuration.dimensions=3
GSDFormat.append(traj, frame)
close(traj)

traj_test = GSDFormat.open("./tmp/test.gsd","r")
test_frame = traj_test[1]

@testset "Empty GSD File" begin
### compare frame data in ram memory to the frame data written on the hard drive
for container in ["particles","bonds","angles","dihedrals","impropers","constraints","pairs"]
    @testset "$container" begin 
        frame_container = getproperty(frame, Symbol(container))
        test_container = getproperty(test_frame, Symbol(container))

        for name in GSDFormat.get_container_names(test_container)
            @namedtest "$name" name==:N ?  getproperty(test_container,name) == GSDFormat.get_default(String(name), frame_container ) : getproperty(test_container,name) == GSDFormat.get_default(String(name), frame_container,1 ) #getproperty(frame_container, name) 
        end
    end
end
end
close(traj_test)



### create 1 chains with multiple different types
N = 48
L = 200

    
mkpath("./tmp/")


traj = GSDFormat.open("./tmp/test.gsd","w")



frame = GSDFormat.Frame()

### init Configuration Data
frame.configuration.step = 1
frame.configuration.dimensions = 3
frame.configuration.box = [L, L, L, 0, 0, 0]

### init Particle Data
frame.particles.N=N
frame.particles.types = vcat([String(UInt8.([i+64])) for i in 1:N/2],[String(UInt8.([i+96])) for i in 1:N/2])
frame.particles.typeid = collect(1:N)
frame.particles.mass = collect(N:-1:1)
frame.particles.charge = rand(N)
frame.particles.diameter = rand(N)
frame.particles.body = ones(Int32, N)
frame.particles.moment_inertia = rand(N,3)
frame.particles.position = rand(N,3)
frame.particles.orientation = rand(N,4)
frame.particles.velocity = rand(N,3)
frame.particles.angmom = rand(N,4)
frame.particles.image = rand((-1,0,0), N,3)
#frame.particles.type_shapes = rand((0,1), (N))

### init bonds
frame.bonds.N = N-1
frame.bonds.types = ["ABC"]
frame.bonds.typeid = ones(N-1)
frame.bonds.group = [i-j for j in 0:1,  i in 2:N]

### init angles 
frame.angles.N = N-2
frame.angles.types = ["A"]
frame.angles.typeid = ones(N-2)
frame.angles.group = [i-j for j in 0:2, i in 3:N]

### init dihedrals 
frame.dihedrals.N = N-3
frame.dihedrals.types = ["A"]
frame.dihedrals.typeid = ones(N-3)
frame.dihedrals.group = [i-j for j in 0:3, i in 4:N]

### init impropers 
frame.impropers.N = N-3
frame.impropers.types = ["B"]
frame.impropers.typeid = ones(N-3)
frame.impropers.group = [i-j for j in 0:3, i in 4:N]

### constraints on first 3 beads
frame.constraints.N=3
frame.constraints.value= ones(3)
frame.constraints.group = [i-j for j in 0:1, i in 2:4]

### init pairs
frame.pairs.N = 3
frame.pairs.types = ["A"]
frame.pairs.typeid = ones(3)
frame.pairs.group = [i-j for j in 0:1, i in N-2:N]



GSDFormat.append(traj, frame)
close(traj)



traj_test = GSDFormat.open("./tmp/test.gsd","r")
test_frame = traj_test[1]

@testset "Written on Harddrive" begin
### compare frame data in ram memory to the frame data written on the hard drive
for container in ["particles","bonds","angles","dihedrals","impropers","constraints","pairs"]
    @testset "$container" begin 
        frame_container = getproperty(frame, Symbol(container))
        test_container = getproperty(test_frame, Symbol(container))

            for name in GSDFormat.get_container_names(test_container)
                @namedtest "$name"  getproperty(test_container,name) == getproperty(frame_container, name) 
            end
    end
end
end

close(traj_test)
