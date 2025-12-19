import Foundation

protocol EditorCommand {
    var name: String { get }
    func apply(to project: inout Project)
    func undo(on project: inout Project)
}

struct CommandStack {
    private(set) var undoStack: [EditorCommand] = []
    private(set) var redoStack: [EditorCommand] = []

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func apply(_ command: EditorCommand, to project: inout Project) {
        command.apply(to: &project)
        undoStack.append(command)
        redoStack.removeAll()
    }

    mutating func undo(on project: inout Project) {
        guard let cmd = undoStack.popLast() else { return }
        cmd.undo(on: &project)
        redoStack.append(cmd)
    }

    mutating func redo(on project: inout Project) {
        guard let cmd = redoStack.popLast() else { return }
        cmd.apply(to: &project)
        undoStack.append(cmd)
    }
}

// MARK: - Helpers to find sequence + mutate clips

extension Project {
    mutating func mutateSequence(_ id: UUID, _ body: (inout Sequence) -> Void) {
        guard let i = sequences.firstIndex(where: { $0.id == id }) else { return }
        body(&sequences[i])
        touch()
    }
}

// MARK: - Commands

struct AddClipCommand: EditorCommand {
    let sequenceID: UUID
    let clip: Clip
    var name: String { "Add Clip" }

    func apply(to project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            var c = clip
            if let track = seq.tracks.first(where: { $0.id == c.trackID }) { c.trackIndexHint = track.index }
            seq.clips.append(c)
        }
    }

    func undo(on project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            seq.clips.removeAll { $0.id == clip.id }
        }
    }
}

struct DeleteClipCommand: EditorCommand {
    let sequenceID: UUID
    let clip: Clip
    var name: String { "Delete Clip" }

    func apply(to project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            seq.clips.removeAll { $0.id == clip.id }
        }
    }

    func undo(on project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            seq.clips.append(clip)
        }
    }
}

struct SetClipStartCommand: EditorCommand {
    let sequenceID: UUID
    let clipID: UUID
    let oldStart: Double
    let newStart: Double
    var name: String { "Move Clip" }

    func apply(to project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            guard let idx = seq.clips.firstIndex(where: { $0.id == clipID }) else { return }
            seq.clips[idx].startTime = newStart
        }
    }

    func undo(on project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            guard let idx = seq.clips.firstIndex(where: { $0.id == clipID }) else { return }
            seq.clips[idx].startTime = oldStart
        }
    }
}

struct SetClipDurationCommand: EditorCommand {
    let sequenceID: UUID
    let clipID: UUID
    let oldDuration: Double
    let oldSourceDuration: Double
    let newDuration: Double
    var name: String { "Trim Clip" }

    func apply(to project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            guard let idx = seq.clips.firstIndex(where: { $0.id == clipID }) else { return }
            seq.clips[idx].duration = newDuration
            seq.clips[idx].sourceDuration = min(seq.clips[idx].sourceDuration, newDuration)
        }
    }

    func undo(on project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            guard let idx = seq.clips.firstIndex(where: { $0.id == clipID }) else { return }
            seq.clips[idx].duration = oldDuration
            seq.clips[idx].sourceDuration = oldSourceDuration
        }
    }
}

struct SplitClipCommand: EditorCommand {
    let sequenceID: UUID
    let original: Clip
    let left: Clip
    let right: Clip
    var name: String { "Split Clip" }

    init(sequenceID: UUID, original: Clip, time: Double) {
        self.sequenceID = sequenceID
        self.original = original

        let cut = max(original.startTime, min(time, original.startTime + original.duration))
        let leftDur = cut - original.startTime
        let rightDur = original.duration - leftDur

        var l = original
        l.duration = leftDur
        l.sourceDuration = min(l.sourceDuration, leftDur)

        var r = original
        r.id = UUID()
        r.startTime = cut
        r.duration = rightDur
        r.sourceStart = original.sourceStart + leftDur
        r.sourceDuration = min(original.sourceDuration - leftDur, rightDur)

        self.left = l
        self.right = r
    }

    func apply(to project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            guard let idx = seq.clips.firstIndex(where: { $0.id == original.id }) else { return }
            // replace original with left and add right
            seq.clips[idx] = left
            seq.clips.append(right)
        }
    }

    func undo(on project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            seq.clips.removeAll { $0.id == right.id }
            if let idx = seq.clips.firstIndex(where: { $0.id == left.id }) {
                seq.clips[idx] = original
            } else {
                seq.clips.append(original)
            }
        }
    }
}

struct SetClipPrimaryFilterCommand: EditorCommand {
    let sequenceID: UUID
    let clipID: UUID
    let oldFilter: EditorFilter?
    let newFilter: EditorFilter?
    var name: String { "Set Filter" }

    func apply(to project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            guard let idx = seq.clips.firstIndex(where: { $0.id == clipID }) else { return }
            seq.clips[idx].primaryFilter = newFilter
        }
    }

    func undo(on project: inout Project) {
        project.mutateSequence(sequenceID) { seq in
            guard let idx = seq.clips.firstIndex(where: { $0.id == clipID }) else { return }
            seq.clips[idx].primaryFilter = oldFilter
        }
    }
}
