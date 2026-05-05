import SwiftUI

struct SaveAllSheet: View {
    let count: Int
    let onContinue: (String?) -> Void
    let onCancel: () -> Void

    @State private var wrap = true
    @State private var folderName = "Pulp Export"

    private var trimmedName: String {
        folderName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Save \(count) images")
                    .font(.headline)
                Text("Choose how to organize the export.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                Toggle("Save in a new folder", isOn: $wrap)

                TextField("Folder name", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!wrap)
                    .opacity(wrap ? 1 : 0.4)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Continue") {
                    onContinue(wrap ? trimmedName : nil)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(wrap && trimmedName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}
