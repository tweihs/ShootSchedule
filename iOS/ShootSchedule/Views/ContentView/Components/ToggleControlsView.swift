//
//  ToggleControlsView.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct ToggleControlsView: View {
    @ObservedObject var filterOptions: FilterOptions
    @EnvironmentObject var dataManager: DataManager
    
    var body: some View {
        HStack(spacing: 24) {
            ToggleControl(
                title: "Future",
                isOn: $filterOptions.showFutureOnly
            )
            
            ToggleControl(
                title: "Notable",
                isOn: $filterOptions.showNotableOnly
            )
            
            ToggleControl(
                title: "Marked (\(dataManager.markedShootsCount))",
                isOn: $filterOptions.showMarkedOnly
            )
            
            Spacer()
        }
    }
}

struct ToggleControl: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .scaleEffect(0.8)
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

struct ToggleControlsView_Previews: PreviewProvider {
    @StateObject static var filterOptions = FilterOptions()
    
    static var previews: some View {
        ToggleControlsView(filterOptions: filterOptions)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}