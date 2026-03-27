function arc_diagram(
	io::IO,
	words::AbstractVector{WordNode};
	highlights::AbstractVector{UnitRange{Int}} = UnitRange{Int}[],
)
	isempty(words) && return
	use_color = get(io, :color, false)
	id_to_index = Dict(w.id => i for (i, w) in enumerate(words))
	forms = [w.form for w in words]
	upos_tags = [w.upos for w in words]
	col_widths = [max(textwidth(f), textwidth(u)) for (f, u) in zip(forms, upos_tags)]
	gap = 3
	col_start = ones(Int, length(words))
	for i in 2:length(words)
		col_start[i] = col_start[i - 1] + col_widths[i - 1] + gap
	end
	col_center = [col_start[i] + col_widths[i] ÷ 2 for i in eachindex(words)]
	total_width = col_start[end] + col_widths[end] - 1

	arcs = NamedTuple{
		(:left_idx, :right_idx, :dep_idx, :head_idx, :label),
		Tuple{Int, Int, Int, Int, String},
	}[]
	root_indices = Int[]

	for (i, w) in enumerate(words)
		if w.head == 0
			push!(root_indices, i)
			continue
		end
		head_idx = get(id_to_index, w.head, nothing)
		isnothing(head_idx) && continue
		left = min(i, head_idx)
		right = max(i, head_idx)
		push!(arcs, (
			left_idx = left,
			right_idx = right,
			dep_idx = i,
			head_idx = head_idx,
			label = w.deprel,
		))
	end

	sort!(arcs, by = a -> a.right_idx - a.left_idx)

	arc_layers = Int[]
	layer_ranges = Vector{Vector{Tuple{Int, Int}}}()

	for arc in arcs
		left = col_center[arc.left_idx]
		right = col_center[arc.right_idx]
		assigned = 0
		for (l, ranges) in enumerate(layer_ranges)
			if !any(lo <= right && hi >= left for (lo, hi) in ranges)
				assigned = l
				push!(ranges, (left, right))
				break
			end
		end
		if assigned == 0
			push!(layer_ranges, [(left, right)])
			assigned = length(layer_ranges)
		end
		push!(arc_layers, assigned)
	end

	num_layers = isempty(arc_layers) ? 0 : maximum(arc_layers)
	has_root = !isempty(root_indices)
	if has_root
		num_layers += 1
	end

	if num_layers == 0
		compact(io, words; highlights)
		return
	end

	grid = fill(' ', num_layers, total_width)
	root_row = 1
	arc_offset = has_root ? 1 : 0

	for root_idx in root_indices
		col = col_center[root_idx]
		label = "root"
		half = length(label) ÷ 2
		for (j, ch) in enumerate(label)
			pos = col - half + j
			if 1 <= pos <= total_width
				grid[root_row, pos] = ch
			end
		end
		for r in (root_row + 1):num_layers
			if grid[r, col] == ' '
				grid[r, col] = '│'
			end
		end
	end

	for (idx, arc) in enumerate(arcs)
		layer = arc_layers[idx]
		row = num_layers - layer + 1
		left_col = col_center[arc.left_idx]
		right_col = col_center[arc.right_idx]
		grid[row, left_col] = '╭'
		grid[row, right_col] = '╮'
		available = right_col - left_col - 1
		label = arc.label
		if textwidth(label) > available
			label = first(label, available)
		end
		padding = available - textwidth(label)
		left_pad = padding ÷ 2
		right_pad = padding - left_pad
		pos = left_col + 1
		for _ in 1:left_pad
			pos <= total_width && (grid[row, pos] = '─')
			pos += 1
		end
		for ch in label
			pos <= total_width && (grid[row, pos] = ch)
			pos += 1
		end
		for _ in 1:right_pad
			pos <= total_width && (grid[row, pos] = '─')
			pos += 1
		end
		for r in (row + 1):num_layers
			for col in (left_col, right_col)
				if grid[r, col] == ' '
					grid[r, col] = '│'
				elseif grid[r, col] == '─'
					grid[r, col] = '┼'
				end
			end
		end
	end

	for r in 1:num_layers
		println(io, rstrip(String(grid[r, :])))
	end

	highlight_ids = Set{Int}()
	for range in highlights
		union!(highlight_ids, range)
	end

	for (row_idx, getter) in enumerate([:form, :upos])
		for (c, word) in enumerate(words)
			c > 1 && print(io, " "^gap)
			value = getter == :form ? word.form : word.upos
			padded = rpad(value, col_widths[c])
			highlighted = use_color && c in highlight_ids
			dimmed = use_color && !highlighted && row_idx > 1
			if highlighted
				print(io, "\e[1;33m", padded, "\e[0m")
			elseif dimmed
				print(io, "\e[90m", padded, "\e[0m")
			else
				print(io, padded)
			end
		end
		println(io)
	end
end

function arc_diagram(words::AbstractVector{WordNode}; kwargs...)
	arc_diagram(stdout, words; kwargs...)
end

function arc_diagram(io::IO, sentence::Sentence; kwargs...)
	arc_diagram(io, sentence.words; kwargs...)
end

function arc_diagram(sentence::Sentence; kwargs...)
	arc_diagram(stdout, sentence.words; kwargs...)
end
