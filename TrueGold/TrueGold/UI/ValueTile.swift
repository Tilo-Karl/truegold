import SwiftUI

struct ValueTile: View {
    let model: ValueTileModel

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(model.title).font(.headline)
            }
            Spacer()
            Text("\(model.value, specifier: "%.2f")")
                .bold()
                .foregroundColor(.appPurple)
        }
        .padding(.vertical, 4)
    }
}
