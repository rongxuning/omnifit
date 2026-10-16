import SwiftUI

struct LiveWorkoutView: View {
    @EnvironmentObject private var app: PhoneAppState
    @EnvironmentObject private var draft: WorkoutDraft
    @State private var session: LiveSession?
    @State private var confirmEnd = false
    @State private var shareRecord: WorkoutRecord?
    @State private var routeNotice: String?
    @State private var started = false

    var body: some View {
        ZStack {
            CanvasBackground()
            if let session {
                LiveBody(session: session, confirmEnd: $confirmEnd)
            }
        }
        .navigationBarHidden(true)
        .task {
            guard !started else { return }
            started = true
            let live = app.session(for: draft.sport, route: draft.planned.points, teammates: draft.members)
            session = live
            await live.start()
        }
        .alert("结束这次运动？", isPresented: $confirmEnd) {
            Button("取消", role: .cancel) {}
            Button("结束", role: .destructive) {
                Task { await finish() }
            }
        }
        .sheet(item: $shareRecord) { record in
            ShareComposer(record: record, notice: routeNotice) { text, image in
                app.addWorkout(record)
                app.addPost(from: record, text: text, imageData: image)
                shareRecord = nil
                app.noteFinished()
            } onSkip: {
                app.addWorkout(record)
                shareRecord = nil
                app.noteFinished()
            }
            .interactiveDismissDisabled(true)
        }
    }

    private func finish() async {
        guard let session else { return }
        let record = await session.stop()
        routeNotice = session.routeSaveWarning
        shareRecord = record
    }
}

private struct LiveBody: View {
    @EnvironmentObject private var app: PhoneAppState
    @ObservedObject var session: LiveSession
    @Binding var confirmEnd: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(session.sport.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Spacer()
                    Text(session.paused ? "已暂停" : "进行中")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniCobalt)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.omniIce.opacity(0.35), in: Capsule())
                    NavigationLink(value: TrainRoute.layout) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.omniCobalt)
                            .frame(width: 36, height: 36)
                    }
                }
                Text(Format.clock(session.elapsed))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                if !session.statusText.isEmpty {
                    Text(session.statusText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniCobalt)
                }
                ForEach(rows) { row in
                    switch row {
                    case .full(let block):
                        full(block)
                    case .metrics(let blocks):
                        HStack(spacing: 0) {
                            ForEach(blocks) { block in
                                compact(block)
                            }
                        }
                        .padding(.vertical, 12)
                        .glass()
                    }
                }
                if !session.teammates.isEmpty {
                    teammateCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 120)
            .foregroundStyle(Color.omniInk)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                Button {
                    session.paused ? session.resume() : session.pause()
                } label: {
                    Label(session.paused ? "继续" : "暂停", systemImage: session.paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.omniCobalt)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                Button {
                    confirmEnd = true
                } label: {
                    Label("结束", systemImage: "stop.fill")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Color.omniCoral, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .glass()
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var rows: [LiveRow] {
        var output: [LiveRow] = []
        var compact: [LiveBlock] = []
        func flush() {
            if !compact.isEmpty {
                output.append(.metrics(compact))
                compact = []
            }
        }
        for block in app.metricOrder {
            if block.isCompact {
                compact.append(block)
            } else {
                flush()
                output.append(.full(block))
            }
        }
        flush()
        return output
    }

    @ViewBuilder
    private func full(_ block: LiveBlock) -> some View {
        switch block {
        case .map:
            RouteMap(
                route: session.route,
                planned: session.plannedRoute,
                teammates: session.teammates,
                showsUser: !session.simulating,
                cornerRadius: 24
            )
            .frame(minHeight: 180)
            .shadow(color: Color.omniInk.opacity(0.06), radius: 14, y: 8)
        case .distance:
            VStack(alignment: .leading, spacing: 0) {
                Text("总距离")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Format.kilometers(session.distanceMeters))
                        .font(.system(size: 72, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.omniIce)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("公里")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
            }
        case .splits:
            VStack(alignment: .leading, spacing: 8) {
                Text("每公里配速")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                let shown = Array((session.splits + [session.currentSplit]).suffix(4))
                HStack(alignment: .top) {
                    ForEach(shown) { split in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(split.index)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(split.partial ? Color.omniIce : Color.omniMuted)
                            Text(Format.pace(split.paceSecPerKm))
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundStyle(split.partial ? Color.omniIce : Color.omniCobalt)
                            if split.partial {
                                Text("进行中")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.omniCobalt)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(14)
            .glass()
        default:
            EmptyView()
        }
    }

    private func compact(_ block: LiveBlock) -> some View {
        let title: String
        let value: String
        let unit: String
        let color: Color
        switch block {
        case .pace:
            title = "当前配速"
            value = Format.pace(session.paceSecPerKm)
            unit = "每公里"
            color = Color.omniIce
        case .heartRate:
            title = "实时心率"
            value = Format.integer(session.heartRate)
            unit = "次/分"
            color = Color.omniCoral
        case .cadence:
            title = "实时步频"
            value = Format.integer(session.cadence)
            unit = "步/分"
            color = Color.omniIce
        default:
            title = ""
            value = ""
            unit = ""
            color = Color.omniIce
        }
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                if block == .heartRate {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.omniCoral)
                }
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(value)
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
            Text(unit)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, 12)
    }

    private var teammateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("队友 · 本地模拟")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
            ForEach(session.teammates) { mate in
                HStack {
                    Text(mate.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Text(Format.pace(mate.paceSecPerKm))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.omniIce)
                    Text(Format.integer(mate.heartRate))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.omniCoral)
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .glass()
    }
}

private enum LiveRow: Identifiable {
    case full(LiveBlock)
    case metrics([LiveBlock])

    var id: String {
        switch self {
        case .full(let block):
            return "full-\(block.rawValue)"
        case .metrics(let blocks):
            return "metrics-" + blocks.map(\.rawValue).joined(separator: "-")
        }
    }
}

struct LayoutEditor: View {
    @EnvironmentObject private var app: PhoneAppState
    @Environment(\.dismiss) private var dismiss
    @State private var order: [LiveBlock] = []

    var body: some View {
        List {
            Section {
                ForEach(order) { block in
                    Text(block.title)
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(Color.omniInk)
                        .listRowBackground(Color.white.opacity(0.4))
                }
                .onMove { from, to in
                    order.move(fromOffsets: from, toOffset: to)
                }
            } header: {
                Text("拖动调整顺序")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                    .textCase(nil)
            }
        }
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(CanvasBackground())
        .navigationTitle("调整展示位置")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .tint(Color.omniCobalt)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") {
                    app.setMetricOrder(order)
                    dismiss()
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
            }
        }
        .onAppear {
            if order.isEmpty {
                order = app.metricOrder
            }
        }
    }
}
