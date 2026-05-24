//
//  EditSegment.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 04/01/2025.
//

import SwiftUI

let dégradéCouleur = LinearGradient(gradient: Gradient(colors: [Color.orange, Color.white]),
                                    startPoint: .leading, endPoint: .trailing)





struct EditSegment: View {

    @State var lastRequestTime: Date = Date()

    @State var index: Int
    @Binding var listOfSegments: [Segment]
    var groupIndex: Int

    @State private var tempKelvins = 200.0
    @State private var tempMireds = 200.0

    @State private var sliderIsEditing = false

    private func timeStr(_ dc: DateComponents) -> String {
        "\(dc.hour!)h\(String(format: "%02d", dc.minute!))"
    }

    private var timeRangeLabel: some View {
        let start = listOfSegments[index].hourStart
        let nextIndex = (index + 1) % listOfSegments.count
        let end = listOfSegments[nextIndex].hourStart
        return Text("\(timeStr(start)) → \(timeStr(end))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    var body: some View {

        VStack {

            Text(listOfSegments[index].name)
                .font(.title)

            timeRangeLabel

            ZStack {
                Rectangle()
                    .foregroundStyle(Color(mireds: tempMireds))
                    .frame(height: 150)
                    .cornerRadius(15)
                    .padding(.horizontal)

                let originalKelvin = 1_000_000 / listOfSegments[index].temp
                let currentKelvin = Int(tempKelvins)
                if listOfSegments[index].tempChanged && currentKelvin != originalKelvin {
                    HStack(spacing: 8) {
                        Text("\(originalKelvin)")
                            .italic()
                            .strikethrough()
                        Image(systemName: "arrowshape.right")
                        Text("\(currentKelvin) °K")
                    }
                    .padding()
                    .font(.title2)
                } else {
                    Text("Temp : \(currentKelvin) °K")
                        .padding()
                        .font(.title2)
                }
            }

            Slider(value: $tempKelvins, in: 2000...5000, onEditingChanged: { bool in
                if bool {
                    sliderIsEditing = true
                    sendGlobalOnOff(ip: ip, indexGlobalOnOff: indexGlobalOnOff, indexTimer: indexTimer, state: 1) { _ in }
                } else {
                    sliderIsEditing = false
                    sendGlobalOnOff(ip: ip, indexGlobalOnOff: indexGlobalOnOff, indexTimer: indexTimer, state: 0) { _ in }
                }
            })
            .padding()
            .frame(height: 100)
            .background(dégradéCouleur)
            .cornerRadius(15)
            .padding()

        }
        .onAppear {
            let initialTemp = listOfSegments[index].newTemp ?? listOfSegments[index].temp
            tempKelvins = Double(1000000 / initialTemp)
        }
        .onChange(of: tempKelvins) { _, newValue in
            tempMireds = Double(1000000 / newValue)
            let newMireds = Int(tempMireds)
            listOfSegments[index].newTemp = newMireds
            listOfSegments[index].tempChanged = (newMireds != listOfSegments[index].temp)
            listOfSegments[index].synced = .notSynced

            if sliderIsEditing {
                let currentTime = Date()
                if currentTime.timeIntervalSince(lastRequestTime) > 0.5 {
                    lastRequestTime = currentTime
                    sendPUTGroupRequest(ip: ip, groupIndex: groupIndex, ct: Int(tempMireds)) { _ in }
                }
            }
        }
    }
}







#Preview {
    EditSegment(index: 0, listOfSegments: .constant(defaultListOfSegments), groupIndex: 0)
}
