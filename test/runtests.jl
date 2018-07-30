using CompactTranslatesDict

types = [Float64, BigFloat]


include("test_banded_operators.jl")

include("test_bsplinetranslatedbasis.jl")

for T in types
    @testset "$(rpad("Translates of B spline expansions",80))" begin
        test_generic_periodicbsplinebasis(BSplineTranslatesBasis, T)
        test_translatedbsplines(T)
        test_bspline_platform(T)
        # test_sparsity_speed(T)
    end
end
