
protocol FSM<Element>: PDAProtocol {
	associatedtype Element;
	associatedtype Symbol;
	associatedtype StateNo;
	associatedtype States;

//	associatedtype Symbol: Hashable;
	associatedtype ID;

	func get(states: Set<Int>, symbol: Symbol) -> Set<Symbol>;
	func get(states: Set<Int>, string: any Sequence<Symbol>) -> Set<Symbol>;
}

typealias FSMString<Symbol: Hashable> = Array<Symbol>;
typealias Homomorphism<S: Hashable, T: Hashable> = Dictionary<FSMString<S>, FSMString<T>>

