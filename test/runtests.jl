using Test
using UniversalDependencies
const UD = UniversalDependencies

const sample_path = joinpath(@__DIR__, "sample.conllu")

@testset "UniversalDependencies" begin

@testset "Features" begin
	f = parse(Features, "Number=Sing|Person=3|Tense=Past")
	@test length(f) == 3
	@test f["Number"] == "Sing"
	@test f["Person"] == "3"
	@test haskey(f, "Tense")
	@test !haskey(f, "Mood")
	@test get(f, "Mood", "none") == "none"
	@test keys(f) == ["Number", "Person", "Tense"]
	f["Mood"] = "Ind"
	@test f["Mood"] == "Ind"
	@test length(f) == 4
	f["Mood"] = "Sub"
	@test f["Mood"] == "Sub"
	@test length(f) == 4
	delete!(f, "Person")
	@test !haskey(f, "Person")
	@test length(f) == 3
	empty_f = parse(Features, "_")
	@test isempty(empty_f)
	@test sprint(show, empty_f) == "_"
	@test sprint(show, parse(Features, "A=1|B=2")) == "A=1|B=2"
	@test sprint(show, parse(Features, "B=2|A=1")) == "A=1|B=2"
end

@testset "NodeRef" begin
	n1 = parse(NodeRef, "5")
	@test n1.major == 5
	@test n1.minor == 0
	@test !is_empty_node(n1)
	@test sprint(show, n1) == "5"
	n2 = parse(NodeRef, "5.1")
	@test n2.major == 5
	@test n2.minor == 1
	@test is_empty_node(n2)
	@test sprint(show, n2) == "5.1"
	@test n1 != n2
	@test parse(NodeRef, "5") == parse(NodeRef, "5")
	@test n1 == 5
	@test 5 == n1
	@test n1 != 3
	@test n2 != 5
	@test NodeRef(3) < NodeRef(5)
	@test NodeRef(5, 0) < NodeRef(5, 1)
	@test NodeRef(5, 1) < NodeRef(5, 2)
end

@testset "EnhancedDeps" begin
	e = parse(EnhancedDeps, "5:nsubj|8:obj")
	@test length(e) == 2
	@test e.deps[1].head == NodeRef(5)
	@test e.deps[1].deprel == "nsubj"
	@test e.deps[2].head == NodeRef(8)
	empty_e = parse(EnhancedDeps, "_")
	@test isempty(empty_e)
	@test sprint(show, empty_e) == "_"
	@test sprint(show, e) == "5:nsubj|8:obj"
	e2 = parse(EnhancedDeps, "5.1:nsubj|3:obj")
	@test e2.deps[1].head == NodeRef(5, 1)
	@test is_empty_node(e2.deps[1].head)
	@test sprint(show, e2) == "5.1:nsubj|3:obj"
end

@testset "WordNode construction" begin
	w = WordNode(id = 1, form = "hello")
	@test w.id == 1
	@test w.id == NodeRef(1)
	@test w.form == "hello"
	@test w.lemma == "_"
	@test w.upos == "_"
	@test w.head == 0
	@test isempty(w.feats)
	@test isempty(w.deps)
	@test isempty(w.misc)
	w2 = WordNode(id = NodeRef(2), form = "world", head = 1)
	@test w2.id == 2
	@test w2.head == 1
end

@testset "MultiwordNode construction" begin
	mw = MultiwordNode(first = 2, last = 3, form = "don't")
	@test mw.first == 2
	@test mw.last == 3
	@test mw.form == "don't"
end

@testset "EmptyNode construction" begin
	en = EmptyNode(id = NodeRef(1, 1), form = "PRO")
	@test en.id == NodeRef(1, 1)
	@test en.id.major == 1
	@test en.id.minor == 1
	@test en.lemma == "_"
end

@testset "load and basic access" begin
	tb = load(sample_path)
	@test length(tb) == 4
	s1 = tb[1]
	@test sent_id(s1) == "weblog-1"
	@test UD.text(s1) == "I don't even know what to say about this place."
	@test length(s1) == 12
	@test length(multiwords(s1)) == 1
	mw = multiwords(s1)[1]
	@test mw.first == 2
	@test mw.last == 3
	@test mw.form == "don't"
	w1 = s1[1]
	@test w1.form == "I"
	@test w1.upos == "PRON"
	@test w1.head == 5
	@test w1.deprel == "nsubj"
	@test w1.feats["Case"] == "Nom"
	w5 = s1[5]
	@test w5.form == "know"
	@test w5.head == 0
	@test w5.deprel == "root"
	s3 = tb[3]
	@test sent_id(s3) == "weblog-3"
	@test length(s3) == 3
end

@testset "Sentence iteration" begin
	tb = load(sample_path)
	s1 = tb[1]
	forms = [w.form for w in s1]
	@test length(forms) == 12
	@test forms[1] == "I"
	@test forms[end] == "."
	@test count(w -> w.upos == "VERB", s1) == 2
end

@testset "Treebank iteration and slicing" begin
	tb = load(sample_path)
	@test length(tb) == 4
	sub = tb[1:2]
	@test sub isa Treebank
	@test length(sub) == 2
	ids = [sent_id(s) for s in tb]
	@test ids == ["weblog-1", "weblog-2", "weblog-3", "weblog-4"]
	filtered = filter(s -> length(s) > 3, tb)
	@test filtered isa Treebank
	@test length(filtered) == 3
end

@testset "tree traversal" begin
	tb = load(sample_path)
	s2 = tb[2]
	r = root(s2)
	@test r.form == "good"
	@test r.head == 0
	kids = children(s2, r.id)
	kid_deprels = sort([k.deprel for k in kids])
	@test "conj" in kid_deprels
	@test "punct" in kid_deprels
	st = subtree(s2, r.id)
	@test length(st) == length(s2) - 1
	det = s2[1]
	@test det.form == "The"
	h = head_of(s2, det)
	@test h.form == "food"
	@test isnothing(head_of(s2, r))
end

@testset "flat word iterator" begin
	tb = load(sample_path)
	all_words = collect(words(tb))
	expected = sum(length(s) for s in tb)
	@test length(all_words) == expected
	@test all_words[1].form == "I"
	@test all_words[end].form == "."
end

@testset "round-trip" begin
	tb = load(sample_path)
	output = IOBuffer()
	save(output, tb)
	original = read(sample_path, String)
	result = String(take!(output))
	@test result == original
end

@testset "write_sentence head=0 as zero" begin
	s = Sentence(words = [WordNode(id = 1, form = "Hi", head = 0, deprel = "root")])
	buf = IOBuffer()
	write_sentence(buf, s)
	line = split(String(take!(buf)), '\n')[1]
	fields = split(line, '\t')
	@test fields[7] == "0"
end

@testset "render smoke test" begin
	tb = load(sample_path)
	buf = IOBuffer()
	render(CompactStyle(), buf, tb[1])
	@test length(String(take!(buf))) > 0
	render(TableStyle(), buf, tb[1])
	@test length(String(take!(buf))) > 0
	render(AutoStyle(), buf, tb[1])
	@test length(String(take!(buf))) > 0
	render(buf, tb[1])
	@test length(String(take!(buf))) > 0
end

@testset "Tables.jl integration" begin
	using Tables
	tb = load(sample_path)
	@test Tables.istable(typeof(tb))
	@test Tables.rowaccess(typeof(tb))
	rows = collect(Tables.rows(tb))
	expected = sum(length(s) for s in tb)
	@test length(rows) == expected
	@test length(Tables.rows(tb)) == expected
	r1 = rows[1]
	@test r1.sentence_index == 1
	@test r1.id == 1
	@test r1.form == "I"
	@test r1.upos == "PRON"
	@test r1.head == 5
	@test r1.deprel == "nsubj"
	s = Tables.schema(tb)
	@test :sentence_index in s.names
	@test :form in s.names
	@test length(s.names) == 8
end

end
