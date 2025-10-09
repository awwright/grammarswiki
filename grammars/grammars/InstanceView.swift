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

	@State private var settingsExpanded = false;
	@State private var settingsAlphabet = false;
	/// Of all the symbols from one state to another state, specifies the subset that should be included in generations, and which can be skipped
	@State private var settingsSymbolSelection = "First";
	/// Specifies how many times a state can be visited (zero loops = max once, one loop = max twice, etc).
	@State private var settingsLoopLimit = "0";
	/// Specifies which permutations should be considered unique, if a loop and symbol can be considered visited only if visited with the same previous input, or if the previous input can be ignored
	@State private var settingsPermutations = "state";
	/// When a loop allows a sufficient set of strings to be expressed, then include some realistic happy-path examples
	@State private var settingsSamples = "none";

	var body: some View {
		VStack(alignment: .leading) {
			HStack {
				Button {
					generateMoreInstances()
				} label: {
					Label("More", systemImage: "arrowshape.forward")
				}
			}
			DisclosureGroup ("Settings", isExpanded: $settingsExpanded){
				Form {
					// Options are listed in "less output to more output" order
					Toggle("Show Alphabet", isOn: $settingsAlphabet)
					Picker("Symbol selection", selection: $settingsSymbolSelection) {
						Text("First").tag("First") // For 0-9A-Za-z, this produces "0"
						Text("Last").tag("Last") // For 0-9A-Za-z, this produces "0" and "z"
						Text("Bounds").tag("Bounds") // For 0-9A-Za-z, this produces six symbols
						Text("All").tag("All") // Include every symbol
					}
					Picker("Loop limit", selection: $settingsLoopLimit) {
						Text("Zero").tag("0")
						Text("One").tag("1")
						Text("Two").tag("2")
						Text("Indefinite").tag("inf")
					}
					Picker("Permutations", selection: $settingsPermutations) {
						Text("Per state").tag("state")
						Text("Per path").tag("path")
					}
					Picker("Sample Strings", selection: $settingsSamples) {
						Text("None").tag("none")
						Text("Email addresses").tag("email")
						// Pick, like, the top 2 baby names every year for the last 75 years
						Text("Names (en-US)").tag("names-en-US")
						Text("Names (ja-JP)").tag("names-ja-JP")
					}
				}
				.formStyle(.grouped)
			}
			HStack {
				Spacer();

				// Allow a user to send generated instances over the network.
				// Allow listening as a server or connecting as a client.
				// Configure how the instances are delimited, e.g. per TCP connection, HTTP request, or by a special character or sequence.
				Button(
					"Network\u{2026}",
					systemImage: "network",
					action: {
					})
				.padding()

				Button(
					"Copy to Clipboard",
					systemImage: "document.on.document",
					action: {
					})
				.padding()

				Button(
					"Save As\u{2026}",
					systemImage: "square.and.arrow.down",
					action: {})
				.padding()
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
