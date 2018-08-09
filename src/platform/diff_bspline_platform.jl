
function bspline_basis(::Type{T}, size::NTuple{N,Int}, degree::NTuple{N,Int}, d::SumDifferentialOperator, dns::NTuple{N,Char}=dimension_names(d)) where N where T
    dicts = tuple(map(x->bspline_basis(T, size, degree, operator(x), dns), SymbolicDifferentialOperators.elements(d))...)
    coefficients = [T(scalar(coefficient(x))) for x in SymbolicDifferentialOperators.elements(d)]
    CompactTranslatesDict.CompactTranslationDictSum(dicts, coefficients)
end

function bspline_basis(::Type{T}, size::NTuple{N,Int}, degree::NTuple{N,Int}, d::PartialDifferentialOperator, dns::NTuple{N,Char}) where {N,T}
    diff = zeros(Int,length(size))
    diff[find(dimension_name(d).==dns)] = SymbolicDifferentialOperators.order(d)
    tensor_product_dict(size, degree, tuple(diff...), T)
end

function bspline_basis(::Type{T}, size::NTuple{N,Int}, degree::NTuple{N,Int}, d::ProductDifferentialOperator, dns::NTuple{N,Char}) where {N,T}
    diff = zeros(Int,length(size))
    for (i,c) in enumerate(dns)
        for (x,v) in SymbolicDifferentialOperators.dictionary(d)
            if c == x
                diff[i] = v
            end
        end
    end
    tensor_product_dict(size, degree, tuple(diff...), T)
end

bspline_basis(::Type{T}, size::NTuple{N,Int}, degree::NTuple{N,Int}, d::IdentityDifferentialOperator, dns::NTuple{N,Char}) where {N,T} =
    tensor_product_dict(size, degree, ntuple(k->0,Val(N)), T)

bspline_evaluation_operator(::Type{T}, size::NTuple{N,Int}, degree::NTuple{N,Int}, grid::ProductGrid, d::SymbolicDifferentialOperators.AbstractDiffOperator, dns::NTuple{N,Char}=dimension_names(d)) where {N,T} =
    evaluation_operator(bspline_basis(T, size, degree, d, dns), grid)


# 1D generators
primal_diff_bspline_generator(::Type{T}, degree::NTuple{N,Int}, d::SumDifferentialOperator, dns::NTuple{N,Char}=dimension_names(d)) where N where T =
    param->bspline_basis(T, tuple(param...), degree, d, dns)

struct DualDiffBSplineGenerator
    primal_generator
    oversampling
    DualDiffBSplineGenerator(primal_generator, oversampling) = (@assert BasisFunctions.isdyadic(oversampling); new(primal_generator, oversampling))
end

function (DG::DualDiffBSplineGenerator)(param)
    B = DG.primal_generator(param)
    DG = DiscreteDualGram(B, oversampling=DG.oversampling)
    OperatedDict(DG)
end

dual_diff_bspline_generator(primal_bspline_generator, oversampling) = DualDiffBSplineGenerator(primal_bspline_generator, oversampling)

# Sampler
diff_bspline_sampler(::Type{T}, primal, oversampling::Int) where {T} = n-> GridSamplingOperator(gridbasis(grid(primal(map(x->oversampling*x, n))),T))

# params
diff_bspline_param(init::NTuple{N,Int}) where N = BasisFunctions.TensorSequence([BasisFunctions.MultiplySequence(i,2 .^(1/length(init))) for i in init])

# Platform
function bspline_platform(::Type{T}, init::NTuple{N,Int}, degree::NTuple{N,Int}, oversampling::Int, d::SymbolicDifferentialOperators.AbstractDiffOperator, dns::NTuple{N,Char}=dimension_names(d)) where {N,T}
	primal = primal_diff_bspline_generator(T, degree, d, dns)
	dual = dual_diff_bspline_generator(primal, oversampling)
    sampler = diff_bspline_sampler(T, primal, oversampling)
    dual_sampler = n->(1/length(dual(n)))*sampler(n)
	params = diff_bspline_param(init)
	BasisFunctions.GenericPlatform(primal = primal, dual = dual, sampler = sampler, dual_sampler=dual_sampler,
		params = params, name = "B-Spline translate on $d")
end