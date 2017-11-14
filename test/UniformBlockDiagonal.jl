using Base.Test, DataArrays, RData, MixedModels

if !isdefined(:dat) || !isa(dat, Dict{Symbol, Any})
    dat = convert(Dict{Symbol,Any}, load(joinpath(dirname(@__FILE__), "dat.rda")))
end

@testset "UBlk" begin
    ex22 = UniformBlockDiagonal(reshape(Vector(1.0:12.0), (2, 2, 3)))
    Lblk = UniformBlockDiagonal(fill(0., (2,2,3)))
    vf1 = VectorFactorReTerm(PooledDataArray(repeat(1:3, inner=2)),
        hcat(ones(6), repeat([-1.0, 1.0], inner=3))', :G, ["(Intercept)", "U"], [2])

    @testset "size" begin
        @test size(ex22) == (6, 6)
        @test size(ex22, 1) == 6
        @test size(ex22, 2) == 6
        @test size(ex22.data) == (2, 2, 3)
        @test length(ex22.facevec) == 3
    end

    @testset "elements" begin
        @test ex22[1, 1] == 1
        @test ex22[2, 1] == 2
        @test ex22[3, 1] == 0
        @test ex22[2, 2] == 4
        @test ex22[3, 3] == 5
        @test ex22[:, 3] == [0,0,5,6,0,0]
        @test ex22[5, 6] == 11
    end

    @testset "facevec" begin
        @test ex22.facevec[3] == reshape(9:12, (2,2))
    end

    @testset "scaleInflate" begin
        MixedModels.scaleInflate!(Lblk, ex22, vf1)
        @test Lblk.facevec[1] == [2. 3.; 2. 5.]
        setθ!(vf1, [1.,1.,1.])
        Λ = vf1.Λ
        MixedModels.scaleInflate!(Lblk, ex22, vf1)
        target = Λ'ex22.facevec[1]*Λ + I
        @test Lblk.facevec[1] == target
        @test MixedModels.scaleInflate!(full(Lblk), ex22, vf1)[1:2, 1:2] == target
    end
end
