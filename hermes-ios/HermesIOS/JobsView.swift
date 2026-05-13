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
                Section("创建任务") {
                    TextField("名称，例如每日早报", text: $name)
                    TextField("Cron，例如 0 9 * * *", text: $schedule)
                    TextEditor(text: $prompt)
                        .frame(minHeight: 90)
                        .overlay(alignment: .topLeading) {
                            if prompt.isEmpty {
                                Text("任务 Prompt")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                            }
                        }
                    Button {
                        Task { await createJob() }
                    } label: {
                        Label("创建任务", systemImage: "plus.circle.fill")
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || schedule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("任务列表") {
                    if isLoading {
                        ProgressView()
                    } else if jobs.isEmpty {
                        Text("暂无任务")
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
            .navigationTitle("定时任务")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
            }
            .task { await refresh() }
            .alert("任务操作失败", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("好", role: .cancel) {}
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
                Button("运行") { action("run") }
                Button(job.enabled == false ? "恢复" : "暂停") { action(job.enabled == false ? "resume" : "pause") }
                Button("删除", role: .destructive) { action("delete") }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
    }

    private var meta: String {
        [
            job.scheduleDisplay,
            job.nextRunAt.map { "下次 \($0)" },
            job.lastStatus.map { "上次 \($0)" },
            job.enabled == false ? "暂停" : "启用"
        ]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
