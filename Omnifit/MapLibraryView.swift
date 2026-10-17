import CoreLocation
import MapKit
import SwiftUI
import UniformTypeIdentifiers

struct ShownRoute: Identifiable {
    var id: String
    var name: String
    var points: [GeoPoint]
    var meters: Double
    var fromWorkout: Bool
}

private enum AreaFilter: String, CaseIterable, Identifiable {
    case all = "全部"
    case visible = "当前范围"
    var id: String { rawValue }
}

private enum EditTool: String, CaseIterable, Identifiable {
    case pan = "平移"
    case add = "添加"
    case move = "移动"
    case delete = "删除"
    var id: String { rawValue }
}

enum RouteMeasure {
    static func length(_ points: [GeoPoint]) -> Double {
        guard points.count >= 2 else { return 0 }
        var total = 0.0
        for index in 1..<points.count {
            let start = CLLocation(latitude: points[index - 1].latitude, longitude: points[index - 1].longitude)
            let end = CLLocation(latitude: points[index].latitude, longitude: points[index].longitude)
            total += start.distance(from: end)
        }
        return total
    }

    static func overlaps(_ region: MKCoordinateRegion, points: [GeoPoint]) -> Bool {
        guard let first = points.first else { return false }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for point in points.dropFirst() {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        let regionMinLat = region.center.latitude - halfLat
        let regionMaxLat = region.center.latitude + halfLat
        let regionMinLon = region.center.longitude - halfLon
        let regionMaxLon = region.center.longitude + halfLon
        return minLat <= regionMaxLat && maxLat >= regionMinLat && minLon <= regionMaxLon && maxLon >= regionMinLon
    }
}

struct MapLibraryView: View {
    @EnvironmentObject private var app: PhoneAppState
    @EnvironmentObject private var draft: WorkoutDraft
    @State private var position: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var minKm = 0.0
    @State private var maxKm = 30.0
    @State private var area: AreaFilter = .all
    @State private var preparedRange = false
    @State private var showFilters = false
    @State private var importing = false
    @State private var importError: String?
    @State private var focusIDs: [String] = []

    private var allLines: [ShownRoute] {
        let saved = app.savedRoutes.map { route in
            ShownRoute(
                id: route.id,
                name: route.name,
                points: route.points,
                meters: RouteMeasure.length(route.points),
                fromWorkout: false
            )
        }
        let recorded = app.workouts.compactMap { workout -> ShownRoute? in
            guard workout.route.count >= 2 else { return nil }
            return ShownRoute(
                id: workout.id.uuidString,
                name: "\(workout.sport.title) \(Format.dayTime(workout.start))",
                points: workout.route,
                meters: RouteMeasure.length(workout.route),
                fromWorkout: true
            )
        }
        return saved + recorded
    }

    private var sliderTop: Double {
        let longest = allLines.map { $0.meters / 1000 }.max() ?? 10
        return max(10, longest, maxKm, minKm + 1)
    }

    private var filtered: [ShownRoute] {
        allLines.filter { line in
            let kilometers = line.meters / 1000
            let low = min(minKm, maxKm)
            let high = max(minKm, maxKm)
            guard kilometers + 0.05 >= low, kilometers <= high + 0.05 else { return false }
            if area == .visible, let visibleRegion {
                return RouteMeasure.overlaps(visibleRegion, points: line.points)
            }
            return true
        }
    }

    var body: some View {
        ZStack {
            overviewMap
                .ignoresSafeArea()
            VStack(spacing: 8) {
                topBar
                Spacer()
                routeStrip
                Text("路线保存在这台手机，没有服务器。")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 88)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showFilters) {
            RouteFilterSheet(minKm: $minKm, maxKm: $maxKm, area: $area, sliderTop: sliderTop)
                .presentationDetents([.height(320)])
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: GPXFile.types) { result in
            importFile(result)
        }
        .alert("导入路线", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(importError ?? "")
        }
        .onAppear {
            guard !preparedRange else { return }
            preparedRange = true
            maxKm = sliderTop
            fit(filtered)
        }
        .onChange(of: filtered.map(\.id)) { _, _ in
            if !focusIDs.isEmpty {
                let ids = focusIDs
                focusIDs = []
                let lines = filtered.filter { ids.contains($0.id) }
                fit(lines.isEmpty ? filtered : lines)
                return
            }
            if area == .all {
                fit(filtered)
            }
        }
    }

    private var overviewMap: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            UserAnnotation()
            ForEach(filtered) { line in
                if line.points.count >= 2 {
                    MapPolyline(coordinates: line.points.map(\.coordinate))
                        .stroke(lineColor(line), lineWidth: line.id == draft.routeID ? 6 : 3)
                }
            }
        }
        .mapStyle(.standard)
        .onMapCameraChange { context in
            visibleRegion = context.region
        }
    }

    private var topBar: some View {
        HStack(spacing: 8) {
            Text("地图")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.omniInk)
            Spacer(minLength: 4)
            barLink("筛选") { showFilters = true }
            barLink("导入") { importing = true }
            NavigationLink(value: MapRoute.editor) {
                Text("编辑")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.omniCobalt)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glass(radius: 22)
    }

    private func barLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Color.omniCobalt)
        }
        .buttonStyle(.plain)
    }

    private var routeStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                routeChip(id: PlannedRoute.free.id, title: "自由", detail: "不画路线")
                ForEach(filtered) { line in
                    routeChip(
                        id: line.id,
                        title: line.name,
                        detail: "\(Format.kilometers(line.meters)) 公里"
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .glass(radius: 22)
    }

    private func routeChip(id: String, title: String, detail: String) -> some View {
        Button {
            draft.routeID = id
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                    .lineLimit(1)
            }
            .foregroundStyle(Color.omniInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                draft.routeID == id ? Color.omniIce.opacity(0.45) : Color.clear,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private func lineColor(_ line: ShownRoute) -> Color {
        if line.id == draft.routeID { return Color.omniCobalt }
        return line.fromWorkout ? Color.omniCobalt.opacity(0.45) : Color.omniIce
    }

    private func fit(_ lines: [ShownRoute]) {
        let coordinates = lines.flatMap { $0.points.map(\.coordinate) }
        guard let region = GeoFit.region(coordinates) else { return }
        position = .region(region)
    }

    private func importFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure:
            importError = "没有打开文件。"
        case .success(let url):
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importError = "这个文件里没有路线点。"
                return
            }
            let parsed = GPXFile.parse(data)
            guard !parsed.isEmpty else {
                importError = "这个文件里没有路线点。"
                return
            }
            let kilometers = parsed.map { RouteMeasure.length($0.points) / 1000 }
            if let shortest = kilometers.min(), shortest < minKm {
                minKm = shortest
            }
            if let longest = kilometers.max(), longest > maxKm {
                maxKm = longest
            }
            if area == .visible {
                area = .all
            }
            let identifiers = app.addGPXRoutes(parsed)
            guard let selected = identifiers.first else {
                importError = "这个文件里没有路线点。"
                return
            }
            draft.routeID = selected
            focusIDs = identifiers
            fit(parsed.map { line in
                ShownRoute(
                    id: selected,
                    name: line.name,
                    points: line.points,
                    meters: RouteMeasure.length(line.points),
                    fromWorkout: false
                )
            })
        }
    }
}

private struct RouteFilterSheet: View {
    @Binding var minKm: Double
    @Binding var maxKm: Double
    @Binding var area: AreaFilter
    var sliderTop: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("筛选")
                .font(.system(size: 22, weight: .bold, design: .rounded))
            Text("长度 \(Format.kilometers(min(minKm, maxKm)))–\(Format.kilometers(max(minKm, maxKm))) 公里")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
            VStack(alignment: .leading, spacing: 4) {
                Text("最短")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Slider(value: $minKm, in: 0...sliderTop)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("最长")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Slider(value: $maxKm, in: 0...sliderTop)
            }
            Text("区域")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
            Picker("区域", selection: $area) {
                ForEach(AreaFilter.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            Text(area == .visible ? "只显示经过当前地图范围的路线。" : "显示全部已保存的路线。")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.omniMuted)
            Spacer()
        }
        .padding(20)
        .background(Color.omniCanvas)
        .tint(Color.omniCobalt)
    }
}

struct PresetRouteEditor: View {
    @EnvironmentObject private var app: PhoneAppState
    @Environment(\.dismiss) private var dismiss
    @State private var points: [GeoPoint] = []
    @State private var loaded = false
    @State private var tool: EditTool = .pan
    @State private var position: MapCameraPosition = .automatic
    @State private var dragIndex: Int?

    var body: some View {
        ZStack {
            MapReader { proxy in
                if tool == .move {
                    editorMap.mapStyle(.standard).gesture(moveGesture(proxy))
                } else if tool == .add || tool == .delete {
                    editorMap.mapStyle(.standard).gesture(tapGesture(proxy))
                } else {
                    editorMap.mapStyle(.standard)
                }
            }
            .ignoresSafeArea()

            VStack {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.omniInk)
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    Text("编辑路线")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                    Spacer()
                    Button {
                        app.replacePresetRunning(points: points)
                        dismiss()
                    } label: {
                        Text("保存")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.omniCobalt)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glass(radius: 22)
                Spacer()
                VStack(spacing: 6) {
                    HStack(spacing: 0) {
                        ForEach(EditTool.allCases) { item in
                            Button { tool = item } label: {
                                Text(item.rawValue)
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(tool == item ? Color.omniCobalt : Color.omniIdle)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text(toolHint)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .glass(radius: 22)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .navigationBarHidden(true)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            points = app.savedRoutes.first { $0.kind == .presetRunning }?.points ?? []
            if let region = GeoFit.region(points.map(\.coordinate)) {
                position = .region(region)
            }
        }
    }

    private var toolHint: String {
        switch tool {
        case .pan: return "拖动地图。保存后写在这台手机上。"
        case .add: return "点地图增加一个点。"
        case .move: return "按住一个点拖动。"
        case .delete: return "点一个点删除它。"
        }
    }

    private var editorMap: some View {
        Map(position: $position, interactionModes: tool == .pan ? [.pan, .zoom] : [.zoom]) {
            if points.count >= 2 {
                MapPolyline(coordinates: points.map(\.coordinate))
                    .stroke(Color.omniCobalt, lineWidth: 4)
            }
            ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                Annotation("", coordinate: point.coordinate) {
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.omniInk)
                        .frame(width: 22, height: 22)
                        .background(Color.omniIce, in: Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func tapGesture(_ proxy: MapProxy) -> some Gesture {
        SpatialTapGesture(coordinateSpace: .local)
            .onEnded { value in
                guard let coordinate = proxy.convert(value.location, from: .local) else { return }
                if tool == .add {
                    points.append(GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: 0, timestamp: nil))
                } else if tool == .delete, let index = nearest(to: coordinate, within: 80) {
                    points.remove(at: index)
                }
            }
    }

    private func moveGesture(_ proxy: MapProxy) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .local)
            .onChanged { value in
                guard let coordinate = proxy.convert(value.location, from: .local) else { return }
                let index = dragIndex ?? nearest(to: coordinate, within: 80)
                guard let index else { return }
                dragIndex = index
                points[index].latitude = coordinate.latitude
                points[index].longitude = coordinate.longitude
            }
            .onEnded { _ in
                dragIndex = nil
            }
    }

    private func nearest(to coordinate: CLLocationCoordinate2D, within meters: Double) -> Int? {
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var best: (Int, Double)?
        for (index, point) in points.enumerated() {
            let distance = CLLocation(latitude: point.latitude, longitude: point.longitude).distance(from: target)
            if distance <= meters, best == nil || distance < best!.1 {
                best = (index, distance)
            }
        }
        return best?.0
    }
}

enum GPXFile {
    static var types: [UTType] {
        var list: [UTType] = [.xml]
        if let gpx = UTType(filenameExtension: "gpx") {
            list.insert(gpx, at: 0)
        }
        return list
    }

    static func parse(_ data: Data) -> [(name: String, points: [GeoPoint])] {
        let parser = GPXParser()
        guard parser.parse(data) else { return [] }
        return parser.lines
    }
}

private final class GPXParser: NSObject, XMLParserDelegate {
    private(set) var lines: [(name: String, points: [GeoPoint])] = []
    private var documentName: String?
    private var trackDepth = 0
    private var routeDepth = 0
    private var waypointDepth = 0
    private var trackPoints: [GeoPoint] = []
    private var trackName: String?
    private var routePoints: [GeoPoint] = []
    private var routeName: String?
    private var insidePoint = false
    private var readingName = false
    private var nameBuffer = ""

    func parse(_ data: Data) -> Bool {
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse()
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch localName(elementName, qualified: qName) {
        case "trk":
            trackDepth += 1
            if trackDepth == 1 {
                trackPoints = []
                trackName = nil
            }
        case "rte":
            routeDepth += 1
            if routeDepth == 1 {
                routePoints = []
                routeName = nil
            }
        case "wpt":
            waypointDepth += 1
            insidePoint = true
        case "trkpt":
            insidePoint = true
            if trackDepth > 0, waypointDepth == 0 {
                append(attributeDict, to: &trackPoints)
            }
        case "rtept":
            insidePoint = true
            if routeDepth > 0, trackDepth == 0, waypointDepth == 0 {
                append(attributeDict, to: &routePoints)
            }
        case "name":
            if !insidePoint {
                readingName = true
                nameBuffer = ""
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if readingName { nameBuffer += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch localName(elementName, qualified: qName) {
        case "name":
            guard readingName else { return }
            let text = nameBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            readingName = false
            guard !text.isEmpty, waypointDepth == 0, !insidePoint else { return }
            if trackDepth > 0, routeDepth == 0 {
                if trackName == nil { trackName = text }
            } else if routeDepth > 0, trackDepth == 0 {
                if routeName == nil { routeName = text }
            } else if documentName == nil {
                documentName = text
            }
        case "trk":
            if trackDepth == 1 {
                commit(name: trackName, points: trackPoints)
                trackPoints = []
                trackName = nil
            }
            trackDepth = max(0, trackDepth - 1)
        case "rte":
            if routeDepth == 1 {
                commit(name: routeName, points: routePoints)
                routePoints = []
                routeName = nil
            }
            routeDepth = max(0, routeDepth - 1)
        case "wpt":
            waypointDepth = max(0, waypointDepth - 1)
            insidePoint = false
        case "trkpt", "rtept":
            insidePoint = false
        default:
            break
        }
    }

    private func append(_ attributes: [String: String], to points: inout [GeoPoint]) {
        guard let latitude = Double(attributes["lat"] ?? ""),
              let longitude = Double(attributes["lon"] ?? ""),
              abs(latitude) <= 90, abs(longitude) <= 180 else { return }
        points.append(GeoPoint(latitude: latitude, longitude: longitude, altitude: 0, timestamp: nil))
    }

    private func commit(name: String?, points: [GeoPoint]) {
        guard points.count >= 2 else { return }
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let fallback = documentName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let title = !trimmed.isEmpty ? trimmed : (fallback.isEmpty ? "导入路线" : fallback)
        lines.append((name: title, points: points))
    }

    private func localName(_ elementName: String, qualified qName: String?) -> String {
        let raw = (qName ?? elementName).lowercased()
        guard let colon = raw.lastIndex(of: ":") else { return raw }
        return String(raw[raw.index(after: colon)...])
    }
}
