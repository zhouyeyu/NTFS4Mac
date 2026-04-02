import SwiftUI

struct DeviceRow: View {
    let device: NTFSDevice
    let onMount: () -> Void
    let onUnmount: () -> Void
    let onRestore: () -> Void
    let onOpenInFinder: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            // Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.displayName)
                    .font(.headline)
                HStack(spacing: 12) {
                    Text(device.id)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(device.size)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Status badge
            Text(statusBadge)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(statusColor))

            // Open in Finder button (if mounted)
            if device.isMounted {
                Button(action: onOpenInFinder) {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Open in Finder")
            }

            // Action button (only if not RW)
            if !device.isReadWrite {
                Button("Mount RW") { onMount() }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }

    private var statusColor: Color {
        if !device.isMounted { return .gray }
        return device.isReadWrite ? .green : .orange
    }

    private var statusBadge: String {
        if device.isReadWrite { return "RW" }
        if device.isMounted { return "RO" }
        return "--"
    }
}
