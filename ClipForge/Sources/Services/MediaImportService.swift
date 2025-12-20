import Foundation
import SwiftUI           // Required for PhotosPickerItem visibility
import PhotosUI          // Required for the picker itself
import AVFoundation
import CoreTransferable  // Required for the .loadTransferable method
import UniformTypeIdentifiers

enum MediaImportError: Error {
    case failedToLoad
    case failedToCopy
}

final class MediaImportService {

    /// Imports a picked media item into the app's Documents/ClipForge/Media folder and returns a MediaAsset.
    @MainActor
    func importMedia(from item: PhotosPickerItem) async throws -> MediaAsset {
        let preferredExt = preferredExtension(for: item)

        // Preferred path: load a temporary file URL from PhotosPicker
        if let sourceURL = try await item.loadTransferable(type: URL.self) {
            let didAccess = sourceURL.startAccessingSecurityScopedResource()
            defer { if didAccess { sourceURL.stopAccessingSecurityScopedResource() } }

            do {
                let destURL = try copyIntoAppMediaFolder(sourceURL: sourceURL, preferredExtension: preferredExt)
                return try await buildMediaAsset(from: destURL)
            } catch {
                Log.warn("Copy from picker URL failed (\(error.localizedDescription)). Falling back to data.")
            }
        }

        // Fallback: sometimes URL loading can return nil; try Data (works for smaller files)
        if let data = try await item.loadTransferable(type: Data.self) {
            let destURL = try writeDataIntoAppMediaFolder(data: data, preferredExt: preferredExt)
            return try await buildMediaAsset(from: destURL)
        }

        throw MediaImportError.failedToLoad
    }

    // MARK: - File ops

    private func copyIntoAppMediaFolder(sourceURL: URL, preferredExtension: String) throws -> URL {
        let mediaDir = AppPaths.mediaDir
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let ext = [sourceURL.pathExtension, preferredExtension].first(where: { !$0.isEmpty }) ?? "mov"
        let filename = "import_\(UUID().uuidString).\(ext)"
        let destURL = mediaDir.appendingPathComponent(filename)

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            return destURL
        } catch {
            throw MediaImportError.failedToCopy
        }
    }

    private func writeDataIntoAppMediaFolder(data: Data, preferredExt: String) throws -> URL {
        let mediaDir = AppPaths.mediaDir
        try FileManager.default.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        let filename = "import_\(UUID().uuidString).\(preferredExt)"
        let destURL = mediaDir.appendingPathComponent(filename)

        do {
            try data.write(to: destURL, options: [.atomic])
            return destURL
        } catch {
            throw MediaImportError.failedToCopy
        }
    }

    // MARK: - MediaAsset build

    private func preferredExtension(for item: PhotosPickerItem) -> String {
        item.supportedContentTypes
            .compactMap { $0.preferredFilenameExtension }
            .first(where: { !$0.isEmpty }) ?? "mov"
    }

    private func buildMediaAsset(from url: URL) async throws -> MediaAsset {
        let avAsset = AVURLAsset(url: url)
        let durationTime = try await avAsset.load(.duration)
        let duration = durationTime.seconds.isFinite ? durationTime.seconds : 0

        return MediaAsset(
            url: url,
            duration: duration,
            displayName: url.deletingPathExtension().lastPathComponent,
            relativePath: url.lastPathComponent
        )
    }
}
