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

    @State private var linkedRooms: [String] = []  // rooms sharing this room's schedule
    @State private var linksChanged = false        // a link was just added → linked rooms need a push

    @State private var isEditing = false
    @State private var isLoading = false
    @State private var hasLoadedOnce = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            topBar
            editBar
            segmentList
        }
        .onAppear {
            if !presetGroupIndex.isEmpty {
                selectedGroupIndex = presetGroupIndex
            }
            loadGroups()
            locationManager.getSingleLocation()
            locationManager.fetchCityName()
            if !hasLoadedOnce, !selectedGroupIndex.isEmpty {
                hasLoadedOnce = true
                loadSegments()
            }
        }
        .onChange(of: selectedGroupIndex) { _, _ in
            linksChanged = false
            loadSegments()
        }
        .onChange(of: locationManager.latitude) { oldValue, newValue in
            // Only reload on FIRST GPS fix (0 → real), not on subsequent updates that would wipe local edits.
            guard oldValue == 0.0, newValue != 0.0, !selectedGroupIndex.isEmpty else { return }
            loadSegments()
        }
        .onChange(of: miredsOffset) { _, newValue in
            setRoomOffset(newValue, for: selectedGroupIndex)
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

    // MARK: - Sub-views

    @ViewBuilder
    private var topBar: some View {
        HStack {
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
            linkMenu
            Button { showOffsetSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "dial.medium").font(.caption)
                    Text(miredsOffset == 0 ? "offset" : "\(miredsOffset > 0 ? "+" : "")\(miredsOffset)").font(.caption)
                }
                .foregroundStyle(miredsOffset == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.accent))
            }
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
    }

    @ViewBuilder
    private var linkMenu: some View {
        Menu {
            Section("Lier cette pièce à") {
                if otherRooms.isEmpty {
                    Text("Aucune autre pièce")
                } else {
                    ForEach(otherRooms, id: \.self) { idx in
                        Toggle(isOn: Binding(
                            get: { linkedRooms.contains(idx) },
                            set: { _ in toggleLink(idx) }
                        )) {
                            Text(groups[idx]?.name ?? idx)
                        }
                    }
                }
            }

            if !linkedRooms.isEmpty {
                Button(role: .destructive) { unlinkAll() } label: {
                    Label("Tout délier", systemImage: "link.badge.minus")
                }
            }

            Menu {
                if otherRooms.isEmpty {
                    Text("Aucune autre pièce")
                } else {
                    ForEach(otherRooms, id: \.self) { idx in
                        Button(groups[idx]?.name ?? idx) { copySegments(from: idx) }
                    }
                }
            } label: {
                Label("Copier les horaires depuis", systemImage: "doc.on.doc")
            }
        } label: {
            Image(systemName: linkedRooms.isEmpty ? "link" : "link.circle.fill")
                .font(.title2)
                .foregroundStyle(linkedRooms.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.accent))
        }
        .accessibilityLabel(linkedRooms.isEmpty
                            ? "Lier cette pièce"
                            : "Liée à \(linkedRooms.count) pièce(s)")
    }

    @ViewBuilder
    private var editBar: some View {
        HStack {
            Button(isEditing ? "Done" : "Edit") { isEditing.toggle() }
            Spacer()
            Button { createSegmentForNow(listOfSegments: &listOfSegments) } label: {
                Image(systemName: "plus")
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var segmentList: some View {
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
            floatingButtons
        }
    }

    @ViewBuilder
    private var floatingButtons: some View {
        let needsUpdate = linksChanged || listOfSegments.contains(where: { $0.synced == .notSynced || $0.hourChanged })
        VStack {
            Spacer()
            HStack {
                Spacer()
                if needsUpdate {
                    Button { applyUpdate() } label: {
                        Button_With_Icon(text: "Update", icon: "arrow.trianglehead.2.clockwise")
                            .foregroundStyle(.accent)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Segment row

    private func timeStr(_ dc: DateComponents) -> String {
        "\(dc.hour!)h\(String(format: "%02d", dc.minute!))"
    }

    private func endTime(for index: Int) -> DateComponents {
        listOfSegments[(index + 1) % listOfSegments.count].hourStart
    }

    private var currentSegmentIndex: Int? {
        guard !listOfSegments.isEmpty else { return nil }
        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let nowAdj = (now.hour! < 3 ? now.hour! + 24 : now.hour!) * 60 + (now.minute ?? 0)
        var best: Int? = nil
        var bestTime = -1
        for (i, seg) in listOfSegments.enumerated() {
            let h = seg.hourStart.hour ?? 0
            let adj = (h < 3 ? h + 24 : h) * 60 + (seg.hourStart.minute ?? 0)
            if adj <= nowAdj && adj > bestTime {
                bestTime = adj
                best = i
            }
        }
        return best ?? (listOfSegments.isEmpty ? nil : listOfSegments.count - 1)
    }

    @ViewBuilder
    private func segmentRow(segment: Segment, index: Int) -> some View {
        let isCurrent = index == currentSegmentIndex
        HStack {
            Image(systemName: "circle.fill")
                .font(.system(size: 7))
                .foregroundStyle(isCurrent ? AnyShapeStyle(.accent) : AnyShapeStyle(.clear))

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
                        Text(timeStr(segment.hourStart))
                            .italic()
                            .strikethrough()
                        Image(systemName: "arrowshape.right")
                            .font(.caption)
                        Text(timeStr(newHour))
                    }
                    .foregroundColor(.sunHours)
                    .font(.footnote)
                } else {
                    Text(timeStr(segment.hourStart))
                        .font(.footnote)
                }
            }
            .italic(segment.synced != .synced)
            .fontWeight(segment.synced == .synced ? .regular : .light)
            .foregroundStyle(segment.synced == .notSynced ? .updateColors : .primary)

            Spacer()

            if segment.tempChanged, let newTemp = segment.newTemp {
                HStack(spacing: 4) {
                    Text("\(segment.temp.miredsToKelvin)")
                        .italic()
                        .strikethrough()
                    Image(systemName: "arrowshape.right")
                        .font(.caption)
                    Text("\(newTemp.miredsToKelvin) °K")
                }
                .foregroundColor(.updateColors)
                .font(.caption)
            } else {
                Text("\(segment.temp.miredsToKelvin) °K")
                    .font(.caption)
            }

            // Color swatch shows offset-adjusted color (uses pending newTemp if any)
            let baseTemp = segment.newTemp ?? segment.temp
            let displayTemp = min(500, max(153, baseTemp + miredsOffset))
            Rectangle()
                .frame(width: 50)
                .foregroundStyle(Color(mireds: Double(displayTemp)))
                .padding(7)
        }
    }

    // MARK: - Data loading

    private func loadGroups() {
        if demoMode {
            groups = demoGroups
            groupsIndices = Array(demoGroups.keys)
            if selectedGroupIndex.isEmpty, let first = groupsIndices.sorted().first {
                selectedGroupIndex = first
            }
            return
        }
        sendGETGroups(ip: ip, which: nil) { response in
            groups = response
            groupsIndices = sortedIndices(response.map { $0.key })
            migrateAndPruneRoomLinks(existingIndices: groupsIndices)
            if selectedGroupIndex.isEmpty, let first = groupsIndices.first {
                selectedGroupIndex = first
            } else {
                // Links could only be resolved now that the room list is known.
                reloadLinkState()
            }
        }
    }

    private func loadSegments() {
        guard !selectedGroupIndex.isEmpty else { return }
        miredsOffset = roomOffset(selectedGroupIndex)
        reloadLinkState()
        // Always read this room's OWN rules, so its sync state tells the truth
        // even when it is linked to other rooms.
        guard let groupIdx = Int(selectedGroupIndex) else { return }
        if demoMode {
            listOfSegments = demoSegments
            return
        }
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

    private func segmentsWithOffset(_ base: [Segment], offset: Int) -> [Segment] {
        guard offset != 0 else { return base }
        return base.map {
            var s = $0
            s.temp = min(500, max(153, s.temp + offset))
            return s
        }
    }

    // MARK: - Link helpers

    /// Every other room on the bridge, sorted by index.
    private var otherRooms: [String] {
        groupsIndices.filter { $0 != selectedGroupIndex }
    }

    private func reloadLinkState() {
        linkedRooms = roomLinks(selectedGroupIndex)
    }

    private func toggleLink(_ idx: String) {
        if linkedRooms.contains(idx) {
            // The room we untick leaves the group; the others stay linked together.
            unlinkRoom(idx)
        } else {
            linkRooms(selectedGroupIndex, idx)
            // Newly linked rooms still hold their old schedule until the next push.
            linksChanged = true
        }
        linkedRooms = roomLinks(selectedGroupIndex)
    }

    private func unlinkAll() {
        unlinkWholeGroup(selectedGroupIndex)
        linkedRooms = []
        linksChanged = false
    }

    private func copySegments(from sourceIdx: String) {
        guard let groupIdx = Int(sourceIdx) else { return }
        isLoading = true
        getSegmentFromRulesForGroup(selectedGroupIndex: groupIdx) { bridgeSegments in
            isLoading = false
            // Strip the source room's own offset — we copy the base schedule, and
            // this room will re-apply its own offset when pushing.
            let base = segmentsWithOffset(bridgeSegments, offset: -roomOffset(sourceIdx))
            // Merge with solar to recompute hours like loadSegments does.
            var merged = mergeSegmentsWithSolar(bridgeSegments: base, locationManager: locationManager)
            merged = merged.sorted {
                let h0 = ($0.hourStart.hour! < 3 ? $0.hourStart.hour! + 24 : $0.hourStart.hour!) * 60 + ($0.hourStart.minute ?? 0)
                let h1 = ($1.hourStart.hour! < 3 ? $1.hourStart.hour! + 24 : $1.hourStart.hour!) * 60 + ($1.hourStart.minute ?? 0)
                return h0 < h1
            }
            // Mark as notSynced so the Update button shows.
            listOfSegments = merged.map { var s = $0; s.synced = .notSynced; return s }
        }
    }

    private func applyUpdate() {
        guard let groupIdx = Int(selectedGroupIndex) else { return }
        var updated = listOfSegments
        for i in updated.indices where updated[i].hourChanged {
            if let newHour = updated[i].newHourStart {
                updated[i].hourStart = newHour
                updated[i].hourChanged = false
                updated[i].newHourStart = nil
            }
        }
        for i in updated.indices where updated[i].tempChanged {
            if let nt = updated[i].newTemp {
                updated[i].temp = nt
                updated[i].tempChanged = false
                updated[i].newTemp = nil
            }
        }
        isLoading = true
        createRulesFromlistOfSegments(listOfSegments: segmentsWithOffset(updated, offset: miredsOffset),
                                      indexGroup: groupIdx) { response in
            listOfSegments = updated.map { var s = $0; s.synced = .synced; return s }
            pushToLinkedRooms(base: updated) { pushed, failed in
                isLoading = false
                linksChanged = false
                var message = response
                if pushed > 0 {
                    message += "\n→ \(pushed) pièce(s) liée(s) mise(s) à jour"
                }
                if !failed.isEmpty {
                    let names = failed.map { groups[$0]?.name ?? $0 }
                    message += "\n⚠︎ échec : \(names.joined(separator: ", "))"
                }
                alertMessage = message
                showAlert = true
            }
        }
    }

    /// Pushes the same schedule to every linked room, each with its own mireds offset.
    private func pushToLinkedRooms(base: [Segment], completion: @escaping (Int, [String]) -> Void) {
        var remaining = linkedRooms
        var pushed = 0
        var failed = [String]()

        func pushNext() {
            guard let idxString = remaining.first else {
                completion(pushed, failed)
                return
            }
            remaining.removeFirst()
            guard let idx = Int(idxString) else {
                failed.append(idxString)
                pushNext()
                return
            }
            let segments = segmentsWithOffset(base, offset: roomOffset(idxString))
            createRulesFromlistOfSegments(listOfSegments: segments, indexGroup: idx) { response in
                if response.contains("correctly") { pushed += 1 } else { failed.append(idxString) }
                pushNext()
            }
        }

        pushNext()
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
