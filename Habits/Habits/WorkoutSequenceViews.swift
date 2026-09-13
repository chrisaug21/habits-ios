//
//  WorkoutSequenceViews.swift
//  Habits
//
//  The Settings "Workout Sequence" card plus its two sheets: the builder
//  (reorder/add/remove workouts, create custom ones) and the program reset
//  picker. See SPEC.md's Settings addendum, pass 2, and the web app's
//  settings.js rotation-builder / program-picker for the behavior mirrored
//  here.
//

import SwiftUI

/// A workout row ready to display, regardless of whether it came from the
/// user's saved `user_rotation` (icon stored as a Lucide name, needs
/// translating) or the hardcoded default rotation (icon already an SF
/// Symbol name) — so the card can show a real sequence either way instead
/// of hiding behind a generic "you're on the default" message.
private struct DisplayWorkout: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let category: String
}

// MARK: - Settings summary card

struct WorkoutSequenceCard: View {
    @ObservedObject var viewModel: RotationBuilderViewModel
    @Binding var showBuilder: Bool
    @Binding var showProgramReset: Bool

    private var displayRotation: [DisplayWorkout] {
        if let rotation = viewModel.currentRotation {
            return rotation.map {
                DisplayWorkout(icon: LucideIcon.sfSymbolName($0.icon), name: $0.name, category: $0.category ?? "")
            }
        }
        return DefaultWorkouts.rotation.map {
            DisplayWorkout(icon: $0.icon, name: $0.name, category: $0.category)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WORKOUT SEQUENCE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.4)
                .foregroundStyle(HabitsColor.textSecondary)

            if !viewModel.hasCustomRotation {
                Text("Using the default sequence:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(HabitsColor.textSecondary)
            }

            VStack(spacing: 10) {
                ForEach(Array(displayRotation.enumerated()), id: \.offset) { index, workout in
                    HStack(spacing: 10) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(HabitsColor.textDim)
                            .frame(width: 18)
                        Image(systemName: workout.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(HabitsColor.textSecondary)
                            .frame(width: 20)
                        Text(workout.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(HabitsColor.textPrimary)
                        Spacer()
                        if !workout.category.isEmpty {
                            Text(workout.category)
                                .font(.system(size: 12))
                                .foregroundStyle(HabitsColor.textSecondary)
                        }
                    }
                }
            }

            VStack(spacing: 10) {
                Button(viewModel.hasCustomRotation ? "Edit Sequence" : "Customize My Sequence") {
                    viewModel.openBuilder()
                    showBuilder = true
                }
                .buttonStyle(HabitsGhostButtonStyle(size: .large))

                Button("Reset to a Program") {
                    showProgramReset = true
                }
                .buttonStyle(HabitsGhostButtonStyle(size: .large))
            }

            if let error = viewModel.loadErrorMessage {
                Text(error).font(.system(size: 12)).foregroundStyle(HabitsColor.red)
            }
        }
        .habitsCard()
    }
}

// MARK: - Builder sheet

struct RotationBuilderSheet: View {
    @ObservedObject var viewModel: RotationBuilderViewModel
    let onDismiss: () -> Void
    @State private var showCustomForm = false

    private var slots: [StagedRotationSlot] { viewModel.stagedSlots ?? [] }

    var body: some View {
        NavigationStack {
            List {
                sequenceSection
                addYourOwnSection
                libraryGroupSection(title: "GLOBAL", workouts: globalWorkouts)
                libraryGroupSection(title: "YOUR WORKOUTS", workouts: customWorkouts)
                if viewModel.workoutLibrary.isEmpty {
                    Section {
                        Text("No workouts available yet — add your own above.")
                            .font(.system(size: 13))
                            .foregroundStyle(HabitsColor.textSecondary)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(HabitsColor.bg.ignoresSafeArea())
            .navigationTitle("Workout Sequence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitsColor.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.closeBuilder()
                        onDismiss()
                    }
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isSaving ? "Saving..." : "Save") {
                        Task {
                            if await viewModel.saveStagedRotation() {
                                onDismiss()
                            }
                        }
                    }
                    .fontWeight(.bold)
                    .disabled(slots.count < 2 || viewModel.isSaving)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let error = viewModel.saveErrorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundStyle(HabitsColor.red)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .background(HabitsColor.bg)
                }
            }
        }
        .habitsSheet(detents: [.large])
        .tint(HabitsColor.accent)
        .preferredColorScheme(.dark)
    }

    private var globalWorkouts: [WorkoutLibraryRow] {
        viewModel.workoutLibrary.filter(\.is_global).sorted { $0.name < $1.name }
    }

    private var customWorkouts: [WorkoutLibraryRow] {
        viewModel.workoutLibrary.filter { !$0.is_global }.sorted { $0.name < $1.name }
    }

    // MARK: Current sequence

    private var sequenceSection: some View {
        Section {
            ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                stagedRow(slot, position: index + 1)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
            .onMove { viewModel.moveStagedSlots(fromOffsets: $0, toOffset: $1) }
        } header: {
            Text("SEQUENCE")
                .font(.system(size: 10, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(HabitsColor.textSecondary)
        }
    }

    private func stagedRow(_ slot: StagedRotationSlot, position: Int) -> some View {
        let workout = viewModel.workout(forID: slot.workoutId)
        return HStack(spacing: 10) {
            Text("\(position)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(HabitsColor.textDim)
                .frame(width: 18)
            Image(systemName: LucideIcon.sfSymbolName(workout?.icon))
                .font(.system(size: 14))
                .foregroundStyle(HabitsColor.textSecondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout?.name ?? "Unknown workout")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HabitsColor.textPrimary)
                if let category = workout?.category, !category.isEmpty {
                    Text(category)
                        .font(.system(size: 11))
                        .foregroundStyle(HabitsColor.textSecondary)
                }
            }
            Spacer()
            Button {
                viewModel.removeStagedSlot(slot.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(HabitsColor.red)
            }
            .buttonStyle(.plain)
            .disabled(slots.count <= 2)
            .opacity(slots.count <= 2 ? 0.35 : 1)
        }
        .padding(12)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Add your own

    private var addYourOwnSection: some View {
        Section {
            if showCustomForm {
                customWorkoutForm
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                Button("+ Add Your Own Workout") {
                    viewModel.showCustomWorkoutForm()
                    showCustomForm = true
                }
                .buttonStyle(HabitsGhostButtonStyle(size: .large))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    private var customWorkoutForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            HabitsTextField(placeholder: "Workout name", text: $viewModel.customWorkoutName)

            Picker("Category", selection: $viewModel.customWorkoutCategory) {
                ForEach(WorkoutCategory.allCases) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)

            if let error = viewModel.customWorkoutErrorMessage {
                Text(error).font(.system(size: 12)).foregroundStyle(HabitsColor.red)
            }

            HStack(spacing: 10) {
                Button("Cancel") {
                    viewModel.hideCustomWorkoutForm()
                    showCustomForm = false
                }
                .buttonStyle(HabitsGhostButtonStyle(size: .large))
                Button(viewModel.isSavingCustomWorkout ? "Adding..." : "Add Workout") {
                    Task {
                        await viewModel.saveCustomWorkout()
                        if viewModel.customWorkoutErrorMessage == nil {
                            showCustomForm = false
                        }
                    }
                }
                .buttonStyle(HabitsPrimaryButtonStyle())
                .disabled(viewModel.isSavingCustomWorkout)
            }
        }
        .padding(14)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Library

    private func libraryGroupSection(title: String, workouts: [WorkoutLibraryRow]) -> some View {
        Group {
            if !workouts.isEmpty {
                Section {
                    ForEach(workouts) { workout in
                        libraryRow(workout)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                    .moveDisabled(true)
                } header: {
                    Text(title)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(HabitsColor.textSecondary)
                }
            }
        }
    }

    private func libraryRow(_ workout: WorkoutLibraryRow) -> some View {
        let isAdded = viewModel.lastAddedWorkoutID == workout.id
        return HStack(spacing: 10) {
            Image(systemName: LucideIcon.sfSymbolName(workout.icon))
                .font(.system(size: 14))
                .foregroundStyle(HabitsColor.textSecondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(HabitsColor.textPrimary)
                if let category = workout.category, !category.isEmpty {
                    Text(category)
                        .font(.system(size: 11))
                        .foregroundStyle(HabitsColor.textSecondary)
                }
            }
            Spacer()
            Button(isAdded ? "Added" : "Add") {
                viewModel.addWorkoutToStage(workout.id)
            }
            .buttonStyle(HabitsGhostButtonStyle())
            .disabled(isAdded)
        }
        .padding(12)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Program reset sheet

struct ProgramResetSheet: View {
    @ObservedObject var viewModel: RotationBuilderViewModel
    let onDismiss: () -> Void
    let onBuildOwn: () -> Void
    @State private var pendingProgram: StarterProgram?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Text("Pick a program to replace your current sequence.")
                        .font(.system(size: 13))
                        .foregroundStyle(HabitsColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if viewModel.isLoadingPrograms {
                        ProgressView().tint(HabitsColor.accent).padding(.top, 40)
                    } else if viewModel.programs.isEmpty {
                        Text("Programs could not be loaded right now. You can still build your own from scratch.")
                            .font(.system(size: 13))
                            .foregroundStyle(HabitsColor.textSecondary)
                            .padding(.top, 24)
                    } else {
                        ForEach(viewModel.programs) { program in
                            Button {
                                pendingProgram = program
                            } label: {
                                programCard(program)
                            }
                            .buttonStyle(HabitsRowButtonStyle())
                            .disabled(viewModel.isApplyingProgram)
                        }
                    }

                    Button {
                        onBuildOwn()
                    } label: {
                        HStack {
                            Text("Build My Own")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .buttonStyle(HabitsGhostButtonStyle(size: .large))
                    .disabled(viewModel.isApplyingProgram)

                    if let error = viewModel.programsErrorMessage ?? viewModel.applyProgramErrorMessage {
                        Text(error).font(.system(size: 12)).foregroundStyle(HabitsColor.red)
                    }
                }
                .padding(16)
            }
            .background(HabitsColor.bg.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .navigationTitle("Select a Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(HabitsColor.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onDismiss)
                }
            }
            .task { await viewModel.loadPrograms() }
            .alert(
                "Replace your sequence?",
                isPresented: Binding(
                    get: { pendingProgram != nil },
                    set: { if !$0 { pendingProgram = nil } }
                )
            ) {
                Button("Cancel", role: .cancel) { pendingProgram = nil }
                Button("Replace", role: .destructive) {
                    guard let program = pendingProgram else { return }
                    Task {
                        if await viewModel.applyProgram(program) {
                            onDismiss()
                        }
                        pendingProgram = nil
                    }
                }
            } message: {
                Text("Replace your current sequence with \(pendingProgram?.name ?? "this program")? This cannot be undone.")
            }
        }
        .habitsSheet(detents: [.large])
        .tint(HabitsColor.accent)
        .preferredColorScheme(.dark)
    }

    private func programCard(_ program: StarterProgram) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(program.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(HabitsColor.textPrimary)
                    if !program.description.isEmpty {
                        Text(program.description)
                            .font(.system(size: 12))
                            .foregroundStyle(HabitsColor.textSecondary)
                    }
                }
                Spacer()
                Text("\(program.workouts.count) workout\(program.workouts.count == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(HabitsColor.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(HabitsColor.accent.opacity(0.14))
                    .clipShape(Capsule())
            }
            HStack(spacing: 8) {
                ForEach(Array(program.workouts.prefix(5))) { workout in
                    Image(systemName: LucideIcon.sfSymbolName(workout.icon))
                        .font(.system(size: 13))
                        .foregroundStyle(HabitsColor.textPrimary)
                        .frame(width: 30, height: 30)
                        .background(HabitsColor.surface2)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(HabitsColor.border, lineWidth: 1))
                }
                if program.workouts.count > 5 {
                    Text("+\(program.workouts.count - 5)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(HabitsColor.textSecondary)
                }
            }
        }
        .padding(16)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HabitsColor.borderActive.opacity(0.4), lineWidth: 1)
        )
    }
}
