import SwiftUI
import PhotosUI

struct RootView: View {
    @EnvironmentObject private var store: EditorStore

    var body: some View {
        NavigationSplitView {
            MediaLibraryView()
                .navigationTitle("Media")
        } detail: {
            EditorWorkspaceView()
                .navigationTitle("ClipForge")
        }
        // When PhotosPicker updates selection, move it into the store's "pendingImportItems"
        // and present the confirm sheet.
        .onChange(of: store.importSelection.count) { _, newCount in
            guard newCount > 0 else { return }
            store.beginImportFlowFromPickerIfNeeded()
        }
        .sheet(isPresented: $store.isShowingImportConfirm) {
            ImportConfirmSheet(
                count: store.pendingImportCount,
                onCancel: { store.cancelImport() },
                onImport: { Task { await store.confirmImport() } }
            )
        }
        .alert("ClipForge", isPresented: $store.showExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(store.exportAlertMessage)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {

                // ✅ Reliable: real PhotosPicker control in the toolbar
                PhotosPicker(
                    selection: $store.importSelection,
                    maxSelectionCount: 10,
                    matching: .any(of: [.videos, .images])
                ) {
                    Image(systemName: "plus")
                }

                Button {
                    store.newProject()
                } label: {
                    Image(systemName: "doc.badge.plus")
                }

                Button {
                    store.saveProject()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }

                Button {
                    Task { await store.generateCaptionsForSelection() }
                } label: {
                    Image(systemName: "captions.bubble")
                }
                .disabled(store.selectedClip == nil)

                Button {
                    Task { await store.exportCurrentSequence() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(store.isExporting || (store.currentSequence?.clips.isEmpty ?? true))

                Menu {
                    Button("New Project") { store.newProject() }
                    Button("Save Project") { store.saveProject() }

                    Divider()

                    Button("Generate Captions (Beta)") {
                        Task { await store.generateCaptionsForSelection() }
                    }
                    .disabled(store.selectedClip == nil)

                    Divider()

                    Button("Undo") { store.undo() }
                        .disabled(!store.canUndo)

                    Button("Redo") { store.redo() }
                        .disabled(!store.canRedo)

                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
}
