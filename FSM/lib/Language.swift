// A Language is a set of strings (usually infinite, possibly requiring compute) where you can determine the membership of some string in the set.
// A Grammar e.g. CFG is in contrast a method of generating strings in a language.

public protocol DecidableLanguage {
	associatedtype Alphabet: AlphabetProtocol;
	func contains(_ string: Array<Alphabet.Symbol>) -> Bool;
}

public protocol CFL: DecidableLanguage {

}
