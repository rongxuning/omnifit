import CoreLocation
import SwiftUI

enum StartSheet: String, Identifiable {
    case type
    case route
    case settings
    var id: String { rawValue }
}

struct StartMapView: View {
    @EnvironmentObject private var app: PhoneAppState
    @EnvironmentObject private var draft: WorkoutDraft
    @Binding var path: NavigationPath
    @StateObject private var location = LocationPermission()
    @State private var sheet: StartSheet?
    @State private var counting = false
    @State private var count = 3

    var body: some View {
        ZStack {
            RouteMap(
                route: [],
                planned: draft.planned.points,
                showsUser: true
            )
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        path = NavigationPath()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.omniInk)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.leading, 8)
                .padding(.top, 4)
                Spacer()
                startBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }

            if counting {
                Text("\(count)")
                    .font(.system(size: 72, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.omniCobalt)
                    .frame(width: 140, height: 140)
                    .glass()
            }
        }
        .navigationBarHidden(true)
        .onAppear { location.request() }
        .onChange(of: location.coordinate?.latitude) { _, _ in
            if let coordinate = location.coordinate {
                draft.origin = GeoPoint(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    altitude: 0,
                    timestamp: nil
                )
            }
        }
        .sheet(item: $sheet) { item in
            switch item {
            case .type: TypeSheet().presentationDetents([.height(280)])
            case .route: RouteSheet().presentationDetents([.medium])
            case .settings: StartSettingsSheet(path: $path, sheet: $sheet).presentationDetents([.medium])
            }
        }
    }

    private var startBar: some View {
        HStack(spacing: 0) {
            barButton("square.grid.2x2", "类型") { sheet = .type }
            barButton("point.topleft.down.curvedto.point.bottomright.up", "路线") { sheet = .route }
            barButton("play.fill", "开始", active: true, action: start)
            barButton("person.2", "组队", badge: draft.memberIDs.count) { path.append(TrainRoute.team) }
            barButton("gearshape.fill", "设置") { sheet = .settings }
        }
        .padding(.horizontal, 4)
        .frame(height: 68)
        .glass(radius: 32)
    }

    private func barButton(_ symbol: String, _ title: String, active: Bool = false, badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(Color.omniCobalt, in: Circle())
                            .offset(x: 10, y: -6)
                    }
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(active ? Color.omniCobalt : Color.omniIdle)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func start() {
        if app.activeSession?.phase == .running {
            path.append(TrainRoute.live)
            return
        }
        guard draft.countdown else {
            path.append(TrainRoute.live)
            return
        }
        counting = true
        count = 3
        Task {
            for value in stride(from: 3, through: 1, by: -1) {
                count = value
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            counting = false
            path.append(TrainRoute.live)
        }
    }
}

struct TypeSheet: View {
    @EnvironmentObject private var draft: WorkoutDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("类型")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(.top, 8)
            ForEach(SportKind.allCases) { sport in
                Button {
                    draft.sport = sport
                    dismiss()
                } label: {
                    HStack {
                        Text(sport.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Spacer()
                        if draft.sport == sport {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.omniCobalt)
                        }
                    }
                    .foregroundStyle(Color.omniInk)
                    .padding(16)
                    .glass()
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(20)
        .background(Color.omniCanvas)
    }
}

struct RouteSheet: View {
    @EnvironmentObject private var draft: WorkoutDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("路线")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .padding(.top, 8)
            ForEach(SampleLibrary.plannedRoutes(around: draft.origin)) { route in
                Button {
                    draft.routeID = route.id
                    dismiss()
                } label: {
                    HStack {
                        Text(route.name)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Spacer()
                        if draft.routeID == route.id {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.omniCobalt)
                        }
                    }
                    .foregroundStyle(Color.omniInk)
                    .padding(16)
                    .glass()
                }
                .buttonStyle(.plain)
            }
            Text("路线画在地图上，仅保存在这台手机。")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
            Spacer()
        }
        .padding(20)
        .background(Color.omniCanvas)
    }
}

struct StartSettingsSheet: View {
    @EnvironmentObject private var draft: WorkoutDraft
    @Binding var path: NavigationPath
    @Binding var sheet: StartSheet?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("设置")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("\(draft.sport.title) · \(draft.planned.name)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
            Toggle(isOn: $draft.countdown) {
                Text("开始前倒计时")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .tint(Color.omniCobalt)
            Text("有健康数据权限时，这次徒步或跑步会写入 Apple 健康。写不进去时，运动页会标明本地模拟。组队位置来自本机模拟，没有服务器。")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
            Button {
                sheet = nil
                path.append(TrainRoute.layout)
            } label: {
                Text("调整展示位置")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.omniCobalt)
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(20)
        .background(Color.omniCanvas)
    }
}

struct TeamPickerView: View {
    @EnvironmentObject private var draft: WorkoutDraft
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("组队")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                Text("选好队友后开始运动，可以看到他们的位置、配速和心率。这些位置由本机模拟，没有服务器。")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                ForEach(SampleLibrary.teammates) { person in
                    Button {
                        toggle(person.id)
                    } label: {
                        HStack {
                            Text(person.name)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Spacer()
                            Image(systemName: draft.memberIDs.contains(person.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.omniCobalt)
                        }
                        .foregroundStyle(Color.omniInk)
                        .padding(16)
                        .glass()
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    dismiss()
                } label: {
                    Text("完成")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.omniCobalt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .background(CanvasBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(Color.omniInk)
    }

    private func toggle(_ id: String) {
        if let index = draft.memberIDs.firstIndex(of: id) {
            draft.memberIDs.remove(at: index)
        } else {
            draft.memberIDs.append(id)
        }
    }
}
