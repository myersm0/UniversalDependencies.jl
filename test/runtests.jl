using Test
using UniversalDependencies
const UD = UniversalDependencies

const sample_path = joinpath(@__DIR__, "sample.conllu")

@testset "UniversalDependencies" begin

@testset "Features" begin
	f = parse(UD.Features, "Number=Sing|Person=3|Tense=Past")
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
	empty_f = parse(UD.Features, "_")
	@test isempty(empty_f)
	@test sprint(show, empty_f) == "_"
	@test sprint(show, parse(UD.Features, "A=1|B=2")) == "A=1|B=2"
	@test sprint(show, parse(UD.Features, "B=2|A=1")) == "A=1|B=2"
end

@testset "NodeRef" begin
	n1 = parse(UD.NodeRef, "5")
	@test n1.major == 5
	@test n1.minor == 0
	@test !UD.is_empty_node(n1)
	@test sprint(show, n1) == "5"
	n2 = parse(UD.NodeRef, "5.1")
	@test n2.major == 5
	@test n2.minor == 1
	@test UD.is_empty_node(n2)
	@test sprint(show, n2) == "5.1"
	@test n1 != n2
	@test parse(UD.NodeRef, "5") == parse(UD.NodeRef, "5")
	@test n1 == 5
	@test 5 == n1
	@test n1 != 3
	@test n2 != 5
	@test UD.NodeRef(3) < UD.NodeRef(5)
	@test UD.NodeRef(5, 0) < UD.NodeRef(5, 1)
	@test UD.NodeRef(5, 1) < UD.NodeRef(5, 2)
end

@testset "EnhancedDeps" begin
	e = parse(UD.EnhancedDeps, "5:nsubj|8:obj")
	@test length(e) == 2
	@test e.deps[1].head == UD.NodeRef(5)
	@test e.deps[1].deprel == "nsubj"
	@test e.deps[2].head == UD.NodeRef(8)
	empty_e = parse(UD.EnhancedDeps, "_")
	@test isempty(empty_e)
	@test sprint(show, empty_e) == "_"
	@test sprint(show, e) == "5:nsubj|8:obj"
	e2 = parse(UD.EnhancedDeps, "5.1:nsubj|3:obj")
	@test e2.deps[1].head == UD.NodeRef(5, 1)
	@test UD.is_empty_node(e2.deps[1].head)
	@test sprint(show, e2) == "5.1:nsubj|3:obj"
end

@testset "Node construction" begin
	w = UD.Node(id = 1, form = "hello")
	@test w.id == 1
	@test w.id == UD.NodeRef(1)
	@test w.form == "hello"
	@test w.lemma == "_"
	@test w.upos == "_"
	@test w.head == 0
	@test isempty(w.feats)
	@test isempty(w.deps)
	@test isempty(w.misc)
	w2 = UD.Node(id = UD.NodeRef(2), form = "world", head = 1)
	@test w2.id == 2
	@test w2.head == 1
end

@testset "MWTNode construction" begin
	mw = UD.MWTNode(first = 2, last = 3, form = "don't")
	@test mw.first == 2
	@test mw.last == 3
	@test mw.form == "don't"
end

@testset "EmptyNode construction" begin
	en = UD.EmptyNode(id = UD.NodeRef(1, 1), form = "PRO")
	@test en.id == UD.NodeRef(1, 1)
	@test en.id.major == 1
	@test en.id.minor == 1
	@test en.lemma == "_"
end

@testset "load and basic access" begin
	tb = UD.load(sample_path)
	@test length(tb) == 4
	s1 = tb[1]
	@test UD.sent_id(s1) == "weblog-1"
	@test UD.id(s1) == "weblog-1"
	@test UD.text(s1) == "I don't even know what to say about this place."
	@test length(s1) == 12
	@test length(UD.multitokens(s1)) == 1
	mw = UD.multitokens(s1)[1]
	@test mw.first == 2
	@test mw.last == 3
	@test UD.form(mw) == "don't"
	@test UD.id(mw) === nothing
	w1 = s1[1]
	@test UD.id(w1) == 1
	@test UD.form(w1) == "I"
	@test UD.lemma(w1) == "I"
	@test UD.upos(w1) == "PRON"
	@test UD.xpos(w1) == "PRP"
	@test UD.head(w1) == 5
	@test UD.deprel(w1) == "nsubj"
	@test UD.feats(w1)["Case"] == "Nom"
	@test UD.misc(w1) isa UD.Features
	w5 = s1[5]
	@test UD.form(w5) == "know"
	@test UD.head(w5) == 0
	@test UD.deprel(w5) == "root"
	s3 = tb[3]
	@test UD.sent_id(s3) == "weblog-3"
	@test length(s3) == 3
end

@testset "Sentence iteration" begin
	tb = UD.load(sample_path)
	s1 = tb[1]
	forms = [w.form for w in s1]
	@test length(forms) == 12
	@test forms[1] == "I"
	@test forms[end] == "."
	@test count(w -> w.upos == "VERB", s1) == 2
end

@testset "Treebank iteration and slicing" begin
	tb = UD.load(sample_path)
	@test length(tb) == 4
	sub = tb[1:2]
	@test sub isa UD.Treebank
	@test length(sub) == 2
	ids = [UD.sent_id(s) for s in tb]
	@test ids == ["weblog-1", "weblog-2", "weblog-3", "weblog-4"]
	filtered = filter(s -> length(s) > 3, tb)
	@test filtered isa UD.Treebank
	@test length(filtered) == 3
end

@testset "tree traversal" begin
	tb = UD.load(sample_path)
	s2 = tb[2]
	r = UD.root(s2)
	@test r.form == "good"
	@test r.head == 0
	kids = UD.children(s2, r.id)
	kid_deprels = sort([k.deprel for k in kids])
	@test "conj" in kid_deprels
	@test "punct" in kid_deprels
	st = UD.subtree(s2, r.id)
	@test length(st) == length(s2) - 1
	det = s2[1]
	@test det.form == "The"
	h = UD.head_of(s2, det)
	@test h.form == "food"
	@test isnothing(UD.head_of(s2, r))
end

@testset "flat word iterator" begin
	tb = UD.load(sample_path)
	all_words = collect(UD.words(tb))
	expected = sum(length(s) for s in tb)
	@test length(all_words) == expected
	@test all_words[1].form == "I"
	@test all_words[end].form == "."
end

@testset "round-trip" begin
	tb = UD.load(sample_path)
	output = IOBuffer()
	UD.save(output, tb)
	original = read(sample_path, String)
	result = String(take!(output))
	@test result == original
end

@testset "write_sentence head=0 as zero" begin
	s = UD.Sentence(words = [UD.Node(id = 1, form = "Hi", head = 0, deprel = "root")])
	buf = IOBuffer()
	UD.write_sentence(buf, s)
	line = split(String(take!(buf)), '\n')[1]
	fields = split(line, '\t')
	@test fields[7] == "0"
end

@testset "render smoke test" begin
	tb = UD.load(sample_path)
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

@testset "enhanced deprel with colon in relation name" begin
	e = parse(UD.EnhancedDeps, "3:nmod:in|5:obl:in_front_of")
	@test length(e) == 2
	@test e.deps[1].head == UD.NodeRef(3)
	@test e.deps[1].deprel == "nmod:in"
	@test e.deps[2].head == UD.NodeRef(5)
	@test e.deps[2].deprel == "obl:in_front_of"
	@test sprint(show, e) == "3:nmod:in|5:obl:in_front_of"
end

@testset "empty node round-trip" begin
	conllu = """
# sent_id = empty-test
# text = I like coffee.
1\tI\tI\tPRON\tPRP\tCase=Nom\t2\tnsubj\t2:nsubj\t_
2\tlike\tlike\tVERB\tVBP\t_\t0\troot\t0:root\t_
2.1\tlike\tlike\tVERB\tVBP\t_\t_\t_\t0:root\t_
3\tcoffee\tcoffee\tNOUN\tNN\tNumber=Sing\t2\tobj\t2:obj|2.1:obj\tSpaceAfter=No
4\t.\t.\tPUNCT\t.\t_\t2\tpunct\t2:punct\t_

"""
	tb = UD.load(IOBuffer(conllu))
	@test length(tb) == 1
	s = tb[1]
	@test length(s) == 4
	@test length(UD.empties(s)) == 1
	en = UD.empties(s)[1]
	@test en.id == UD.NodeRef(2, 1)
	@test en.form == "like"
	@test en.upos == "VERB"
	w3 = s[3]
	@test w3.deps.deps[2].head == UD.NodeRef(2, 1)
	@test w3.deps.deps[2].deprel == "obj"
	buf = IOBuffer()
	UD.save(buf, tb)
	result = String(take!(buf))
	@test result == conllu
end

@testset "Tables.jl integration" begin
	using Tables
	tb = UD.load(sample_path)
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
