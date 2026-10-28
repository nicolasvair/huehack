//
//  8_segment_editor.swift
//  HUEHACK
//
//  Edits the colour temperature of one segment, with the same controls as the
//  manual light sheet. Changes are shown live on the room (its circadian is
//  paused meanwhile) and the room is put back as it was on close: the new value
//  only reaches the bridge rules with « Update ».
//

import SwiftUI

struct SegmentEditorSheet: View {
    @Binding var listOfSegments: [Segment]
    let index: Int

    private let groupIndex: Int
    private let previous: RoomAction?
    private let wasPaused: Bool

    @State private var mireds: Double
    @State private var preview: LiveLightPreview<Int>
    @Environment(\.dismiss) private var dismiss

    /// `previous` / `wasPaused`: the room's current action and pause state, restored on close.
    init(listOfSegments: Binding<[Segment]>, index: Int, groupIndex: Int,
         previous: RoomAction?, wasPaused: Bool) {
        _listOfSegments = listOfSegments
        self.index = index
        self.groupIndex = groupIndex
        self.previous = previous
        self.wasPaused = wasPaused
        let segment = listOfSegments.wrappedValue[index]
        _mireds = State(initialValue: Double(clampMireds(segment.newTemp ?? segment.temp)))
        _preview = State(initialValue: LiveLightPreview(
            begin: { done in beginManualPreview(groupIndex: groupIndex) { done($0) } },
            send: { ct, _, done in
                // Colour only: the room's on/off and brightness are left alone.
                sendManualPreview(groupIndex: groupIndex, light: .white(ct: ct), bri: nil) { _ in done() }
            }))
    }

    private var segment: Segment { listOfSegments[index] }
    private var editedTemp: Int { clampMireds(Int(mireds.rounded())) }

    private var timeRange: String {
        let end = listOfSegments[(index + 1) % listOfSegments.count].hourStart
        return "\(timeStr(segment.hourStart)) → \(timeStr(end))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text(segment.name)
                            .font(.headline)
                        Text(timeRange)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    LightSwatch(color: Color(mireds: mireds), height: 100) {
                        HStack(spacing: 8) {
                            if editedTemp != segment.temp {
                                Text("\(segment.temp.miredsToKelvin)")
                                    .italic()
                                    .strikethrough()
                                Image(systemName: "arrowshape.right")
                            }
                            Text("\(editedTemp.miredsToKelvin) K")
                        }
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.black.opacity(0.75))
                    }

                    WhiteTemperaturePicker(mireds: $mireds)

                    Text("Le réglage s'affiche en direct sur la pièce. Il sera envoyé au bridge avec « Update ».")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding([.horizontal, .bottom])
            }
            .onChange(of: editedTemp) { _, newValue in preview.update(newValue) }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { close(keep: false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { close(keep: true) }
                }
            }
        }
        .presentationDetents([.medium, .large])
        // Swiping the sheet away would leave the preview on the lights.
        .interactiveDismissDisabled()
    }

    private func close(keep: Bool) {
        if keep {
            let temp = editedTemp
            let changed = temp != listOfSegments[index].temp
            listOfSegments[index].newTemp = changed ? temp : nil
            listOfSegments[index].tempChanged = changed
            if changed { listOfSegments[index].synced = .notSynced }
        }
        let groupIndex = groupIndex, previous = previous, wasPaused = wasPaused
        preview.close { started in
            guard started else { return }
            cancelManualPreview(groupIndex: groupIndex, previous: previous, wasPaused: wasPaused,
                                restoreOnAndBrightness: false)
        }
        dismiss()
    }
}

#Preview {
    SegmentEditorSheet(listOfSegments: .constant(defaultListOfSegments), index: 0,
                       groupIndex: 1, previous: nil, wasPaused: false)
}
