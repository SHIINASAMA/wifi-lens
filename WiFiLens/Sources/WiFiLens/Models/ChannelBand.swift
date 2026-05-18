enum ChannelBand: Int, Sendable, CaseIterable {
    case band24GHz = 1
    case band5GHz = 2
    case band6GHz = 3

    var displayName: String {
        switch self {
        case .band24GHz: "2.4 GHz"
        case .band5GHz: "5 GHz"
        case .band6GHz: "6 GHz"
        }
    }

    /// Short identifier matching the current app's band IDs ("24", "5", "6")
    var id: String {
        switch self {
        case .band24GHz: "24"
        case .band5GHz: "5"
        case .band6GHz: "6"
        }
    }

    var maxChannel: Int {
        switch self {
        case .band24GHz: 16
        case .band5GHz: 170
        case .band6GHz: 233
        }
    }
}
