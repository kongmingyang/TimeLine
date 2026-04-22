//
//  TimeLineView.swift
//  Demo-Swift
//
//  Created by T on 2026/4/22.
//

import Foundation
import UIKit

struct TimelineEvent {
    let start: TimeInterval
    let end: TimeInterval
    let color: UIColor
}

struct TimeRange {
    let start: TimeInterval
    let end: TimeInterval
}

struct TickConfig {
    let majorStep: Int
    let minorStep: Int
}

protocol MonitorTimelineViewDelegate: AnyObject {
    func timelineView(_ view: MonitorTimelineView, didChangeCurrentTime time: TimeInterval)
    func timelineView(_ view: MonitorTimelineView, didChangeClipRange range: TimeRange)
}

final class MonitorTimelineView: UIView {

    // MARK: - Public

    weak var delegate: MonitorTimelineViewDelegate?

    /// 录像事件
    var events: [TimelineEvent] = [] {
        didSet {
            setNeedsDisplay()
        }
    }

    // MARK: - Constants

    private let secondsPerDay: CGFloat = 24 * 60 * 60
    private let minPixelsPerSecond: CGFloat = 0.02
    private let maxPixelsPerSecond: CGFloat = 2.0

    private let minClipSeconds: CGFloat = 10
    private let minClipWidthPx: CGFloat = 60

    private let clipTop: CGFloat = 62
    private let clipHeight: CGFloat = 72

    // MARK: - State

    /// 当前缩放比例
    private var pixelsPerSecond: CGFloat = 0.08 {
        didSet {
            pixelsPerSecond = max(minPixelsPerSecond, min(maxPixelsPerSecond, pixelsPerSecond))
        }
    }

    /// 当前滚动偏移：
    /// 这里 scrollOffset 直接表示“中线对应的时间像素值”
    /// 当 scrollOffset = 0 时，中线对应 00:00
    private var scrollOffset: CGFloat = 0 {
        didSet {
            scrollOffset = max(0, min(scrollOffset, maxScroll))
            setNeedsDisplay()
            notifyCurrentTimeChanged()
            notifyClipRangeChanged()
        }
    }

    /// 裁剪框左右边界，使用屏幕坐标
    private var clipLeft: CGFloat = 80 {
        didSet {
            setNeedsDisplay()
            notifyClipRangeChanged()
        }
    }

    private var clipRight: CGFloat = 280 {
        didSet {
            setNeedsDisplay()
            notifyClipRangeChanged()
        }
    }

    private var currentTimeLabel = UILabel()

    /// 左右留白，让 00:00 和末尾时间都可以在中线显示
    private var sideInset: CGFloat {
        bounds.width / 2
    }

    /// 时间轴像素长度，不含左右留白
    private var timelinePixels: CGFloat {
        secondsPerDay * pixelsPerSecond
    }

    /// 总内容宽度
    private var contentWidth: CGFloat {
        sideInset + timelinePixels + sideInset
    }

    /// 最大滚动
    private var maxScroll: CGFloat {
        max(0, timelinePixels)
    }

    // MARK: - Gesture

    private enum DragMode {
        case none
        case timeline
        case leftHandle
        case rightHandle
        case moveClip
    }

    private var dragMode: DragMode = .none

    // MARK: - Deceleration

    private var displayLink: CADisplayLink?
    private var velocityX: CGFloat = 0
    private let decelerationRate: CGFloat = 0.95

    // MARK: - Animators

    private var tempAnimator: CADisplayLinkAnimator?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        backgroundColor = .black

        currentTimeLabel.textColor = .white
        currentTimeLabel.font = .boldSystemFont(ofSize: 13)
        currentTimeLabel.textAlignment = .center
        currentTimeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        currentTimeLabel.layer.cornerRadius = 4
        currentTimeLabel.layer.masksToBounds = true
        addSubview(currentTimeLabel)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)

        updateCurrentTimeLabel()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        currentTimeLabel.frame = CGRect(x: bounds.midX - 50, y: 4, width: 100, height: 22)
//        scrollOffset = scrollOffset
        clipRight = min(clipRight, bounds.width)
    }

    // MARK: - Public API

    /// 设置初始时间
    func setInitialTime(_ time: TimeInterval) {
        jumpToTime(time)
    }

    /// 立即滚动到某时间，让该时间显示在中线
    func jumpToTime(_ time: TimeInterval) {
        stopAllAnimation()
        scrollOffset = offsetForCenterTime(time)
    }

    /// 动画滚动到某时间
    func animateToTime(_ time: TimeInterval,
                       duration: TimeInterval = 0.45) {
        stopAllAnimation()
        let target = offsetForCenterTime(time)
        animateScroll(to: target, duration: duration, completion: nil)
    }

    /// Date -> 当天秒数后滚动
    func animateToDate(_ date: Date,
                       calendar: Calendar = .current,
                       duration: TimeInterval = 0.45) {
        let comps = calendar.dateComponents([.hour, .minute, .second], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        let s = comps.second ?? 0

        let sec = TimeInterval(h * 3600 + m * 60 + s)
     
        animateToTime(sec, duration: duration)
    }

    /// 设置裁剪区间
    func setClipRange(start: TimeInterval,
                      end: TimeInterval,
                      animated: Bool = false,
                      keepVisible: Bool = true,
                      duration: TimeInterval = 0.3) {
        stopAllAnimation()

        var s = max(0, min(start, 24 * 3600))
        var e = max(0, min(end, 24 * 3600))

        if s > e {
            swap(&s, &e)
        }

        if e - s < TimeInterval(minClipSeconds) {
            e = min(24 * 3600, s + TimeInterval(minClipSeconds))
        }

        if keepVisible {
            ensureTimeRangeVisible(start: s, end: e)
        }

        let left = viewXFromTime(CGFloat(s))
        let right = viewXFromTime(CGFloat(e))

        let minWidth = max(minClipWidthPx, minClipSeconds * pixelsPerSecond)
        let targetLeft = max(0, min(left, bounds.width))
        let targetRight = min(bounds.width, max(right, targetLeft + minWidth))

        if !animated {
            clipLeft = targetLeft
            clipRight = targetRight
            return
        }

        animateClip(toLeft: targetLeft, right: targetRight, duration: duration)
    }

    /// 用 Date 设置裁剪区间
    func setClipDateRange(start: Date,
                          end: Date,
                          calendar: Calendar = .current,
                          animated: Bool = false,
                          keepVisible: Bool = true,
                          duration: TimeInterval = 0.3) {
        let cs = calendar.dateComponents([.hour, .minute, .second], from: start)
        let ce = calendar.dateComponents([.hour, .minute, .second], from: end)
        let h = cs.hour ?? 0
        let m = cs.minute ?? 0
        let s = cs.second ?? 0
        let startSec = TimeInterval(h * 3600 + m * 60 + s)
        let endSec = TimeInterval(h * 3600 + m * 60 + s)

        setClipRange(start: startSec,
                     end: endSec,
                     animated: animated,
                     keepVisible: keepVisible,
                     duration: duration)
    }

    /// 当前中线时间
    func currentCenterTime() -> TimeInterval {
        let sec = scrollOffset / pixelsPerSecond
        return TimeInterval(max(0, min(sec, secondsPerDay)))
    }

    /// 当前裁剪区间
    func currentClipRange() -> TimeRange {
        let start = timeFromViewX(clipLeft)
        let end = timeFromViewX(clipRight)
        return TimeRange(
            start: TimeInterval(max(0, min(start, secondsPerDay))),
            end: TimeInterval(max(0, min(end, secondsPerDay)))
        )
    }

    /// 外部缩放，保持中线时间不变
    func zoomTo(_ newPixelsPerSecond: CGFloat, duration: TimeInterval = 0.25) {
        stopAllAnimation()
        
        let centerTime = timeFromViewX(bounds.midX)
        let targetScale = max(minPixelsPerSecond, min(maxPixelsPerSecond, newPixelsPerSecond))
        let beginScale = pixelsPerSecond
        
        let animator = CADisplayLinkAnimator(duration: duration) { [weak self] progress in
            guard let self else { return }
            let eased = 1 - pow(1 - progress, 3)
            let scale = beginScale + (targetScale - beginScale) * eased
            self.setScaleKeepingFocal(scale, focalTime: centerTime, focalX: self.bounds.midX)
        }completion: {
            
        }

        tempAnimator = animator
        animator.start()
    }

    // MARK: - Draw

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        drawBackground(ctx)
        drawTrack(ctx)
        drawEvents(ctx)
        drawTicks(ctx)
        drawCenterLine(ctx)
        drawClipRect(ctx)

        updateCurrentTimeLabel()
    }

    private func drawBackground(_ ctx: CGContext) {
        ctx.setFillColor(UIColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1).cgColor)
        ctx.fill(bounds)
    }

    private func drawTrack(_ ctx: CGContext) {
        let rect = CGRect(x: 0, y: 90, width: bounds.width, height: 26)
        ctx.setFillColor(UIColor(white: 0.17, alpha: 1).cgColor)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
    }

    private func drawEvents(_ ctx: CGContext) {
        for event in events {
            let left = sideInset + CGFloat(event.start) * pixelsPerSecond - scrollOffset
            let right = sideInset + CGFloat(event.end) * pixelsPerSecond - scrollOffset
            if right < 0 || left > bounds.width { continue }

            let rect = CGRect(x: left, y: 90, width: right - left, height: 26)
            ctx.setFillColor(event.color.cgColor)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 3)
            ctx.addPath(path.cgPath)
            ctx.fillPath()
        }
    }

    private func drawCenterLine(_ ctx: CGContext) {
        ctx.setStrokeColor(UIColor.yellow.cgColor)
        ctx.setLineWidth(1)
        ctx.move(to: CGPoint(x: bounds.midX, y: 28))
        ctx.addLine(to: CGPoint(x: bounds.midX, y: bounds.height))
        ctx.strokePath()
    }

    private func drawClipRect(_ ctx: CGContext) {
        let rect = CGRect(x: clipLeft, y: clipTop, width: clipRight - clipLeft, height: clipHeight)

        ctx.setFillColor(UIColor.orange.withAlphaComponent(0.16).cgColor)
        ctx.fill(rect)

        ctx.setStrokeColor(UIColor.orange.cgColor)
        ctx.setLineWidth(2)
        ctx.stroke(rect)

        let leftHandle = CGRect(x: clipLeft - 2, y: clipTop + 18, width: 4, height: 36)
        let rightHandle = CGRect(x: clipRight - 2, y: clipTop + 18, width: 4, height: 36)

        ctx.setFillColor(UIColor.orange.cgColor)
        ctx.fill(leftHandle)
        ctx.fill(rightHandle)

        let range = currentClipRange()
        let text = "\(formatHms(Int(range.start))) - \(formatHms(Int(range.end)))"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.white
        ]
        let size = text.size(withAttributes: attrs)
        let labelRect = CGRect(
            x: rect.midX - size.width / 2 - 6,
            y: rect.minY + 4,
            width: size.width + 12,
            height: size.height + 4
        )

        let labelPath = UIBezierPath(roundedRect: labelRect, cornerRadius: 4)
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.8).cgColor)
        ctx.addPath(labelPath.cgPath)
        ctx.fillPath()

        text.draw(
            at: CGPoint(x: rect.midX - size.width / 2, y: rect.minY + 6),
            withAttributes: attrs
        )
    }

    private func drawTicks(_ ctx: CGContext) {
        let config = calculateTickConfig()
        let majorStep = config.majorStep
        let minorStep = config.minorStep

        /// 因为增加了左右留白，所以可见区间换算时要减 sideInset
        let startSec = Int(((scrollOffset - sideInset) / pixelsPerSecond).rounded(.down))
        let endSec = Int(((scrollOffset + bounds.width - sideInset) / pixelsPerSecond).rounded(.up))
        let firstMinor = (startSec / minorStep) * minorStep

        var lastLabelX: CGFloat = -9999

        for sec in stride(from: firstMinor, through: endSec, by: minorStep) {
            guard sec >= 0 && sec <= 86400 else { continue }

            let x = sideInset + CGFloat(sec) * pixelsPerSecond - scrollOffset
            let isMajor = sec % majorStep == 0
            let top: CGFloat = isMajor ? 52 : 64

            ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.7).cgColor)
            ctx.setLineWidth(1)
            ctx.move(to: CGPoint(x: x, y: top))
            ctx.addLine(to: CGPoint(x: x, y: 90))
            ctx.strokePath()

            if isMajor && x - lastLabelX > 36 {
                let text = formatAdaptiveLabel(seconds: sec, majorStep: majorStep)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.white
                ]
                let size = text.size(withAttributes: attrs)
                let bgRect = CGRect(x: x - size.width / 2 - 3,
                                    y: 27,
                                    width: size.width + 6,
                                    height: size.height + 2)

                let path = UIBezierPath(roundedRect: bgRect, cornerRadius: 3)
                ctx.setFillColor(UIColor.black.withAlphaComponent(0.54).cgColor)
                ctx.addPath(path.cgPath)
                ctx.fillPath()

                text.draw(at: CGPoint(x: x - size.width / 2, y: 28), withAttributes: attrs)
                lastLabelX = x
            }
        }
    }

    // MARK: - Gesture

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let location = pan.location(in: self)
        let translation = pan.translation(in: self)

        switch pan.state {
        case .began:
            stopAllAnimation()

            let leftHandleArea = CGRect(x: clipLeft - 20, y: clipTop, width: 40, height: clipHeight)
            let rightHandleArea = CGRect(x: clipRight - 20, y: clipTop, width: 40, height: clipHeight)
            let bodyArea = CGRect(x: clipLeft + 20, y: clipTop, width: max(0, clipRight - clipLeft - 40), height: clipHeight)

            if leftHandleArea.contains(location) {
                dragMode = .leftHandle
            } else if rightHandleArea.contains(location) {
                dragMode = .rightHandle
            } else if bodyArea.contains(location) {
                dragMode = .moveClip
            } else {
                dragMode = .timeline
            }

        case .changed:
            switch dragMode {
            case .timeline:
                scrollOffset -= translation.x

            case .leftHandle:
                let minWidth = max(minClipWidthPx, minClipSeconds * pixelsPerSecond)
                clipLeft += translation.x
                clipLeft = max(0, min(clipLeft, clipRight - minWidth))

            case .rightHandle:
                let minWidth = max(minClipWidthPx, minClipSeconds * pixelsPerSecond)
                clipRight += translation.x
                clipRight = min(bounds.width, max(clipRight, clipLeft + minWidth))

            case .moveClip:
                let width = clipRight - clipLeft
                var newLeft = clipLeft + translation.x
                newLeft = max(0, min(newLeft, bounds.width - width))
                clipLeft = newLeft
                clipRight = newLeft + width

            case .none:
                break
            }

            pan.setTranslation(.zero, in: self)

        case .ended, .cancelled:
            if dragMode == .timeline {
                let v = pan.velocity(in: self).x
                if abs(v) > 30 {
                    startDeceleration(with: v)
                }
            }
            dragMode = .none

        default:
            dragMode = .none
        }
    }

    @objc private func handlePinch(_ pinch: UIPinchGestureRecognizer) {
        stopAllAnimation()

        let focalX = pinch.location(in: self).x
        let focalTime = timeFromViewX(focalX)

        if pinch.state == .changed {
            let newScale = pixelsPerSecond * pinch.scale
            setScaleKeepingFocal(newScale, focalTime: focalTime, focalX: focalX)
            pinch.scale = 1.0
        }
    }

    // MARK: - Scroll / Animation

    private func animateScroll(to target: CGFloat,
                               duration: TimeInterval,
                               completion: (() -> Void)?) {
        let from = scrollOffset
        let to = max(0, min(target, maxScroll))

        let animator = CADisplayLinkAnimator(duration: duration) { [weak self] progress in
            guard let self else { return }
            let eased = 1 - pow(1 - progress, 3)
            self.scrollOffset = from + (to - from) * eased
        } completion: { [weak self] in
            self?.scrollOffset = to
            completion?()
        }
        tempAnimator = animator
        animator.start()
    }

    private func animateClip(toLeft left: CGFloat, right: CGFloat, duration: TimeInterval) {
        let fromLeft = clipLeft
        let fromRight = clipRight

        let animator = CADisplayLinkAnimator(duration: duration) { [weak self] progress in
            guard let self else { return }
            let eased = 1 - pow(1 - progress, 3)
            self.clipLeft = fromLeft + (left - fromLeft) * eased
            self.clipRight = fromRight + (right - fromRight) * eased
        } completion: { [weak self] in
            self?.clipLeft = left
            self?.clipRight = right
        }
        tempAnimator = animator
        animator.start()
    }

    private func startDeceleration(with velocity: CGFloat) {
        stopDeceleration()
        velocityX = velocity

        let link = CADisplayLink(target: self, selector: #selector(handleDeceleration))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDeceleration() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func handleDeceleration() {
        guard abs(velocityX) > 0.1 else {
            stopDeceleration()
            return
        }

        scrollOffset -= velocityX / 60.0
        velocityX *= decelerationRate

        if scrollOffset <= 0 || scrollOffset >= maxScroll {
            scrollOffset = max(0, min(scrollOffset, maxScroll))
            stopDeceleration()
        }
    }

    private func stopAllAnimation() {
        stopDeceleration()
        tempAnimator?.stop()
        tempAnimator = nil
    }

    // MARK: - Helpers

    /// 保持某个焦点时间在 focalX 位置不变
    private func setScaleKeepingFocal(_ newScale: CGFloat, focalTime: CGFloat, focalX: CGFloat) {
        let scale = max(minPixelsPerSecond, min(maxPixelsPerSecond, newScale))

        /// viewX = sideInset + time * scale - scrollOffset
        /// 已知 focalTime、focalX，反推 scrollOffset
        let newOffset = sideInset + focalTime * scale - focalX

        pixelsPerSecond = scale
        scrollOffset = max(0, min(newOffset, max(0, secondsPerDay * scale)))
    }

    /// 让某个时间显示在中线时，对应的 scrollOffset
    private func offsetForCenterTime(_ time: TimeInterval) -> CGFloat {
        let sec = CGFloat(max(0, min(time, 24 * 3600)))

        /// 因为中线 x == sideInset
        /// sideInset = sideInset + sec*pps - scrollOffset
        /// 所以 scrollOffset = sec*pps
        return max(0, min(sec * pixelsPerSecond, maxScroll))
    }

    /// 屏幕 x -> 时间秒
    private func timeFromViewX(_ x: CGFloat) -> CGFloat {
        /// x = sideInset + time*pps - scrollOffset
        /// => time = (x + scrollOffset - sideInset) / pps
        let sec = (x + scrollOffset - sideInset) / pixelsPerSecond
        return max(0, min(sec, secondsPerDay))
    }

    /// 时间秒 -> 屏幕 x
    private func viewXFromTime(_ time: CGFloat) -> CGFloat {
        sideInset + time * pixelsPerSecond - scrollOffset
    }

    /// 保证某个时间区间在可视区域内
    private func ensureTimeRangeVisible(start: TimeInterval, end: TimeInterval) {
        let leftPx = viewXFromTime(CGFloat(start))
        let rightPx = viewXFromTime(CGFloat(end))

        var targetOffset = scrollOffset

        if leftPx < 0 {
            targetOffset = sideInset + CGFloat(start) * pixelsPerSecond
        } else if rightPx > bounds.width {
            targetOffset = sideInset + CGFloat(end) * pixelsPerSecond - bounds.width
        }

        targetOffset = max(0, min(targetOffset, maxScroll))
        scrollOffset = targetOffset
    }

    private func calculateTickConfig() -> TickConfig {
        let candidates: [Int] = [
            1, 2, 5, 10, 15, 30,
            60, 120, 300, 600, 900, 1800,
            3600, 7200, 10800, 21600, 43200
        ]

        let targetMajorPx: CGFloat = 100
        var bestMajor = candidates[0]
        var bestDiff = CGFloat.greatestFiniteMagnitude

        for sec in candidates {
            let px = CGFloat(sec) * pixelsPerSecond
            let diff = abs(px - targetMajorPx)
            if diff < bestDiff {
                bestDiff = diff
                bestMajor = sec
            }
        }

        let minor: Int
        if bestMajor >= 3600 {
            minor = max(1, bestMajor / 6)
        } else if bestMajor >= 60 {
            minor = max(1, bestMajor / 5)
        } else {
            minor = max(1, bestMajor / 5)
        }

        return TickConfig(majorStep: bestMajor, minorStep: minor)
    }

    private func updateCurrentTimeLabel() {
        currentTimeLabel.text = formatHms(Int(currentCenterTime()))
        currentTimeLabel.frame = CGRect(x: bounds.midX - 50, y: 4, width: 100, height: 22)
    }

    private func notifyCurrentTimeChanged() {
        delegate?.timelineView(self, didChangeCurrentTime: currentCenterTime())
        updateCurrentTimeLabel()
    }

    private func notifyClipRangeChanged() {
        delegate?.timelineView(self, didChangeClipRange: currentClipRange())
    }

    private func formatAdaptiveLabel(seconds: Int, majorStep: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60

        if majorStep >= 3600 {
            return String(format: "%02d:00", h)
        } else if majorStep >= 60 {
            return String(format: "%02d:%02d", h, m)
        } else {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
    }

    private func formatHms(_ seconds: Int) -> String {
        let sec = max(0, min(seconds, 86400))
        let h = sec / 3600
        let m = (sec % 3600) / 60
        let s = sec % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }
}
