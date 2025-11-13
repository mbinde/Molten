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

                if let description = schedule.description {
                    descriptionCard(description)
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
            if let technique = displaySchedule.technique {
                HStack {
                    Image(systemName: "flame.fill")
                        .font(.title3)
                    Text(technique.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(techniqueColor)
                .clipShape(Capsule())
            }

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
                    Text("Temperature Unit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(displaySchedule.temperatureUnit.symbol)
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
                        startTemperature: index == 0 ? 20 : displaySchedule.segments[index - 1].targetTemperature
                    )
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func descriptionCard(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Description")
                .font(.headline)
                .foregroundColor(.secondary)

            Text(description)
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
        case .fusing: return .orange
        case .casting: return .purple
        case .glassBlowing: return .blue
        case .flameworkinghard, .flameworkingsoft: return .red
        case .stainedGlass: return .green
        case .other, .none: return .gray
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
                // Target temperature
                HStack(spacing: 8) {
                    Image(systemName: "thermometer")
                        .font(.caption)
                    Text("Target")
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
                    DetailLabel(
                        icon: "speedometer",
                        text: "\(segment.rampRate.formatted()) \(temperatureUnit.symbol)/hr"
                    )

                    if segment.holdTime > 0 {
                        DetailLabel(
                            icon: "clock",
                            text: "\(segment.holdTime.formatted()) min"
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
        // Red for heating, blue for cooling, orange for same temp
        if segment.targetTemperature > startTemperature {
            return .red
        } else if segment.targetTemperature < startTemperature {
            return .blue
        } else {
            return .orange
        }
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
    @State private var selectedTechnique: TechniqueType?
    @State private var temperatureUnit: TemperatureUnit
    @State private var description: String
    @State private var segments: [KilnSegmentInput]

    // UI state
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
        _temperatureUnit = State(initialValue: displaySchedule.temperatureUnit)
        _description = State(initialValue: displaySchedule.description ?? "")
        _segments = State(initialValue: displaySchedule.segments.map { segment in
            KilnSegmentInput(
                id: segment.id,
                targetTemperature: segment.targetTemperature,
                rampRate: segment.rampRate,
                holdTime: segment.holdTime
            )
        })
    }

    private var validSegmentCount: Int {
        segments.filter { $0.targetTemperature > 0 && $0.rampRate > 0 }.count
    }

    private var graphSectionHeader: some View {
        HStack {
            Image(systemName: "clock.fill")
                .foregroundColor(.secondary)
                .font(.caption)
            Text("Estimated Duration:")
                .foregroundColor(.secondary)
                .font(.caption)
            Text(calculateEstimatedDuration())
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Schedule Information") {
                    TextField("Schedule Name", text: $name)

                    Picker("Technique", selection: $selectedTechnique) {
                        Text("None").tag(nil as TechniqueType?)
                        ForEach(TechniqueType.allCases, id: \.self) { technique in
                            Text(technique.displayName).tag(technique as TechniqueType?)
                        }
                    }

                    Picker("Temperature Unit", selection: $temperatureUnit) {
                        Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit)
                        Text("Celsius (°C)").tag(TemperatureUnit.celsius)
                    }
                }

                Section {
                    ForEach(segments.indices, id: \.self) { index in
                        InlineSegmentRow(
                            segment: $segments[index],
                            index: index,
                            temperatureUnit: temperatureUnit,
                            onDelete: {
                                segments.remove(at: index)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                segments.remove(at: index)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove { from, to in
                        segments.move(fromOffsets: from, toOffset: to)
                    }
                } header: {
                    HStack {
                        Text("Segments")
                        Spacer()
                        if validSegmentCount > 0 {
                            Text("\(validSegmentCount) segment\(validSegmentCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    Button(action: {
                        segments.append(KilnSegmentInput(targetTemperature: 0, rampRate: 0, holdTime: 0))
                    }) {
                        Label("Add Segment", systemImage: "plus.circle.fill")
                    }
                }

                Section {
                    KilnScheduleGraphView(
                        segments: segments,
                        temperatureUnit: temperatureUnit
                    )
                    .padding(.vertical, 8)
                } header: {
                    graphSectionHeader
                }

                Section("Description") {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
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
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An error occurred")
            }
        }
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        validSegmentCount > 0
    }

    private func calculateEstimatedDuration() -> String {
        // Assume room temperature start (20°C)
        var currentTemp: Decimal = 20
        var totalSeconds: TimeInterval = 0

        // Only include segments that have both rate and target
        let validSegments = segments.filter { $0.targetTemperature > 0 && $0.rampRate > 0 }

        guard !validSegments.isEmpty else {
            return "0m"
        }

        for segment in validSegments {
            let segmentDuration = segment.calculateDuration(from: currentTemp)
            totalSeconds += segmentDuration
            currentTemp = segment.targetTemperature
        }

        let totalMinutes = Int(totalSeconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func saveSchedule() {
        guard isFormValid else { return }

        isSaving = true

        Task {
            do {
                // Filter out empty/incomplete segments before saving
                let validSegments = segments.filter { segment in
                    segment.targetTemperature > 0 && segment.rampRate > 0
                }

                // Convert segment inputs to domain models
                let domainSegments = validSegments.map { input -> KilnSegment in
                    KilnSegment(
                        id: input.id,
                        targetTemperature: input.targetTemperature,
                        rampRate: input.rampRate,
                        holdTime: input.holdTime
                    )
                }

                // Use fromInput to normalize temperatures to Celsius for storage
                let updatedSchedule = KilnSchedule.fromInput(
                    id: schedule.id,
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    technique: selectedTechnique,
                    dateCreated: schedule.dateCreated,
                    dateModified: Date(),
                    segments: domainSegments,
                    description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
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
    let deps = AppDependencies(persistenceController: .createTestController())
    let schedule = KilnSchedule(
        name: "Full Fuse - Standard",
        technique: .fusing,
        segments: [
            KilnSegment(targetTemperature: 1000, rampRate: 300),
            KilnSegment(targetTemperature: 1000, rampRate: 1, holdTime: 15),
            KilnSegment(targetTemperature: 1450, rampRate: 150),
            KilnSegment(targetTemperature: 1450, rampRate: 1, holdTime: 30)
        ],
        description: "Standard full fuse schedule for COE 96 glass",
        temperatureUnit: .celsius
    )
    NavigationStack {
        KilnScheduleDetailView(schedule: schedule, kilnScheduleService: deps.kilnScheduleService)
    }
}
