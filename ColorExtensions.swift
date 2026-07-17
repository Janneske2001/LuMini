//
//  ColorExtensions.swift
//  LuMini
//
//  Created by Jannes ‎ on 07/07/2026.
//

import SwiftUI

extension Color {
    var rgba: (red: Double, green: Double, blue: Double, alpha: Double) {
        let nsColor = NSColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
    
    func toRGB() -> (r: Int, g: Int, b: Int) {
        let nsColor = NSColor(self)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return (Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }
}
