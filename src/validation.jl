const upos_tags = Set(
	(
		"ADJ", "ADP", "ADV", "AUX", "CCONJ", "DET", "INTJ", "NOUN",
		"NUM", "PART", "PRON", "PROPN", "PUNCT", "SCONJ", "SYM", "VERB", "X",
	)
)

const universal_deprels = Set(
	(
		"acl", "advcl", "advmod", "amod", "appos", "aux", "case", "cc",
		"ccomp", "clf", "compound", "conj", "cop", "csubj", "dep", "det",
		"discourse", "dislocated", "expl", "fixed", "flat", "goeswith",
		"iobj", "list", "mark", "nmod", "nsubj", "nummod", "obj", "obl",
		"orphan", "parataxis", "punct", "reparandum", "root", "vocative", "xcomp",
	)
)

const enhanced_deprels = union(universal_deprels, Set(("ref",)))

function is_valid_upos(tag::AbstractString)
	tag in upos_tags
end

function split_deprel(deprel::AbstractString)
	idx = findfirst(':', deprel)
	isnothing(idx) && return (String(deprel), nothing)
	(String(deprel[1:idx - 1]), String(deprel[idx + 1:end]))
end

function is_valid_deprel(deprel::AbstractString)
	universal, _ = split_deprel(deprel)
	universal in universal_deprels
end

function is_valid_enhanced_deprel(deprel::AbstractString)
	universal, _ = split_deprel(deprel)
	universal in enhanced_deprels
end
