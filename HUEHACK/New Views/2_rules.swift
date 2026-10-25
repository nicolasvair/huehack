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
    @State private var fadeDeciseconds: Int = defaultRoomFade  // shared by the link group
    @State private var showOffsetSheet = false

    @State private var linkedRooms: [String] = []  // rooms sharing this room's schedule
    @State private var linksChanged = false        // a link was just added → linked rooms need a push
    @State private var showLinkSheet = false

    @State private var isPaused = false            // circadian paused for this room (manual colour)
    @State private var isChangingPause = false     // a pause / resume request is in flight
    @State private var showColorSheet = false

    @State private var isEditing = false
    @State private var isLoading = false
    @State private var pendingReload = false       // a reload was requested while busy
    @State private var pushedOffset: Int? = nil    // room offset used by the rules on the bridge
    @State private var pushedFade: Int? = nil      // fade used by the rules on the bridge
    @State private var hasLoadedOnce = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            topBar
            sharedScheduleBanner
            pauseBanner
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
            isPaused = false
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
            OffsetEditorSheet(
                offset: $miredsOffset,
                // Written only on user changes, to the whole link group.
                fade: Binding(
                    get: { fadeDeciseconds },
                    set: { newValue in
                        fadeDeciseconds = newValue
                        setLinkGroupFade(newValue, for: selectedGroupIndex)
                    }
                ),
                isLinked: !linkedRooms.isEmpty
            )
        }
        .sheet(isPresented: $showLinkSheet) {
            LinkRoomsSheet(
                roomIndex: selectedGroupIndex,
                otherRooms: otherRooms,
                groups: groups,
                initialSelection: Set(linkedRooms)
            ) { selection in
                applyLinkSelection(selection)
            }
        }
        .sheet(isPresented: $showColorSheet) {
            ManualColorSheet(
                roomName: groups[selectedGroupIndex]?.name ?? selectedGroupIndex,
                initialAction: groups[selectedGroupIndex]?.action
            ) { hue, sat, bri in
                applyManualColorToRoom(hue: hue, sat: sat, bri: bri)
            }
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
                    .disabled(isLoading)
                }
            }
            Spacer()
            copyMenu
            manualColorButton
            linkButton
            Button { showOffsetSheet = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: "dial.medium").font(.caption)
                    Text(miredsOffset == 0 ? "offset" : "\(miredsOffset > 0 ? "+" : "")\(miredsOffset)").font(.caption)
                    if fadeDeciseconds != defaultRoomFade {
                        Image(systemName: "timer").font(.caption)
                    }
                }
                .foregroundStyle(miredsOffset == 0 && fadeDeciseconds == defaultRoomFade
                                 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.accent))
            }
            .accessibilityLabel("Réglages de la pièce : offset et transition")
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

    /// Link control: a big icon-only button opening a multi-select sheet.
    /// Kept separate from "copy" so its purpose is obvious.
    private var linkButton: some View {
        Button { showLinkSheet = true } label: {
            Image(systemName: linkedRooms.isEmpty ? "link" : "link.circle.fill")
                .font(.title)
                .foregroundStyle(linkedRooms.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.accent))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(groups.isEmpty || selectedGroupIndex.isEmpty)
        .accessibilityLabel(linkedRooms.isEmpty
                            ? "Lier cette pièce à d'autres pièces"
                            : "Liée à \(linkedRooms.count) pièce(s)")
    }

    /// Manual colour: opens the colour sheet. Filled / accent while paused.
    private var manualColorButton: some View {
        Button { showColorSheet = true } label: {
            Image(systemName: isPaused ? "paintpalette.fill" : "paintpalette")
                .font(.title3)
                .foregroundStyle(isPaused ? AnyShapeStyle(.accent) : AnyShapeStyle(.secondary))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(groups.isEmpty || selectedGroupIndex.isEmpty || isChangingPause)
        .accessibilityLabel(isPaused
                            ? "Couleur manuelle — circadien en pause"
                            : "Choisir une couleur manuelle")
    }

    /// One-shot copy of another room's schedule (no lasting link).
    private var copyMenu: some View {
        Menu {
            Section("Copier les horaires depuis") {
                if otherRooms.isEmpty {
                    Text("Aucune autre pièce")
                } else {
                    ForEach(otherRooms, id: \.self) { idx in
                        Button(groups[idx]?.name ?? idx) { copySegments(from: idx) }
                    }
                }
            }
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .disabled(isLoading)
        .accessibilityLabel("Copier les horaires d'une autre pièce")
    }

    /// Reminds the user that this schedule is shared; tap to edit the links.
    @ViewBuilder
    private var sharedScheduleBanner: some View {
        if !linkedRooms.isEmpty {
            Button { showLinkSheet = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                    Text("Planning partagé avec \(linkedRooms.map { groups[$0]?.name ?? $0 }.joined(separator: ", "))")
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .foregroundStyle(.accent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }

    /// Shown while this room's circadian is paused by a manual colour.
    @ViewBuilder
    private var pauseBanner: some View {
        if isPaused {
            HStack(spacing: 6) {
                Image(systemName: "pause.circle.fill")
                Text("Circadien en pause — couleur manuelle")
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isChangingPause {
                    ProgressView()
                } else {
                    Button("Reprendre") { resumeCircadianInRoom() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .font(.caption)
            .foregroundStyle(.accent)
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
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
        // The offset and the fade are applied at push time: changing them needs a push too.
        let offsetChanged = pushedOffset != nil && pushedOffset != miredsOffset
        let fadeChanged = pushedFade != nil && pushedFade != fadeDeciseconds
        let needsUpdate = linksChanged || offsetChanged || fadeChanged
            || listOfSegments.contains(where: { $0.synced == .notSynced || $0.hourChanged || $0.tempChanged })
        VStack {
            Spacer()
            HStack {
                Spacer()
                if needsUpdate {
                    Button { applyUpdate() } label: {
                        Button_With_Icon(text: "Update", icon: "arrow.trianglehead.2.clockwise")
                            .foregroundStyle(.accent)
                    }
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.4 : 1)
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
            // Empty = bridge unreachable / error: keep what we have.
            guard !response.isEmpty else { return }
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
        // Never read the bridge while a push/read is in flight (would see partial
        // rules); reload once it is done instead.
        if isLoading {
            pendingReload = true
            return
        }
        pendingReload = false
        miredsOffset = roomOffset(selectedGroupIndex)
        fadeDeciseconds = roomFade(selectedGroupIndex)
        reloadLinkState()
        loadPauseState()
        // Always read this room's OWN rules, so its sync state tells the truth
        // even when it is linked to other rooms.
        guard let groupIdx = Int(selectedGroupIndex) else { return }
        pushedOffset = demoMode ? nil : lastPushedOffset(groupIndex: groupIdx)
        pushedFade = demoMode ? nil : lastPushedFade(groupIndex: groupIdx)
        if demoMode {
            listOfSegments = demoSegments
            return
        }
        let requestedGroup = selectedGroupIndex
        isLoading = true
        // Read-back returns the BASE schedule (offset removed, lossless thanks to the
        // pushed meta); `legacyOffset` only serves rules pushed by older builds.
        getSegmentFromRulesForGroup(selectedGroupIndex: groupIdx,
                                    legacyOffset: roomOffset(requestedGroup)) { bridgeSegments in
            if finishBusyAndReloadIfNeeded(for: requestedGroup) { return }
            guard let bridgeSegments = bridgeSegments else {
                // Keep the current list: an empty one would look like "nothing installed".
                alertMessage = "Impossible de lire les règles du bridge. Vérifie la connexion puis tire pour rafraîchir."
                showAlert = true
                return
            }
            listOfSegments = sortedCircular(mergeSegmentsWithSolar(
                bridgeSegments: bridgeSegments,
                locationManager: locationManager
            ))
        }
    }

    /// Ends a busy phase. Returns true (and reloads) if the result is stale — the room
    /// changed meanwhile — or a reload was requested while busy.
    private func finishBusyAndReloadIfNeeded(for requestedGroup: String) -> Bool {
        isLoading = false
        guard pendingReload || requestedGroup != selectedGroupIndex else { return false }
        loadSegments()
        return true
    }

    // MARK: - Circadian pause (manual colour)

    /// Reads this room's pause sensor. Independent of `isLoading`: it does not
    /// touch the rules. Ignored if the room changed meanwhile or the read failed.
    private func loadPauseState() {
        guard let groupIdx = Int(selectedGroupIndex) else { return }
        let requestedGroup = selectedGroupIndex
        fetchRoomOverrideState(groupIndex: groupIdx) { paused in
            guard requestedGroup == selectedGroupIndex, let paused = paused else { return }
            isPaused = paused
        }
    }

    /// Pauses this room's circadian, then sends the colour. Never goes through
    /// applyUpdate: the schedule on the bridge is not touched.
    private func applyManualColorToRoom(hue: Int, sat: Int, bri: Int) {
        guard !isChangingPause, let groupIdx = Int(selectedGroupIndex) else { return }
        let requestedGroup = selectedGroupIndex
        isChangingPause = true
        applyManualColor(groupIndex: groupIdx, hue: hue, sat: sat, bri: bri) { ok, message in
            isChangingPause = false
            if !ok {
                alertMessage = message
                showAlert = true
            }
            guard requestedGroup == selectedGroupIndex else { return }
            if ok {
                isPaused = true
                loadGroups()  // refresh the room's colour (sheet starting point)
            } else {
                // The pause may be set even if the colour failed: show the truth.
                loadPauseState()
            }
        }
    }

    /// Resumes the circadian and, if the global switch is on, sends the current
    /// segment's colour right away (base temp + the offset of the rules on the bridge).
    private func resumeCircadianInRoom() {
        guard !isChangingPause, let groupIdx = Int(selectedGroupIndex) else { return }
        var ct: Int? = nil
        if let i = currentSegmentIndex, listOfSegments[i].synced == .synced {
            ct = clampMireds(listOfSegments[i].temp + (pushedOffset ?? miredsOffset))
        }
        let fade = pushedFade ?? fadeDeciseconds
        let requestedGroup = selectedGroupIndex
        isChangingPause = true
        resumeCircadian(groupIndex: groupIdx, ct: ct, fade: fade) { ok, message in
            isChangingPause = false
            if !ok {
                alertMessage = message
                showAlert = true
            }
            guard requestedGroup == selectedGroupIndex else { return }
            if ok { isPaused = false } else { loadPauseState() }
        }
    }

    // MARK: - Link helpers

    /// Every other room on the bridge, sorted by index.
    private var otherRooms: [String] {
        sortedIndices(groupsIndices.filter { $0 != selectedGroupIndex })
    }

    private func reloadLinkState() {
        linkedRooms = roomLinks(selectedGroupIndex)
    }

    /// Applies the checklist from LinkRoomsSheet. Rooms that join the group still
    /// hold their old schedule on the bridge, so this room's schedule is pushed to
    /// the whole group right away — linked rooms then really share one schedule,
    /// instead of depending on an "Update" flag that is lost when leaving the view.
    private func applyLinkSelection(_ selection: Set<String>) {
        let joined = updateRoomLinks(for: selectedGroupIndex, to: selection)
        linkedRooms = roomLinks(selectedGroupIndex)
        if linkedRooms.isEmpty { linksChanged = false }
        guard !joined.isEmpty else { return }
        if listOfSegments.isEmpty || isLoading {
            // Schedule not loaded yet: fall back to the Update button.
            linksChanged = true
        } else {
            applyUpdate()
        }
    }

    private func copySegments(from sourceIdx: String) {
        guard !isLoading, let groupIdx = Int(sourceIdx) else { return }
        let requestedGroup = selectedGroupIndex
        isLoading = true
        // The read-back already strips the source room's own offset — we copy the
        // base schedule, and this room re-applies its own offset when pushing.
        getSegmentFromRulesForGroup(selectedGroupIndex: groupIdx,
                                    legacyOffset: roomOffset(sourceIdx)) { bridgeSegments in
            if finishBusyAndReloadIfNeeded(for: requestedGroup) { return }
            guard let bridgeSegments = bridgeSegments else {
                alertMessage = "Impossible de lire les règles de \(groups[sourceIdx]?.name ?? sourceIdx)."
                showAlert = true
                return
            }
            // Merge with solar to recompute hours like loadSegments does.
            let merged = sortedCircular(mergeSegmentsWithSolar(bridgeSegments: bridgeSegments,
                                                               locationManager: locationManager))
            // Mark as notSynced so the Update button shows.
            listOfSegments = merged.map { var s = $0; s.synced = .notSynced; return s }
        }
    }

    private func applyUpdate() {
        guard !isLoading, let groupIdx = Int(selectedGroupIndex) else { return }
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
        // New hours can change the order: rule N must end where rule N+1 starts.
        updated = sortedCircular(updated)

        // Capture everything now: the view state may change while the push runs.
        let requestedGroup = selectedGroupIndex
        let offset = miredsOffset
        let fade = fadeDeciseconds
        let linked = linkedRooms
        // The fade is shared by the link group: make sure every member has it before
        // pushing (defensive — it is already written group-wide on change / join).
        setLinkGroupFade(fade, for: requestedGroup)
        isLoading = true
        // `updated` is the BASE schedule; the offset and fade are applied (and
        // remembered) by createRulesFromlistOfSegments.
        createRulesFromlistOfSegments(listOfSegments: updated, indexGroup: groupIdx,
                                      offset: offset, fade: fade) { response in
            let ok = response.contains("correctly")
            if ok, requestedGroup == selectedGroupIndex {
                listOfSegments = updated.map { var s = $0; s.synced = .synced; return s }
                pushedOffset = offset
                pushedFade = fade
            }
            pushToLinkedRooms(linked, base: updated) { pushed, failed in
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
                // On failure, show what is really on the bridge rather than a fake "synced".
                if !ok { pendingReload = true }
                _ = finishBusyAndReloadIfNeeded(for: requestedGroup)
            }
        }
    }

    /// Pushes the same base schedule to every linked room, each with its own mireds
    /// offset and its fade (shared by the link group, so equal for all).
    private func pushToLinkedRooms(_ rooms: [String], base: [Segment], completion: @escaping (Int, [String]) -> Void) {
        var remaining = rooms
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
            createRulesFromlistOfSegments(listOfSegments: base, indexGroup: idx,
                                          offset: roomOffset(idxString),
                                          fade: roomFade(idxString)) { response in
                if response.contains("correctly") { pushed += 1 } else { failed.append(idxString) }
                pushNext()
            }
        }

        pushNext()
    }
}

// MARK: - Link editor sheet

/// Multi-select checklist: tick every room that should share this room's schedule.
struct LinkRoomsSheet: View {
    let roomIndex: String
    let otherRooms: [String]
    let groups: [String: RoomResponse]
    let initialSelection: Set<String>
    let onValidate: (Set<String>) -> Void

    @State private var selection = Set<String>()
    @Environment(\.dismiss) private var dismiss

    private var roomName: String { groups[roomIndex]?.name ?? roomIndex }

    /// Rooms that would join the group on validation (ticked ones plus, transitively,
    /// the other members of their own link group).
    private var joining: Set<String> {
        var result = Set<String>()
        for idx in selection.subtracting(initialSelection) {
            result.formUnion(roomLinkGroup(idx))
        }
        return result.subtracting(initialSelection).subtracting([roomIndex])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if otherRooms.isEmpty {
                        Text("Aucune autre pièce").foregroundStyle(.secondary)
                    }
                    ForEach(otherRooms, id: \.self) { idx in
                        Button { toggle(idx) } label: { row(idx) }
                            .buttonStyle(.plain)
                    }
                } header: {
                    Text("Partager le planning de \(roomName) avec")
                } footer: {
                    Text(footer)
                }
            }
            .navigationTitle("Pièces liées")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        onValidate(selection)
                        dismiss()
                    }
                    .disabled(selection == initialSelection)
                }
            }
        }
        .onAppear { selection = initialSelection }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private func row(_ idx: String) -> some View {
        let isOn = selection.contains(idx)
        // Members of another link group: ticking one moves it out of that group.
        let otherGroup = roomLinks(idx).filter { $0 != roomIndex && !initialSelection.contains($0) }
        HStack(spacing: 12) {
            Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isOn ? AnyShapeStyle(.accent) : AnyShapeStyle(.secondary))
            VStack(alignment: .leading, spacing: 2) {
                Text(groups[idx]?.name ?? idx)
                if !initialSelection.contains(idx), !otherGroup.isEmpty {
                    Text(isOn
                         ? "quittera son lien avec \(otherGroup.map { groups[$0]?.name ?? $0 }.joined(separator: ", "))"
                         : "déjà liée à \(otherGroup.map { groups[$0]?.name ?? $0 }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func toggle(_ idx: String) {
        if selection.contains(idx) { selection.remove(idx) } else { selection.insert(idx) }
    }

    private var footer: String {
        var text = "Les pièces liées partagent un seul planning et une même durée de transition, modifiables depuis n'importe laquelle d'entre elles. Chaque pièce garde son propre offset."
        let names = sortedIndices(joining).map { groups[$0]?.name ?? $0 }
        if !names.isEmpty {
            text += "\n\nValider enverra le planning et la transition de \(roomName) à : \(names.joined(separator: ", "))."
        }
        let removed = initialSelection.subtracting(selection)
        if !removed.isEmpty {
            let removedNames = sortedIndices(removed).map { groups[$0]?.name ?? $0 }
            text += "\n\nDéliées (gardent leur planning actuel) : \(removedNames.joined(separator: ", "))."
        }
        return text
    }
}

// MARK: - Offset editor sheet

/// Room options: mireds offset (per room) and fade (shared by the link group).
struct OffsetEditorSheet: View {
    @Binding var offset: Int
    /// Hue `transitiontime`, in deciseconds.
    @Binding var fade: Int
    var isLinked: Bool = false
    @Environment(\.dismiss) private var dismiss

    /// Preset fades (deciseconds). 4 = bridge default.
    private static let fadePresets = [0, 4, 10, 20, 50, 100, 300, 600]

    /// Presets, plus the current value if it is not one of them (keeps the Picker valid).
    private var fadeChoices: [Int] {
        Self.fadePresets.contains(fade) ? Self.fadePresets : (Self.fadePresets + [fade]).sorted()
    }

    private func fadeLabel(_ deciseconds: Int) -> String {
        switch deciseconds {
        case 0: return "Instantané"
        case defaultRoomFade: return "0,4 s (défaut)"
        case let d where d >= 600 && d % 600 == 0: return "\(d / 600) min"
        case let d where d % 10 == 0: return "\(d / 10) s"
        default: return "\(deciseconds / 10),\(deciseconds % 10) s"
        }
    }

    private var fadeCaption: String {
        var text = "Adoucit le passage d'un segment au suivant. Une transition longue s'applique aussi à l'allumage : la lampe repart de sa couleur précédente puis glisse vers la bonne teinte."
        if fade > 100 {
            text += " Au-delà de 10 s, la transition est relancée à chaque cycle de 10 s et ralentit en fin de course."
        }
        if isLinked {
            text += "\nAppliqué à toutes les pièces liées."
        }
        return text
    }

    var body: some View {
        NavigationStack {
            ScrollView {
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

                    Divider()
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Transition", systemImage: "timer")
                                .font(.headline)
                            Spacer()
                            Picker("Transition", selection: $fade) {
                                ForEach(fadeChoices, id: \.self) { value in
                                    Text(fadeLabel(value)).tag(value)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        Text(fadeCaption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
