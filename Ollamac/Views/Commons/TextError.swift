//
//  TextError.swift
//  Ollamac
//
//  Created by Kevin Hermawan on 20/11/23.
//

import SwiftUI

struct TextError: View {
    private var text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .foregroundStyle(.red)
    }
}

#Preview {
    TextError(AppMessages.generalErrorMessage)
}
#Preview {
    TextError("Error: This is an extremely long error string. The Ollama server cannot be reached at the moment. Make sure to implement word wrap so you do not suffer the same terrible fate.")
}
