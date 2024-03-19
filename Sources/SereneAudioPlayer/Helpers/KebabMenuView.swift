//
//  KebabMenuView.swift
//  SiddhaOne
//
//  Created by Fatemeh Najafi Moghadam on 3/6/24.
//

import SwiftUI
import Resources

struct KebabMenuModel: Hashable {
    let text: String
    let icon: ImageResource?
}

struct KebabMenuView: View {
    let options: [KebabMenuModel]
    @Binding var currentSelection: String
    
    var body: some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(action: {
                    currentSelection = option.text
                }, label: {
                    Text(option.text)
                    if let icon = option.icon {
                        Image(icon)
                    }
                })
            }
        } label: {
            Image(.kebab)
        }
    }
}

#Preview {
    KebabMenuView(
        options: [
            KebabMenuModel(text: "Favorite", icon: .download),
            KebabMenuModel(text: "Share", icon: .share)
        ],
        currentSelection: .constant("Item2")
    )
}
