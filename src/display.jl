function word_fields(word::Node)::Vector{String}
	[
		string(word.id),
		word.form,
		word.lemma,
		word.upos,
		word.xpos,
		sprint(show, word.feats),
		string(word.head),
		word.deprel,
		sprint(show, word.deps),
		sprint(show, word.misc),
	]
end

function column_widths(words::AbstractVector{Node})
	widths = zeros(Int, 10)
	for word in words
		for (i, field) in enumerate(word_fields(word))
			widths[i] = max(widths[i], textwidth(field))
		end
	end
	widths
end

function format_nodes(
	io::IO,
	words::AbstractVector{Node};
	highlights::AbstractVector{UnitRange{Int}} = UnitRange{Int}[],
	margin_labels::Dict{Int, String} = Dict{Int, String}(),
)
	isempty(words) && return
	use_color = get(io, :color, false)
	widths = column_widths(words)
	margin_width = if isempty(margin_labels)
		0
	else
		maximum(textwidth, values(margin_labels)) + 1
	end
	highlight_set = Set{Int}()
	for range in highlights
		union!(highlight_set, range)
	end
	for (index, word) in enumerate(words)
		if margin_width > 0
			label = get(margin_labels, index, "")
			if use_color && !isempty(label)
				print(io, "\e[36m", rpad(label, margin_width), "\e[0m")
			else
				print(io, rpad(label, margin_width))
			end
		end
		highlighted = use_color && index in highlight_set
		highlighted && print(io, "\e[1;33m")
		fields = word_fields(word)
		for (col, field) in enumerate(fields)
			col > 1 && print(io, "  ")
			print(io, rpad(field, widths[col]))
		end
		highlighted && print(io, "\e[0m")
		println(io)
	end
end

function format_nodes(words::AbstractVector{Node}; kwargs...)
	format_nodes(stdout, words; kwargs...)
end


function compact(
	io::IO,
	words::AbstractVector{Node};
	highlights::AbstractVector{UnitRange{Int}} = UnitRange{Int}[],
	rows::Vector{Symbol} = [:form, :upos],
)
	isempty(words) && return
	use_color = get(io, :color, false)
	field_getter = Dict{Symbol, Function}(
		:form => w -> w.form,
		:lemma => w -> w.lemma,
		:upos => w -> w.upos,
		:xpos => w -> w.xpos,
		:deprel => w -> w.deprel,
	)
	row_values = [
		[field_getter[r](w) for w in words]
		for r in rows
	]
	col_widths = [
		maximum(textwidth(row_values[r][c]) for r in eachindex(rows))
		for c in eachindex(words)
	]
	highlight_ids = Set{Int}()
	for range in highlights
		union!(highlight_ids, range)
	end
	for (r, row_name) in enumerate(rows)
		for (c, word) in enumerate(words)
			c > 1 && print(io, "  ")
			value = row_values[r][c]
			highlighted = use_color && c in highlight_ids
			if highlighted
				print(io, "\e[1;33m", rpad(value, col_widths[c]), "\e[0m")
			else
				dimmed = use_color && r > 1
				dimmed && print(io, "\e[90m")
				print(io, rpad(value, col_widths[c]))
				dimmed && print(io, "\e[0m")
			end
		end
		println(io)
	end
end

function compact(words::AbstractVector{Node}; kwargs...)
	compact(stdout, words; kwargs...)
end

function compact(io::IO, sentence::Sentence; kwargs...)
	compact(io, sentence.words; kwargs...)
end

function compact(sentence::Sentence; kwargs...)
	compact(stdout, sentence.words; kwargs...)
end


function Base.show(io::IO, word::Node)
	print(io, word.id, '\t', word.form, '\t', word.lemma, '\t', word.upos)
end

function Base.show(io::IO, ::MIME"text/plain", word::Node)
	names = ["id", "form", "lemma", "upos", "xpos", "feats", "head", "deprel", "deps", "misc"]
	fields = word_fields(word)
	width = maximum(length, names)
	first_line = true
	for (name, value) in zip(names, fields)
		value == "_" && continue
		first_line || println(io)
		first_line = false
		print(io, lpad(name, width), " │ ", value)
	end
end

function Base.show(io::IO, sentence::Sentence)
	id = sent_id(sentence)
	word_count = length(sentence.words)
	label = isnothing(id) ? "Sentence" : "Sentence($(repr(id)))"
	print(io, label, ": ", word_count, " words")
end

function Base.show(io::IO, mw::MWTNode)
	print(io, mw.first, '-', mw.last, '\t', mw.form)
end

function Base.show(io::IO, en::EmptyNode)
	print(io, en.id, '\t', en.form, '\t', en.lemma, '\t', en.upos)
end
