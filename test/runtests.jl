
using GSDFormat, Aqua, Test,CBinding

macro namedtest(name, test)
    esc(:(@testset $name begin @test $test end))
end


using Base: unsafe_convert
@testset "Aqua" begin
    Aqua.test_all(GSDFormat; ambiguities=(exclude=[CBinding.Ptr], broken=true)) ### ambiguitiy of unsafe_convert(::Type{Ptr{CBinding.Cptr{T1}}}, x::Ref{Ptr{T2}}) where {T1, T2} is known
end


include("./SelfConsistency.jl")
include("./Python_Compatible.jl")
