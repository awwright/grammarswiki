import SwiftUI
import FSM

struct InstanceGeneratorView: View {
	@Binding var rule_fsm: DFA<UInt32>?
	@State private var iterator: DFA<UInt32>.Iterator?
	@State private var instances: [String] = []

	var body: some View {
		VStack(alignment: .leading) {
			HStack {
				Button {
					resetIterator()
				} label: {
					Label("Reset", systemImage: "restart")
				}
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
