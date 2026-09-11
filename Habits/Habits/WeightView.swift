//
//  WeightView.swift
//  Habits
//

import SwiftUI

struct WeightView: View {
    @EnvironmentObject var auth: AuthViewModel
    @StateObject private var viewModel: WeightViewModel

    @State private var manualDate = Date()
    @State private var manualWeight = ""
    @State private var showManualEntry = false

    init(userID: UUID) {
        _viewModel = StateObject(wrappedValue: WeightViewModel(userID: userID))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task { await viewModel.syncFromHealthKit() }
                    } label: {
                        Label(viewModel.isSyncing ? "Syncing..." : "Sync from Health", systemImage: "heart.fill")
                    }
                    .disabled(viewModel.isSyncing)

                    Button {
                        showManualEntry = true
                    } label: {
                        Label("Add Weight Manually", systemImage: "plus")
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Section("Recent") {
                    if viewModel.entries.isEmpty && !viewModel.isLoading {
                        Text("No weight entries yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.entries) { entry in
                        HStack {
                            Text(entry.date)
                            Spacer()
                            Text("\(entry.value_lbs, specifier: "%.1f") lbs")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Weight")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log Out") {
                        Task { await auth.signOut() }
                    }
                }
            }
            .refreshable {
                await viewModel.loadEntries()
            }
            .task {
                await viewModel.loadEntries()
            }
            .sheet(isPresented: $showManualEntry) {
                manualEntrySheet
            }
        }
    }

    private var manualEntrySheet: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $manualDate, displayedComponents: .date)
                TextField("Weight (lbs)", text: $manualWeight)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Add Weight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showManualEntry = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let pounds = Double(manualWeight) else { return }
                        let date = manualDate
                        Task {
                            await viewModel.addManualEntry(date: date, pounds: pounds)
                            showManualEntry = false
                            manualWeight = ""
                        }
                    }
                    .disabled(Double(manualWeight) == nil)
                }
            }
        }
    }
}
