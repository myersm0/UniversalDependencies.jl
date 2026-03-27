abstract type DisplayStyle end
struct TableStyle <: DisplayStyle end
struct CompactStyle <: DisplayStyle end
struct ArcStyle <: DisplayStyle end
struct AutoStyle <: DisplayStyle end

const default_compact_rows = [:form, :upos]
const compact_gap = 2
const arc_gap = 3

function terminal_width(io::IO)
	displaysize(io)[2]
end

function terminal_width(io::IOContext)
	haskey(io, :displaysize) && return io[:displaysize][2]
	terminal_width(io.io)
end

function terminal_width(io)
	80
end

function words_line_width(words::AbstractVector{Node}, gap::Int)
	isempty(words) && return 0
	sum(max(textwidth(w.form), textwidth(w.upos)) for w in words) + gap * (length(words) - 1)
end

function chunk_words(words::AbstractVector{Node}, max_width::Int, gap::Int)
	chunks = UnitRange{Int}[]
	start = 1
	current_width = 0
	for i in eachindex(words)
		word_width = max(textwidth(words[i].form), textwidth(words[i].upos))
		needed = i == start ? word_width : current_width + gap + word_width
		if needed > max_width && i > start
			push!(chunks, start:(i - 1))
			start = i
			current_width = word_width
		else
			current_width = needed
		end
	end
	push!(chunks, start:lastindex(words))
	chunks
end


# --- render on raw word vectors (internal workhorse) ---

function render(
	::TableStyle,
	io::IO,
	words::AbstractVector{Node};
	highlights::AbstractVector{UnitRange{Int}} = UnitRange{Int}[],
	margin_labels::Dict{Int, String} = Dict{Int, String}(),
	kwargs...,
)
	format_nodes(io, words; highlights, margin_labels)
end

function render(
	::CompactStyle,
	io::IO,
	words::AbstractVector{Node};
	highlights::AbstractVector{UnitRange{Int}} = UnitRange{Int}[],
	rows::Vector{Symbol} = default_compact_rows,
	kwargs...,
)
	isempty(words) && return
	width = terminal_width(io)
	line_width = words_line_width(words, compact_gap)
	if line_width <= width
		compact(io, words; highlights, rows)
	else
		chunks = chunk_words(words, width, compact_gap)
		for (ci, chunk) in enumerate(chunks)
			ci > 1 && println(io)
			compact(io, view(words, chunk); highlights, rows)
		end
	end
end

function render(
	::ArcStyle,
	io::IO,
	words::AbstractVector{Node};
	highlights::AbstractVector{UnitRange{Int}} = UnitRange{Int}[],
	kwargs...,
)
	isempty(words) && return
	width = terminal_width(io)
	line_width = words_line_width(words, arc_gap)
	if line_width <= width
		arc_diagram(io, words; highlights)
	else
		chunks = chunk_words(words, width, arc_gap)
		for (ci, chunk) in enumerate(chunks)
			ci > 1 && println(io)
			arc_diagram(io, words[chunk]; highlights)
		end
	end
end

function render(
	::AutoStyle,
	io::IO,
	words::AbstractVector{Node};
	highlights::AbstractVector{UnitRange{Int}} = UnitRange{Int}[],
	margin_labels::Dict{Int, String} = Dict{Int, String}(),
	rows::Vector{Symbol} = default_compact_rows,
	kwargs...,
)
	isempty(words) && return
	width = terminal_width(io)
	if words_line_width(words, arc_gap) <= width
		arc_diagram(io, words; highlights)
	elseif words_line_width(words, compact_gap) <= width
		compact(io, words; highlights, rows)
	else
		chunks = chunk_words(words, width, compact_gap)
		for (ci, chunk) in enumerate(chunks)
			ci > 1 && println(io)
			compact(io, view(words, chunk); highlights, rows)
		end
	end
end


# --- render on Sentence (prints comments, then delegates) ---

function _render_sentence(style::DisplayStyle, io::IO, sentence::Sentence; kwargs...)
	for comment in sentence.comments
		printstyled(io, comment, '\n'; color = :light_black)
	end
	render(style, io, sentence.tokens; kwargs...)
end

render(s::TableStyle, io::IO, sent::Sentence; kw...) = _render_sentence(s, io, sent; kw...)
render(s::CompactStyle, io::IO, sent::Sentence; kw...) = _render_sentence(s, io, sent; kw...)
render(s::ArcStyle, io::IO, sent::Sentence; kw...) = _render_sentence(s, io, sent; kw...)
render(s::AutoStyle, io::IO, sent::Sentence; kw...) = _render_sentence(s, io, sent; kw...)


# --- render on sentence collections ---

function estimate_height(sentence::Sentence, style::DisplayStyle, width::Int)
	comment_lines = length(sentence.comments)
	word_count = length(sentence)
	if style isa TableStyle
		return comment_lines + word_count + length(sentence.multitokens) + length(sentence.empties)
	end
	line_width = words_line_width(sentence.tokens, style isa ArcStyle ? arc_gap : compact_gap)
	num_chunks = max(1, ceil(Int, line_width / max(width, 1)))
	if style isa CompactStyle
		return comment_lines + 2 * num_chunks + (num_chunks - 1)
	end
	if style isa ArcStyle
		depth = min(word_count, 8)
		return comment_lines + (depth + 2) * num_chunks + (num_chunks - 1)
	end
	arc_width = words_line_width(sentence.tokens, arc_gap)
	if arc_width <= width
		depth = min(word_count, 8)
		return comment_lines + depth + 2
	end
	compact_width = words_line_width(sentence.tokens, compact_gap)
	num_chunks = max(1, ceil(Int, compact_width / max(width, 1)))
	comment_lines + 2 * num_chunks + (num_chunks - 1)
end

function render(
	style::DisplayStyle,
	io::IO,
	sentences::AbstractVector{Sentence};
	kwargs...,
)
	n = length(sentences)
	if n == 0
		println(io, "0-element Vector{Sentence}")
		return
	end
	height, width = try
		ds = displaysize(io)
		(ds[1], ds[2])
	catch
		(24, 80)
	end
	budget = max(height - 2, 6)
	if n <= 3 || sum(s -> estimate_height(s, style, width) + 1, sentences) <= budget
		for (i, s) in enumerate(sentences)
			i > 1 && println(io)
			print(io, "[", i, "] ")
			show(io, s)
			println(io)
			render(style, io, s.tokens; kwargs...)
		end
		return
	end
	head_count = 0
	head_lines = 0
	for i in 1:n
		cost = estimate_height(sentences[i], style, width) + 2
		if head_lines + cost > budget ÷ 2
			break
		end
		head_count = i
		head_lines += cost
	end
	head_count = max(head_count, 1)
	tail_count = 0
	tail_lines = 0
	for i in n:-1:(head_count + 1)
		cost = estimate_height(sentences[i], style, width) + 2
		if tail_lines + cost > budget - head_lines - 1
			break
		end
		tail_count += 1
		tail_lines += cost
	end
	tail_count = max(tail_count, 1)
	for i in 1:head_count
		i > 1 && println(io)
		print(io, "[", i, "] ")
		show(io, sentences[i])
		println(io)
		render(style, io, sentences[i].tokens; kwargs...)
	end
	elided = n - head_count - tail_count
	if elided > 0
		println(io)
		printstyled(io, "  ⋮ ", elided, " sentences omitted\n"; color = :light_black)
	end
	tail_start = n - tail_count + 1
	for i in tail_start:n
		println(io)
		print(io, "[", i, "] ")
		show(io, sentences[i])
		println(io)
		render(style, io, sentences[i].tokens; kwargs...)
	end
end


# --- convenience: style-first without io, defaults to stdout ---

render(style::DisplayStyle, target; kwargs...) = render(style, stdout, target; kwargs...)


# --- convenience: no style specified, defaults to TableStyle ---

render(io::IO, target; kwargs...) = render(TableStyle(), io, target; kwargs...)
render(target; kwargs...) = render(TableStyle(), stdout, target; kwargs...)


# --- show methods ---

function Base.show(io::IO, ::MIME"text/plain", sentence::Sentence)
	render(TableStyle(), io, sentence)
end

function Base.show(io::IO, tb::Treebank)
	word_count = sum(length(s) for s in tb; init = 0)
	print(io, "Treebank: ", length(tb), " sentences, ", word_count, " words")
end

function Base.show(io::IO, ::MIME"text/plain", tb::Treebank)
	show(io, tb)
	println(io)
	render(TableStyle(), io, tb.sentences)
end
