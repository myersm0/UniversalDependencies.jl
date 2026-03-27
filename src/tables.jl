using Tables

const word_row_names = (
	:sentence_index, :id, :form, :lemma, :upos, :xpos, :head, :deprel,
)

const word_row_types = (
	Int, Int, String, String, String, String, Int, String,
)

const word_row_type = NamedTuple{word_row_names, Tuple{word_row_types...}}

Tables.istable(::Type{Treebank}) = true
Tables.rowaccess(::Type{Treebank}) = true

function Tables.schema(::Treebank)
	Tables.Schema(word_row_names, word_row_types)
end

struct TreebankRows
	treebank::Treebank
end

Base.length(tr::TreebankRows) = sum(length(s) for s in tr.treebank; init = 0)
Base.eltype(::Type{TreebankRows}) = word_row_type

function Base.iterate(tr::TreebankRows, state = (1, 1))
	sent_idx, word_idx = state
	while sent_idx <= length(tr.treebank)
		sentence = tr.treebank[sent_idx]
		if word_idx <= length(sentence)
			w = sentence[word_idx]
			row = (
				sentence_index = sent_idx,
				id = w.id,
				form = w.form,
				lemma = w.lemma,
				upos = w.upos,
				xpos = w.xpos,
				head = w.head,
				deprel = w.deprel,
			)
			return (row, (sent_idx, word_idx + 1))
		end
		sent_idx += 1
		word_idx = 1
	end
	nothing
end

Tables.rows(tb::Treebank) = TreebankRows(tb)
