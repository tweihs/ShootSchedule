//
//  SearchBar.swift
//  ShootsDB
//
//  Created on 1/24/25.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                
                TextField("Search shoots", text: $text)
                    .padding(7)
                    .focused($isTextFieldFocused)
                    .onTapGesture {
                        self.isEditing = true
                        self.isTextFieldFocused = true
                    }
                    .onChange(of: isTextFieldFocused) { focused in
                        self.isEditing = focused
                    }
                    .onSubmit {
                        // Keep keyboard focused for continued searching
                        // User can dismiss via toolbar Done button if desired
                    }
                    .submitLabel(.search)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                self.isTextFieldFocused = false
                                self.isEditing = false
                                // Optionally clear search when dismissing keyboard
                                // self.text = ""
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                        }
                    }
                
                if !text.isEmpty {
                    Button(action: {
                        self.text = ""
                        // Dismiss keyboard when clearing search results
                        self.isTextFieldFocused = false
                        self.isEditing = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .padding(.trailing, 8)
                    }
                }
            }
            .background(Color.secondaryBackground.opacity(0.8))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(UIColor.systemGray4), lineWidth: 1)
            )
            .gesture(
                // Swipe down to dismiss keyboard
                DragGesture()
                    .onEnded { value in
                        if value.translation.height > 50 {
                            self.isTextFieldFocused = false
                            self.isEditing = false
                        }
                    }
            )
            
        }
    }
}

struct SearchBar_Previews: PreviewProvider {
    @State static var searchText = ""
    
    static var previews: some View {
        SearchBar(text: $searchText)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}