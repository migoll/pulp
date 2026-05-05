import SwiftUI

struct SettingsBar: View {
    @Binding var settings: EncodeSettings

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            Spacer(minLength: 0)

            FieldColumn(label: "Format") {
                Menu {
                    ForEach(PulpFormat.allCases) { format in
                        Button(format.displayName) { settings.format = format }
                    }
                } label: {
                    MenuLabel(text: settings.format.displayName)
                }
            }

            FieldColumn(label: "Quality") {
                NumberField(
                    value: $settings.quality,
                    range: 1...100,
                    suffix: "%"
                )
                .opacity(settings.format.supportsQuality ? 1 : 0.4)
                .disabled(!settings.format.supportsQuality)
            }

            FieldColumn(label: "Max Width") {
                NumberField(
                    value: $settings.maxWidth,
                    range: 0...20000,
                    placeholder: "Auto"
                )
                .disabled(settings.preset != .custom)
                .opacity(settings.preset == .custom ? 1 : 0.4)
            }

            FieldColumn(label: "Max Height") {
                NumberField(
                    value: $settings.maxHeight,
                    range: 0...20000,
                    placeholder: "Auto"
                )
                .disabled(settings.preset != .custom)
                .opacity(settings.preset == .custom ? 1 : 0.4)
            }

            FieldColumn(label: "Preset Size") {
                Menu {
                    ForEach(SizePreset.allCases) { preset in
                        Button(preset.displayName) { settings.preset = preset }
                    }
                } label: {
                    MenuLabel(text: settings.preset.displayName)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 24)
    }
}

private struct FieldColumn<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            content
        }
        .frame(width: 140, alignment: .leading)
    }
}

private struct MenuLabel: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(.quaternary, in: .rect(cornerRadius: 8))
        .contentShape(.rect)
    }
}

private struct NumberField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var placeholder: String = ""
    var suffix: String = ""

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($focused)
                .onChange(of: text) { _, new in commit(new) }
                .onChange(of: value) { _, new in syncFromValue(new) }
                .onAppear { syncFromValue(value) }
            if !suffix.isEmpty {
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    private func syncFromValue(_ v: Int) {
        let displayed = (v == 0 && !placeholder.isEmpty) ? "" : String(v)
        if displayed != text { text = displayed }
    }

    private func commit(_ raw: String) {
        let digits = raw.filter(\.isNumber)
        if digits != raw { text = digits }

        let parsed = Int(digits) ?? 0
        let clamped = min(max(parsed, range.lowerBound), range.upperBound)
        if clamped != value { value = clamped }
    }
}
