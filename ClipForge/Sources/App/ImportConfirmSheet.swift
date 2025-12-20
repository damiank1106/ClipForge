import SwiftUI

struct ImportConfirmSheet: View {
    let count: Int
    let onCancel: () -> Void
    let onImport: () -> Void

    init(count: Int = 1, onCancel: @escaping () -> Void, onImport: @escaping () -> Void) {
        self.count = max(1, count)
        self.onCancel = onCancel
        self.onImport = onImport
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "film")
                    .font(.system(size: 44))
                    .padding(.top, 8)

                Text(count == 1 ? "Import this item?" : "Import \(count) items?")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("On iPad, the Photos picker may use a checkmark + Done/Add. Select your photo(s) or video(s), tap Done/Add, then confirm here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                HStack(spacing: 12) {
                    Button("Cancel") { onCancel() }
                        .buttonStyle(.bordered)

                    Button("Import") { onImport() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(.top, 6)

                Spacer()
            }
            .padding()
            .navigationTitle("Confirm")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
