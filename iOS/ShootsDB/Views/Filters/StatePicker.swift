//
//  StatePicker.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct StatePicker: View {
    @Binding var selectedStates: Set<String>
    @Environment(\.dismiss) var dismiss
    
    let states = [
        "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
        "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
        "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
        "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
        "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(states, id: \.self) { state in
                    HStack {
                        Text(state)
                        Spacer()
                        if selectedStates.contains(state) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedStates.contains(state) {
                            selectedStates.remove(state)
                        } else {
                            selectedStates.insert(state)
                        }
                    }
                }
            }
            .navigationTitle("State")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct StatePicker_Previews: PreviewProvider {
    @State static var selectedStates = Set<String>()
    
    static var previews: some View {
        StatePicker(selectedStates: $selectedStates)
    }
}