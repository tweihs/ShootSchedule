import SwiftUI

struct HeaderView: View {
    var body: some View {
        HStack {
            Text("ShootsDB")
                .font(.largeTitle)
                .bold()
            Spacer()
            Button(action: {
                // Add action here
            }) {
                Image(systemName: "person.crop.circle") // Example silhouette icon
                    .font(.title)
            }
        }
        .padding()
    }
}

struct HeaderView_Previews: PreviewProvider {
    static var previews: some View {
        HeaderView()
    }
}
