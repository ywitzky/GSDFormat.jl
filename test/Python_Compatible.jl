using GSDFormat: libgsd

filename= "$(pwd())/python_output.gsd"


file = GSDFormat.open(filename, "r")

frame = file[1]

N=16

@testset "Python Compatible" begin
    @testset "Particles" begin
        @namedtest "N" frame.particles.N == N
        @namedtest "types" frame.particles.types==["octahedron"]
        @namedtest "mass" frame.particles.mass==[123.5 for i in 1:N]
        @namedtest "charge" frame.particles.charge==[-1.0 for i in 1:N]
        @namedtest "diameter" frame.particles.diameter==[5.0 for i in 1:N]
        @namedtest "body" frame.particles.body==[3.0 for i in 1:N]

        @namedtest "angmom" frame.particles.angmom== [6.0+j for i in 1:N, j in 1:4]

        @namedtest "position" frame.particles.position == Float32[-1.5 -1.5 -1.5; -1.5 -1.5 -0.5; -1.5 -1.5 0.5; -1.5 -0.5 -1.5; -1.5 -0.5 -0.5; -1.5 -0.5 0.5; -1.5 0.5 -1.5; -1.5 0.5 -0.5; -1.5 0.5 0.5; -0.5 -1.5 -1.5; -0.5 -1.5 -0.5; -0.5 -1.5 0.5; -0.5 -0.5 -1.5; -0.5 -0.5 -0.5; -0.5 -0.5 0.5; -0.5 0.5 -1.5]

        @namedtest "image" frame.particles.image == Int32[ Int32(j==3) for i in 1:N, j in 1:3]

        @namedtest "velocity" frame.particles.velocity== [3.0+j for   i in 1:N, j in 1:3]
        @namedtest "moment inertia" frame.particles.moment_inertia== [Float32(j) for   i in 1:N, j in 1:3]

        ### the next one is chosen such that they are the default values which are not written on the Harddrive
        @namedtest "orientation" frame.particles.orientation == Int32[ Int32(j==1) for i in 1:N, j in 1:4] 
    end

    @testset "Bonds" begin
        @namedtest "N"      frame.bonds.N == 2
        @namedtest "typeid" frame.bonds.typeid == [0,1]
        @namedtest "types"  frame.bonds.types  == ["typea","typeb"]
        @namedtest "group"  frame.bonds.group  == [0 1; 1 2]
    end

    @testset "Angles" begin
        @namedtest "N"      frame.angles.N == 3
        @namedtest "typeid" frame.angles.typeid == [0,1,2]
        @namedtest "types"  frame.angles.types  == ["bond_a","bond_b","bond_c"]
        @namedtest "group"  frame.angles.group  == [0 1 2; 1 2 3; 2 3 4]
    end

    @testset "Dihedrals" begin
        @namedtest "N"      frame.dihedrals.N == 4
        @namedtest "typeid" frame.dihedrals.typeid == [0,1,2,3]
        @namedtest "types"  frame.dihedrals.types  == ["dih_a","dih_b","dih_c", "dih_d"]
        @namedtest "group"  frame.dihedrals.group  == [0 1 2 3; 1 2 3 4; 2 3 4 5; 3 4 5 6]
    end
end


frame = file[2]

### test whether unchanged values will be read correctly
@testset "Python Compatible 2nd Frame" begin
    @testset "Particles" begin
        @namedtest "N" frame.particles.N == N
        @namedtest "types" frame.particles.types==["my_new_name"]
        @namedtest "mass" frame.particles.mass==[321.5 for i in 1:N]
        @namedtest "charge" frame.particles.charge==[-1.0 for i in 1:N]
        @namedtest "diameter" frame.particles.diameter==[5.0 for i in 1:N]
        @namedtest "body" frame.particles.body==[3.0 for i in 1:N]

        @namedtest "angmom" frame.particles.angmom== [6.0+j for i in 1:N, j in 1:4]

        @namedtest "position" frame.particles.position == Float32[-1.5 -1.5 -1.5; -1.5 -1.5 -0.5; -1.5 -1.5 0.5; -1.5 -0.5 -1.5; -1.5 -0.5 -0.5; -1.5 -0.5 0.5; -1.5 0.5 -1.5; -1.5 0.5 -0.5; -1.5 0.5 0.5; -0.5 -1.5 -1.5; -0.5 -1.5 -0.5; -0.5 -1.5 0.5; -0.5 -0.5 -1.5; -0.5 -0.5 -0.5; -0.5 -0.5 0.5; -0.5 0.5 -1.5]

        ### now default value in second file
        @namedtest "image" frame.particles.image == Int32[ 0 for i in 1:N, j in 1:3]


        @namedtest "velocity" frame.particles.velocity== [3.0+j for   i in 1:N, j in 1:3]
        @namedtest "moment inertia" frame.particles.moment_inertia== [Float32(j) for   i in 1:N, j in 1:3]

        ### the next one is chosen such that they are the default values which are not written on the Harddrive
        @namedtest "orientation" frame.particles.orientation == Int32[ Int32(j==1)+Int32(j==4) for i in 1:N, j in 1:4] 
    end

    @testset "Bonds" begin
        @namedtest "N"      frame.bonds.N == 2
        @namedtest "typeid" frame.bonds.typeid == [0,1]
        @namedtest "types"  frame.bonds.types == ["typea","typeb"]
        @namedtest "group"  frame.bonds.group == [0 1; 1 2]
    end


    @testset "Angles" begin
        @namedtest "N"      frame.angles.N == 3
        @namedtest "typeid" frame.angles.typeid == [0,1,2]
        @namedtest "types"  frame.angles.types  == ["bond_a","bond_b","bond_c"]
        @namedtest "group"  frame.angles.group  == [0 1 2; 1 2 3; 2 3 4]
    end

    @testset "Dihedrals" begin
        @namedtest "N"      frame.dihedrals.N == 4
        @namedtest "typeid" frame.dihedrals.typeid == [0,1,2,3]
        @namedtest "types"  frame.dihedrals.types  == ["dih_a","dih_b","dih_c", "dih_d"]
        @namedtest "group"  frame.dihedrals.group  == [0 1 2 3; 1 2 3 4; 2 3 4 5; 3 4 5 6]
    end
end
