@kwdef mutable struct Features
	pairs::Vector{Pair{String, String}} = Pair{String, String}[]
end

Base.getindex(f::Features, key::AbstractString) = begin
	for (k, v) in f.pairs
		k == key && return v
	end
	throw(KeyError(key))
end

Base.setindex!(f::Features, value::AbstractString, key::AbstractString) = begin
	for (i, (k, _)) in enumerate(f.pairs)
		if k == key
			f.pairs[i] = String(key) => String(value)
			return value
		end
	end
	push!(f.pairs, String(key) => String(value))
	value
end

Base.get(f::Features, key::AbstractString, default) = begin
	for (k, v) in f.pairs
		k == key && return v
	end
	default
end

Base.haskey(f::Features, key::AbstractString) = any(k == key for (k, _) in f.pairs)
Base.delete!(f::Features, key::AbstractString) = (filter!(p -> first(p) != key, f.pairs); f)
Base.keys(f::Features) = first.(f.pairs)
Base.values(f::Features) = last.(f.pairs)
Base.isempty(f::Features) = isempty(f.pairs)
Base.length(f::Features) = length(f.pairs)
Base.iterate(f::Features, state...) = iterate(f.pairs, state...)

function Base.:(==)(a::Features, b::Features)
	length(a) != length(b) && return false
	for (pa, pb) in zip(a.pairs, b.pairs)
		pa != pb && return false
	end
	true
end

function Base.show(io::IO, f::Features)
	if isempty(f)
		print(io, "_")
	else
		join(io, ("$k=$v" for (k, v) in f.pairs), '|')
	end
end

function Base.parse(::Type{Features}, raw::AbstractString)::Features
	raw == "_" && return Features()
	pairs = Pair{String, String}[]
	for item in split(raw, '|')
		key, value = split(item, '='; limit = 2)
		push!(pairs, String(key) => String(value))
	end
	Features(pairs)
end


@kwdef struct EnhancedDep
	head::Int
	deprel::String
end

@kwdef mutable struct EnhancedDeps
	deps::Vector{EnhancedDep} = EnhancedDep[]
end

Base.isempty(e::EnhancedDeps) = isempty(e.deps)
Base.length(e::EnhancedDeps) = length(e.deps)
Base.iterate(e::EnhancedDeps, state...) = iterate(e.deps, state...)

function Base.:(==)(a::EnhancedDeps, b::EnhancedDeps)
	a.deps == b.deps
end

function Base.show(io::IO, e::EnhancedDeps)
	if isempty(e)
		print(io, "_")
	else
		join(io, ("$(d.head):$(d.deprel)" for d in e.deps), '|')
	end
end

function Base.parse(::Type{EnhancedDeps}, raw::AbstractString)::EnhancedDeps
	raw == "_" && return EnhancedDeps()
	deps = EnhancedDep[]
	for item in split(raw, '|')
		head_str, deprel = split(item, ':'; limit = 2)
		push!(deps, EnhancedDep(parse(Int, head_str), String(deprel)))
	end
	EnhancedDeps(deps)
end


abstract type AbstractNode end

@kwdef mutable struct WordNode <: AbstractNode
	id::Int
	form::String
	lemma::String = "_"
	upos::String = "_"
	xpos::String = "_"
	feats::Features = Features()
	head::Int = 0
	deprel::String = "_"
	deps::EnhancedDeps = EnhancedDeps()
	misc::Features = Features()
end

@kwdef mutable struct MultiwordNode <: AbstractNode
	first::Int
	last::Int
	form::String
	misc::Features = Features()
end

@kwdef mutable struct EmptyNode <: AbstractNode
	major::Int
	minor::Int
	form::String
	lemma::String = "_"
	upos::String = "_"
	xpos::String = "_"
	feats::Features = Features()
	deps::EnhancedDeps = EnhancedDeps()
	misc::Features = Features()
end


@kwdef mutable struct Sentence <: AbstractVector{WordNode}
	words::Vector{WordNode} = WordNode[]
	multiwords::Vector{MultiwordNode} = MultiwordNode[]
	empties::Vector{EmptyNode} = EmptyNode[]
	comments::Vector{String} = String[]
end

Base.size(s::Sentence) = size(s.words)
Base.getindex(s::Sentence, i::Int) = s.words[i]
Base.getindex(s::Sentence, r) = s.words[r]
Base.setindex!(s::Sentence, w::WordNode, i::Int) = (s.words[i] = w)
Base.IndexStyle(::Type{Sentence}) = IndexLinear()


struct Treebank <: AbstractVector{Sentence}
	sentences::Vector{Sentence}
end

Treebank() = Treebank(Sentence[])

Base.size(tb::Treebank) = size(tb.sentences)
Base.getindex(tb::Treebank, i::Int) = tb.sentences[i]
Base.getindex(tb::Treebank, r::AbstractVector) = Treebank(tb.sentences[r])
Base.getindex(tb::Treebank, r::UnitRange) = Treebank(tb.sentences[r])
Base.setindex!(tb::Treebank, s::Sentence, i::Int) = (tb.sentences[i] = s)
Base.push!(tb::Treebank, s::Sentence) = (push!(tb.sentences, s); tb)
Base.IndexStyle(::Type{Treebank}) = IndexLinear()
