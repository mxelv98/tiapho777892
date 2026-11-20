import SwiftUI

/// Demo data — hand-picked Algerian cities, static sample weather.
/// The point of this app is the design, not a forecast.
enum Condition: String {
    case sunny, clearNight, cloudy, rain, hot

    var symbol: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .clearNight: return "moon.stars.fill"
        case .cloudy: return "cloud.sun.fill"
        case .rain: return "cloud.rain.fill"
        case .hot: return "thermometer.sun.fill"
        }
    }
    var label: String {
        switch self {
        case .sunny: return "Sunny"
        case .clearNight: return "Clear night"
        case .cloudy: return "Partly cloudy"
        case .rain: return "Rain"
        case .hot: return "Very hot"
        }
    }
    /// Three-stop sky gradient, top to bottom.
    var sky: [Color] {
        switch self {
        case .sunny:
            return [Color(red: 0.10, green: 0.35, blue: 0.75),
                    Color(red: 0.25, green: 0.55, blue: 0.90),
                    Color(red: 0.55, green: 0.78, blue: 0.98)]
        case .clearNight:
            return [Color(red: 0.03, green: 0.05, blue: 0.16),
                    Color(red: 0.10, green: 0.14, blue: 0.34),
                    Color(red: 0.24, green: 0.28, blue: 0.52)]
        case .cloudy:
            return [Color(red: 0.23, green: 0.32, blue: 0.45),
                    Color(red: 0.38, green: 0.48, blue: 0.62),
                    Color(red: 0.58, green: 0.66, blue: 0.76)]
        case .rain:
            return [Color(red: 0.13, green: 0.20, blue: 0.32),
                    Color(red: 0.25, green: 0.36, blue: 0.52),
                    Color(red: 0.42, green: 0.52, blue: 0.68)]
        case .hot:
            return [Color(red: 0.62, green: 0.28, blue: 0.10),
                    Color(red: 0.85, green: 0.48, blue: 0.18),
                    Color(red: 0.98, green: 0.72, blue: 0.38)]
        }
    }
}

struct HourPoint: Identifiable {
    let id = UUID()
    let hour: String
    let temp: Double
    let symbol: String
}

struct DayRow: Identifiable {
    let id = UUID()
    let day: String
    let symbol: String
    let low: Int
    let high: Int
}

struct City: Identifiable {
    let id = UUID()
    let name: String
    let region: String
    let condition: Condition
    let temp: Int
    let high: Int
    let low: Int
    let feels: Int
    let humidity: Int
    let wind: Int
    let uv: Int
    let pressure: Int
    let sunrise: String
    let sunset: String
    let hourly: [HourPoint]
    let days: [DayRow]
}

extension City {
    static func hours(_ base: Double, _ symbols: [String]) -> [HourPoint] {
        let labels = ["Now", "14", "15", "16", "17", "18", "19", "20", "21", "22"]
        let curve: [Double] = [0, 1, 1.6, 1.8, 1.4, 0.6, -0.4, -1.4, -2.2, -2.8]
        return labels.enumerated().map { i, label in
            HourPoint(hour: label, temp: base + curve[i], symbol: symbols[min(i, symbols.count - 1)])
        }
    }
    static func week(_ low: Int, _ high: Int) -> [DayRow] {
        [DayRow(day: "Today", symbol: "sun.max.fill", low: low, high: high),
         DayRow(day: "Sat", symbol: "sun.max.fill", low: low + 1, high: high + 1),
         DayRow(day: "Sun", symbol: "cloud.sun.fill", low: low, high: high - 1),
         DayRow(day: "Mon", symbol: "cloud.fill", low: low - 1, high: high - 3),
         DayRow(day: "Tue", symbol: "cloud.rain.fill", low: low - 2, high: high - 4),
         DayRow(day: "Wed", symbol: "sun.max.fill", low: low, high: high - 1),
         DayRow(day: "Thu", symbol: "sun.max.fill", low: low + 1, high: high)]
    }

    static let all: [City] = [
        City(name: "Algiers", region: "Capital — the Casbah coast", condition: .sunny,
             temp: 24, high: 26, low: 17, feels: 25, humidity: 58, wind: 14, uv: 6, pressure: 1018,
             sunrise: "07:12", sunset: "17:38",
             hourly: hours(24, ["sun.max.fill", "sun.max.fill", "sun.max.fill", "sun.max.fill", "sun.max.fill", "cloud.sun.fill", "sunset.fill", "moon.stars.fill"]),
             days: week(17, 26)),
        City(name: "Oran", region: "West — Santa Cruz bay", condition: .clearNight,
             temp: 19, high: 25, low: 15, feels: 19, humidity: 66, wind: 11, uv: 1, pressure: 1020,
             sunrise: "07:28", sunset: "17:52",
             hourly: hours(19, ["moon.stars.fill", "moon.stars.fill", "moon.fill", "moon.fill", "moon.stars.fill", "moon.fill", "moon.fill", "moon.stars.fill"]),
             days: week(15, 25)),
        City(name: "Constantine", region: "East — city of bridges", condition: .cloudy,
             temp: 16, high: 19, low: 9, feels: 15, humidity: 71, wind: 19, uv: 3, pressure: 1012,
             sunrise: "06:58", sunset: "17:24",
             hourly: hours(16, ["cloud.sun.fill", "cloud.fill", "cloud.fill", "cloud.sun.fill", "cloud.fill", "cloud.fill", "cloud.moon.fill", "moon.fill"]),
             days: week(9, 19)),
        City(name: "Annaba", region: "East — Mediterranean port", condition: .rain,
             temp: 15, high: 17, low: 12, feels: 13, humidity: 84, wind: 26, uv: 2, pressure: 1006,
             sunrise: "06:52", sunset: "17:18",
             hourly: hours(15, ["cloud.rain.fill", "cloud.rain.fill", "cloud.heavyrain.fill", "cloud.rain.fill", "cloud.fill", "cloud.rain.fill", "cloud.moon.fill", "cloud.moon.fill"]),
             days: week(12, 17)),
        City(name: "Béjaïa", region: "Kabylie — Cap Carbon", condition: .sunny,
             temp: 22, high: 24, low: 16, feels: 23, humidity: 62, wind: 9, uv: 5, pressure: 1019,
             sunrise: "07:02", sunset: "17:28",
             hourly: hours(22, ["sun.max.fill", "sun.max.fill", "cloud.sun.fill", "sun.max.fill", "sun.max.fill", "sunset.fill", "moon.stars.fill", "moon.fill"]),
             days: week(16, 24)),
        City(name: "Ghardaïa", region: "M'zab valley — the desert gate", condition: .hot,
             temp: 33, high: 36, low: 21, feels: 34, humidity: 18, wind: 17, uv: 9, pressure: 1015,
             sunrise: "07:05", sunset: "17:45",
             hourly: hours(33, ["sun.max.fill", "thermometer.sun.fill", "thermometer.sun.fill", "sun.max.fill", "sun.max.fill", "sunset.fill", "moon.stars.fill", "moon.fill"]),
             days: week(21, 36)),
        City(name: "Tamanrasset", region: "Deep south — Hoggar", condition: .sunny,
             temp: 29, high: 31, low: 14, feels: 28, humidity: 12, wind: 13, uv: 10, pressure: 1017,
             sunrise: "06:48", sunset: "17:52",
             hourly: hours(29, ["sun.max.fill", "sun.max.fill", "sun.max.fill", "sun.max.fill", "sun.max.fill", "sunset.fill", "moon.stars.fill", "moon.stars.fill"]),
             days: week(14, 31)),
        City(name: "Tlemcen", region: "West — pearl of the Maghreb", condition: .cloudy,
             temp: 18, high: 21, low: 11, feels: 17, humidity: 64, wind: 12, uv: 4, pressure: 1016,
             sunrise: "07:30", sunset: "17:55",
             hourly: hours(18, ["cloud.sun.fill", "cloud.sun.fill", "sun.max.fill", "cloud.sun.fill", "cloud.fill", "sunset.fill", "cloud.moon.fill", "moon.fill"]),
             days: week(11, 21)),
    ]
}
