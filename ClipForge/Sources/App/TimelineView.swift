import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        let clips = store.currentSequence?.clips.sorted(by: { $0.startTime < $1.startTime }) ?? []

        GroupBox("Timeline") {
            if clips.isEmpty {
                Text("No clips yet. Import a video, then tap Add.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    ForEach(clips) { clip in
                        TimelineClipRow(clip: clip)
                    }
                }
            }
        }
    }
}

private struct TimelineClipRow: View {
    @EnvironmentObject private var store: EditorStore
    let clip: Clip

    @State private var dragOldStart: Double?
    @State private var dragStartX: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button {
                    store.selection.select(clip: clip)
                } label: {
                    Text("Select")
                }
                .buttonStyle(.bordered)

                Spacer()

                Text(String(format: "Start %.2fs  Dur %.2fs", clip.startTime, clip.duration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Drag to move clip start
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.secondary.opacity(0.15))
                    .frame(height: 22)

                RoundedRectangle(cornerRadius: 10)
                    .fill(.blue.opacity(0.45))
                    .frame(width: max(40, min(320, clip.duration * 60)), height: 22)
                    .offset(x: CGFloat(min(320, clip.startTime * 60)))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragOldStart == nil {
                                    dragOldStart = clip.startTime
                                    dragStartX = value.startLocation.x
                                }
                                let dx = value.location.x - dragStartX
                                let proposed = max(0, (dragOldStart ?? 0) + Double(dx / 60.0))
                                let snapped = store.snap(time: proposed, excludingClipID: clip.id)
                                store.setClipStartPreview(clipID: clip.id, start: snapped)
                            }
                            .onEnded { _ in
                                let old = dragOldStart ?? clip.startTime
                                let newStart = store.currentSequence?.clips.first(where: { $0.id == clip.id })?.startTime ?? clip.startTime
                                dragOldStart = nil
                                store.commitClipStartMove(clipID: clip.id, oldStart: old, newStart: newStart)
                            }
                    )
            }

            // Trim
            Slider(
                value: Binding(
                    get: { clip.duration },
                    set: { store.setClipDuration(clipID: clip.id, duration: max(0.2, $0)) }
                ),
                in: 0.2...max(0.2, clip.duration + 10)
            )
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

