import SwiftUI

@main
struct OmnifitWatchApp: App {
    @StateObject private var app = WatchAppState()

    var body: some Scene {
        WindowGroup {
            WatchRoot()
                .environmentObject(app)
        }
    }
}

enum WatchPush: Hashable {
    case team
    case live(SportKind)
}

struct WatchRoot: View {
    var body: some View {
        TabView {
            NavigationStack {
                WatchStartView()
            }
            NavigationStack {
                WatchListView()
            }
            NavigationStack {
                WatchSocialView()
            }
            NavigationStack {
                WatchMeView()
            }
        }
        .tabViewStyle(.verticalPage)
    }
}

struct WatchStartView: View {
    @EnvironmentObject private var app: WatchAppState

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("开始运动")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Spacer()
                NavigationLink(value: WatchPush.team) {
                    Text(app.members.isEmpty ? "组队" : "组队 \(app.members.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniCobalt)
                }
                .buttonStyle(.plain)
            }
            NavigationLink(value: WatchPush.live(.hiking)) {
                Text("徒步")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.omniCobalt)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glass(radius: 24)
            }
            .buttonStyle(.plain)
            NavigationLink(value: WatchPush.live(.running)) {
                Text("跑步")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.omniCobalt)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glass(radius: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .background(CanvasBackground())
        .navigationDestination(for: WatchPush.self) { push in
            switch push {
            case .team:
                WatchTeamView()
            case .live(let sport):
                WatchLiveView(sport: sport, teammates: app.members)
            }
        }
    }
}

struct WatchTeamView: View {
    @EnvironmentObject private var app: WatchAppState

    var body: some View {
        List {
            ForEach(SampleLibrary.teammates) { person in
                Button {
                    app.toggleTeammate(person.id)
                } label: {
                    HStack {
                        Text(person.name)
                        Spacer()
                        if app.members.contains(where: { $0.id == person.id }) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.omniCobalt)
                        }
                    }
                }
            }
        }
        .navigationTitle("组队")
    }
}

struct WatchLiveView: View {
    @EnvironmentObject private var app: WatchAppState
    @Environment(\.dismiss) private var dismiss
    var sport: SportKind
    @StateObject private var session: LiveSession
    @State private var started = false
    @State private var routeWarning: String?

    init(sport: SportKind, teammates: [TeammateProfile]) {
        self.sport = sport
        _session = StateObject(wrappedValue: LiveSession(
            sport: sport,
            plannedRoute: [],
            teammates: teammates
        ))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(sport.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                    Spacer()
                    Button {
                        Task { await end() }
                    } label: {
                        Label("结束", systemImage: "stop.fill")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.omniCoral, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Format.kilometers(session.distanceMeters))
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.omniIce)
                    Text("公里")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
                HStack {
                    VStack(alignment: .leading) {
                        Text(Format.pace(session.paceSecPerKm))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.omniIce)
                        Text("配速")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.omniMuted)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text(Format.integer(session.heartRate))
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.omniCoral)
                        Label("心率", systemImage: "heart.fill")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.omniCoral)
                    }
                }
                RouteMap(route: session.route, teammates: session.teammates, showsUser: !session.simulating, cornerRadius: 16)
                    .frame(height: 72)
                Text(session.simulating ? "本地模拟" : "Apple")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                Text(session.teammates.isEmpty ? "未组队" : "队友 · 本地模拟")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                ForEach(session.teammates.prefix(3)) { mate in
                    HStack {
                        Text(mate.name)
                        Spacer()
                        Text(Format.pace(mate.paceSecPerKm))
                            .foregroundStyle(Color.omniIce)
                        Text(Format.integer(mate.heartRate))
                            .foregroundStyle(Color.omniCoral)
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                }
            }
        }
        .background(CanvasBackground())
        .navigationBarBackButtonHidden(true)
        .task {
            guard !started else { return }
            started = true
            await session.start()
        }
        .alert("路线没有写入健康", isPresented: Binding(
            get: { routeWarning != nil },
            set: { if !$0 { routeWarning = nil } }
        )) {
            Button("好") { dismiss() }
        } message: {
            Text(routeWarning ?? "")
        }
    }

    private func end() async {
        let record = await session.stop()
        app.add(record)
        if let warning = session.routeSaveWarning {
            routeWarning = warning
        } else {
            dismiss()
        }
    }
}

struct WatchListView: View {
    @EnvironmentObject private var app: WatchAppState
    @State private var window: StatsWindow = .week

    private var stats: TrainingStats {
        app.stats(for: window)
    }

    var body: some View {
        List {
            Section {
                Picker("范围", selection: $window) {
                    ForEach(StatsWindow.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.navigationLink)
                Text("距离 \(Format.kilometers(stats.distanceMeters)) 公里")
                Text("心率 \(Format.integer(stats.averageHeartRate))")
                    .foregroundStyle(Color.omniCoral)
                Text("爬升 \(stats.elevationGainMeters > 0 ? String(Int(stats.elevationGainMeters.rounded())) : "—") 米")
                Text("步频 \(Format.integer(stats.averageCadence))")
            }
            ForEach(app.workouts) { workout in
                NavigationLink(value: workout.id) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.sport.title)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(Format.kilometers(workout.distanceMeters))
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color.omniIce)
                            Text("公里")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.omniMuted)
                        }
                    }
                }
            }
        }
        .navigationTitle("运动列表")
        .navigationDestination(for: UUID.self) { id in
            if let workout = app.workouts.first(where: { $0.id == id }) {
                WatchDetailView(workout: workout)
            }
        }
        .task {
            await app.importFromApple()
        }
    }
}

struct WatchDetailView: View {
    var workout: WorkoutRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(workout.sport.title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Text("\(Format.dayTime(workout.start)) · \(Format.duration(workout.duration))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Format.kilometers(workout.distanceMeters))
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.omniIce)
                    Text("公里")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
                Text("\(Format.pace(workout.averagePaceSecPerKm)) 每公里")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Text("心率 \(Format.integer(workout.averageHeartRate))")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniCoral)
                RouteMap(route: workout.route, cornerRadius: 12)
                    .frame(height: 70)
                if workout.origin != .apple {
                    Text(workout.origin == .sample ? "示例" : "本地模拟")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
            }
        }
        .background(CanvasBackground())
    }
}

struct WatchSocialView: View {
    @EnvironmentObject private var app: WatchAppState

    var body: some View {
        List(app.posts) { post in
            VStack(alignment: .leading, spacing: 2) {
                Text(post.isMine ? "\(post.author) · 我的" : post.author)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                if !post.text.isEmpty {
                    Text(post.text)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(2)
                }
                Text("\(post.sport.title) \(Format.kilometers(post.distanceMeters)) 公里")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.omniCobalt)
            }
        }
        .navigationTitle("社交")
    }
}

struct WatchMeView: View {
    @EnvironmentObject private var app: WatchAppState
    @State private var heart = 72.0
    @State private var sleep = 7.4
    @State private var steps = 6420
    @State private var heartSample = true
    @State private var sleepSample = true
    @State private var stepsSample = true

    private var estimate: TrainingEstimateSummary {
        app.estimate()
    }

    var body: some View {
        List {
            Section("健康") {
                Text("心率 \(Int(heart.rounded()))\(heartSample ? " 示例" : "")")
                    .foregroundStyle(Color.omniCoral)
                Text("睡眠 \(String(format: "%.1f", sleep)) 小时\(sleepSample ? " 示例" : "")")
                Text("步数 \(steps)\(stepsSample ? " 示例" : "")")
            }
            Section("训练估计") {
                Text("体能储备 \(estimate.reserve)")
                Text("训练负荷 \(estimate.recentLoad)")
                Text(estimate.restHint)
                Text("不是医疗建议")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
            }
        }
        .navigationTitle("我")
        .task {
            guard AppleHealth.available else { return }
            do {
                try await AppleHealth.authorize()
            } catch {
                return
            }
            let day = await AppleHealth.today()
            if let value = day.heartRate, value > 0 {
                heart = value
                heartSample = false
            }
            if let value = day.sleepHours, value > 0 {
                sleep = value
                sleepSample = false
            }
            if let value = day.steps {
                steps = value
                stepsSample = false
            }
        }
    }
}
