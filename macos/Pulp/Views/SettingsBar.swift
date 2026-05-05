import SwiftUI

struct SettingsBar: View {
    @Binding var settings: EncodeSettings

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            Spacer(minLength: 0)

            FieldColumn(label: "Format") {
                FormatPicker(value: $settings.format)
            }
            FieldColumn(label: "Quality") {
                NumberField(value: $settings.quality, range: 1...100, suffix: "%")
                    .controlEnabled(settings.format.supportsQuality)
            }
            FieldColumn(label: "Max Width") {
                NumberField(value: $settings.maxWidth, range: 0...20000, placeholder: "Auto")
                    .controlEnabled(settings.preset == .custom)
            }
            FieldColumn(label: "Max Height") {
                NumberField(value: $settings.maxHeight, range: 0...20000, placeholder: "Auto")
                    .controlEnabled(settings.preset == .custom)
            }
            FieldColumn(label: "Preset Size") {
                PresetPicker(value: $settings.preset)
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
        .frame(minWidth: 100, idealWidth: 140, maxWidth: 140, alignment: .leading)
    }
}

private struct FormatPicker: View {
    @Binding var value: PulpFormat

    var body: some View {
        Menu {
            ForEach(PulpFormat.allCases) { format in
                Button(format.displayName) { value = format }
            }
        } label: {
            DropdownLabel(text: value.displayName)
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

private struct PresetPicker: View {
    @Binding var value: SizePreset

    var body: some View {
        Menu {
            ForEach(SizePreset.allCases) { preset in
                Button(preset.displayName) { value = preset }
            }
        } label: {
            DropdownLabel(text: value.displayName)
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
    }
}

private struct DropdownLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .pulpControl()
        .contentShape(.rect)
    }
}

private struct NumberField: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var placeholder: String = ""
    var suffix: String = ""

    @State private var text: String = ""

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .onChange(of: text) { _, new in commit(new) }
                .onChange(of: value) { _, new in syncFromValue(new) }
                .onAppear { syncFromValue(value) }
            if !suffix.isEmpty {
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
        .pulpControl()
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

private extension View {
    /// Shared chrome for every control in the settings bar. Keeps height,
    /// padding, and background identical between menus and text fields.
    func pulpControl() -> some View {
        self
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(.quaternary, in: .rect(cornerRadius: 8))
    }

    func controlEnabled(_ enabled: Bool) -> some View {
        self
            .opacity(enabled ? 1 : 0.4)
            .disabled(!enabled)
    }
}
