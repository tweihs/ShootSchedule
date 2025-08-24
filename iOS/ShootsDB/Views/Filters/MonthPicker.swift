//
//  MonthPicker.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct MonthPicker: View {
    @Binding var selectedMonths: Set<Int>
    @Environment(\.dismiss) var dismiss
    
    let months = Calendar.current.shortMonthSymbols
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(months.enumerated()), id: \.offset) { index, month in
                    HStack {
                        Text(month)
                        Spacer()
                        if selectedMonths.contains(index + 1) {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let monthNumber = index + 1
                        if selectedMonths.contains(monthNumber) {
                            selectedMonths.remove(monthNumber)
                        } else {
                            selectedMonths.insert(monthNumber)
                        }
                    }
                }
            }
            .navigationTitle("Month")
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

struct MonthPicker_Previews: PreviewProvider {
    @State static var selectedMonths = Set<Int>()
    
    static var previews: some View {
        MonthPicker(selectedMonths: $selectedMonths)
    }
}