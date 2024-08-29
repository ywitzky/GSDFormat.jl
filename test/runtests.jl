
using GSDFormat, Aqua, Test,CBinding

using Base: unsafe_convert
@testset "Aqua" begin
    Aqua.test_all(GSDFormat; ambiguities=(exclude=[CBinding.Ptr], broken=true)) ### ambiguitiy of unsafe_convert(::Type{Ptr{CBinding.Cptr{T1}}}, x::Ref{Ptr{T2}}) where {T1, T2} is known
end

