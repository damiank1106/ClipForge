import SwiftUI
import PhotosUI

struct MediaLibraryView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ✅ Reliable PhotosPicker in the sidebar
            PhotosPicker(
                selection: $store.importSelection,
                maxSelectionCount: 10,
                matching: .any(of: [.videos, .images])
            ) {
                Label("Import Media", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)

            Text("Imported")
                .font(.headline)
                .padding(.top, 6)

            if store.mediaAssets.isEmpty {
                Text("No media yet. Tap Import Media.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                List {
                    ForEach(store.mediaAssets) { asset in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(asset.displayName).font(.headline)
                                Text(asset.durationText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Add") { store.addToTimeline(asset: asset) }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 6)
                    }
                }
                .listStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding()
    }
}
