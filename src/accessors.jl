function sent_id(sentence::Sentence)
	for comment in sentence.comments
		if startswith(comment, "# sent_id")
			parts = split(comment, '='; limit = 2)
			length(parts) == 2 && return strip(String(parts[2]))
		end
	end
	nothing
end

function text(sentence::Sentence)
	for comment in sentence.comments
		if startswith(comment, "# text")
			parts = split(comment, '='; limit = 2)
			length(parts) == 2 && return strip(String(parts[2]))
		end
	end
	nothing
end

multitokens(sentence::Sentence) = sentence.multitokens
empties(sentence::Sentence) = sentence.empties

function root(sentence::Sentence)::Node
	for word in sentence.words
		word.head == 0 && return word
	end
	error("no root found in sentence")
end

function children(sentence::Sentence, id::NodeRef)::Vector{Node}
	[w for w in sentence.words if w.head == id]
end

children(sentence::Sentence, id::Int) = children(sentence, NodeRef(id))

function subtree(sentence::Sentence, id::NodeRef)::Vector{Node}
	result = Node[]
	stack = [id]
	while !isempty(stack)
		current = pop!(stack)
		for word in sentence.words
			if word.head == current
				push!(result, word)
				push!(stack, word.id)
			end
		end
	end
	sort!(result, by = w -> w.id)
end

subtree(sentence::Sentence, id::Int) = subtree(sentence, NodeRef(id))

function head_of(sentence::Sentence, word::Node)::Union{Node, Nothing}
	word.head == 0 && return nothing
	for w in sentence.words
		w.id == word.head && return w
	end
	nothing
end


struct WordIterator
	treebank::Treebank
end

Base.IteratorSize(::Type{WordIterator}) = Base.SizeUnknown()
Base.eltype(::Type{WordIterator}) = Node

function Base.iterate(iter::WordIterator, state = (1, 1))
	sent_idx, word_idx = state
	while sent_idx <= length(iter.treebank)
		sentence = iter.treebank[sent_idx]
		if word_idx <= length(sentence)
			return (sentence[word_idx], (sent_idx, word_idx + 1))
		end
		sent_idx += 1
		word_idx = 1
	end
	nothing
end

words(treebank::Treebank) = WordIterator(treebank)
