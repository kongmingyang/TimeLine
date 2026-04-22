//
//  CADisplayLinkAnimator.swift
//  Demo-Swift
//
//  Created by T on 2026/4/22.
//

import Foundation
import UIKit

final class CADisplayLinkAnimator {

    private let duration: TimeInterval
    private let onUpdate: (CGFloat) -> Void
    private let completion: (() -> Void)?

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0

    init(duration: TimeInterval,
         onUpdate: @escaping (CGFloat) -> Void,
         completion: (() -> Void)? = nil) {
        self.duration = max(0.01, duration)
        self.onUpdate = onUpdate
        self.completion = completion
    }

    func start() {
        stop()
        startTime = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step() {
        let now = CACurrentMediaTime()
        let progress = min(1, (now - startTime) / duration)
        onUpdate(CGFloat(progress))
        if progress >= 1 {
            stop()
            completion?()
        }
    }

    deinit {
        stop()
    }
}
