import SwiftUI

struct ValueTile: View {
    let model: ValueTileModel

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(model.title).font(.headline)
                Text(model.subtitle).font(.subheadline)
            }
            Spacer()
            Text("\(model.value, specifier: "%.2f") \(model.currency)")
                .bold()
        }
        .padding(.vertical, 4)
    }
}
