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
# sent_id = weblog-3
# # text = Highly recommended!
#              root
#               ╭──punct───╮
#    ╭──advmod──╮          │
# Highly   recommended   !
# ADV      VERB          PUNCT

render(CompactStyle(), tb[2])
# The   food  was   not   very  good  but   the   service  was   excellent  .
# DET   NOUN  AUX   PART  ADV   ADJ   CCONJ DET   NOUN     AUX   ADJ        PUNCT


