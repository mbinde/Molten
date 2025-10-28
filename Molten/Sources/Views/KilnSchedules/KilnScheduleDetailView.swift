//
//  KilnScheduleDetailView.swift
//  Molten
//
//  Detailed view for viewing and editing kiln schedules
//

import SwiftUI

struct KilnScheduleDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let schedule: KilnSchedule
    let kilnScheduleService: KilnScheduleService
    let onScheduleUpdated: ((KilnSchedule) -> Void)?
    let onScheduleDeleted: (() -> Void)?

    // Convert schedule to user's preferred temperature unit for display
    private var displaySchedule: KilnSchedule {
        schedule.converted(to: UserSettings.shared.preferredTemperatureUnit)
    }

    // UI state
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDuplicateSheet = false
    @State private var showingExportSheet = false
    @State private var duplicateName: String = ""

    init(
        schedule: KilnSchedule,
        kilnScheduleService: KilnScheduleService,
        onScheduleUpdated: ((KilnSchedule) -> Void)? = nil,
        onScheduleDeleted: (() -> Void)? = nil
    ) {
        self.schedule = schedule
        self.kilnScheduleService = kilnScheduleService
        self.onScheduleUpdated = onScheduleUpdated
        self.onScheduleDeleted = onScheduleDeleted
        _duplicateName = State(initialValue: "\(schedule.name) (Copy)")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                scheduleHeaderCard
                temperatureInfoCard
                segmentsCard

                if let notes = schedule.notes {
                    notesCard(notes)
                }

                metadataCard
            }
            .padding()
        }
        .background(DesignSystem.Colors.background)
        .navigationTitle(schedule.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showingEditSheet) {
            EditKilnScheduleView(
                schedule: schedule,
                kilnScheduleService: kilnScheduleService,
                onScheduleUpdated: onScheduleUpdated
            )
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportScheduleView(schedule: schedule)
        }
        .alert("Duplicate Schedule", isPresented: $showingDuplicateSheet) {
            TextField("New name", text: $duplicateName)
            Button("Cancel", role: .cancel) { }
            Button("Duplicate") {
                duplicateSchedule()
            }
        } message: {
            Text("Enter a name for the duplicated schedule")
        }
        .confirmationDialog(
            "Delete Schedule",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                deleteSchedule()
            }
        } message: {
            Text("Are you sure you want to delete \"\(schedule.name)\"? This action cannot be undone.")
        }
    }

    // MARK: - View Components

    private var scheduleHeaderCard: some View {
        VStack(spacing: 12) {
            // Technique badge
            HStack {
                Image(systemName: "flame.fill")
                    .font(.title3)
                Text(displaySchedule.technique.displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(techniqueColor)
            .clipShape(Capsule())

            // Duration badge
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .foregroundColor(.secondary)
                Text(displaySchedule.formattedDuration)
                    .font(.title2)
                    .fontWeight(.bold)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var temperatureInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temperature Settings")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Start Temperature")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(displaySchedule.startTemperature.formatted()) \(displaySchedule.temperatureUnit.symbol)")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Peak Temperature")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let maxTemp = displaySchedule.segments.map({ $0.targetTemperature }).max() {
                        Text("\(maxTemp.formatted()) \(displaySchedule.temperatureUnit.symbol)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var segmentsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Firing Schedule")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(displaySchedule.segments.count) segment\(displaySchedule.segments.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 12) {
                ForEach(Array(displaySchedule.segments.enumerated()), id: \.offset) { index, segment in
                    DetailSegmentRowView(
                        segment: segment,
                        index: index,
                        temperatureUnit: displaySchedule.temperatureUnit,
                        startTemperature: index == 0 ? displaySchedule.startTemperature : displaySchedule.segments[index - 1].targetTemperature
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(notes)
                .font(.body)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var metadataCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Created:")
                    .foregroundColor(.secondary)
                Spacer()
                Text(schedule.dateCreated, style: .date)
            }
            .font(.caption)

            if schedule.dateModified != schedule.dateCreated {
                HStack {
                    Text("Modified:")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(schedule.dateModified, style: .date)
                }
                .font(.caption)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    showingEditSheet = true
                } label: {
                    Label("Edit Schedule", systemImage: "pencil")
                }

                Button {
                    showingDuplicateSheet = true
                } label: {
                    Label("Duplicate", systemImage: "doc.on.doc")
                }

                Button {
                    showingExportSheet = true
                } label: {
                    Label("Export & Share", systemImage: "square.and.arrow.up")
                }

                Divider()

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Helper Properties

    private var cardBackground: some View {
        Color(UIColor.secondarySystemGroupedBackground)
    }

    private var techniqueColor: Color {
        switch displaySchedule.technique {
        case .fusing, .fullFuse:
            return .orange
        case .tackFuse:
            return .yellow
        case .slumping:
            return .blue
        case .casting:
            return .purple
        case .annealing:
            return .green
        case .other:
            return .gray
        }
    }

    // MARK: - Actions

    private func duplicateSchedule() {
        guard !duplicateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        Task {
            do {
                let duplicated = try await kilnScheduleService.duplicateSchedule(
                    scheduleId: schedule.id,
                    newName: duplicateName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                await MainActor.run {
                    onScheduleUpdated?(duplicated)
                }
            } catch {
                print("Error duplicating schedule: \(error)")
            }
        }
    }

    private func deleteSchedule() {
        Task {
            do {
                try await kilnScheduleService.deleteSchedule(id: schedule.id)
                await MainActor.run {
                    onScheduleDeleted?()
                    dismiss()
                }
            } catch {
                print("Error deleting schedule: \(error)")
            }
        }
    }
}

// MARK: - Detail Segment Row View

struct DetailSegmentRowView: View {
    let segment: KilnSegment
    let index: Int
    let temperatureUnit: TemperatureUnit
    let startTemperature: Decimal

    var body: some View {
        HStack(spacing: 12) {
            // Step number
            Text("\(index + 1)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(segmentColor))

            VStack(alignment: .leading, spacing: 6) {
                // Segment type and target
                HStack(spacing: 8) {
                    Image(systemName: segment.segmentType == .ramp ? "arrow.up.right" : "timer")
                        .font(.caption)
                    Text(segment.segmentType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(segment.targetTemperature.formatted()) \(temperatureUnit.symbol)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .foregroundColor(segmentColor)

                // Details
                HStack(spacing: 16) {
                    if let rampRate = segment.rampRate {
                        DetailLabel(
                            icon: "speedometer",
                            text: "\(rampRate.formatted()) \(temperatureUnit.symbol)/hr"
                        )
                    } else if let holdTime = segment.holdTime {
                        DetailLabel(
                            icon: "clock",
                            text: "\(holdTime.formatted()) min"
                        )
                    }

                    Spacer()

                    // Duration for this segment
                    let duration = segment.calculateDuration(from: startTemperature)
                    let minutes = Int(duration / 60)
                    DetailLabel(
                        icon: "hourglass",
                        text: minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
                    )
                }
            }
        }
        .padding()
        .background(segmentBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var segmentColor: Color {
        segment.segmentType == .ramp ? .orange : .blue
    }

    private var segmentBackground: some View {
        segmentColor.opacity(0.1)
    }
}

struct DetailLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption)
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Edit Schedule View

struct EditKilnScheduleView: View {
    @Environment(\.dismiss) private var dismiss

    let schedule: KilnSchedule
    let kilnScheduleService: KilnScheduleService
    let onScheduleUpdated: ((KilnSchedule) -> Void)?

    // Form state
    @State private var name: String
    @State private var selectedTechnique: KilnTechnique
    @State private var startTemperature: String
    @State private var temperatureUnit: TemperatureUnit
    @State private var notes: String
    @State private var segments: [KilnSegmentInput]

    // UI state
    @State private var showingAddSegment = false
    @State private var editingSegmentIndex: Int? = nil
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showingError = false

    init(
        schedule: KilnSchedule,
        kilnScheduleService: KilnScheduleService,
        onScheduleUpdated: ((KilnSchedule) -> Void)? = nil
    ) {
        self.schedule = schedule
        self.kilnScheduleService = kilnScheduleService
        self.onScheduleUpdated = onScheduleUpdated

        // Convert schedule to user's preferred temperature unit for editing
        let displaySchedule = schedule.converted(to: UserSettings.shared.preferredTemperatureUnit)

        // Initialize state from converted schedule
        _name = State(initialValue: displaySchedule.name)
        _selectedTechnique = State(initialValue: displaySchedule.technique)
        _startTemperature = State(initialValue: displaySchedule.startTemperature.formatted())
        _temperatureUnit = State(initialValue: displaySchedule.temperatureUnit)
        _notes = State(initialValue: displaySchedule.notes ?? "")
        _segments = State(initialValue: displaySchedule.segments.map { segment in
            KilnSegmentInput(
                id: segment.id,
                targetTemperature: segment.targetTemperature,
                rampRate: segment.rampRate,
                holdTime: segment.holdTime
            )
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule Information") {
                    TextField("Schedule Name", text: $name)

                    Picker("Technique", selection: $selectedTechnique) {
                        ForEach(KilnTechnique.allCases, id: \.self) { technique in
                            Text(technique.displayName).tag(technique)
                        }
                    }
                }

                Section("Temperature Settings") {
                    HStack {
                        Text("Start Temperature")
                        Spacer()
                        TextField("70", text: $startTemperature)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(temperatureUnit.symbol)
                            .foregroundColor(.secondary)
                    }

                    Picker("Temperature Unit", selection: $temperatureUnit) {
                        Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
                        Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                    }
                }

                Section {
                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        SegmentRowView(
                            segment: segment,
                            index: index,
                            temperatureUnit: temperatureUnit
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                segments.remove(at: index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                editingSegmentIndex = index
                                showingAddSegment = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onMove { from, to in
                        segments.move(fromOffsets: from, toOffset: to)
                    }

                    Button {
                        showingAddSegment = true
                    } label: {
                        Label("Add Segment", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Segments (\(segments.count))")
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Schedule")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(!isFormValid || isSaving)
                }
            }
            .sheet(isPresented: $showingAddSegment) {
                AddSegmentView(
                    segment: editingSegmentIndex.map { segments[$0] },
                    temperatureUnit: temperatureUnit,
                    onSave: { segment in
                        if let index = editingSegmentIndex {
                            segments[index] = segment
                            editingSegmentIndex = nil
                        } else {
                            segments.append(segment)
                        }
                    }
                )
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !startTemperature.isEmpty &&
        Decimal(string: startTemperature) != nil &&
        !segments.isEmpty
    }

    private func saveSchedule() {
        guard isFormValid else { return }

        isSaving = true

        Task {
            do {
                guard let startTemp = Decimal(string: startTemperature) else {
                    throw NSError(domain: "EditKilnSchedule", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid start temperature"])
                }

                // Convert segment inputs to domain models
                let domainSegments = segments.map { input -> KilnSegment in
                    if let rampRate = input.rampRate {
                        return KilnSegment(
                            id: input.id,
                            targetTemperature: input.targetTemperature,
                            rampRate: rampRate
                        )
                    } else if let holdTime = input.holdTime {
                        return KilnSegment(
                            id: input.id,
                            targetTemperature: input.targetTemperature,
                            holdTime: holdTime
                        )
                    } else {
                        return KilnSegment(
                            id: input.id,
                            targetTemperature: input.targetTemperature,
                            rampRate: 100
                        )
                    }
                }

                // Use fromInput to normalize temperatures to Celsius for storage
                let updatedSchedule = KilnSchedule.fromInput(
                    id: schedule.id,
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    technique: selectedTechnique,
                    dateCreated: schedule.dateCreated,
                    dateModified: Date(),
                    segments: domainSegments,
                    notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                    startTemperature: startTemp,
                    inputUnit: temperatureUnit
                )

                try await kilnScheduleService.updateSchedule(updatedSchedule)

                await MainActor.run {
                    onScheduleUpdated?(updatedSchedule)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isSaving = false
                }
            }
        }
    }
}

#Preview {
    let service = RepositoryFactory.createKilnScheduleService()
    let schedule = KilnSchedule(
        name: "Full Fuse - Standard",
        technique: .fullFuse,
        segments: [
            KilnSegment(targetTemperature: 1000, rampRate: 300),
            KilnSegment(targetTemperature: 1000, holdTime: 15),
            KilnSegment(targetTemperature: 1450, rampRate: 150),
            KilnSegment(targetTemperature: 1450, holdTime: 30)
        ],
        notes: "Standard full fuse schedule for COE 96 glass",
        startTemperature: 70,
        temperatureUnit: .fahrenheit
    )
    return NavigationStack {
        KilnScheduleDetailView(schedule: schedule, kilnScheduleService: service)
    }
}
