using UniversalDependencies

# Treebank: 4 sentences, 44 words
tb = UD.load(joinpath(pkgdir(UD), "test", "sample.conllu"))

# sentence-level access
s = tb[1]
UD.id(s)                                        # "weblog-1"
UD.text(s)                                      # "I don't even know what to say about this place."

# multiword tokens
mwt = UD.multitokens(s)[1]
UD.form(mwt)                                    # "don't" (covers words 2–3: "do" + "n't")

# tree traversal
r = UD.root(s)                                  # the root Node
UD.form(r)                                      # "know"
[UD.form(w) for w in UD.children(s, UD.id(r))]  # ["I", "do", "n't", "even", "say", "."]

# features
UD.feats(s[1])["Case"]                          # "Nom"
haskey(UD.feats(s[1]), "Tense")                 # false

# filtering and iteration
verbs = filter(w -> UD.upos(w) == "VERB", s)
[UD.form(w) for w in verbs]                     # ["know", "say"]

long = filter(s -> length(s) > 10, tb)
length(long)                                    # 3

# corpus-wide word iteration
noun_count = count(w -> UD.upos(w) == "NOUN", UD.words(tb))
# 7

# display
render(ArcStyle(), tb[3])
# # sent_id = weblog-3
# # text = Highly recommended!
#              root
#               ╭──punct───╮
#    ╭──advmod──╮          │
# Highly   recommended   !
# ADV      VERB          PUNCT

render(CompactStyle(), tb[2])
# The   food  was   not   very  good  but   the   service  was   excellent  .
# DET   NOUN  AUX   PART  ADV   ADJ   CCONJ DET   NOUN     AUX   ADJ        PUNCT

# highlight specific word positions (ANSI color in terminal)
render(ArcStyle(), tb[1]; highlights = [5:5, 8:8])

# margin labels for annotation review
render(TableStyle(), tb[1]; margin_labels = Dict(5 => "✓", 8 => "?"))

# streaming: process and render sentence by sentence without loading the full corpus
open("large_treebank.conllu") do io
    for sentence in UD.eachsentence(io)
        # find sentences where a noun is the root
        r = UD.root(sentence)
        if UD.upos(r) == "NOUN"
            render(ArcStyle(), sentence)
            println()
        end
    end
end

