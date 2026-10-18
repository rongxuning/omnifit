import SwiftUI

@main
struct OmnifitApp: App {
    @StateObject private var app = PhoneAppState()
    @StateObject private var draft = WorkoutDraft()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .environmentObject(draft)
                .tint(Color.omniCobalt)
        }
    }
}

enum TrainRoute: Hashable {
    case start
    case team
    case live
    case layout
}

enum RecordRoute: Hashable {
    case detail(UUID)
}

enum MeRoute: Hashable {
    case layout
}

enum MapRoute: Hashable {
    case editor
}

enum RootTab: String, CaseIterable, Identifiable {
    case train
    case map
    case records
    case social
    case me

    var id: String { rawValue }

    var title: String {
        switch self {
        case .train: return "训练"
        case .map: return "地图"
        case .records: return "记录"
        case .social: return "社交"
        case .me: return "我"
        }
    }

    var symbol: String {
        switch self {
        case .train: return "figure.run"
        case .map: return "map"
        case .records: return "list.bullet"
        case .social: return "person.2"
        case .me: return "person"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: PhoneAppState

    var body: some View {
        Group {
            if app.isLoggedIn {
                MainShell()
            } else {
                AuthFlow()
            }
        }
        .preferredColorScheme(.light)
    }
}

struct MainShell: View {
    @EnvironmentObject private var app: PhoneAppState
    @State private var tab: RootTab = .train
    @State private var trainPath = NavigationPath()
    @State private var mapPath = NavigationPath()
    @State private var recordPath = NavigationPath()
    @State private var mePath = NavigationPath()

    private var showsTabBar: Bool {
        switch tab {
        case .train: return trainPath.isEmpty
        case .map: return mapPath.isEmpty
        case .records: return recordPath.isEmpty
        case .social: return true
        case .me: return mePath.isEmpty
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .train:
                    NavigationStack(path: $trainPath) {
                        TrainHome()
                            .navigationDestination(for: TrainRoute.self) { route in
                                switch route {
                                case .start: StartMapView(path: $trainPath, tab: $tab)
                                case .team: TeamPickerView()
                                case .live: LiveWorkoutView()
                                case .layout: LayoutEditor()
                                }
                            }
                    }
                case .map:
                    NavigationStack(path: $mapPath) {
                        MapLibraryView()
                            .navigationDestination(for: MapRoute.self) { _ in
                                PresetRouteEditor()
                            }
                    }
                case .records:
                    NavigationStack(path: $recordPath) {
                        RecordsView()
                            .navigationDestination(for: RecordRoute.self) { route in
                                if case .detail(let id) = route {
                                    WorkoutDetailView(workoutID: id)
                                }
                            }
                    }
                case .social:
                    NavigationStack {
                        SocialFeedView()
                    }
                case .me:
                    NavigationStack(path: $mePath) {
                        MeView()
                            .navigationDestination(for: MeRoute.self) { route in
                                if case .layout = route {
                                    LayoutEditor()
                                }
                            }
                    }
                }
            }
            if showsTabBar {
                FloatingTabBar(tab: $tab)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .onChange(of: app.finishedToken) { _, _ in
            trainPath = NavigationPath()
            tab = .records
        }
    }
}

struct FloatingTabBar: View {
    @Binding var tab: RootTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(RootTab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 16, weight: .semibold))
                        Text(item.title)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(tab == item ? Color.omniCobalt : Color.omniIdle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 64)
        .glass(radius: 32)
    }
}

struct TrainHome: View {
    @EnvironmentObject private var app: PhoneAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("训练")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("徒步与跑步")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                NavigationLink(value: TrainRoute.start) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("开始运动")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("地图上选择类型、路线和队友")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.omniMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.omniCobalt)
                    }
                    .foregroundStyle(Color.omniInk)
                    .padding(18)
                    .glass()
                }
                .buttonStyle(.plain)
                if app.activeSession?.phase == .running {
                    NavigationLink(value: TrainRoute.live) {
                        Text("回到进行中的运动")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.omniCobalt)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(18)
                            .glass()
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 120)
        }
        .background(CanvasBackground())
        .navigationBarHidden(true)
    }
}
