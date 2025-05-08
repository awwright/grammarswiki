import SwiftUI
import FSM

// TODO: Generate instances starting with a certain prefix, or matching a certain regex
// TODO: Exclude certain symbols or classes of symbols from generation
// TODO: Exclude certain rules from generation
// TODO: Generate negative instances and off-by-one errors

struct InstanceGeneratorView: View {
	@Binding var rule_fsm: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>?
	@State private var iterator: SymbolClassDFA<ClosedRangeAlphabet<UInt32>>.Iterator?
	@State private var instances: [String] = []

	var body: some View {
		VStack(alignment: .leading) {
			HStack {
				Button {
					generateMoreInstances()
				} label: {
					Label("More", systemImage: "arrowshape.forward")
				}
			}
			ScrollView {
				ForEach(instances, id: \.self) { instance in
					Text(instance)
						.border(Color.gray, width: 1)
						.frame(maxWidth: .infinity, alignment: .leading)
				}
			}
			HStack {
				Button {
					generateMoreInstances()
				} label: {
					Label("More", systemImage: "arrowshape.forward")
				}
			}
		}
		.onAppear { resetIterator() }
		.onChange(of: rule_fsm) { resetIterator() }
	}

	private func resetIterator() {
		if let fsm = rule_fsm {
			iterator = fsm.makeIterator()
			instances = []
			generateMoreInstances()
		} else {
			iterator = nil
			instances = []
		}
	}

	private func generateMoreInstances() {
		if var iterator {
			for _ in 0..<1000 {
				if let value: [UInt32] = iterator.next() {
					instances.append(String(decoding: value, as: Unicode.UTF32.self))
				} else {
					break
				}
			}
		}
	}
}
