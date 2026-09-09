//
//  0f_welcome.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 31/07/2025.
//

import SwiftUI
import SunCalc

struct _f_welcome: View {

    /// Rooms picked in 0d. Empty → every room of the bridge.
    var selectedRooms: [String] = []

    @StateObject private var locationManager = LocationManager()
    @State private var listOfSegments = [Segment]()
    @State private var isEditing = false
    @State private var groups = [String: RoomResponse]()
    @State private var groupsIndices = [String]()
    @State private var sendStatus: SendStatus = .idle
    @State private var pushedRooms = 0
    @State private var failedRooms = [String]()
    @State private var message = ""

    enum SendStatus { case idle, inProgress, success, failure }

    /// The rooms this default config is applied to.
    private var targetRooms: [String] {
        guard !selectedRooms.isEmpty else { return groupsIndices }
        guard !groupsIndices.isEmpty else { return sortedIndices(selectedRooms) }
        return sortedIndices(Set(selectedRooms).intersection(groupsIndices))
    }

    private var targetNames: String {
        let names = targetRooms.map { groups[$0]?.name ?? $0 }
        return names.isEmpty ? "—" : names.joined(separator: ", ")
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack {
                    Text("Sun hours for : ")
                    Button {
                        locationManager.getSingleLocation()
                        locationManager.fetchCityName()
                        listOfSegments = fillListOfSegmentsInit(locationManager: locationManager)
                        listOfSegments = sortedSegments(listOfSegments)
                    } label: {
                        Group {
                            Text(locationManager.cityName ?? "Locate me !")
                            Image(systemName: "scope")
                        }
                        .foregroundStyle(.accent)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
                .padding(.horizontal)
            }

            // This first config is the default schedule for every selected room.
            VStack(alignment: .leading, spacing: 2) {
                Text("Configuration par défaut de \(targetRooms.count) pièce\(targetRooms.count > 1 ? "s" : "")")
                    .font(.subheadline.weight(.semibold))
                Text(targetNames)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top, 4)

            ZStack {
                List {
                    ForEach(listOfSegments.indices, id: \.self) { index in
                        let segment = listOfSegments[index]
                        if segment.show! || isEditing {
                            HStack {
                                if isEditing {
                                    Button {
                                        listOfSegments[index].show?.toggle()
                                    } label: {
                                        Image(systemName: listOfSegments[index].show! ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                                VStack(alignment: .leading) {
                                    Text("\(segment.name)")
                                    Text("\(String(segment.hourStart.hour!))h\(String(format: "%02d", segment.hourStart.minute!))")
                                }
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
                    listOfSegments = fillListOfSegmentsInit(locationManager: locationManager)
                    listOfSegments = sortedSegments(listOfSegments)
                    locationManager.fetchCityName()
                    if demoMode {
                        groups = demoGroups
                        groupsIndices = sortedIndices(demoGroups.keys)
                    } else {
                        sendGETGroups(ip: ip, which: nil) { response in
                            groups = response
                            groupsIndices = sortedIndices(response.map { $0.key })
                        }
                    }
                }

                VStack {
                    Spacer()
                    HStack {
                        if !message.isEmpty {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(sendStatus == .failure ? .red : .green)
                                .padding(.horizontal)
                        }
                        Spacer()
                        if sendStatus == .success {
                            NavigationLink {
                                _g_welcome(configuredRooms: targetRooms)
                                    .navigationTitle("Lier les pièces")
                            } label: {
                                Button_With_Icon(text: "next", icon: "arrowshape.right.circle", color: .fondClair)
                            }
                        } else {
                            HStack(spacing: 12) {
                                if sendStatus == .inProgress { ProgressView() }
                                else if sendStatus == .failure {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                }
                                Button {
                                    sendToAllRooms()
                                } label: {
                                    Button_With_Icon(text: "send to bridge", icon: "square.and.arrow.up", color: .fondClair)
                                }
                                .disabled(sendStatus == .inProgress || targetRooms.isEmpty)
                                .opacity(targetRooms.isEmpty ? 0.35 : 1)
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    /// Pushes the same schedule to every target room, one after the other.
    private func sendToAllRooms() {
        let rooms = targetRooms
        guard !rooms.isEmpty else { return }
        sendStatus = .inProgress
        pushedRooms = 0
        failedRooms = []
        message = "0/\(rooms.count)"

        var remaining = rooms

        func pushNext() {
            guard let idxString = remaining.first else {
                finish(total: rooms.count)
                return
            }
            remaining.removeFirst()
            guard let idx = Int(idxString) else {
                failedRooms.append(idxString)
                pushNext()
                return
            }
            createRulesFromlistOfSegments(listOfSegments: listOfSegments, indexGroup: idx) { response in
                if response.contains("correctly") { pushedRooms += 1 } else { failedRooms.append(idxString) }
                message = "\(pushedRooms + failedRooms.count)/\(rooms.count)"
                pushNext()
            }
        }

        pushNext()
    }

    private func finish(total: Int) {
        if failedRooms.isEmpty {
            sendStatus = .success
            message = "\(pushedRooms)/\(total) pièce\(total > 1 ? "s" : "") configurée\(total > 1 ? "s" : "") ✓"
        } else {
            let names = failedRooms.map { groups[$0]?.name ?? $0 }
            sendStatus = pushedRooms > 0 ? .success : .failure
            message = "\(pushedRooms)/\(total) — échec : \(names.joined(separator: ", "))"
        }
    }
}

func sortedSegments(_ segments: [Segment]) -> [Segment] {
    segments.sorted {
        ($0.hourStart.hour! < 3 ? 24 + $0.hourStart.hour! : $0.hourStart.hour!) <
        ($1.hourStart.hour! < 3 ? 24 + $1.hourStart.hour! : $1.hourStart.hour!)
    }
}

#Preview {
    NavigationStack { _f_welcome() }
}


func fillListOfSegmentsInit(locationManager: LocationManager) -> [Segment] {
    let timeOfSun = SunCalc.getTimes(date: Date(), latitude: locationManager.latitude, longitude: locationManager.longitude)
    return [
        Segment(name: "nightEnd",      hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.nightEnd!),     temp: 500, synced: .notSynced, show: false),
        Segment(name: "dawn",          hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.dawn!),         temp: 325, synced: .notSynced, show: true),
        Segment(name: "sunrise",       hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunrise!),      temp: 300, synced: .notSynced, show: true),
        Segment(name: "sunriseEnd",    hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunriseEnd!),   temp: 275, synced: .notSynced, show: true),
        Segment(name: "goldenHourEnd", hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.goldenHourEnd!),temp: 250, synced: .notSynced, show: true),
        Segment(name: "solarNoon",     hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.solarNoon!),    temp: 250, synced: .notSynced, show: true),
        Segment(name: "goldenHour",    hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.goldenHour!),   temp: 250, synced: .notSynced, show: true),
        Segment(name: "sunsetStart",   hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.sunsetStart!),  temp: 280, synced: .notSynced, show: true),
        Segment(name: "dusk",          hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.dusk!),         temp: 290, synced: .notSynced, show: true),
        Segment(name: "night",         hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.night!),        temp: 350, synced: .notSynced, show: true),
        Segment(name: "nadir",         hourStart: Calendar.current.dateComponents([.hour, .minute], from: timeOfSun.nadir!),        temp: 500, synced: .notSynced, show: true),
    ]
}
