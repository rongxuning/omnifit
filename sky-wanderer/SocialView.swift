import PhotosUI
import SwiftUI
import UIKit

struct SocialFeedView: View {
    @EnvironmentObject private var app: PhoneAppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("社交")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("运动结束后可以选择分享到这里。示例和你自己的分享都在这台手机上。")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.omniMuted)
                if app.posts.isEmpty {
                    Text("还没有分享")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
                ForEach(app.posts) { post in
                    PostCard(post: post)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .background(CanvasBackground())
        .navigationBarHidden(true)
    }
}

private struct PostCard: View {
    @EnvironmentObject private var app: PhoneAppState
    var post: SocialPost

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(String(post.author.prefix(1)))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.omniCobalt)
                    .frame(width: 36, height: 36)
                    .background(Color.omniIce.opacity(0.35), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(post.author)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        if post.isMine {
                            Text("我的")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.omniCobalt)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.omniIce.opacity(0.35), in: Capsule())
                        }
                    }
                    Text(Format.dayTime(post.createdAt))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                }
                Spacer()
            }
            if !post.text.isEmpty {
                Text(post.text)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            if let filename = post.imageFilename, let image = app.image(named: filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                RouteArt(route: post.route)
            }
            HStack {
                Text(post.sport.title)
                Text(Format.kilometers(post.distanceMeters) + " 公里")
                Text(Format.pace(post.paceSecPerKm))
                Text(Format.duration(post.duration))
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.omniCobalt)
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(Color.omniCoral)
                Text("\(Int(post.energyKilocalories.rounded())) 千卡")
                    .foregroundStyle(Color.omniCoral)
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
        }
        .padding(14)
        .glass()
    }
}

struct RouteArt: View {
    var route: [GeoPoint]

    var body: some View {
        Canvas { context, size in
            let points = normalized(in: size)
            guard points.count >= 2 else { return }
            var path = Path()
            path.move(to: points[0])
            for point in points.dropFirst() {
                path.addLine(to: point)
            }
            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .color(Color.omniCobalt), style: StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
            if let last = points.last {
                let dot = Path(ellipseIn: CGRect(x: last.x - 5, y: last.y - 5, width: 10, height: 10))
                context.fill(dot, with: .color(Color.omniCobalt))
            }
        }
        .frame(height: 180)
        .background(Color(red: 224 / 255, green: 242 / 255, blue: 254 / 255))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func normalized(in size: CGSize) -> [CGPoint] {
        guard let first = route.first else { return [] }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for point in route {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }
        let latSpan = max(maxLat - minLat, 0.0008)
        let lonSpan = max(maxLon - minLon, 0.0008)
        let inset: CGFloat = 16
        return route.map { point in
            let x = inset + (point.longitude - minLon) / lonSpan * (size.width - inset * 2)
            let y = inset + (1 - (point.latitude - minLat) / latSpan) * (size.height - inset * 2)
            return CGPoint(x: x, y: y)
        }
    }
}

struct ShareComposer: View {
    var record: WorkoutRecord
    var notice: String? = nil
    var onShare: (String, Data?) -> Void
    var onSkip: () -> Void

    @State private var text = ""
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("分享到社交")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("\(record.sport.title) · \(Format.kilometers(record.distanceMeters)) 公里 · \(Format.pace(record.averagePaceSecPerKm)) · \(Format.duration(record.duration))")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                    if let notice {
                        Text(notice)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.omniInk)
                    }
                    TextField("写点什么", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 16, design: .rounded))
                        .padding(12)
                        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Text(imageData == nil ? "添加照片" : "更换照片")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.omniCobalt)
                    }
                    .buttonStyle(.plain)
                    if let imageData, let image = UIImage(data: imageData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    } else {
                        RouteArt(route: record.route)
                    }
                    Button {
                        onShare(text, imageData)
                    } label: {
                        Text("分享")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.omniCobalt, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button("暂不分享", action: onSkip)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.omniMuted)
                        .frame(maxWidth: .infinity)
                }
                .padding(24)
            }
            .background(CanvasBackground())
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    imageData = try? await item.loadTransferable(type: Data.self)
                }
            }
        }
    }
}
