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
		sorted = sort(f.pairs; by = first)
		join(io, ("$k=$v" for (k, v) in sorted), '|')
	end
end

function Base.parse(::Type{Features}, raw::AbstractString)::Features
	(raw == "_" || isempty(strip(raw))) && return Features()
	pairs = Pair{String, String}[]
	for item in split(raw, '|')
		item = strip(item)
		isempty(item) && continue
		parts = split(item, '='; limit = 2)
		if length(parts) == 2
			push!(pairs, String(parts[1]) => String(parts[2]))
		else
			@warn "skipping malformed feature (no '=' found)" item
		end
	end
	Features(pairs)
end


@kwdef struct NodeRef
	major::Int
	minor::Int = 0
end

NodeRef(major::Int) = NodeRef(major, 0)

Base.convert(::Type{NodeRef}, i::Int) = NodeRef(i, 0)
Base.:(==)(r::NodeRef, i::Int) = r.major == i && r.minor == 0
Base.:(==)(i::Int, r::NodeRef) = r == i

function Base.isless(a::NodeRef, b::NodeRef)
	a.major < b.major || (a.major == b.major && a.minor < b.minor)
end

is_empty_node(id::NodeRef) = id.minor > 0

function Base.show(io::IO, id::NodeRef)
	if id.minor == 0
		print(io, id.major)
	else
		print(io, id.major, '.', id.minor)
	end
end

function Base.parse(::Type{NodeRef}, raw::AbstractString)::NodeRef
	if contains(raw, '.')
		left, right = split(raw, '.'; limit = 2)
		NodeRef(parse(Int, left), parse(Int, right))
	else
		NodeRef(parse(Int, raw))
	end
end

function Base.:(==)(a::NodeRef, b::NodeRef)
	a.major == b.major && a.minor == b.minor
end

function Base.hash(id::NodeRef, h::UInt)
	hash(id.minor, hash(id.major, h))
end

@kwdef struct EnhancedDep
	head::NodeRef
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
	(raw == "_" || isempty(strip(raw))) && return EnhancedDeps()
	deps = EnhancedDep[]
	for item in split(raw, '|')
		item = strip(item)
		isempty(item) && continue
		parts = split(item, ':'; limit = 2)
		if length(parts) < 2
			@warn "skipping malformed enhanced dep (no ':' found)" item
			continue
		end
		head_str = parts[1]
		deprel = parts[2]
		head = try
			parse(NodeRef, head_str)
		catch e
			@warn "skipping enhanced dep with unparseable head" item exception = e
			continue
		end
		push!(deps, EnhancedDep(head, String(deprel)))
	end
	EnhancedDeps(deps)
end


abstract type AbstractNode end

# String fields default to "_" which means "unspecified" in CoNLL-U,
# not a literal underscore. This matches the serialization format directly.
mutable struct Node <: AbstractNode
	id::NodeRef
	form::String
	lemma::String
	upos::String
	xpos::String
	feats::Features
	head::NodeRef
	deprel::String
	deps::EnhancedDeps
	misc::Features
end

function Node(;
	id::Union{Int, NodeRef},
	form::String,
	lemma::String = "_",
	upos::String = "_",
	xpos::String = "_",
	feats::Features = Features(),
	head::Union{Int, NodeRef} = NodeRef(0),
	deprel::String = "_",
	deps::EnhancedDeps = EnhancedDeps(),
	misc::Features = Features(),
)
	Node(
		id isa Int ? NodeRef(id) : id,
		form, lemma, upos, xpos, feats,
		head isa Int ? NodeRef(head) : head,
		deprel, deps, misc,
	)
end

@kwdef mutable struct MWTNode <: AbstractNode
	first::Int
	last::Int
	form::String
	misc::Features = Features()
end

@kwdef mutable struct EmptyNode <: AbstractNode
	id::NodeRef
	form::String
	lemma::String = "_"
	upos::String = "_"
	xpos::String = "_"
	feats::Features = Features()
	deps::EnhancedDeps = EnhancedDeps()
	misc::Features = Features()
end


@kwdef mutable struct Sentence <: AbstractVector{Node}
	words::Vector{Node} = Node[]
	multitokens::Vector{MWTNode} = MWTNode[]
	empties::Vector{EmptyNode} = EmptyNode[]
	comments::Vector{String} = String[]
end

Base.size(s::Sentence) = size(s.words)
Base.getindex(s::Sentence, i::Int) = s.words[i]
Base.getindex(s::Sentence, r) = s.words[r]
Base.setindex!(s::Sentence, w::Node, i::Int) = (s.words[i] = w)
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
Base.filter(f, tb::Treebank) = Treebank(filter(f, tb.sentences))
