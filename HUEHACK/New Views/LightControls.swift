//
//  LightControls.swift
//  HUEHACK
//
//  Controls shared by the light editors (manual light sheet, segment editor):
//  gradient sliders (white temperature, hue, saturation), brightness slider,
//  preview swatch, and the live preview that sends values to the bridge while
//  dragging.
//

import SwiftUI

// MARK: - Gradient slider

/// Horizontal capsule filled with `colors`, with a round thumb showing the colour
/// under it; drag or tap anywhere to set `value` within `range`.
struct GradientSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let colors: [Color]
    let thumbColor: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let ratio = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
                    .overlay(Capsule().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                Circle()
                    .fill(thumbColor)
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(radius: 2)
                    .frame(width: 34, height: 34)
                    .offset(x: min(max(0, ratio), 1) * width - 17)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                let r = min(1, max(0, drag.location.x / max(1, width)))
                value = range.lowerBound + r * (range.upperBound - range.lowerBound)
            })
        }
        .frame(height: 44)
    }
}

/// Small legend under a slider: left label, value in the middle, right label.
private struct SliderLegend: View {
    let leading: String
    let value: String
    let trailing: String

    var body: some View {
        HStack {
            Text(leading)
            Spacer()
            Text(value).monospacedDigit()
            Spacer()
            Text(trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Blancs

/// Cool white (153 mireds, left) → warm white (500, right).
struct WhiteTemperaturePicker: View {
    @Binding var mireds: Double

    var body: some View {
        VStack(spacing: 8) {
            GradientSlider(value: $mireds, range: 153...500,
                           colors: stride(from: 153.0, through: 500.0, by: 25).map { Color(mireds: $0) },
                           thumbColor: Color(mireds: mireds))
            SliderLegend(leading: "Froid", value: "\(Int(mireds.rounded()).miredsToKelvin) K", trailing: "Chaud")
        }
    }
}

// MARK: - Couleurs

/// Hue (0…1, the colour wheel unrolled) and saturation (0 = white … 1 = vivid),
/// independent of the brightness slider — the same three settings as a Hue lamp.
struct HueSaturationPicker: View {
    @Binding var hue: Double
    @Binding var saturation: Double

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                GradientSlider(value: $hue, range: 0...1,
                               colors: stride(from: 0.0, through: 1.0, by: 1.0 / 12).map {
                                   Color(hue: $0, saturation: 1, brightness: 1)
                               },
                               thumbColor: Color(hue: hue, saturation: 1, brightness: 1))
                SliderLegend(leading: "Teinte", value: "\(Int((hue * 360).rounded()))°", trailing: "")
            }
            VStack(spacing: 8) {
                GradientSlider(value: $saturation, range: 0...1,
                               colors: [.white, Color(hue: hue, saturation: 1, brightness: 1)],
                               thumbColor: Color(hue: hue, saturation: saturation, brightness: 1))
                SliderLegend(leading: "Blanc", value: "Saturation \(Int((saturation * 100).rounded())) %", trailing: "Vif")
            }
        }
    }
}

// MARK: - Brightness & swatch

/// Brightness slider (0.01…1) with its percentage.
struct BrightnessSlider: View {
    @Binding var level: Double

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sun.min").foregroundStyle(.secondary)
                Slider(value: $level, in: 0.01...1)
                Image(systemName: "sun.max.fill").foregroundStyle(.secondary)
            }
            Text("Luminosité \(Int((level * 100).rounded())) %")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

/// Rounded preview of the light being edited, with an optional caption on top.
struct LightSwatch<Caption: View>: View {
    let color: Color
    var height: CGFloat = 60
    @ViewBuilder var caption: () -> Caption

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.black)
            .overlay(RoundedRectangle(cornerRadius: 14).fill(color))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            .overlay(caption())
            .frame(height: height)
    }
}

extension LightSwatch where Caption == EmptyView {
    init(color: Color, height: CGFloat = 60) {
        self.init(color: color, height: height) { EmptyView() }
    }
}

/// 0…1 → Hue v1 `bri` (1…254).
func hueBrightness(_ level: Double) -> Int {
    min(254, max(1, Int(level * 254)))
}

// MARK: - Live preview

/// Sends the edited value to the bridge while the user drags: latest value wins,
/// one request at a time, at most once a second — the bridge handles about one
/// group command per second and queues the rest (seconds of lag). `send` also
/// gets the value sent before (nil the first time) to send only what changed.
/// The first change runs `begin` (pausing the room's circadian so the 10 s tick
/// does not overwrite the preview) before anything is sent. Main thread only.
final class LiveLightPreview<Value: Equatable> {
    private enum Phase { case idle, starting, active, failed, closed }

    private let begin: (@escaping (Bool) -> Void) -> Void
    private let send: (_ value: Value, _ previous: Value?, _ done: @escaping () -> Void) -> Void
    private let minimumInterval: TimeInterval = 1

    private var phase = Phase.idle
    private var hasStarted = false
    private var latest: Value?
    private var sent: Value?
    private var busy = false
    private var lastSend = Date.distantPast
    private var whenIdle: (() -> Void)?

    init(begin: @escaping (@escaping (Bool) -> Void) -> Void,
         send: @escaping (_ value: Value, _ previous: Value?, _ done: @escaping () -> Void) -> Void) {
        self.begin = begin
        self.send = send
    }

    func update(_ value: Value) {
        latest = value
        switch phase {
        case .idle:
            phase = .starting
            hasStarted = true
            busy = true
            begin { [self] ok in
                busy = false
                if phase == .starting { phase = ok ? .active : .failed }
                pump()
            }
        case .active:
            pump()
        case .starting, .failed, .closed:
            break
        }
    }

    /// Stops sending, then calls `then` once no request is in flight (so a late
    /// preview cannot land after what the caller sends next). `started`: whether
    /// the preview changed anything on the bridge.
    func close(then: @escaping (_ started: Bool) -> Void) {
        phase = .closed
        let started = hasStarted
        whenIdle = { then(started) }
        pump()
    }

    private func pump() {
        guard !busy else { return }
        guard phase == .active, let value = latest, value != sent else {
            if let action = whenIdle {
                whenIdle = nil
                action()
            }
            return
        }
        busy = true
        let wait = minimumInterval - Date().timeIntervalSince(lastSend)
        if wait > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [self] in
                busy = false
                pump()
            }
            return
        }
        lastSend = Date()
        let previous = sent
        sent = value
        send(value, previous) { [self] in
            busy = false
            pump()
        }
    }
}
