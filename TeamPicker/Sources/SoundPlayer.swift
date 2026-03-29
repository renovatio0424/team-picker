import Foundation
#if os(iOS)
import AudioToolbox
#endif
#if os(macOS)
import AppKit
#endif

enum SoundPlayer {
    static func playTimerAlert() {
        #if os(iOS)
        AudioServicesPlaySystemSound(1005)
        #elseif os(macOS)
        NSSound.beep()
        #endif
    }
}
