import Testing
@testable import TextMorph

@Suite("The longest common subsequence")
struct LcsTests {
    @Test("Pairs the elements that survive, in order")
    func pairsSurvivors() {
        let (a, b) = lcsIndices(["the", "quick", "brown", "fox"], ["the", "brown", "fox"])
        #expect(a == [0, 2, 3])
        #expect(b == [0, 1, 2])
    }

    @Test("An empty sequence pairs with nothing")
    func emptyInputs() {
        #expect(lcsIndices([String](), ["a"]) == ([], []))
        #expect(lcsIndices(["a"], [String]()) == ([], []))
        #expect(lcsIndices([String](), [String]()) == ([], []))
    }

    @Test("A repeated element pairs with the earliest match, not the latest")
    func tiesGoToTheEarliestMatch() {
        // This is the whole reason the table is filled backwards and walked
        // forwards. Paired with the later "a", the segment would travel the
        // width of the value to reach it.
        let (a, b) = lcsIndices(["a", "x", "a"], ["a", "y"])
        #expect(a == [0])
        #expect(b == [0])

        let (c, d) = lcsIndices(["a", "b"], ["a", "z", "a"])
        #expect(c == [0])
        #expect(d == [0])
    }

    @Test("Nothing in common pairs nothing")
    func disjoint() {
        #expect(lcsIndices(["a", "b"], ["c", "d"]) == ([], []))
    }

    @Test("Identical sequences pair completely")
    func identical() {
        let words = ["one", "two", "three"]
        let (a, b) = lcsIndices(words, words)
        #expect(a == [0, 1, 2])
        #expect(b == [0, 1, 2])
    }

    @Test("Works per character, which is how a word morphs into another")
    func charactersWithinAWord() {
        let old = Array("balance")
        let new = Array("banana")
        let (a, b) = lcsIndices(old, new)
        #expect(a.map { old[$0] } == b.map { new[$0] })
        // b, a, a, n: "bana" is not a subsequence of "balance", because
        // nothing follows its only "n".
        #expect(String(a.map { old[$0] }) == "baan")
        #expect(a == [0, 1, 3, 4])
        #expect(b == [0, 1, 3, 4])
    }
}
