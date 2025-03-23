/// Find the partition-intersection of multiple sets, i.e. a set partitioned into the largest possible subsets that are always in the same input sets
func partitionReduce<Symbol>(_ base: Set<Set<Symbol>>, _ with: Set<Symbol>) -> Set<Set<Symbol>> where Symbol: Hashable {
	let extra = with.subtracting(Set(base.flatMap { $0 }))
	return Set((base.flatMap { [ $0.intersection(with), $0.subtracting(with)] } + [extra]).filter { !$0.isEmpty })
}

/// Find the intersection of multiple alphabets; the partitioned set with the largest possible partitions such that each set contains all or none of the elements in each partition
func alphabetCombine<Symbol>(_ seq: any Sequence<Set<Symbol>>) -> Set<Set<Symbol>> where Symbol: Hashable {
	Set(seq.reduce(Set<Set<Symbol>>([]), partitionReduce))
}
