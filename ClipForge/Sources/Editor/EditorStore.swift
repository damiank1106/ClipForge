import Foundation
import SwiftUI
import AVFoundation
import AVKit
import PhotosUI
import Combine

@MainActor
final class EditorStore: ObservableObject {

    // Fixes ObservableObject conformance under newer Swift concurrency rules
    nonisolated let objectWillChange = ObservableObjectPublisher()

    // MARK: - UI State
    @Published var project: Project?
    @Published var mediaAssets: [MediaAsset] = []
    @Published var selection: EditorSelection = .init()

    // MARK: - Import flow (iPad-friendly)
    @Published var isShowingImporter: Bool = false
    @Published var importSelection: [PhotosPickerItem] = []

    @Published var isShowingImportConfirm: Bool = false
    @Published var isImporting: Bool = false
    @Published private(set) var pendingImportCount: Int = 0
    private var pendingImportItems: [PhotosPickerItem] = []

    // Playback
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var playheadSeconds: Double = 0

    // Export / alerts
    @Published var isExporting: Bool = false
    @Published var showExportAlert: Bool = false
    @Published var exportAlertMessage: String = ""

    private let storage = ProjectStorage()
    private let mediaService = MediaImportService()
    private let engine = EditorEngine()
    private let exporter = ExportService()
    private let captions = CaptionService()

    private var playheadTimer: Timer?
    private var debounceTask: Task<Void, Never>?
    private var rebuildTask: Task<Void, Never>?

    // Undo/Redo
    private(set) var commands = CommandStack()
    var canUndo: Bool { commands.canUndo }
    var canRedo: Bool { commands.canRedo }

    deinit {
        playheadTimer?.invalidate()
        debounceTask?.cancel()
        rebuildTask?.cancel()
    }

    // MARK: - Boot
    func bootstrap() async {
        if let loaded = storage.loadMostRecentProject() {
            self.project = loaded
        } else {
            newProject()
        }
        rebuildPreviewComposition()
    }

    // MARK: - Project ops
    func newProject() {
        let p = Project.makeNew(name: "ClipForge Project")
        self.project = p
        selection.clear()
        commands = CommandStack()
        storage.save(project: p)
        rebuildPreviewComposition()
    }

    func saveProject() {
        guard let project else { return }
        storage.save(project: project)
    }

    func saveProjectDebounced() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 400_000_000)
            await MainActor.run { self?.saveProject() }
        }
    }

    // MARK: - Import
    func requestImport() {
        isShowingImporter = true
    }

    /// Called after the PhotosPicker dismisses.
    func beginImportFlowFromPickerIfNeeded() {
        guard !importSelection.isEmpty else { return }
        guard !isShowingImportConfirm else { return }

        pendingImportItems = importSelection
        pendingImportCount = pendingImportItems.count

        importSelection.removeAll()
        isShowingImportConfirm = true
    }

    func cancelImportFlow() {
        pendingImportItems.removeAll()
        pendingImportCount = 0
        importSelection.removeAll()
        isShowingImportConfirm = false
    }

    /// Backwards-compatible name used by some views.
    func cancelImport() {
        cancelImportFlow()
    }

    func confirmImport() async {
        let items = pendingImportItems
        pendingImportItems.removeAll()
        pendingImportCount = 0
        isShowingImportConfirm = false
        importSelection.removeAll()

        guard !items.isEmpty else { return }

        isImporting = true
        defer { isImporting = false }

        do {
            for item in items {
                let asset = try await mediaService.importVideo(from: item)
                mediaAssets.insert(asset, at: 0)
            }
        } catch {
            exportAlertMessage = "Import failed: \(error.localizedDescription)"
            showExportAlert = true
        }
    }

    // MARK: - Timeline helpers
    var currentSequence: Sequence? { project?.sequences.first }
    var currentTracks: [Track] { currentSequence?.tracks ?? [] }

    var selectedClip: Clip? {
        guard let id = selection.selectedClipID else { return nil }
        return currentSequence?.clips.first(where: { $0.id == id })
    }

    var sequenceDuration: Double {
        guard let seq = currentSequence else { return 0 }
        return max(0.01, seq.clips.map { $0.startTime + $0.duration }.max() ?? 0.01)
    }

    func addToTimeline(asset: MediaAsset) {
        guard var project else { return }
        guard let seqID = project.sequences.first?.id else { return }

        guard let trackID = project.sequences.first?.tracks.first(where: { $0.kind == .video })?.id else {
            exportAlertMessage = "This project has NO VIDEO track. Fix Project.makeNew to create a .video track."
            showExportAlert = true
            return
        }

        let clip = Clip.makeFromMedia(asset: asset, trackID: trackID, startTime: 0)
        let cmd = AddClipCommand(sequenceID: seqID, clip: clip)
        commands.apply(cmd, to: &project)

        self.project = project
        selection.select(clip: clip)

        rebuildPreviewComposition()
        saveProjectDebounced()
    }

    func setClipStartPreview(clipID: UUID, start: Double) {
        guard var project else { return }
        guard let seqID = currentSequence?.id else { return }

        project.mutateSequence(seqID) { seq in
            guard let idx = seq.clips.firstIndex(where: { $0.id == clipID }) else { return }
            seq.clips[idx].startTime = start
        }

        self.project = project
    }

    func commitClipStartMove(clipID: UUID, oldStart: Double, newStart: Double) {
        guard var project else { return }
        guard let seqID = currentSequence?.id else { return }

        let cmd = SetClipStartCommand(sequenceID: seqID, clipID: clipID, oldStart: oldStart, newStart: newStart)
        commands.apply(cmd, to: &project)

        self.project = project
        rebuildPreviewComposition()
        saveProjectDebounced()
    }

    func setClipStart(clipID: UUID, start: Double, rebuildPreview: Bool = true) {
        guard var project else { return }
        guard let seqID = currentSequence?.id else { return }

        let old = currentSequence?.clips.first(where: { $0.id == clipID })?.startTime ?? start
        let cmd = SetClipStartCommand(sequenceID: seqID, clipID: clipID, oldStart: old, newStart: start)
        commands.apply(cmd, to: &project)

        self.project = project
        if rebuildPreview { rebuildPreviewComposition() }
        saveProjectDebounced()
    }

    func setClipDuration(clipID: UUID, duration: Double) {
        guard var project else { return }
        guard let seqID = currentSequence?.id else { return }

        let oldDur = currentSequence?.clips.first(where: { $0.id == clipID })?.duration ?? duration
        let oldSrc = currentSequence?.clips.first(where: { $0.id == clipID })?.sourceDuration ?? duration

        let cmd = SetClipDurationCommand(
            sequenceID: seqID,
            clipID: clipID,
            oldDuration: oldDur,
            oldSourceDuration: oldSrc,
            newDuration: duration
        )
        commands.apply(cmd, to: &project)

        self.project = project
        rebuildPreviewComposition()
        saveProjectDebounced()
    }

    func setClipPrimaryFilter(clipID: UUID, filter: EditorFilter?) {
        guard var project else { return }
        guard let seqID = currentSequence?.id else { return }

        let old = currentSequence?.clips.first(where: { $0.id == clipID })?.primaryFilter
        let cmd = SetClipPrimaryFilterCommand(sequenceID: seqID, clipID: clipID, oldFilter: old, newFilter: filter)
        commands.apply(cmd, to: &project)

        self.project = project
        rebuildPreviewComposition()
        saveProjectDebounced()
    }

    // MARK: - Snapping
    func snap(time: Double, excludingClipID: UUID?) -> Double {
        var candidates: [Double] = [round(time)]

        if let seq = currentSequence {
            for c in seq.clips where c.id != excludingClipID {
                candidates.append(c.startTime)
                candidates.append(c.startTime + c.duration)
            }
        }

        let threshold = 0.12
        var best = time
        var bestDist = Double.infinity

        for cand in candidates {
            let d = abs(cand - time)
            if d < threshold && d < bestDist {
                bestDist = d
                best = cand
            }
        }
        return best
    }

    // MARK: - Preview build
    func rebuildPreviewComposition() {
        rebuildTask?.cancel()
        rebuildTask = Task { @MainActor in
            await rebuildPreviewCompositionAsync()
        }
    }

    private func rebuildPreviewCompositionAsync() async {
        guard let project, let seq = project.sequences.first else {
            stopPlaybackAndClearPlayer()
            return
        }

        // Avoid FigFilePlayer err when timeline empty
        if seq.clips.isEmpty {
            stopPlaybackAndClearPlayer()
            return
        }

        do {
            let build = try await engine.buildPlayableAsset(project: project, sequence: seq)
            let item = AVPlayerItem(asset: build.asset)

            if let vc = build.videoComposition,
               vc.renderSize.width > 0,
               vc.renderSize.height > 0 {
                item.videoComposition = vc
            }

            self.player = AVPlayer(playerItem: item)
            hookPlayerTime()
        } catch {
            stopPlaybackAndClearPlayer()
            exportAlertMessage = "Preview build failed: \(error.localizedDescription)"
            showExportAlert = true
        }
    }

    private func stopPlaybackAndClearPlayer() {
        playheadTimer?.invalidate()
        playheadTimer = nil

        player?.pause()
        player = nil

        isPlaying = false
        playheadSeconds = 0
    }

    func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
        hookPlayerTime()
    }

    func seek(to seconds: Double) {
        guard let player else { return }
        let t = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func hookPlayerTime() {
        playheadTimer?.invalidate()
        guard let player else { return }

        playheadTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            let sec = player.currentTime().seconds
            Task { @MainActor in
                self.playheadSeconds = max(0, sec.isFinite ? sec : 0)
                self.isPlaying = player.timeControlStatus == .playing
            }
        }
    }

    // MARK: - Undo / Redo
    func undo() {
        guard var project else { return }
        commands.undo(on: &project)
        self.project = project
        rebuildPreviewComposition()
        saveProjectDebounced()
    }

    func redo() {
        guard var project else { return }
        commands.redo(on: &project)
        self.project = project
        rebuildPreviewComposition()
        saveProjectDebounced()
    }

    // MARK: - Export
    func exportCurrentSequence() async {
        guard let project, let seq = project.sequences.first else { return }
        isExporting = true
        defer { isExporting = false }

        do {
            let outputURL = try await exporter.export(project: project, sequence: seq)
            exportAlertMessage = "Export complete: \(outputURL.lastPathComponent)\nSaved to Files (Documents)."
            showExportAlert = true
        } catch {
            exportAlertMessage = "Export failed: \(error.localizedDescription)"
            showExportAlert = true
        }
    }

    // MARK: - Captions (beta)
    func generateCaptionsForSelection() async {
        guard let clip = selectedClip else { return }
        guard let url = clip.mediaURL else { return }

        do {
            let srt = try await captions.transcribeToSRT(url: url)
            exportAlertMessage = "Captions generated (SRT).\n\n\(srt.prefix(300))..."
            showExportAlert = true
        } catch {
            exportAlertMessage = "Captions failed: \(error.localizedDescription)"
            showExportAlert = true
        }
    }
}

