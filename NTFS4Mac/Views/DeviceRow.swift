import SwiftUI

struct DeviceRow: View {
    let device: NTFSDevice
    let onMount: () -> Void
    let onUnmount: () -> Void
    let onRestore: () -> Void

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
                    if device.mountPoint != nil {
                        Text(device.statusText)
                            .font(.caption)
                            .foregroundStyle(statusColor)
                    }
                }
            }

            Spacer()

            // Action buttons
            HStack(spacing: 8) {
                if !device.isMounted {
                    Button("Mount RW") { onMount() }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                        .controlSize(.small)
                } else if device.isReadWrite {
                    Button("Restore RO") { onRestore() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button("Unmount") { onUnmount() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    Text("Read-Only")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Button("Mount RW") { onMount() }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                        .controlSize(.small)
                }
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
}
