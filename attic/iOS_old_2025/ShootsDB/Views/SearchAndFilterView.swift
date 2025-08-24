//
//  SearchAndFilterView.swift
//  ShootsDB
//
//  Created by Tyson Weihs on 12/7/24.
//

import SwiftUI

struct SearchAndFilterView: View {
    @State private var searchText: String = ""
    
    var body: some View {
        HStack {
            TextField("Search...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(action: {
                // Add filter action here
            }) {
                Image(systemName: "line.horizontal.3.decrease.circle") // Filter icon
                    .font(.title)
            }
        }
        .padding()
    }
}

#Preview {
    SearchAndFilterView()
}
