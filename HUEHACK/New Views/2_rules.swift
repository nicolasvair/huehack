//
//  2_rules.swift
//  HUEHACK
//

import SwiftUI
import SunCalc
import Foundation

struct __rules: View {

    var presetGroupIndex: String = ""

    @StateObject private var locationManager = LocationManager()

    @State private var listOfSegments = [Segment]()
    @State private var groups = [String: RoomResponse]()
    @State private var groupsIndices = [String]()
    @State private var selectedGroupIndex = ""

    @State private var miredsOffset: Int = 0
    @State private var showOffsetSheet = false

    @State private var isEditing = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 0) {

            // Top bar
            HStack {
                // Room picker — hidden when navigated from __rooms
                if presetGroupIndex.isEmpty {
                    if groups.isEmpty {
                        Text("Chargement…").foregroundStyle(.secondary)
                    } else {
                        Menu {
                            ForEach(groupsIndices.sorted(), id: \.self) { idx in
                                if let name = groups[idx]?.name {
                                    Button(name) { selectedGroupIndex = idx }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(groups[selectedGroupIndex]?.name ?? "Choisir une pièce")
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                        }
                    }
                }

                Spacer()

                // Offset badge
                Button { showOffsetSheet = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "dial.medium")
                            .font(.caption)
                        Text(miredsOffset == 0 ? "offset" : "\(miredsOffset > 0 ? "+" : "")\(miredsOffset)")
                            .font(.caption)
                    }
                    .foregroundStyle(miredsOffset == 0 ? .secondary : .accent)
                }

                // Location
                Button {
                    locationManager.getSingleLocation()
                    locationManager.fetchCityName()
                } label: {
                    HStack(spacing: 4) {
                        Text(locationManager.cityName ?? "Localisation")
                        Image(systemName: "scope")
                    }
                    .foregroundStyle(.accent)
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // Edit / add row
            HStack {
                Button(isEditing ? "Done" : "Edit") { isEditing.toggle() }
                Spacer()
                Button {
                    createSegmentForNow(listOfSegments: &listOfSegments)
                } label: {
                    Image(systemName: "plus")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            ZStack {
                List {
                    ForEach(listOfSegments.indices, id: \.self) { index in
                        let segment = listOfSegments[index]
                        if segment.show ?? true || isEditing {
                            NavigationLink {
                                EditSegment(
                                    index: index,
                                    listOfSegments: $listOfSegments,
                                    groupIndex: Int(selectedGroupIndex) ?? 0
                                )
                            } label: {
                                segmentRow(segment: segment, index: index)
                            }
                        }
                    }
                }
                .refreshable { loadSegments() }

                if isLoading { ProgressView() }

                // Floating action buttons
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            if listOfSegments.contains(where: { $0.synced == .notSynced }) {
                                Button { applyColorUpdate() } label: {
                                    Button_With_Icon(
                                        text: "update colors",
                                        icon: "slider.horizontal.below.sun.max"
                                    )
                                    .foregroundStyle(.updateColors)
                                }
                            }
                            if listOfSegments.contains(where: { $0.hourChanged }) {
                                Button { applySunHoursUpdate() } label: {
                                    Button_With_Icon(
                                        text: "update sun hours",
                                        icon: "clock.arrow.trianglehead.2.counterclockwise.rotate.90"
                                    )
                                    .foregroundStyle(.sunHours)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            if !presetGroupIndex.isEmpty {
                selectedGroupIndex = presetGroupIndex
            }
            loadGroups()
            locationManager.getSingleLocation()
            locationManager.fetchCityName()
        }
        .onChange(of: selectedGroupIndex) { _, _ in
            loadSegments()
        }
        .onChange(of: miredsOffset) { _, newValue in
            UserDefaults.standard.set(newValue, forKey: "huehack-offset-\(selectedGroupIndex)")
        }
        .sheet(isPresented: $showOffsetSheet) {
            OffsetEditorSheet(offset: $miredsOffset)
        }
        .alert("Bridge", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Segment row

    @ViewBuilder
    private func segmentRow(segment: Segment, index: Int) -> some View {
        HStack {
            if segment.synced != .synced {
                Image(systemName: "slider.horizontal.below.sun.max")
                    .foregroundStyle(.updateColors)
            }

            if isEditing {
                Button {
                    listOfSegments[index].show = !(listOfSegments[index].show ?? true)
                } label: {
                    Image(systemName: (listOfSegments[index].show ?? true) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading) {
                Text(segment.name)
                    .font(.subheadline)

                if segment.hourChanged, let newHour = segment.newHourStart {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
                            .font(.caption)
                        Text("\(segment.hourStart.hour!)h\(String(format: "%02d", segment.hourStart.minute!))")
                            .italic()
                            .strikethrough()
                        Image(systemName: "arrowshape.right")
                            .font(.caption)
                        Text("\(newHour.hour!)h\(String(format: "%02d", newHour.minute!))")
                    }
                    .foregroundColor(.sunHours)
                    .font(.footnote)
                } else {
                    Text("\(segment.hourStart.hour!)h\(String(format: "%02d", segment.hourStart.minute!))")
                        .font(.footnote)
                }
            }
            .italic(segment.synced != .synced)
            .fontWeight(segment.synced == .synced ? .regular : .light)
            .foregroundStyle(segment.synced == .notSynced ? .updateColors : .primary)

            Spacer()

            Text("\(segment.temp.miredsToKelvin) °K")
                .font(.caption)

            // Color swatch shows offset-adjusted color
            let displayTemp = min(500, max(153, segment.temp + miredsOffset))
            Rectangle()
                .frame(width: 50)
                .foregroundStyle(Color(mireds: Double(displayTemp)))
                .padding(7)
        }
    }

    // MARK: - Data loading

    private func loadGroups() {
        sendGETGroups(ip: ip, which: nil) { response in
            groups = response
            groupsIndices = response.map { $0.key }
            if selectedGroupIndex.isEmpty, let first = groupsIndices.sorted().first {
                selectedGroupIndex = first
            }
        }
    }

    private func loadSegments() {
        guard !selectedGroupIndex.isEmpty, let groupIdx = Int(selectedGroupIndex) else { return }
        miredsOffset = UserDefaults.standard.integer(forKey: "huehack-offset-\(selectedGroupIndex)")
        isLoading = true
        getSegmentFromRulesForGroup(selectedGroupIndex: groupIdx) { bridgeSegments in
            isLoading = false
            let baseBridge: [Segment] = miredsOffset == 0 ? bridgeSegments : bridgeSegments.map {
                var s = $0
                s.temp = min(500, max(153, s.temp - miredsOffset))
                return s
            }
            listOfSegments = mergeSegmentsWithSolar(
                bridgeSegments: baseBridge,
                locationManager: locationManager
            )
            listOfSegments = listOfSegments.sorted {
                let h0 = ($0.hourStart.hour! < 3 ? $0.hourStart.hour! + 24 : $0.hourStart.hour!) * 60 + ($0.hourStart.minute ?? 0)
                let h1 = ($1.hourStart.hour! < 3 ? $1.hourStart.hour! + 24 : $1.hourStart.hour!) * 60 + ($1.hourStart.minute ?? 0)
                return h0 < h1
            }
        }
    }

    // MARK: - Bridge actions

    private func segmentsWithOffset(_ base: [Segment]) -> [Segment] {
        guard miredsOffset != 0 else { return base }
        return base.map {
            var s = $0
            s.temp = min(500, max(153, s.temp + miredsOffset))
            return s
        }
    }

    private func applySunHoursUpdate() {
        guard let groupIdx = Int(selectedGroupIndex) else { return }
        var updated = listOfSegments
        for i in updated.indices where updated[i].hourChanged {
            if let newHour = updated[i].newHourStart {
                updated[i].hourStart = newHour
                updated[i].hourChanged = false
                updated[i].newHourStart = nil
            }
        }
        createRulesFromlistOfSegments(listOfSegments: segmentsWithOffset(updated), indexGroup: groupIdx) { response in
            alertMessage = response
            showAlert = true
            listOfSegments = updated.map { var s = $0; s.synced = .synced; return s }
        }
    }

    private func applyColorUpdate() {
        guard let groupIdx = Int(selectedGroupIndex) else { return }
        createRulesFromlistOfSegments(listOfSegments: segmentsWithOffset(listOfSegments), indexGroup: groupIdx) { response in
            alertMessage = response
            showAlert = true
            for i in listOfSegments.indices { listOfSegments[i].synced = .synced }
        }
    }
}

// MARK: - Offset editor sheet

struct OffsetEditorSheet: View {
    @Binding var offset: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Fine-tuning de la pièce")
                    .font(.headline)
                    .padding(.top)

                HStack(spacing: 0) {
                    ForEach([-150, -75, 0, 75, 150], id: \.self) { step in
                        Rectangle()
                            .foregroundStyle(Color(mireds: Double(min(500, max(153, 300 + step)))))
                    }
                }
                .frame(height: 50)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)

                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { Double(offset) },
                            set: { offset = (Int($0) / 25) * 25 }
                        ),
                        in: -200...200
                    )
                    .padding(.horizontal)

                    HStack {
                        Text("plus froid")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(offset == 0 ? "neutre" : "\(offset > 0 ? "+" : "")\(offset) mireds")
                            .font(.caption.monospacedDigit())
                            .fontWeight(.semibold)
                        Spacer()
                        Text("plus chaud")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                Button("Réinitialiser") { offset = 0 }
                    .foregroundStyle(.secondary)
                    .font(.callout)

                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack { __rules() }
}

// MARK: - Solar segment builder

func fillListOfSegments(locationManager: LocationManager) -> [Segment] {
    let sun = SunCalc.getTimes(date: Date(), latitude: locationManager.latitude, longitude: locationManager.longitude)
    var segments = [Segment]()

    segments += [Segment(name: "nightEnd",      hourStart: dc(sun.nightEnd),      temp: 500, synced: .notSynced, show: false)]
    segments += [Segment(name: "dawn",          hourStart: dc(sun.dawn),          temp: 325, synced: .notSynced, show: true)]
    segments += [Segment(name: "sunrise",       hourStart: dc(sun.sunrise),       temp: 300, synced: .notSynced, show: true)]
    segments += [Segment(name: "sunriseEnd",    hourStart: dc(sun.sunriseEnd),    temp: 275, synced: .notSynced, show: true)]
    segments += [Segment(name: "goldenHourEnd", hourStart: dc(sun.goldenHourEnd), temp: 250, synced: .notSynced, show: true)]
    segments += [Segment(name: "solarNoon",     hourStart: dc(sun.solarNoon),     temp: 250, synced: .notSynced, show: true)]
    segments += [Segment(name: "goldenHour",    hourStart: dc(sun.goldenHour),    temp: 250, synced: .notSynced, show: true)]
    segments += [Segment(name: "sunsetStart",   hourStart: dc(sun.sunsetStart),   temp: 280, synced: .notSynced, show: true)]
    segments += [Segment(name: "dusk",          hourStart: dc(sun.dusk),          temp: 290, synced: .notSynced, show: true)]
    segments += [Segment(name: "night",         hourStart: dc(sun.night),         temp: 350, synced: .notSynced, show: true)]
    segments += [Segment(name: "nadir",         hourStart: dc(sun.nadir),         temp: 500, synced: .notSynced, show: true)]

    return segments
}

private func dc(_ date: Date?) -> DateComponents {
    Calendar.current.dateComponents([.hour, .minute], from: date ?? Date())
}
