//
//  7_manual_color.swift
//  HUEHACK
//
//  Manual light for one room. Applying it pauses that room's circadian rules
//  (see RoomOverride.swift) until the room is switched off or "Reprendre".
//  Two tabs: « Blancs » (cool → warm white, sent as ct) and « Couleurs »
//  (hue and saturation sliders, sent as hue/sat). The brightness slider is
//  common to both and the only one that changes the brightness. Every change is shown live on the
//  room; « Annuler » puts the room back as it was.
//

import SwiftUI

struct ManualColorSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case white = "Blancs"
        case color = "Couleurs"
        var id: Self { self }
    }

    struct Output: Equatable {
        let light: ManualLight
        let bri: Int
    }

    let roomName: String
    let onApply: (_ light: ManualLight, _ bri: Int) -> Void
    /// Called once the room is back to its previous state after « Annuler ».
    let onCancelled: () -> Void

    private let groupIndex: Int
    private let previous: RoomAction?
    private let wasPaused: Bool

    @State private var mode: Mode
    @State private var mireds: Double                 // 153 (cool) … 500 (warm)
    @State private var hue: Double                    // 0…1
    @State private var saturation: Double             // 0 (white) … 1 (vivid)
    @State private var brightness: Double             // 0…1
    @State private var preview: LiveLightPreview<Output>
    @Environment(\.dismiss) private var dismiss

    /// `previous`: the room's current group action — the sheet opens on the matching
    /// tab (hue/sat → Couleurs, otherwise Blancs) with its values, and « Annuler »
    /// restores it. `wasPaused`: whether the room's circadian is already paused.
    init(roomName: String, groupIndex: Int, previous: RoomAction?, wasPaused: Bool,
         onApply: @escaping (_ light: ManualLight, _ bri: Int) -> Void,
         onCancelled: @escaping () -> Void) {
        self.roomName = roomName
        self.groupIndex = groupIndex
        self.previous = previous
        self.wasPaused = wasPaused
        self.onApply = onApply
        self.onCancelled = onCancelled

        var startMode = Mode.white
        var startHue = 0.08, startSaturation = 0.75
        if let action = previous, action.colormode == "hs",
           let hue = action.hue, let sat = action.sat {
            startMode = .color
            startHue = Double(hue) / 65535
            startSaturation = Double(sat) / 254
        }
        _mode = State(initialValue: startMode)
        _hue = State(initialValue: startHue)
        _saturation = State(initialValue: startSaturation)
        _mireds = State(initialValue: Double(clampMireds(previous?.ct ?? 300)))
        _brightness = State(initialValue: min(1, max(1, Double(previous?.bri ?? 254)) / 254))
        _preview = State(initialValue: LiveLightPreview(
            begin: { done in beginManualPreview(groupIndex: groupIndex) { done($0) } },
            send: { value, previous, done in
                sendManualPreview(groupIndex: groupIndex, light: value.light, bri: value.bri,
                                  after: previous.map { ($0.light, $0.bri) }) { _ in done() }
            }))
    }

    /// What gets sent.
    private var output: Output {
        switch mode {
        case .white:
            return Output(light: .white(ct: clampMireds(Int(mireds.rounded()))), bri: hueBrightness(brightness))
        case .color:
            let light = ManualLight.color(hue: min(65535, max(0, Int(hue * 65535))),
                                          sat: min(254, max(0, Int(saturation * 254))))
            return Output(light: light, bri: hueBrightness(brightness))
        }
    }

    private var swatchColor: Color {
        let level = max(0.15, Double(output.bri) / 254)
        switch mode {
        case .white:
            return Color(mireds: mireds).opacity(level)
        case .color:
            return Color(hue: hue, saturation: saturation, brightness: level)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Lumière manuelle — \(roomName)")
                        .font(.headline)
                        .padding(.top)

                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    LightSwatch(color: swatchColor)

                    switch mode {
                    case .white:
                        WhiteTemperaturePicker(mireds: $mireds)
                    case .color:
                        HueSaturationPicker(hue: $hue, saturation: $saturation)
                    }

                    BrightnessSlider(level: $brightness)

                    Text("Le réglage s'affiche en direct. Le circadien de cette pièce reste en pause jusqu'à ce qu'elle soit éteinte, ou jusqu'à « Reprendre ».")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding([.horizontal, .bottom])
            }
            .onChange(of: output) { _, newValue in preview.update(newValue) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { confirm() }
                }
            }
        }
        .presentationDetents([.large])
        // Swiping the sheet away would leave the preview on the lights.
        .interactiveDismissDisabled()
    }

    private func confirm() {
        let out = output
        preview.close { _ in onApply(out.light, out.bri) }
        dismiss()
    }

    private func cancel() {
        let groupIndex = groupIndex, previous = previous, wasPaused = wasPaused, onCancelled = onCancelled
        preview.close { started in
            guard started else { return }
            cancelManualPreview(groupIndex: groupIndex, previous: previous, wasPaused: wasPaused) { _ in
                onCancelled()
            }
        }
        dismiss()
    }
}

#Preview {
    ManualColorSheet(roomName: "Salon", groupIndex: 1, previous: nil, wasPaused: false,
                     onApply: { _, _ in }, onCancelled: {})
}
