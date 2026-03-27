function write_word(io::IO, word::WordNode)
	print(io, word.id)
	print(io, '\t', word.form)
	print(io, '\t', word.lemma)
	print(io, '\t', word.upos)
	print(io, '\t', word.xpos)
	print(io, '\t', word.feats)
	print(io, '\t', word.head)
	print(io, '\t', word.deprel)
	print(io, '\t', word.deps)
	print(io, '\t', word.misc)
	println(io)
end

function write_multiword(io::IO, mw::MultiwordNode)
	print(io, mw.first, '-', mw.last)
	print(io, '\t', mw.form)
	for _ in 1:7
		print(io, '\t', '_')
	end
	print(io, '\t', mw.misc)
	println(io)
end

function write_empty(io::IO, en::EmptyNode)
	print(io, en.id)
	print(io, '\t', en.form)
	print(io, '\t', en.lemma)
	print(io, '\t', en.upos)
	print(io, '\t', en.xpos)
	print(io, '\t', en.feats)
	print(io, '\t', '_')
	print(io, '\t', '_')
	print(io, '\t', en.deps)
	print(io, '\t', en.misc)
	println(io)
end

function write_sentence(io::IO, sentence::Sentence)
	for comment in sentence.comments
		println(io, comment)
	end
	mw_idx = 1
	em_idx = 1
	for word in sentence.words
		while mw_idx <= length(sentence.multiwords) && sentence.multiwords[mw_idx].first == word.id.major
			write_multiword(io, sentence.multiwords[mw_idx])
			mw_idx += 1
		end
		write_word(io, word)
		while em_idx <= length(sentence.empties) && sentence.empties[em_idx].id.major == word.id.major
			write_empty(io, sentence.empties[em_idx])
			em_idx += 1
		end
	end
	println(io)
end

function save(path::AbstractString, treebank)
	open(path, "w") do io
		for sentence in treebank
			write_sentence(io, sentence)
		end
	end
end

function save(io::IO, treebank)
	for sentence in treebank
		write_sentence(io, sentence)
	end
end
