"""
    ReMat{T,S} <: AbstractMatrix{T}

A section of a model matrix generated by a random-effects term.

# Fields
- `trm`: the grouping factor as a `StatsModels.CategoricalTerm`
- `refs`: indices into the levels of the grouping factor as a `Vector{Int32}`
- `z`: transpose of the model matrix generated by the left-hand side of the term
- `wtz`: a weighted copy of `z` (`z` and `wtz` are the same object for unweighted cases)
- `λ`: a `LowerTriangular` matrix of size `S×S`
- `inds`: a `Vector{Int}` of linear indices of the potential nonzeros in `λ`
- `adjA`: the adjoint of the matrix as a `SparseMatrixCSC{T}`
"""
mutable struct ReMat{T,S} <: AbstractMatrix{T}
    trm::CategoricalTerm
    refs::Vector{Int32}
    cnames::Vector{String}
    z::Matrix{T}
    wtz::Matrix{T}
    λ::LowerTriangular{T,Matrix{T}}
    inds::Vector{Int}
    adjA::SparseMatrixCSC{T,Int32}
    scratch::Matrix{T}
end

Base.size(A::ReMat) = (length(A.refs), length(A.scratch))

SparseArrays.sparse(A::ReMat) = adjoint(A.adjA)

Base.getindex(A::ReMat, i::Integer, j::Integer) = getindex(A.adjA, j, i)

"""
    nranef(A::ReMat)

Return the number of random effects represented by `A`.  Zero unless `A` is an `ReMat`.
"""
nranef(A::ReMat) = size(A.adjA, 1)

LinearAlgebra.cond(A::ReMat) = cond(A.λ)

"""
    fname(A::ReMat)

Return the name of the grouping factor as a `Symbol`
"""
fname(A::ReMat) = A.trm.sym

getθ(A::ReMat{T}) where {T} = getθ!(Vector{T}(undef, nθ(A)), A)

"""
    getθ!(v::AbstractVector{T}, A::ReMat{T}) where {T}

Overwrite `v` with the elements of the blocks in the lower triangle of `A.Λ` (column-major ordering)
"""
function getθ!(v::AbstractVector{T}, A::ReMat{T}) where {T}
    length(v) == length(A.inds) || throw(DimensionMismatch("length(v) ≠ length(A.inds)"))
    m = A.λ.data
    @inbounds for (j, ind) in enumerate(A.inds)
        v[j] = m[ind]
    end
    v
end

levs(A::ReMat) = A.trm.contrasts.levels

nlevs(A::ReMat) = length(levs(A))

"""
    nθ(A::ReMat)

Return the number of free parameters in the relative covariance matrix λ
"""
nθ(A::ReMat) = length(A.inds)

"""
    lowerbd{T}(A::ReMat{T})

Return the vector of lower bounds on the parameters, `θ` associated with `A`

These are the elements in the lower triangle of `A.λ` in column-major ordering.
Diagonals have a lower bound of `0`.  Off-diagonals have a lower-bound of `-Inf`.
"""
lowerbd(A::ReMat{T}) where {T} =
    T[x ∈ diagind(A.λ.data) ? zero(T) : T(-Inf) for x in A.inds]

"""
    isnested(A::ReMat, B::ReMat)

Is the grouping factor for `A` nested in the grouping factor for `B`?

That is, does each value of `A` occur with just one value of B?
"""
function isnested(A::ReMat, B::ReMat)
    size(A, 1) == size(B, 1) || throw(DimensionMismatch("must have size(A,1) == size(B,1)"))
    bins = zeros(Int32, nlevs(A))
    @inbounds for (a, b) in zip(A.refs, B.refs)
        bba = bins[a]
        if iszero(bba)    # bins[a] not yet set?
            bins[a] = b   # set it
        elseif bba ≠ b    # set to another value?
            return false
        end
    end
    true
end

lmulΛ!(adjA::Adjoint{T,ReMat{T,1}}, B::Matrix{T}) where {T} = lmul!(first(adjA.parent.λ), B)

function lmulΛ!(adjA::Adjoint{T,ReMat{T,1}}, B::SparseMatrixCSC{T}) where {T}
    lmul!(first(adjA.parent.λ), nonzeros(B))
    B
end

function lmulΛ!(adjA::Adjoint{T,ReMat{T,1}}, B::M) where{M<:AbstractMatrix{T}} where {T}
    lmul!(first(adjA.parent.λ), B)
end

function lmulΛ!(adjA::Adjoint{T,ReMat{T,S}}, B::VecOrMat{T}) where {T,S}
    lmul!(adjoint(adjA.parent.λ), reshape(B, S, :))
    B
end

function lmulΛ!(adjA::Adjoint{T,<:ReMat{T,S}}, B::BlockedSparse{T}) where {T,S}
    lmulΛ!(adjA, nonzeros(B.cscmat))
    B
end

function lmulΛ!(adjA::Adjoint{T,<:ReMat{T,S}}, B::SparseMatrixCSC{T}) where {T,S}
    lmulΛ!(adjA, nonzeros(B))
    B
end

LinearAlgebra.Matrix(A::ReMat) = Matrix(sparse(A))

function LinearAlgebra.mul!(C::Diagonal{T}, adjA::Adjoint{T,<:ReMat{T,1}},
        B::ReMat{T,1}) where {T}
    A = adjA.parent
    @assert A === B
    d = C.diag
    fill!(d, zero(T))
    @inbounds for (ri, Azi) in zip(A.refs, A.wtz)
        d[ri] += abs2(Azi)
    end
    C
end

function *(adjA::Adjoint{T,<:ReMat{T,1}}, B::ReMat{T,1}) where {T}
    A = adjA.parent
    A === B ? mul!(Diagonal(Vector{T}(undef, size(B, 2))), adjA, B) :
    sparse(Int32.(A.refs), Int32.(B.refs), vec(A.wtz .* B.wtz))
end

*(adjA::Adjoint{T,<:ReMat{T}}, B::ReMat{T}) where {T} = adjA.parent.adjA * sparse(B)
*(adjA::Adjoint{T,<:FeMat{T}}, B::ReMat{T}) where {T} =
    mul!(Matrix{T}(undef, rank(adjA.parent), size(B, 2)), adjA, B)

LinearAlgebra.mul!(C::AbstractMatrix{T}, adjA::Adjoint{T,<:FeMat{T}},
        B::ReMat{T}) where {T} = mulαβ!(C, adjA, B)

function mulαβ!(C::Matrix{T}, adjA::Adjoint{T,<:FeMat{T}}, B::ReMat{T,1},
        α=true, β=false) where {T}
    A = adjA.parent
    Awt = A.wtx
    n, p = size(Awt)
    r = A.rank
    m, q = size(B)
    size(C) == (r, q) && m == n || throw(DimensionMismatch(""))
    isone(β) || rmul!(C, β)
    zz = B.wtz
    @inbounds for (j, rrj) in enumerate(B.refs)
        αzj = α * zz[j]
        for i in 1:r
            C[i, rrj] += αzj * Awt[j, i]
        end
    end
    C
end

function mulαβ!(C::Matrix{T}, adjA::Adjoint{T,<:FeMat{T}},
        B::ReMat{T,S}, α=true, β=false) where {T,S}
    A = adjA.parent
    Awt = A.wtx
    r = rank(A)
    rr = B.refs
    scr = B.scratch
    vscr = vec(scr)
    Bwt = B.wtz
    n = length(rr)
    q = length(scr)
    size(C) == (r, q) && size(Awt, 1) == n || throw(DimensionMismatch(""))
    isone(β) || rmul!(C, β)
    @inbounds for i in 1:r
        fill!(scr, 0)
        for k in 1:n
            aki = α * Awt[k,i]
            kk = Int(rr[k])
            for ii in 1:S
                scr[ii, kk] += aki * Bwt[ii, k]
            end
        end
        for j in 1:q
            C[i, j] += vscr[j]
        end
    end
    C
end

function LinearAlgebra.mul!(C::SparseMatrixCSC{T}, adjA::Adjoint{T,<:ReMat{T,1}},
        B::ReMat{T,1}) where {T}
    A = adjA.parent
    m, n = size(B)
    size(C, 1) == size(A, 2) && n == size(C, 2) && size(A, 1) == m || throw(DimensionMismatch)
    Ar = A.refs
    Br = B.refs
    Az = A.wtz
    Bz = B.wtz
    nz = nonzeros(C)
    rv = rowvals(C)
    fill!(nz, zero(T))
    for k in 1:m       # iterate over rows of A and B
        i = Ar[k]      # [i,j] are Cartesian indices in C - find and verify corresponding position K in rv and nz
        j = Br[k]
        coljlast = Int(C.colptr[j + 1] - 1)
        K = searchsortedfirst(rv, i, Int(C.colptr[j]), coljlast, Base.Order.Forward)
        if K ≤ coljlast && rv[K] == i
            nz[K] += Az[k] * Bz[k]
        else
            throw(ArgumentError("C does not have the nonzero pattern of A'B"))
        end
    end
    C
end

function LinearAlgebra.mul!(C::UniformBlockDiagonal{T}, adjA::Adjoint{T,ReMat{T,S}},
        B::ReMat{T,S}) where {T,S}
    A = adjA.parent
    @assert A === B
    Cd = C.data
    size(Cd) == (S, S, nlevs(B)) || throw(DimensionMismatch(""))
    fill!(Cd, zero(T))
    Awtz = A.wtz
    for (j, r) in enumerate(A.refs)
        @inbounds for i in 1:S
            zij = Awtz[i,j]
            for k in 1:S
                Cd[k, i, r] += zij * Awtz[k,j]
            end
        end
    end
    C
end

function LinearAlgebra.mul!(C::Matrix{T}, adjA::Adjoint{T,ReMat{T,S}},
        B::ReMat{T,P}) where {T,S,P}
    A = adjA.parent
    m, n = size(A)
    p, q = size(B)
    m == p && size(C, 1) == n && size(C, 2) == q || throw(DimensionMismatch(""))
    fill!(C, zero(T))

    Ar = A.refs
    Br = B.refs
    if isone(S) && isone(P)
        for (ar, az, br, bz) in zip(Ar, vec(A.wtz), Br, vec(B.wtz))
            C[ar, br] += az * bz
        end
        return C
    end
    ab = S * P
    Az = A.wtz
    Bz = B.wtz
    for i in 1:m
        Ari = Ar[i]
        Bri = Br[i]
        ioffset = (Ari - 1) * S
        joffset = (Bri - 1) * P
        for jj in 1:P
            jjo = jj + joffset
            Bzijj = Bz[jj, i]
            for ii in 1:S
                C[ii + ioffset, jjo] += Az[ii, i] * Bzijj
            end
        end
    end
    C
end

function *(adjA::Adjoint{T,<:ReMat{T,S}}, B::ReMat{T,P}) where {T,S,P}
    A = adjA.parent
    if A === B
        return mul!(UniformBlockDiagonal(Array{T}(undef, S, S, nlevs(A))), adjA, A)
    end
    cscmat = A.adjA * adjoint(B.adjA)
    if nnz(cscmat) > *(0.25, size(cscmat)...)
        return Matrix(cscmat)
    end

    BlockedSparse{T,S,P}(cscmat, reshape(cscmat.nzval, S, :),
        cscmat.colptr[1:P:(cscmat.n + 1)])
end

function reweight!(A::ReMat, sqrtwts::Vector)
    if length(sqrtwts) > 0
        if A.z === A.wtz
            A.wtz = similar(A.z)
        end
        rmul!(copyto!(A.wtz, A.z), Diagonal(sqrtwts))
    end
    A
end

rmulΛ!(A::M, B::ReMat{T,1}) where{M<:AbstractMatrix{T}} where{T} = rmul!(A, first(B.λ))

function rmulΛ!(A::M, B::ReMat{T,S}) where{M<:AbstractMatrix{T}} where{T,S}
    m, n = size(A)
    q, r = divrem(n, S)
    iszero(r) || throw(DimensionMismatch("size(A, 2) = is not a multiple of block size"))
    A3 = reshape(A, (m, S, q))
    for k in 1:q
        rmul!(view(A3, :, :, k), B.λ)
    end
    A
end

function rmulΛ!(A::BlockedSparse{T,S,P}, B::ReMat{T,P}) where {T,S,P}
    cbpt = A.colblkptr
    csc = A.cscmat
    nzv = csc.nzval
    for j in 1:div(csc.n, P)
        rmul!(reshape(view(nzv, cbpt[j]:(cbpt[j + 1] - 1)), :, P), B.λ)
    end
    A
end

rowlengths(A::ReMat{T,1}) where {T} = vec(abs.(A.λ.data))

function rowlengths(A::ReMat)
    ld = A.λ.data
    [norm(view(ld, i, 1:i)) for i in 1:size(ld, 1)]
end

"""
    scaleinflate!(L::AbstractMatrix, Λ::ReMat)

Overwrite L with `Λ'LΛ + I`
"""
function scaleinflate! end

function scaleinflate!(Ljj::Diagonal{T}, Λj::ReMat{T,1}) where {T}
    Ljjd = Ljj.diag
    broadcast!((x, λsqr) -> x * λsqr + 1, Ljjd, Ljjd, abs2(first(Λj.λ)))
    Ljj
end

function scaleinflate!(Ljj::Matrix{T}, Λj::ReMat{T,1}) where {T}
    lambsq = abs2(first(Λj.λ))
    @inbounds for i in diagind(Ljj)
        Ljj[i] *= lambsq
        Ljj[i] += one(T)
    end
    Ljj
end

function scaleinflate!(Ljj::UniformBlockDiagonal{T}, Λj::ReMat{T}) where {T}
    Ljjdd = Ljj.data
    m, n, l = size(Ljjdd)
    λ = Λj.λ
    Lfv = Ljj.facevec
    @inbounds for Lf in Lfv
        lmul!(adjoint(λ), rmul!(Lf, λ))
    end
    @inbounds for k in 1:l, i in 1:m
        Ljjdd[i, i, k] += one(T)
    end
    Ljj
end

function scaleinflate!(Ljj::Matrix{T}, Λj::ReMat{T,S}) where{T,S}
    n = LinearAlgebra.checksquare(Ljj)
    q, r = divrem(n, S)
    iszero(r) || throw(DimensionMismatch("size(Ljj, 1) is not a multiple of S"))
    λ = Λj.λ
    offset = 0
    @inbounds for k in 1:q
        inds = (offset + 1):(offset + S)
        tmp = view(Ljj, inds, inds)
        lmul!(adjoint(λ), rmul!(tmp, λ))
        offset += S
    end
    for k in diagind(Ljj)
        Ljj[k] += 1
    end
    Ljj
end

function setθ!(A::ReMat{T}, v::AbstractVector{T}) where {T}
    A.λ.data[A.inds] = v
    A
end

σs(A::ReMat{T,1}, sc::T) where {T} =
    NamedTuple{(Symbol(first(A.cnames)),)}(sc*abs(first(A.λ.data)),)

function σs(A::ReMat{T}, sc::T) where {T}
    λ = A.λ.data
    NamedTuple{(Symbol.(A.cnames)...,)}(ntuple(i -> sc*norm(view(λ,i,1:i)), size(λ, 1)))
end

function σρs(A::ReMat{T,1}, sc::T) where {T}
    NamedTuple{(:σ,)}((NamedTuple{(Symbol(first(A.cnames)),)}((sc*abs(first(A.λ.data)),)),))
end

function ρ(i, λ::AbstractMatrix{T}, k, σs::NamedTuple, sc::T)::T where {T}
    row, col = indpairs(k)[i]
    (dot(view(λ,row,:), view(λ,col,:)) * abs2(sc)) / (σs[row] * σs[col])
end

function σρs(A::ReMat{T}, sc::T) where {T}
    λ = A.λ.data
    k = size(λ, 1)
    σs = NamedTuple{(Symbol.(A.cnames)...,)}(ntuple(i -> sc*norm(view(λ,i,1:i)), k))
    NamedTuple{(:σ,:ρ)}((σs, ntuple(i -> ρ(i,λ,k,σs,sc), (k * (k - 1)) >> 1)))
end

vsize(A::ReMat{T,S}) where {T,S} = S

function zerocorr!(A::ReMat{T}) where {T}
    λ = A.λ
    A.inds = intersect(A.inds, diagind(λ))
    fill!(λ.data, 0)
    for i in A.inds
        λ.data[i] = 1
    end
    A
end
