# UniversalDependencies

[![Build Status](https://github.com/myersm0/UniversalDependencies.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/myersm0/UniversalDependencies.jl/actions/workflows/CI.yml?query=branch%3Amain)

A Julia toolkit for reading, validating, editing, comparing, and analyzing [Universal Dependencies](https://universaldependencies.org/) treebanks.

Features a Julia representation of the UD data model: typed nodes, structured features, and tree traversal.

CoNLL-U is the serialization format. 

## Installation

```julia
using Pkg
Pkg.add("UniversalDependencies")
```

## Quick start

```julia
using UniversalDependencies
const UD = UniversalDependencies

treebank = UD.load("en_ewt-ud-train.conllu")
sentence = treebank[1]

sent_id(sentence)        # "weblog-01"
UD.text(sentence)        # reconstruct the text of the sentence
length(sentence)         # 12 (word count)
multiwords(sentence)     # [MultiwordNode(2, 3, "don't", ...)]

word = sentence[5]
word.form               # "know"
word.upos               # "VERB"
word.head               # 0 (root)
word.feats["VerbForm"]  # "Inf"
```

## Types

### Node types

The package uses three concrete node types, reflecting the UD ontology:

**`WordNode`** — a word in the basic dependency tree.

| Field    | Type            | Default | Notes                          |
|----------|-----------------|---------|--------------------------------|
| `id`     | `Int`           |         | 1-indexed, gapless             |
| `form`   | `String`        |         |                                |
| `lemma`  | `String`        | `"_"`   |                                |
| `upos`   | `String`        | `"_"`   |                                |
| `xpos`   | `String`        | `"_"`   |                                |
| `feats`  | `Features`      | empty   | dict-like, `w.feats["Case"]`   |
| `head`   | `Int`           | `0`     | 0 = root                      |
| `deprel` | `String`        | `"_"`   |                                |
| `deps`   | `EnhancedDeps`  | empty   | enhanced dependency graph      |
| `misc`   | `Features`      | empty   | key-value misc column          |

**`MultiwordNode`** — a surface-form span (e.g. "don't" → words 2–3). Only carries `first`, `last`, `form`, and `misc`.

**`EmptyNode`** — participates in enhanced deps only. Has `major`, `minor`, `form`, `lemma`, `upos`, `xpos`, `feats`, `deps`, `misc`. No `head` or `deprel` (empty nodes are not in the basic tree).

All node types subtype `AbstractNode`. WordNode fields use `@kwdef`, so you can construct partial nodes easily:

```julia
node = WordNode(id = 1, form = "hello")
# lemma="_", upos="_", head=0, etc. — all defaulted
```

### Features

Parsed key-value pairs from the FEATS and MISC columns:

```julia
w.feats["Number"]            # "Sing"
get(w.feats, "Mood", "N/A")  # safe access
haskey(w.feats, "Tense")     # true/false
keys(w.feats)                # ["Number", "Person", ...]

# mutable
w.feats["Mood"] = "Sub"
delete!(w.feats, "Gender")

# parse from string
f = parse(Features, "Number=Sing|Tense=Past")
```

### EnhancedDeps

Parsed from the DEPS column:

```julia
e = parse(EnhancedDeps, "5:nsubj|8:obj")
for dep in e
    dep.head    # Int
    dep.deprel  # String
end
```

### Sentence

`Sentence <: AbstractVector{WordNode}` — iteration, indexing, `filter`, `map`, `count` all operate on the word layer:

```julia
s[3]                                  # third word
length(s)                             # word count
[w.form for w in s]                   # all forms
count(w -> w.upos == "VERB", s)       # verb count
filter(w -> w.head == 0, s)           # root words
```

Other node types are accessed via:

```julia
multiwords(s)    # Vector{MultiwordNode}
empties(s)       # Vector{EmptyNode}
s.comments       # Vector{String}, raw comment lines
```

Metadata from comments:

```julia
sent_id(s)    # parses # sent_id = ...
UD.text(s)    # parses # text = ...
```

### Treebank

`Treebank <: AbstractVector{Sentence}`:

```julia
treebank = load("my_treebank_file.conllu")
length(treebank)                              # sentence count
treebank[1:10]                                # slicing returns a Treebank
filter(s -> length(s) > 20, treebank)         # long sentences
[sent_id(s) for s in treebank]                # all sentence IDs
```

Flat word iteration across sentence boundaries:

```julia
for w in words(treebank)
    # every WordNode in the corpus
end
```

## I/O

```julia
# load entire corpus
treebank = load("treebank.conllu")
treebank = load(io)

# stream sentence by sentence
open("treebank.conllu") do io
    for sentence in eachsentence(io)
        # process without materializing
    end
end

# write
save("output.conllu", treebank)
save(io, treebank)
write_sentence(io, sentence)
```

All words, multiword tokens, empty nodes, comments, and features are semantically preserved upon writing.

## Tree traversal

```julia
r = root(s)                   # WordNode with head == 0
children(s, r.id)             # direct dependents
subtree(s, r.id)              # all descendants (sorted by id)
head_of(s, s[3])              # parent WordNode (or nothing for root)
```

## Display

All display goes through `render`, with the style as the first argument:

```julia
render(TableStyle(), s)              # full CoNLL-U table (default)
render(CompactStyle(), s)            # inline form + UPOS rows
render(ArcStyle(), s)                # dependency arc diagram
render(AutoStyle(), s)               # arcs if fits, compact otherwise

render(s)                            # defaults to TableStyle
render(CompactStyle(), io, s)        # write to specific IO
render(TableStyle(), tb)             # render treebank with head/tail elision
```

Styles support highlights for marking matched tokens:

```julia
render(ArcStyle(), s; highlights = [3:5])
render(TableStyle(), s; margin_labels = Dict(3 => "a", 5 => "b"))
```

## License

MIT
