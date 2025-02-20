
protocol PDAProtocol<Symbol> {
	associatedtype Symbol: Hashable;
	func getAll(states: Set<Int>, symbol: Symbol) -> Set<Symbol>;
	func getAll(states: Set<Int>, string: any Sequence<Symbol>) -> Set<Symbol>;
}

//class PDA<Symbol>: PDAProtocol {
//	typealias Symbol = Symbol;
//
//	func getAll(states: Set<Int>, symbol: Symbol) -> Set<Symbol> {
//		return Set<Symbol>(self.get(states: states, symbol: symbol));
//	}
//	func getAll(states: Set<Int>, string: any Sequence<Symbol>) -> Set<Symbol> {
//
//	}
//
//}
