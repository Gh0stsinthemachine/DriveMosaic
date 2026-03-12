import SwiftUI

/// Shows available volumes with usage bars and a "Choose Folder" option.
struct DiskSelectorView: View {
    let onScanVolume: (String) -> Void
    let onChooseFolder: () -> Void

    @State private var volumes: [VolumeDetector.Volume] = []
    @State private var hasFDA = true

    var body: some View {
        VStack(spacing: 0) {
            // FDA warning banner
            if !hasFDA {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(.orange)
                    Text("Full Disk Access not granted. Some areas may be restricted.")
                        .font(.caption)
                    Spacer()
                    Button("Open Settings") {
                        FullDiskAccessChecker.openSystemSettings()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))

                Divider()
            }

            ScrollView {
                VStack(spacing: 16) {
                    // Volumes grid
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 400))], spacing: 12) {
                        ForEach(volumes) { volume in
                            VolumeCard(volume: volume) {
                                onScanVolume(volume.mountPoint)
                            }
                        }
                    }
                    .padding(.top, 20)

                    // Choose folder button
                    Button(action: onChooseFolder) {
                        Label("Choose Folder...", systemImage: "folder.badge.plus")
                            .font(.callout)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
            }
        }
        .onAppear {
            volumes = VolumeDetector.detectVolumes()
            hasFDA = FullDiskAccessChecker.hasFullDiskAccess
        }
    }
}

// MARK: - Volume Card

struct VolumeCard: View {
    let volume: VolumeDetector.Volume
    let onScan: () -> Void

    var body: some View {
        Button(action: onScan) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: volumeIcon)
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(volume.name)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(volume.mountPoint)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(usageColor)
                            .frame(width: geo.size.width * volume.usedFraction)
                    }
                }
                .frame(height: 8)

                // Size labels
                HStack {
                    Text("\(ByteFormatter.format(volume.usedBytes)) used")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(ByteFormatter.format(volume.freeBytes)) free")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(ByteFormatter.format(volume.totalBytes)) total")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.quaternary, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var volumeIcon: String {
        if volume.isRemovable { return "externaldrive.fill" }
        if volume.mountPoint == "/" { return "internaldrive.fill" }
        return "externaldrive.fill"
    }

    private var usageColor: Color {
        if volume.usedFraction > 0.9 { return .red }
        if volume.usedFraction > 0.75 { return .orange }
        return .blue
    }
}
