import SwiftUI
import MapKit

struct ShootDetailView: View {
    let event: Event

    @State private var isMapExpanded = false
    @State private var isMarked = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Event Name
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(event.club ?? "No Name")
                    Spacer()
                    Text("\(event.formattedStartDate) - \(event.formattedEndDate)")
                }
//                Text(event.name)
//                Text(event.club)
//                HStack {
////                    Text(event.club)
////                    Spacer()
//                }
//                Text("\(event.city), \(event.state)")
                Text(event.fullAddress ?? "No Name")
            }

            // Separator
            Divider()

            // Mark/Unmark Button
            Button(action: {
                isMarked.toggle()
            }) {
                HStack {
                    if isMarked {
                        Image(systemName: "checkmark")
                    }
                    Text(isMarked ? "Unmark" : "Mark")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }

            // Separator
            Divider()


            // Map
            ZStack {
                MapView(coordinate: event.coordinates)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        isMapExpanded = true
                    }

                Text("Tap to expand")
                    .foregroundColor(.white)
                    .font(.footnote)
                    .padding(6)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding()
            }

            // Separator
            Divider()

            // Club Contact Information
            VStack(alignment: .leading, spacing: 4) {
                Text(event.pocName ?? "No Name")
                Text(event.pocEmail ?? "No Name")
                    .foregroundColor(.blue)
                    .onTapGesture {
                        if let url = URL(string: "mailto:\(event.pocEmail ?? "No Email")") {
                            UIApplication.shared.open(url)
                        }
                    }
                Text(event.pocPhone ?? "No Phone")
                    .foregroundColor(.blue)
                    .onTapGesture {
                        if let url = URL(string: "tel:\(event.pocPhone?.replacingOccurrences(of: " ", with: "") ?? "No Phone")") {
                            UIApplication.shared.open(url)
                        }
                    }
            }

            Spacer()
        }
        .padding()
//        .navigationTitle("Event Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack {
                            Text(event.name ?? "No Name")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("\(event.formattedStartDate) - \(event.formattedEndDate)")
                                .font(.subheadline)

//                            Text("\(event.city), \(event.state)")
//                                .font(.subheadline)
//                                .foregroundColor(.secondary)
                        }
                    }
                }
        .sheet(isPresented: $isMapExpanded) {
            FullScreenMapView(coordinate: event.coordinates)
        }
    }
}

#Preview {
    ShootDetailView(
        event: sampleEvents.first!
    )
}
