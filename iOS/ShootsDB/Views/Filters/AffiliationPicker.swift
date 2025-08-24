//
//  AffiliationPicker.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct AffiliationPicker: View {
    @Binding var selectedAffiliations: Set<ShootAffiliation>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(ShootAffiliation.allCases, id: \.self) { affiliation in
                    HStack {
                        Text(affiliation.displayName)
                        Spacer()
                        if selectedAffiliations.contains(affiliation) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selectedAffiliations.contains(affiliation) {
                            selectedAffiliations.remove(affiliation)
                        } else {
                            selectedAffiliations.insert(affiliation)
                        }
                    }
                }
            }
            .navigationTitle("Type")
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

struct AffiliationPicker_Previews: PreviewProvider {
    @State static var selectedAffiliations = Set<ShootAffiliation>()
    
    static var previews: some View {
        AffiliationPicker(selectedAffiliations: $selectedAffiliations)
    }
}