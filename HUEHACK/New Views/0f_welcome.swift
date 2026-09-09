//
//  0f_welcome.swift
//  HUEHACK
//
//  Created by Nicolas Vair on 31/07/2025.
//

import SwiftUI
import SunCalc

struct _f_welcome: View {

    @AppStorage("hueOnboardingComplete") private var onboardingComplete = false

    @StateObject private var locationManager = LocationManager()
    @State private var listOfSegments = [Segment]()
    @State private var isEditing = false
    @State private var groups = [String: RoomResponse]()
    @State private var groupsIndices = [String]()
    @State private var selectedGroupIndex = ""
    @State private var sendStatus: SendStatus = .idle
    @State private var message = ""

    enum SendStatus { case idle, inProgress, success, failure }

    var body: some View {
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

        if !groupsIndices.isEmpty {
            Picker("Groupe", selection: $selectedGroupIndex) {
                ForEach(groupsIndices.sorted(), id: \.self) { idx in
                    Text(groups[idx]?.name ?? idx).tag(idx)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal)
        }

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
                sendGETGroups(ip: ip, which: nil) { response in
                    groups = response
                    groupsIndices = response.map { $0.key }
                    if selectedGroupIndex.isEmpty, let first = groupsIndices.sorted().first {
                        selectedGroupIndex = first
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
                        // Ends onboarding → the app root swaps to the rooms view.
                        Button { onboardingComplete = true } label: {
                            Button_With_Icon(text: "done !", icon: "checkmark.circle", color: .fondClair)
                        }
                    } else {
                        HStack(spacing: 12) {
                            if sendStatus == .inProgress { ProgressView() }
                            else if sendStatus == .failure {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                            }
                            Button {
                                guard let groupIdx = Int(selectedGroupIndex) else { return }
                                sendStatus = .inProgress
                                createRulesFromlistOfSegments(listOfSegments: listOfSegments, indexGroup: groupIdx) { response in
                                    message = response
                                    sendStatus = response.contains("correctly") ? .success : .failure
                                }
                            } label: {
                                Button_With_Icon(text: "send to bridge", icon: "square.and.arrow.up", color: .fondClair)
                            }
                            .disabled(sendStatus == .inProgress || selectedGroupIndex.isEmpty)
                            .opacity(selectedGroupIndex.isEmpty ? 0.35 : 1)
                        }
                    }
                }
            }
            .padding()
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
