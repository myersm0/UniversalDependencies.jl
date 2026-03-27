function parse_word(fields::Vector{<:AbstractString})::Node
	Node(
		id = NodeRef(parse(Int, fields[1])),
		form = String(fields[2]),
		lemma = String(fields[3]),
		upos = String(fields[4]),
		xpos = String(fields[5]),
		feats = parse(Features, fields[6]),
		head = fields[7] == "_" ? NodeRef(0) : NodeRef(parse(Int, fields[7])),
		deprel = String(fields[8]),
		deps = parse(EnhancedDeps, fields[9]),
		misc = parse(Features, fields[10]),
	)
end

function parse_multiword(fields::Vector{<:AbstractString}, first::Int, last::Int)::MWTNode
	MWTNode(
		first = first,
		last = last,
		form = String(fields[2]),
		misc = parse(Features, fields[10]),
	)
end

function parse_empty(fields::Vector{<:AbstractString}, major::Int, minor::Int)::EmptyNode
	EmptyNode(
		id = NodeRef(major, minor),
		form = String(fields[2]),
		lemma = String(fields[3]),
		upos = String(fields[4]),
		xpos = String(fields[5]),
		feats = parse(Features, fields[6]),
		deps = parse(EnhancedDeps, fields[9]),
		misc = parse(Features, fields[10]),
	)
end

function parse_sentence(lines::AbstractVector{<:AbstractString})::Sentence
	words = Node[]
	multitokens = MWTNode[]
	empties = EmptyNode[]
	comments = String[]
	for line in lines
		if startswith(line, '#')
			push!(comments, String(line))
		elseif !isempty(strip(line))
			fields = split(line, '\t')
			length(fields) == 10 || error("expected 10 tab-separated fields, got $(length(fields))")
			id_str = fields[1]
			if contains(id_str, '-')
				left, right = split(id_str, '-')
				push!(multitokens, parse_multiword(fields, parse(Int, left), parse(Int, right)))
			elseif contains(id_str, '.')
				left, right = split(id_str, '.')
				push!(empties, parse_empty(fields, parse(Int, left), parse(Int, right)))
			else
				push!(words, parse_word(fields))
			end
		end
	end
	Sentence(words = words, multitokens = multitokens, empties = empties, comments = comments)
end


struct SentenceIterator
	io::IO
end

Base.IteratorSize(::Type{SentenceIterator}) = Base.SizeUnknown()
Base.eltype(::Type{SentenceIterator}) = Sentence

function Base.iterate(iter::SentenceIterator, _ = nothing)
	lines = String[]
	while !eof(iter.io)
		line = readline(iter.io)
		if isempty(line)
			isempty(lines) && continue
			return (parse_sentence(lines), nothing)
		end
		push!(lines, line)
	end
	isempty(lines) && return nothing
	(parse_sentence(lines), nothing)
end

eachsentence(io::IO) = SentenceIterator(io)

function load(path::AbstractString)::Treebank
	open(path) do io
		Treebank(collect(SentenceIterator(io)))
	end
end

function load(io::IO)::Treebank
	Treebank(collect(SentenceIterator(io)))
end
