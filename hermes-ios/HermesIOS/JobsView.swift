import SwiftUI

struct JobsView: View {
    @EnvironmentObject private var settings: HermesSettings
    @State private var jobs: [HermesJob] = []
    @State private var name = ""
    @State private var schedule = ""
    @State private var prompt = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Create Job") {
                    TextField("Name, e.g. Daily Briefing", text: $name)
                    TextField("Cron, e.g. 0 9 * * *", text: $schedule)
                    TextEditor(text: $prompt)
                        .frame(minHeight: 90)
                        .overlay(alignment: .topLeading) {
                            if prompt.isEmpty {
                                Text("Job Prompt")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                    Button {
                        Task { await createJob() }
                    } label: {
                        Label("Create Job", systemImage: "plus.circle.fill")
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || schedule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Jobs") {
                    if isLoading {
                        ProgressView()
                    } else if jobs.isEmpty {
                        Text("No jobs yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(jobs) { job in
                            JobRow(job: job) { action in
                                Task { await runAction(action, for: job) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cron Jobs")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .task { await refresh() }
            .alert("Job Action Failed", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            jobs = try await HermesClient(settings: settings).jobs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func createJob() async {
        do {
            try await HermesClient(settings: settings).createJob(name: name, schedule: schedule, prompt: prompt)
            name = ""
            schedule = ""
            prompt = ""
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runAction(_ action: String, for job: HermesJob) async {
        do {
            try await HermesClient(settings: settings).jobAction(id: job.id, action: action)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct JobRow: View {
    let job: HermesJob
    let action: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(job.name ?? job.id)
                .font(.headline)
            Text(meta)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let prompt = job.prompt, !prompt.isEmpty {
                Text(prompt)
                    .font(.caption)
                    .lineLimit(3)
            }
            HStack {
                Button("Run") { action("run") }
                Button(job.enabled == false ? "Resume" : "Pause") { action(job.enabled == false ? "resume" : "pause") }
                Button("Delete", role: .destructive) { action("delete") }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }

    private var meta: String {
        [
            job.scheduleDisplay,
            job.nextRunAt.map { "Next \($0)" },
            job.lastStatus.map { "Last \($0)" },
            job.enabled == false ? "Paused" : "Enabled"
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
