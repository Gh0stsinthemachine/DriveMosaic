import SwiftUI

/// The collector panel at the bottom of the window where users drag files for deletion.
struct CollectorView: View {
    @Binding var items: [CollectorItem]
    let isPro: Bool
    let onDelete: () -> Void
    let onUpgrade: () -> Void
    /// Resolves a dropped node ID string to a FileNode and adds it to the collector
    var onDropNodeID: ((String) -> Void)?

    @State private var isTargeted = false

    var totalSize: UInt64 {
        items.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            if items.isEmpty {
                // Empty collector — drop target hint
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line.compact")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Drop items here to collect for deletion")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(isTargeted ? Color.red.opacity(0.1) : Color.clear)
            } else {
                // Collector with items
                HStack(spacing: 12) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .foregroundStyle(.red)

                    // Item count and total size
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(items.count) item\(items.count == 1 ? "" : "s") collected")
                            .font(.callout)
                            .fontWeight(.medium)
                        Text(ByteFormatter.format(totalSize))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Spacer()

                    // Item pills (show first few)
                    HStack(spacing: 4) {
                        ForEach(items.prefix(5)) { item in
                            HStack(spacing: 3) {
                                Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                    .font(.caption2)
                                Text(item.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                                Button {
                                    items.removeAll { $0.id == item.id }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.quaternary, in: Capsule())
                        }

                        if items.count > 5 {
                            Text("+\(items.count - 5)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Action buttons
                    Button("Clear") {
                        withAnimation {
                            items.removeAll()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if isPro {
                        Button("Move to Trash") {
                            onDelete()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                    } else {
                        Button {
                            onUpgrade()
                        } label: {
                            Label("Upgrade to Delete", systemImage: "lock.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isTargeted ? Color.red.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
            }
        }
        .dropDestination(for: String.self) { droppedIDs, _ in
            for id in droppedIDs {
                onDropNodeID?(id)
            }
            return !droppedIDs.isEmpty
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}
