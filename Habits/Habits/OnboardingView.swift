//
//  OnboardingView.swift
//  Habits
//
//  Onboarding/FTUX (SPEC.md's Settings Pass 3), ported from the web app's
//  6-step `#welcome-screen` flow (`index.html` + `settings.js`'s
//  renderOnboardingStep/openWelcomeScreen) — same copy, same step order,
//  same first-run-only program-picker step. Step 5 adds HealthKit sync
//  content the web app doesn't have, since that's iOS-only.
//
//  Presented as a full-screen cover, either automatically on first sign-in
//  (ContentView, mode: .firstRun) or from Settings' "Tutorial" row
//  (mode: .tutorial, skips the program-picker step, matching web's
//  getOnboardingVisibleSteps).
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @StateObject private var rotationBuilderViewModel: RotationBuilderViewModel
    @State private var selectedProgramID: String?
    @State private var showBuilder = false
    let onFinished: () -> Void

    init(userID: UUID, mode: OnboardingMode, onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(userID: userID, mode: mode))
        _rotationBuilderViewModel = StateObject(wrappedValue: RotationBuilderViewModel(userID: userID))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                stepContent
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            footer
        }
        .background(HabitsColor.bg.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .task {
            if viewModel.mode == .firstRun {
                await rotationBuilderViewModel.loadPrograms()
            }
        }
        .onChange(of: rotationBuilderViewModel.programs.count) {
            if selectedProgramID == nil {
                selectedProgramID = rotationBuilderViewModel.programs.first?.id
            }
        }
        .sheet(isPresented: $showBuilder, onDismiss: {
            rotationBuilderViewModel.closeBuilder()
            viewModel.goNext()
        }) {
            RotationBuilderSheet(viewModel: rotationBuilderViewModel) {
                showBuilder = false
            }
        }
    }

    // MARK: - Header (badge + progress dots)

    private var header: some View {
        VStack(spacing: 14) {
            HStack {
                Label(badgeLabel, systemImage: badgeIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(HabitsColor.accent)
                Spacer()
                Text("\(viewModel.stepIndex) / \(viewModel.visibleSteps.count)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(HabitsColor.textSecondary)
            }
            HStack(spacing: 6) {
                ForEach(viewModel.visibleSteps, id: \.self) { step in
                    Capsule()
                        .fill(step == viewModel.step ? HabitsColor.accent : HabitsColor.border)
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 4)
    }

    private var badgeLabel: String {
        switch viewModel.step {
        case 1: return "Why Ondoloop"
        case 2: return "How It Works"
        case 3: return "Pick A Sequence"
        case 4: return "Journaling"
        case 5: return "Weight Tracking"
        default: return "Ready"
        }
    }

    private var badgeIcon: String {
        switch viewModel.step {
        case 1: return "chart.line.uptrend.xyaxis"
        case 2: return "arrow.triangle.2.circlepath"
        case 3: return "list.number"
        case 4: return "book.closed"
        case 5: return "waveform.path.ecg"
        default: return "checkmark.circle.fill"
        }
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case 1: step1
        case 2: step2
        case 3: programPickerStep
        case 4: step4
        case 5: step5
        default: step6
        }
    }

    private func title(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(HabitsColor.textPrimary)
    }

    private func copy(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15))
            .foregroundStyle(HabitsColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var step1: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Small actions. Big change.")
            copy("The science is clear: consistency beats intensity every time. A short workout today is worth more than a perfect workout someday. Ondoloop sets you up with a workout sequence and helps you stay on track — day by day, at your own pace.")
        }
    }

    private var step2: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Your sequence. Your pace.")
            copy("Ondoloop gives you a personalized workout sequence — an ordered list of workouts that cycles day by day. Finish one, the next is waiting. Miss a day? No problem. Your sequence picks up exactly where you left off.")
            copy("No fixed days. No guilt. Just your next step, always ready.")
        }
    }

    private var step4: some View {
        VStack(alignment: .leading, spacing: 18) {
            title("Three questions. Sixty seconds.")
            copy("Research shows that writing down your intentions and gratitude — even briefly — meaningfully improves follow-through and wellbeing. Every day, Ondoloop asks you three things:")

            journalSection("Intention", "Who do you want to be today? Before the noise of the day takes over, intention asks you to pause and be deliberate. Not just what you'll do — but how you'll show up. Mindful. Present. Aligned with the person you're working to become.")
            journalSection("Gratitude", "What are you grateful for? It's easy to fixate on what went wrong or what's still undone. Gratitude practice pushes back. When you stop to name something you're grateful for — even something small you usually take for granted — you start to see how much you've actually built.")
            journalSection("One thing", "What's the single most important thing you'll accomplish today? If you only clear one item today, which one would make everything else feel worth it?")

            copy("Sixty seconds. Compounding returns.")
            Text("Not feeling journaling every day? You can turn it off in Settings.")
                .font(.system(size: 13))
                .italic()
                .foregroundStyle(HabitsColor.textDim)
        }
    }

    private func journalSection(_ heading: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(heading.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(HabitsColor.accent)
            copy(body)
        }
    }

    private var step5: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Daily tracking reveals what sporadic weigh-ins hide.")
            copy("Your weight fluctuates by 2–4 lbs every single day based on water, food, sleep, and stress. A single weigh-in can mislead you — whether you're losing, gaining, or maintaining.")
            copy("Daily tracking gives you the truth. Ondoloop shows your weight trend over time and your 7-day rolling average — the signal, not the noise.")
            copy("On iOS, Ondoloop can also read your weight straight from Apple Health — tap \"Sync from Health\" in Settings anytime your smart scale logs a new reading, and it lands in the same log automatically. This is read-only: Ondoloop never writes back to Health.")
            Text("Not ready to track weight yet? You can turn it off in Settings.")
                .font(.system(size: 13))
                .italic()
                .foregroundStyle(HabitsColor.textDim)
        }
    }

    private var step6: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("You're all set.")
            copy("Your sequence is loaded. Your habits are waiting. Let's go.")
            copy("Not ready to track everything at once? That's completely fine. Head to Settings to choose which habits are right for you — workouts, journaling, and weight tracking can each be turned on or off independently.")
        }
    }

    // MARK: - Step 3: program picker (first-run only)

    private var programPickerStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Choose your starting point.")
            copy("Pick a pre-built sequence or build your own. You can customize it anytime from Settings.")

            if rotationBuilderViewModel.isLoadingPrograms {
                ProgressView().tint(HabitsColor.accent).padding(.top, 20)
            } else if rotationBuilderViewModel.programs.isEmpty {
                Text("Programs could not be loaded right now. You can still build your own from scratch.")
                    .font(.system(size: 13))
                    .foregroundStyle(HabitsColor.textSecondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(rotationBuilderViewModel.programs) { program in
                        Button { selectedProgramID = program.id } label: {
                            programRow(program)
                        }
                        .buttonStyle(HabitsRowButtonStyle())
                    }
                }
            }

            Button {
                rotationBuilderViewModel.openBuilder()
                showBuilder = true
            } label: {
                HStack {
                    Text("Build my own from scratch")
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                }
            }
            .buttonStyle(HabitsGhostButtonStyle(size: .large))

            if let error = rotationBuilderViewModel.programsErrorMessage ?? rotationBuilderViewModel.applyProgramErrorMessage {
                Text(error).font(.system(size: 12)).foregroundStyle(HabitsColor.red)
            }
        }
    }

    private func programRow(_ program: StarterProgram) -> some View {
        let isSelected = program.id == selectedProgramID
        return HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(program.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(HabitsColor.textPrimary)
                if !program.description.isEmpty {
                    Text(program.description)
                        .font(.system(size: 13))
                        .foregroundStyle(HabitsColor.textSecondary)
                }
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? HabitsColor.accent : HabitsColor.textDim)
        }
        .padding(14)
        .background(HabitsColor.surface2)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? HabitsColor.accent : HabitsColor.border, lineWidth: isSelected ? 1.5 : 1)
        )
    }

    // MARK: - Footer (Back / Next)

    private var footer: some View {
        HStack(spacing: 12) {
            if !viewModel.isFirstVisibleStep {
                Button("Back") { viewModel.goBack() }
                    .buttonStyle(HabitsGhostButtonStyle(size: .large))
            }

            Button {
                Task { await advance() }
            } label: {
                if rotationBuilderViewModel.isApplyingProgram {
                    ProgressView().tint(.white)
                } else {
                    Text(primaryButtonLabel)
                }
            }
            .buttonStyle(HabitsPrimaryButtonStyle())
            .disabled(viewModel.step == 3 && (selectedProgramID == nil || rotationBuilderViewModel.isApplyingProgram))
        }
        .padding(20)
    }

    private var primaryButtonLabel: String {
        if viewModel.step == 3 {
            let name = rotationBuilderViewModel.programs.first(where: { $0.id == selectedProgramID })?.name
            return name.map { "Start with \($0)" } ?? "Choose a sequence"
        }
        return viewModel.isLastVisibleStep ? "Get started" : "Next"
    }

    private func advance() async {
        if viewModel.step == 3 {
            guard let id = selectedProgramID,
                  let program = rotationBuilderViewModel.programs.first(where: { $0.id == id }) else { return }
            if await rotationBuilderViewModel.applyProgram(program) {
                viewModel.goNext()
            }
            return
        }
        if viewModel.isLastVisibleStep {
            viewModel.finish()
            onFinished()
        } else {
            viewModel.goNext()
        }
    }
}
