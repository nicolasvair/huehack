//
//  2_rules.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 09/04/2025.
//

import SwiftUI
import SunCalc


struct __rules: View {

    @StateObject private var locationManager = LocationManager()

    @State private var listOfSegments = [Segment]()
    @State private var groups = [String: RoomResponse]()
    @State private var groupsIndices = [String]()
    @State private var selectedGroupIndex = ""
    @State private var isEditing = false
    @State private var updateStatus: UpdateStatus = .idle
    @State private var message = ""

    enum UpdateStatus { case idle, inProgress, success, failure }

    var body: some View {
        HStack {
            HStack {
                Text("Sun hours for : ")
                Group {
                    Text(locationManager.cityName ?? "Localisation")
                    Image(systemName: "scope")
                }
                .foregroundStyle(.accent)
            }
            .padding(.horizontal)

            Spacer()

            Button {
            } label: {
                Image(systemName: "plus")
            }

            Button(isEditing ? "Done" : "Edit") {
                isEditing.toggle()
            }
            .padding(.horizontal)
        }

        if !groupsIndices.isEmpty {
            Picker("Groupe", selection: $selectedGroupIndex) {
                ForEach(groupsIndices.sorted(), id: \.self) { idx in
                    Text(groups[idx]?.name ?? idx).tag(idx)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
            .onChange(of: selectedGroupIndex) { _, _ in
                loadSegments()
            }
        }

        ZStack {
            List {
                ForEach(listOfSegments.indices, id: \.self) { index in
                    let segment = listOfSegments[index]

                    if segment.show! || isEditing {
                        HStack {
                            if segment.synced != .synced {
                                Image(systemName: "slider.horizontal.below.sun.max")
                                    .foregroundStyle(.updateColors)
                            }

                            if isEditing {
                                Button {
                                    listOfSegments[index].show?.toggle()
                                } label: {
                                    Image(systemName: listOfSegments[index].show! ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(.blue)
                                }
                            }

                            VStack(alignment: .leading) {
                                Text(segment.name)

                                if segment.hourChanged {
                                    HStack {
                                        Image(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                                        Text("\(segment.hourStart.hour!)h\(String(format: "%02d", segment.hourStart.minute!))")
                                    }
                                    .foregroundColor(.sunHours)
                                } else {
                                    Text("\(segment.hourStart.hour!)h\(String(format: "%02d", segment.hourStart.minute!))")
                                }
                            }
                            .italic(segment.synced != .synced || segment.hourChanged)
                            .fontWeight(segment.synced == .synced && !segment.hourChanged ? .regular : .light)
                            .foregroundStyle(segment.synced == .notSynced ? .updateColors : .primary)

                            Spacer()

                            Text("\(segment.temp.miredsToKelvin) °K")
                                .font(.subheadline)

                            Rectangle()
                                .frame(width: 50)
                                .foregroundStyle(Color(mireds: Double(segment.temp)))
                                .padding(7)
                        }
                    }
                }
            }
            .onAppear {
                locationManager.getSingleLocation()
                locationManager.fetchCityName()
                sendGETGroups(ip: ip, which: nil) { response in
                    groups = response
                    groupsIndices = response.map { $0.key }
                    if selectedGroupIndex.isEmpty, let first = groupsIndices.sorted().first {
                        selectedGroupIndex = first
                        loadSegments()
                    }
                }
            }

            VStack {
                Spacer()
                HStack {
                    if !message.isEmpty {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(updateStatus == .failure ? .red : .green)
                            .padding(.horizontal)
                    }
                    Spacer()
                    if updateStatus == .inProgress {
                        ProgressView().padding(.horizontal)
                    } else {
                        if listOfSegments.contains(where: { $0.synced == .notSynced }) {
                            Button { sendSolarToBridge() } label: {
                                Button_With_Icon(text: "update colors", icon: "slider.horizontal.below.sun.max")
                                    .foregroundStyle(.updateColors)
                            }
                        }
                        if listOfSegments.contains(where: { $0.hourChanged }) {
                            Button { sendSolarToBridge() } label: {
                                Button_With_Icon(text: "update sun hours", icon: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                                    .foregroundStyle(.sunHours)
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func loadSegments() {
        guard let groupIdx = Int(selectedGroupIndex) else { return }
        var solar = sortedSegments(fillListOfSegmentsInit(locationManager: locationManager))

        getSegmentFromRulesForGroup(selectedGroupIndex: groupIdx) { bridgeSegments in
            if bridgeSegments.isEmpty {
                listOfSegments = solar
                return
            }
            for i in solar.indices {
                guard i < bridgeSegments.count else { break }
                let b = bridgeSegments[i]
                if solar[i].hourStart.hour != b.hourStart.hour || solar[i].hourStart.minute != b.hourStart.minute {
                    solar[i].hourChanged = true
                }
                if solar[i].temp != b.temp {
                    solar[i].synced = .notSynced
                }
            }
            listOfSegments = solar
        }
    }

    private func sendSolarToBridge() {
        guard let groupIdx = Int(selectedGroupIndex) else { return }
        updateStatus = .inProgress
        message = ""
        let fresh = sortedSegments(fillListOfSegmentsInit(locationManager: locationManager))
        createRulesFromlistOfSegments(listOfSegments: fresh, indexGroup: groupIdx) { response in
            message = response
            updateStatus = response.contains("correctly") ? .success : .failure
            if updateStatus == .success { loadSegments() }
        }
    }
}


#Preview {
    __rules()
}


func fillListOfSegmentsWrongHour(locationManager: LocationManager) -> [Segment] {
    let timeOfSun = SunCalc.getTimes(date: Date(), latitude: locationManager.latitude, longitude: locationManager.longitude)
    return [
        Segment(name: "nightEnd",      hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.nightEnd!),     temp: 500, synced: .synced,    show: false, hourChanged: true),
        Segment(name: "dawn",          hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.dawn!),         temp: 325, synced: .synced,    show: true,  hourChanged: true),
        Segment(name: "sunrise",       hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunrise!),      temp: 300, synced: .synced,    show: true),
        Segment(name: "sunriseEnd",    hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunriseEnd!),   temp: 275, synced: .synced,    show: true),
        Segment(name: "goldenHourEnd", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.goldenHourEnd!),temp: 250, synced: .synced,    show: true),
        Segment(name: "solarNoon",     hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.solarNoon!),    temp: 250, synced: .synced,    show: true),
        Segment(name: "goldenHour",    hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.goldenHour!),   temp: 250, synced: .notSynced, show: true),
        Segment(name: "sunsetStart",   hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunsetStart!),  temp: 280, synced: .notSynced, show: true,  hourChanged: true),
        Segment(name: "dusk",          hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.dusk!),         temp: 290, synced: .synced,    show: true),
        Segment(name: "night",         hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.night!),        temp: 350, synced: .synced,    show: true),
        Segment(name: "nadir",         hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.nadir!),        temp: 500, synced: .synced,    show: true),
    ]
}
