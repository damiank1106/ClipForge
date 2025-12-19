import SwiftUI
import AVKit

struct EditorWorkspaceView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        VStack(spacing: 12) {
            PreviewPane()
                .frame(maxWidth: .infinity, maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

            PlaybackControls()
                .padding(.horizontal)

            TimelineView()
                .padding(.horizontal)

            InspectorPane()
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

private struct PlaybackControls: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        HStack(spacing: 12) {
            Button(store.isPlaying ? "Pause" : "Play") {
                store.togglePlay()
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.player == nil)

            Button("Seek 0") {
                store.seek(to: 0)
            }
            .buttonStyle(.bordered)
            .disabled(store.player == nil)

            Spacer()

            Text("\(store.playheadSeconds, specifier: "%.2f")s")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PreviewPane: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(.thinMaterial)

            if let player = store.player {
                VideoPlayer(player: player)
            } else {
                ContentUnavailableView(
                    "No Preview",
                    systemImage: "film",
                    description: Text("Import a video, then tap Add to put it on the timeline.")
                )
            }
        }
    }
}

private struct InspectorPane: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Inspector").font(.headline)
                    Spacer()
                    if let clip = store.selectedClip {
                        Text(clip.name).foregroundStyle(.secondary)
                    } else {
                        Text("Nothing selected").foregroundStyle(.secondary)
                    }
                }

                if let clip = store.selectedClip {
                    ClipInspector(clip: clip)
                } else {
                    Text("Select a clip in the timeline to edit properties.")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ClipInspector: View {
    @EnvironmentObject private var store: EditorStore
    let clip: Clip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper(
                "Start: \(clip.startTime, specifier: "%.2f")s",
                value: Binding(
                    get: { clip.startTime },
                    set: { newValue in
                        store.setClipStart(clipID: clip.id, start: max(0, newValue))
                    }
                ),
                in: 0...10_000,
                step: 0.1
            )

            Stepper(
                "Duration: \(clip.duration, specifier: "%.2f")s",
                value: Binding(
                    get: { clip.duration },
                    set: { newValue in
                        store.setClipDuration(clipID: clip.id, duration: max(0.1, newValue))
                    }
                ),
                in: 0.1...10_000,
                step: 0.1
            )

            Picker(
                "Filter",
                selection: Binding(
                    get: { clip.primaryFilter ?? EditorFilter.none },
                    set: { f in
                        store.setClipPrimaryFilter(clipID: clip.id, filter: f == EditorFilter.none ? nil : f)
                    }
                )
            ) {
                ForEach(EditorFilter.allCases, id: \.self) { f in
                    Text(f.displayName).tag(f)
                }
            }
        }
    }
}

