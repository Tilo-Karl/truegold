//
//  KeyboardObserver.swift
//  TrueGold
//
//  Created by Tilo Delau on 2025-10-03.
//

import SwiftUI
import UIKit

final class KeyboardObserver: ObservableObject {
    @Published var height: CGFloat = 0

    init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handle(notification:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        /*
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handle(notification:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
         */
        /*
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handle(notification:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
         */
    }

    @objc private func handle(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            self.height = 0
            return
        }
        // Translate keyboard height into a bottom inset, minus safe-area so we don't double-inset
        let screen = UIScreen.main.bounds
        let overlap = max(0, screen.maxY - endFrame.minY)
        let safeBottom: CGFloat = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom }
            .first ?? 0
        let target = max(0, overlap - safeBottom)

        // Animate to match the keyboard
        if let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
           let curveRaw = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt {
            let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
            UIView.animate(withDuration: duration, delay: 0, options: options) {
                self.height = target
            }
        } else {
            self.height = target
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
