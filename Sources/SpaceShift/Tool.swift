// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI

enum Tool: String, CaseIterable, Identifiable {
    case spaceSwitching, smartZoom, keepAwake, inputLock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .spaceSwitching: "Space Switching"
        case .smartZoom: "Smart Zoom"
        case .keepAwake: "Keep Awake"
        case .inputLock: "Input Lock"
        }
    }

    var symbol: String {
        switch self {
        case .spaceSwitching: "chevron.right.2"
        case .smartZoom: "plus.magnifyingglass"
        case .keepAwake: "cup.and.saucer.fill"
        case .inputLock: "lock.fill"
        }
    }

    var tint: Tint {
        switch self {
        case .spaceSwitching: .brand
        case .smartZoom: .zoom
        case .keepAwake: .awake
        case .inputLock: .lock
        }
    }
}
