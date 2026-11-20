import SwiftUI

// MARK: - Root

struct ContentView: View {
    @State private var cityIndex = 0
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            TodayView(city: City.all[cityIndex])
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
                .tag(0)
            CitiesView(selected: $cityIndex, tab: $tab)
                .tabItem { Label("Cities", systemImage: "list.bullet") }
                .tag(1)
        }
        .tint(.white)
    }
}

// MARK: - Sky

struct SkyBackground: View {
    let condition: Condition
    @State private var drift = false

    var body: some View {
        ZStack {
            LinearGradient(colors: condition.sky, startPoint: .top, endPoint: .bottom)
            // A soft glow that slowly breathes — the sun, or the moon's halo.
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.35), .clear],
                                     center: .center, startRadius: 0, endRadius: 190))
                .frame(width: 380, height: 380)
                .offset(x: drift ? 26 : -10, y: drift ? -318 : -300)
                .blur(radius: 6)
            if condition == .clearNight {
                ForEach(0..<42, id: \.self) { i in
                    Circle().fill(.white.opacity(0.35 + Double(i % 4) * 0.14))
                        .frame(width: i % 5 == 0 ? 2.4 : 1.4, height: i % 5 == 0 ? 2.4 : 1.4)
                        .position(x: CGFloat((i * 89) % 390) + 8, y: CGFloat((i * 61) % 330) + 14)
                }
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.9), value: condition)
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

// MARK: - Today

struct TodayView: View {
    let city: City
    @State private var appeared = false
    @State private var dayDetail: DayRow?

    var body: some View {
        ZStack {
            SkyBackground(condition: city.condition)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header.entrance(0, appeared)
                    hourlyCard.entrance(1, appeared)
                    detailsGrid.entrance(2, appeared)
                    weekCard.entrance(3, appeared)
                    Text("Samaa — design showcase · demo data, not a forecast")
                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.65))
                        .padding(.top, 2).padding(.bottom, 10)
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
            }
        }
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.05)) { appeared = true } }
        .onChange(of: city.id) { _ in
            appeared = false
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.08)) { appeared = true }
        }
        .sheet(item: $dayDetail) { day in
            DaySheet(city: city, day: day)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(city.name).font(.system(size: 34, weight: .medium))
            Text(city.region).font(.system(size: 13)).foregroundColor(.white.opacity(0.8))
            HStack(alignment: .top, spacing: 0) {
                Text("\(city.temp)")
                    .font(.system(size: 92, weight: .thin))
                    .contentTransition(.numericText())
                Text("°").font(.system(size: 60, weight: .thin))
            }
            .animation(.easeInOut(duration: 0.45), value: city.temp)
            HStack(spacing: 6) {
                Image(systemName: city.condition.symbol).symbolRenderingMode(.multicolor)
                Text(city.condition.label).font(.system(size: 16, weight: .medium))
            }
            Text("H:\(city.high)°   L:\(city.low)°").font(.system(size: 15, weight: .medium))
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
    }

    private var hourlyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Hourly forecast", systemImage: "clock")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.85))
                .textCase(.uppercase)
            TempCurve(points: city.hourly)
                .frame(height: 74)
            HStack {
                ForEach(city.hourly) { h in
                    VStack(spacing: 5) {
                        Text(h.hour).font(.system(size: 11.5)).foregroundColor(.white.opacity(0.85))
                        Image(systemName: h.symbol).symbolRenderingMode(.multicolor).font(.system(size: 15))
                        Text("\(Int(h.temp.rounded()))°").font(.system(size: 13.5, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .foregroundColor(.white)
        .padding(14)
        .glassCard()
    }

    private var detailsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            detail("thermometer.medium", "Feels like", "\(city.feels)°", "Similar to the real temperature")
            detail("humidity.fill", "Humidity", "\(city.humidity)%", city.humidity > 75 ? "Humid — rain is close" : "Comfortable air")
            detail("wind", "Wind", "\(city.wind) km/h", city.wind > 20 ? "Strong — hold your hat" : "Light breeze")
            detail("sun.max.fill", "UV index", "\(city.uv)", city.uv >= 8 ? "Very high — seek shade" : city.uv >= 5 ? "High — wear sunscreen" : "Moderate")
            detail("gauge.with.dots.needle.50percent", "Pressure", "\(city.pressure) hPa", city.pressure < 1010 ? "Low — weather changing" : "Steady and settled")
            detail("sunrise.fill", "Sun & moon", "\(city.sunrise)", "Sunset at \(city.sunset)")
        }
    }

    private func detail(_ icon: String, _ title: String, _ value: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: icon)
                .font(.system(size: 11.5, weight: .semibold)).foregroundColor(.white.opacity(0.85))
                .textCase(.uppercase).lineLimit(1)
            Text(value).font(.system(size: 25, weight: .medium))
            Text(note).font(.system(size: 12)).foregroundColor(.white.opacity(0.85))
            Spacer(minLength: 0)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(12)
        .glassCard()
    }

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("7-day forecast", systemImage: "calendar")
                .font(.system(size: 12, weight: .semibold)).foregroundColor(.white.opacity(0.85))
                .textCase(.uppercase)
                .padding(.bottom, 6)
            let lo = city.days.map(\.low).min() ?? 0
            let hi = city.days.map(\.high).max() ?? 1
            ForEach(city.days) { d in
                Button { dayDetail = d } label: {
                    HStack(spacing: 10) {
                        Text(d.day).font(.system(size: 15, weight: .medium)).frame(width: 62, alignment: .leading)
                        Image(systemName: d.symbol).symbolRenderingMode(.multicolor).font(.system(size: 16))
                        Text("\(d.low)°").font(.system(size: 14)).foregroundColor(.white.opacity(0.75)).frame(width: 32, alignment: .trailing)
                        RangeBar(low: d.low, high: d.high, minAll: lo, maxAll: hi)
                        Text("\(d.high)°").font(.system(size: 14, weight: .semibold)).frame(width: 32, alignment: .leading)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundColor(.white.opacity(0.6))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if d.id != city.days.last?.id { Divider().background(Color.white.opacity(0.25)) }
            }
        }
        .padding(14)
        .glassCard()
    }
}

struct RangeBar: View {
    let low: Int, high: Int, minAll: Int, maxAll: Int
    var body: some View {
        GeometryReader { g in
            let span = max(1, maxAll - minAll)
            let x0 = g.size.width * CGFloat(low - minAll) / CGFloat(span)
            let w = max(14, g.size.width * CGFloat(high - low) / CGFloat(span))
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.25))
                Capsule()
                    .fill(LinearGradient(colors: [.cyan, .yellow, .orange], startPoint: .leading, endPoint: .trailing))
                    .frame(width: w).offset(x: x0)
            }
        }
        .frame(height: 5)
    }
}

struct TempCurve: View {
    let points: [HourPoint]
    var body: some View {
        GeometryReader { g in
            let temps = points.map(\.temp)
            let lo = (temps.min() ?? 0) - 1, hi = (temps.max() ?? 1) + 1
            let step = g.size.width / CGFloat(max(1, points.count - 1))
            let pts: [CGPoint] = points.enumerated().map { i, p in
                CGPoint(x: step * CGFloat(i),
                        y: g.size.height - (CGFloat(p.temp - lo) / CGFloat(hi - lo)) * g.size.height)
            }
            ZStack {
                Path { path in
                    path.move(to: pts[0])
                    for i in 1..<pts.count {
                        let mid = CGPoint(x: (pts[i - 1].x + pts[i].x) / 2, y: (pts[i - 1].y + pts[i].y) / 2)
                        path.addQuadCurve(to: mid, control: pts[i - 1])
                        if i == pts.count - 1 { path.addLine(to: pts[i]) }
                    }
                }
                .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                ForEach(Array(pts.enumerated()), id: \.offset) { _, p in
                    Circle().fill(.white).frame(width: 5, height: 5).position(p)
                }
            }
        }
    }
}

struct DaySheet: View {
    let city: City
    let day: DayRow
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ZStack {
            LinearGradient(colors: city.condition.sky, startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: 10) {
                Image(systemName: day.symbol).symbolRenderingMode(.multicolor).font(.system(size: 54))
                Text("\(city.name) — \(day.day)").font(.system(size: 20, weight: .semibold)).foregroundColor(.white)
                Text("Between \(day.low)° at night and \(day.high)° in the afternoon.")
                    .font(.system(size: 14)).foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Button("Done") { dismiss() }
                    .font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                    .padding(.horizontal, 26).padding(.vertical, 9)
                    .background(.ultraThinMaterial).clipShape(Capsule())
                    .padding(.top, 6)
            }
            .padding(24)
        }
    }
}

// MARK: - Cities

struct CitiesView: View {
    @Binding var selected: Int
    @Binding var tab: Int
    @State private var query = ""

    private var shown: [(Int, City)] {
        City.all.enumerated().filter { query.isEmpty || $0.element.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.07, green: 0.10, blue: 0.22),
                                    Color(red: 0.13, green: 0.20, blue: 0.38),
                                    Color(red: 0.22, green: 0.30, blue: 0.52)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.white.opacity(0.7))
                    TextField("Search a city", text: $query)
                        .foregroundColor(.white)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .padding(.horizontal, 12).frame(height: 42)
                .background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16).padding(.top, 14)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(shown, id: \.element.id) { i, c in
                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                    selected = i
                                    tab = 0
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: c.condition.symbol)
                                        .symbolRenderingMode(.multicolor).font(.system(size: 26))
                                        .frame(width: 40)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.name).font(.system(size: 17, weight: .semibold))
                                        Text(c.region).font(.system(size: 12)).foregroundColor(.white.opacity(0.75)).lineLimit(1)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("\(c.temp)°").font(.system(size: 26, weight: .medium))
                                        Text("H:\(c.high)° L:\(c.low)°").font(.system(size: 11.5)).foregroundColor(.white.opacity(0.8))
                                    }
                                    if i == selected {
                                        Image(systemName: "checkmark.circle.fill").foregroundColor(.green).font(.system(size: 18))
                                    }
                                }
                                .foregroundColor(.white)
                                .padding(14)
                                .glassCard()
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(PressableStyle())
                        }
                        if shown.isEmpty {
                            Text("No city matches “\(query)”.")
                                .font(.system(size: 14)).foregroundColor(.white.opacity(0.8))
                                .padding(.top, 30)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
        }
    }
}

// MARK: - Shared style kit

extension View {
    func glassCard(radius: CGFloat = 18) -> some View {
        background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).stroke(Color.white.opacity(0.28), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
    }
    func entrance(_ index: Int, _ on: Bool) -> some View {
        opacity(on ? 1 : 0)
            .offset(y: on ? 0 : 16)
            .animation(.spring(response: 0.55, dampingFraction: 0.85).delay(Double(index) * 0.07), value: on)
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
