import SwiftUI

enum BuildConfig {
    case oss
    case pro

    static var current: BuildConfig {
        #if OSS
        .oss
        #elseif PRO
        .pro
        #else
        .oss
        #endif
    }
}
