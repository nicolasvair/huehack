//
//  7_manual_color.swift
//  HUEHACK
//
//  Manual colour for one room. Applying it pauses that room's circadian rules
//  (see RoomOverride.swift) until the room is switched off or "Reprendre".
//  Colour only (hue/sat + brightness): no manual white / ct mode.
//

import SwiftUI
import UIKit

struct ManualColorSheet: View {
    let roomName: String
    let onApply: (_ hue: Int, _ sat: Int, _ bri: Int) -> Void

    @State private var color: Color
    @State private var brightness: Double  // 0…1
    @Environment(\.dismiss) private var dismiss

    /// `initialAction`: the room's current group action — its colour is used as the
    /// starting point when the room is already in hue/sat mode.
    init(roomName: String, initialAction: RoomAction?, onApply: @escaping (_ hue: Int, _ sat: Int, _ bri: Int) -> Void) {
        self.roomName = roomName
        self.onApply = onApply
        var start = Color(hue: 0.08, saturation: 0.75, brightness: 1)
        if let action = initialAction, action.colormode == "hs",
           let hue = action.hue, let sat = action.sat {
            start = Color(hue: Double(hue) / 65535, saturation: Double(sat) / 254, brightness: 1)
        }
        _color = State(initialValue: start)
        _brightness = State(initialValue: min(1, max(1, Double(initialAction?.bri ?? 254)) / 254))
    }

    private var values: (hue: Int, sat: Int, bri: Int) {
        manualColorHueValues(color: color, brightness: brightness)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Couleur manuelle — \(roomName)")
                    .font(.headline)
                    .padding(.top)

                let v = values
                RoundedRectangle(cornerRadius: 14)
                    .foregroundStyle(Color(hue: Double(v.hue) / 65535,
                                           saturation: Double(v.sat) / 254,
                                           brightness: max(0.15, Double(v.bri) / 254)))
                    .frame(height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)

                ColorPicker("Couleur", selection: $color, supportsOpacity: false)
                    .padding(.horizontal)

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "sun.min")
                            .foregroundStyle(.secondary)
                        Slider(value: $brightness, in: 0.01...1)
                        Image(systemName: "sun.max.fill")
                            .foregroundStyle(.secondary)
                    }
                    Text("Luminosité \(Int((brightness * 100).rounded())) %")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Text("Le circadien de cette pièce sera mis en pause jusqu'à ce qu'elle soit éteinte, ou jusqu'à « Reprendre ».")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Appliquer") {
                        let v = values
                        onApply(v.hue, v.sat, v.bri)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// SwiftUI colour + brightness (0…1) → Hue v1 `hue` (0…65535), `sat` (0…254),
/// `bri` (1…254). The colour's own brightness is ignored: the slider sets `bri`.
func manualColorHueValues(color: Color, brightness: Double) -> (hue: Int, sat: Int, bri: Int) {
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    let uiColor = UIColor(color)
    if !uiColor.getHue(&h, saturation: &s, brightness: &b, alpha: &a),
       let srgb = CGColorSpace(name: CGColorSpace.sRGB),
       let converted = uiColor.cgColor.converted(to: srgb, intent: .defaultIntent, options: nil) {
        // Colours outside an RGB-compatible space: convert to sRGB first.
        _ = UIColor(cgColor: converted).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    }
    let hue = min(65535, max(0, Int(Double(h) * 65535)))
    let sat = min(254, max(0, Int(Double(s) * 254)))
    let bri = min(254, max(1, Int(brightness * 254)))
    return (hue, sat, bri)
}

#Preview {
    ManualColorSheet(roomName: "Salon", initialAction: nil) { _, _, _ in }
}
