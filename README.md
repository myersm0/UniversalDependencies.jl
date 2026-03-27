# UniversalDependencies.jl

[![Build Status](https://github.com/myersm0/UniversalDependencies.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/myersm0/UniversalDependencies.jl/actions/workflows/CI.yml?query=branch%3Amain)

A Julia representation of the [Universal Dependencies](https://universaldependencies.org/) data model for annotated linguistic data: typed nodes, structured features, and tree traversal.

Featuring a toolkit for reading, editing, and analyzing UD treebanks. CoNLL-U is the supported serialization format.

## Installation

```julia
using Pkg
Pkg.add("UniversalDependencies")
```

## Quick start
A constant `UD` is exported as a shorthand for `UniversalDependencies`, so that package-specific functions can be brief and general without risking collision in the global namespace:

```julia
using UniversalDependencies

treebank = UD.load("en_ewt-ud-train.conllu")
sentence = treebank[1]

UD.id(sentence)          # "weblog-01"
UD.text(sentence)        # the original text of the sentence
length(sentence)         # 12 (word count)

node = sentence[5]
UD.form(node)                # "know"
UD.upos(node)                # "VERB"
UD.head(node)                # 0 (root)
UD.feats(node)["VerbForm"]   # "Inf"
```

## API overview

The package exports only display styles and `render`. Everything else is accessed through the `UD` module prefix.

## Types

### NodeRef

A unified identity type for addressable nodes and dependency references.

```julia
UD.NodeRef(5)        # word 5 — shorthand for NodeRef(5, 0)
UD.NodeRef(5, 1)     # empty node 5.1

ref = UD.NodeRef(5)
ref == 5             # true — Int comparison works transparently
ref.major            # 5
ref.minor            # 0
```

`NodeRef` supports ordering, hashing, and `parse`:

```julia
parse(UD.NodeRef, "5.1")          # NodeRef(5, 1)
UD.NodeRef(3) < UD.NodeRef(5, 1)  # true (lexicographic by major, minor)
UD.is_empty_node(UD.NodeRef(5,1)) # true
```

### Node types

Three concrete types, reflecting the UD ontology. All subtype `UD.AbstractNode`.

**`UD.Node`** — a token in the basic dependency tree.

| Field    | Type              | Default        | Notes                        |
|----------|-------------------|----------------|------------------------------|
| `id`     | `NodeRef`         |                | `NodeRef(i)` for word i      |
| `form`   | `String`          |                |                              |
| `lemma`  | `String`          | `"_"`          |                              |
| `upos`   | `String`          | `"_"`          |                              |
| `xpos`   | `String`          | `"_"`          |                              |
| `feats`  | `Features`        | empty          | dict-like, `n.feats["Case"]` |
| `head`   | `NodeRef`         | `NodeRef(0)`   | 0 = root                    |
| `deprel` | `String`          | `"_"`          |                              |
| `deps`   | `EnhancedDeps`    | empty          | enhanced dependency graph    |
| `misc`   | `Features`        | empty          | key-value misc column        |

Construction accepts plain `Int` for `id` and `head`:

```julia
UD.Node(id = 1, form = "hello")                 # defaults for everything else
UD.Node(id = 1, form = "hello", head = 3)       # Int auto-converts to NodeRef
```

**`UD.MWTNode`** — a multiword token span (e.g. "don't" covering tokens 2–3). Carries `first`, `last`, `form`, and `misc`.

**`UD.EmptyNode`** — participates in enhanced deps only. Uses `id::NodeRef` with a non-zero minor (e.g. `NodeRef(5, 1)`). Has `form`, `lemma`, `upos`, `xpos`, `feats`, `deps`, `misc`. No `head` or `deprel`.

### Features

Parsed key-value pairs from the FEATS and MISC columns:

```julia
n.feats["Number"]              # "Sing"
get(n.feats, "Mood", "N/A")    # safe access
haskey(n.feats, "Tense")       # true/false
keys(n.feats)                  # ["Number", "Person", ...]

UD.feats(n)["Mood"] = "Sub"    # mutable
delete!(n.feats, "Gender")

f = parse(UD.Features, "Number=Sing|Tense=Past")
```

Features are sorted alphabetically by key on serialization, per the CoNLL-U spec.

### EnhancedDeps

Parsed from the DEPS column. Heads use `NodeRef`, so references to empty nodes work naturally:

```julia
e = parse(UD.EnhancedDeps, "5:nsubj|5.1:obj")
for dep in e
    UD.head(dep)    # NodeRef — could be a word or empty node
    UD.deprel(dep)  # String
end
```

### Sentence

`UD.Sentence <: AbstractVector{UD.Node}` — iteration, indexing, `filter`, `map`, `count` all operate on the word layer:

```julia
s[3]                                  # third token
length(s)                             # word count
[UD.form(n) for n in s]               # all forms
count(n -> UD.upos(n) == "VERB", s)   # verb count
filter(n -> UD.head(n) == 0, s)       # root tokens
```

Other node types and metadata:

```julia
UD.multitokens(s)    # Vector{MWTNode}
UD.empties(s)        # Vector{EmptyNode}
UD.id(s)             # parses # id = ...
UD.text(s)           # parses # text = ...
s.comments           # Vector{String}, raw comment lines
```

### Treebank

`UD.Treebank <: AbstractVector{UD.Sentence}`:

```julia
treebank = UD.load("my_treebank.conllu")
length(treebank)                              # sentence count
treebank[1:10]                                # slicing returns a Treebank
filter(s -> length(s) > 20, treebank)         # long sentences (returns Treebank)
[UD.id(s) for s in treebank]                  # all sentence IDs
```

Flat word iteration across sentence boundaries:

```julia
for n in UD.words(treebank)
    # every Node in the corpus
end
```

### Tables.jl integration

`Treebank` implements the Tables.jl interface, producing a flat word-level table:

```julia
using DataFrames
df = DataFrame(treebank)
# columns: sentence_index, id, form, lemma, upos, xpos, head, deprel
```

## I/O

```julia
treebank = UD.load("treebank.conllu")
treebank = UD.load(io)

# stream sentence by sentence
open("treebank.conllu") do io
    for sentence in UD.eachsentence(io)
        # process without materializing the full treebank
    end
end

UD.save("output.conllu", treebank)
UD.save(io, treebank)
UD.write_sentence(io, sentence)
```

Round-trip fidelity: all tokens, multiword tokens, empty nodes, comments, and features are semantically preserved.

## Tree traversal

```julia
r = UD.root(s)              # Node with head == 0
UD.children(s, r.id)        # direct dependents
UD.subtree(s, r.id)         # all descendants (sorted by id)
UD.head_of(s, s[3])         # parent Node (or nothing for root)
```

These also accept plain `Int` arguments: `UD.children(s, 6)`.

## Display

Display styles and `render` are the only exported names. All display goes through `render`, with the style as the first argument:

```julia
render(TableStyle(), s)              # full CoNLL-U table (default)
render(CompactStyle(), s)            # inline form + UPOS rows
render(ArcStyle(), s)                # dependency arc diagram
render(AutoStyle(), s)               # arcs if fits, compact otherwise

render(s)                            # defaults to TableStyle
render(CompactStyle(), io, s)        # write to specific IO
render(TableStyle(), treebank)       # render treebank with head/tail elision
```

Styles support highlights for marking matched tokens:

```julia
render(ArcStyle(), s; highlights = [3:5])
render(TableStyle(), s; margin_labels = Dict(3 => "a", 5 => "b"))
```

## Terminology note

This package follows the UD spec's distinction between "words" (syntactic units in the dependency tree, represented by `UD.Node`) and "tokens" (orthographic units, including multiword tokens). `UD.words` iterates the word layer; multiword tokens are accessed separately via `UD.multitokens`.

## License

MIT
