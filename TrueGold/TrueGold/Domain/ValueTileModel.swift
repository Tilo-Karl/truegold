import Foundation

struct ValueTileModel: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let currency: String
    let value: Double
}
