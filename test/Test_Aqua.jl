using GSDFormat
using Aqua

#include("../src/GSDFormat.jl")


@testset "Aqua.jl" begin
    Aqua.test_all(GSDFormat; ambiguities=false) ### pointer conversion is ambiguous
end