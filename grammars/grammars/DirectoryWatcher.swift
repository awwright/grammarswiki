import Foundation
import Dispatch

/// A mechanism for knowing when to re-load the catalog list if the directory changes due to external editing
class DirectoryWatcher {
	private let url: URL
	private let queue: DispatchQueue
	private var fileDescriptor: CInt = -1
	private var source: DispatchSourceFileSystemObject?

	var onChange: (() -> Void)?

	init(url: URL, queue: DispatchQueue = .global(qos: .default)) {
		self.url = url;
		self.queue = queue;
	}

	func start() throws {
		// Open directory with O_EVTONLY (event-only, low overhead)
		fileDescriptor = open(url.path, O_EVTONLY);
		guard fileDescriptor >= 0 else {
			throw NSError(domain: "DirectoryWatcher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open directory"]);
		}

		// Create the dispatch source
		source = DispatchSource.makeFileSystemObjectSource(
			fileDescriptor: fileDescriptor,
			eventMask: [.write, .rename, .delete],  // .write catches most filename/content changes
			queue: queue,
		);

		source?.setEventHandler { [weak self] in
			self?.onChange?();

			// Optional: You can get more details by checking which events fired
			if let data = self?.source?.data {
				print("Events: \(data)");
			}
		}

		source?.setCancelHandler { [weak self] in
			if let fd = self?.fileDescriptor, fd >= 0 {
				close(fd);
				self?.fileDescriptor = -1;
			}
		}

		source?.resume();
	}

	func stop() {
		source?.cancel();
		source = nil;
	}

	deinit {
		stop();
	}
}
