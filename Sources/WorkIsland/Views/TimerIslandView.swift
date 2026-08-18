import AppKit
import CoreImage
import SwiftUI

final class IslandPresentationState: ObservableObject {
    @Published var isExpanded = false
    @Published private(set) var interactionDepth = 0
    @Published private(set) var compactStatus: IslandCompactStatus?
    @Published private(set) var completionNotice: TimedActivityCompletion?
    @Published private(set) var isCompletionRevealPinned = false

    var isInteractionActive: Bool {
        interactionDepth > 0
    }

    func beginInteraction() {
        interactionDepth += 1
    }

    func endInteraction() {
        interactionDepth = max(0, interactionDepth - 1)
    }

    func updateCompactStatus(_ status: IslandCompactStatus?) {
        compactStatus = status
    }

    func presentCompletion(_ notice: TimedActivityCompletion) {
        completionNotice = notice
        isCompletionRevealPinned = true
        isExpanded = true
    }

    func dismissCompletion() {
        completionNotice = nil
        isCompletionRevealPinned = false
    }

}

struct IslandActionLayout {
    static let runningSpacing: CGFloat = 9
    static let pausedSpacing: CGFloat = runningSpacing / 2
    static let completionSpacing: CGFloat = runningSpacing / 3

    static func runningButtonWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, (totalWidth - runningSpacing) / 2)
    }

    static func pausedUnitWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, (totalWidth - pausedSpacing * 2) / 4)
    }

    static func completionUnitWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, (totalWidth - completionSpacing * 3) / 4)
    }

    static func runningCompletionPauseWidth(totalWidth: CGFloat) -> CGFloat {
        completionUnitWidth(totalWidth: totalWidth) * 2 + completionSpacing
    }
}

struct IslandHeaderLayout {
    static let openWindowSystemImage = "macwindow"
}

struct IslandDigitalClockLayout {
    static let idleFontSize: CGFloat = 18
    static let activeFontSize: CGFloat = 27
    static let fontWeight = Font.Weight.bold
    static let idleWidth: CGFloat = 108
    static let idleTextHorizontalOffset: CGFloat = -6
    static let timerChevronTrailingInset: CGFloat = 4
}

struct IslandSessionIdentityLayout {
    static let idleRowHeight: CGFloat = 34
    static let activeRowHeight = idleRowHeight
}

struct IslandDetailsToggleLayout {
    static let rowSpacing: CGFloat = 10
    static let actionSpacing: CGFloat = rowSpacing
    static let controlSize: CGFloat = IslandSessionIdentityLayout.idleRowHeight
    static let symbolCanvasSize: CGFloat = 16

    static func systemImage(isShowingDetails: Bool) -> String {
        isShowingDetails ? "chevron.backward" : "list.bullet.rectangle"
    }
}

struct ManualAddFeedbackTiming {
    static let labelFadeOutDuration: TimeInterval = 0.18
    static let labelFadeInDuration: TimeInterval = 0.24
    static let confirmedHoldDuration: TimeInterval = 1

    static var labelMorphDuration: TimeInterval {
        labelFadeOutDuration + labelFadeInDuration
    }

    static var confirmationDuration: TimeInterval {
        labelMorphDuration + confirmedHoldDuration
    }

    static var resetDelayAfterCollapse: TimeInterval {
        max(
            NotchAnimationTiming.movementDuration,
            NotchAnimationTiming.contentResponse
        )
    }
}

enum ManualAddFeedbackPhase: Equatable {
    case idle
    case fadingOut
    case confirmed

    var title: String {
        self == .confirmed ? "Added" : "Add"
    }

    var systemName: String {
        self == .confirmed ? "checkmark" : "plus"
    }

    var labelOpacity: Double {
        self == .fadingOut ? 0 : 1
    }

    var labelTransitionDuration: TimeInterval {
        self == .confirmed
            ? ManualAddFeedbackTiming.labelFadeInDuration
            : ManualAddFeedbackTiming.labelFadeOutDuration
    }

    var locksInteraction: Bool {
        self != .idle
    }
}

struct IslandCompletionMotion {
    static let cycleDuration: TimeInterval = 0.95
    static let ringingDuration: TimeInterval = 0.54
    static let oscillationCount = 4.0
    static let horizontalAmplitude: CGFloat = 2.0
    static let rotationAmplitude = 0.45

    static func amount(at elapsed: TimeInterval) -> Double {
        guard elapsed >= 0, cycleDuration > 0 else {
            return 0
        }

        let cycleTime = elapsed.truncatingRemainder(
            dividingBy: cycleDuration
        )
        guard cycleTime < ringingDuration else {
            return 0
        }

        let progress = cycleTime / ringingDuration
        let envelope = sin(.pi * progress)
        return sin(progress * .pi * 2 * oscillationCount) * envelope
    }
}

struct IslandAppearancePolicy {
    static func usesLiquidNotchBackground(
        isExpanded: Bool,
        appearance: WorkIslandAppearance
    ) -> Bool {
        isExpanded && appearance == .liquidGlass
    }
}

struct IslandLiquidGlassStyle {
    static let shellBlackOpacity = 0.06
    static let shellTintOpacity = 0.14
    static let shellReflectionTintOpacity = 0.14
    static let primaryActionTintOpacity = 0.70
    static let vividActionTintOpacity = 0.78
    static let selectedActivityTintOpacity = 0.76
    static let controlWhiteOverlayOpacity = 0.025
    static let controlHighlightOpacity = 0.10
    static let controlTintReflectionOpacity = 0.24
    static let controlTintBorderOpacity = 0.40

    static let primaryActionRGB = (red: 0.05, green: 0.92, blue: 0.28)
    static let pauseActionRGB = (red: 1.00, green: 0.46, blue: 0.00)
    static let finishActionRGB = (red: 0.28, green: 0.12, blue: 1.00)
    static let discardActionRGB = (red: 1.00, green: 0.06, blue: 0.14)
    static let selectedActivityRGB = (red: 0.32, green: 0.18, blue: 1.00)

    static var resumeActionRGB: (red: Double, green: Double, blue: Double) {
        primaryActionRGB
    }

    static var resumeActionTintOpacity: Double {
        primaryActionTintOpacity
    }

    static var primaryActionTint: Color {
        Color(
            red: primaryActionRGB.red,
            green: primaryActionRGB.green,
            blue: primaryActionRGB.blue
        )
    }

    static var selectedActivityTint: Color {
        Color(
            red: selectedActivityRGB.red,
            green: selectedActivityRGB.green,
            blue: selectedActivityRGB.blue
        )
    }

    static var pauseActionTint: Color {
        Color(
            red: pauseActionRGB.red,
            green: pauseActionRGB.green,
            blue: pauseActionRGB.blue
        )
    }

    static var resumeActionTint: Color {
        primaryActionTint
    }

    static var finishActionTint: Color {
        Color(
            red: finishActionRGB.red,
            green: finishActionRGB.green,
            blue: finishActionRGB.blue
        )
    }

    static var discardActionTint: Color {
        Color(
            red: discardActionRGB.red,
            green: discardActionRGB.green,
            blue: discardActionRGB.blue
        )
    }

    static func shellBlackOpacity(
        for configuration: NotchGlassConfiguration
    ) -> Double {
        Double(configuration.frost) / 100
    }

    static func shellTintOpacity(
        for _: NotchGlassConfiguration
    ) -> Double {
        shellTintOpacity
    }

    static func shellReflectionTintOpacity(
        for _: NotchGlassConfiguration
    ) -> Double {
        shellReflectionTintOpacity
    }

    static func nativeGlassOpacity(
        for configuration: NotchGlassConfiguration
    ) -> Double {
        pow(blurProgress(for: configuration), 1.55)
    }

    static func additionalBlurOpacity(
        for configuration: NotchGlassConfiguration
    ) -> Double {
        pow(blurProgress(for: configuration), 2.4)
    }

    static func reflectionBlurRadius(
        for configuration: NotchGlassConfiguration
    ) -> CGFloat {
        CGFloat(blurProgress(for: configuration) * 2.8)
    }

    static func fallbackBaseMaterialOpacity(
        for configuration: NotchGlassConfiguration
    ) -> Double {
        nativeGlassOpacity(for: configuration)
    }

    static func fallbackBlackOpacity(
        for configuration: NotchGlassConfiguration
    ) -> Double {
        min(
            0.62,
            shellBlackOpacity(for: configuration)
                + nativeGlassOpacity(for: configuration) * 0.28
        )
    }

    private static func blurProgress(
        for configuration: NotchGlassConfiguration
    ) -> Double {
        Double(configuration.blur)
            / Double(NotchGlassConfiguration.blurScaleMaximum)
    }

}

/// Mathematical reference retained from the rejected Convex Squircle lens
/// experiment. It is covered by geometry tests but is not rendered by the app.
struct IslandConvexSquircleLens {
    static let bandWidth: CGFloat = 30
    static let glassThickness: CGFloat = 18
    static let sampleCount = 192

    struct RenderedMap {
        let image: CIImage
        let maximumDisplacement: CGFloat
    }

    static func profileHeight(at progress: Double) -> Double {
        let x = min(1, max(0, progress))
        return pow(max(0, 1 - pow(1 - x, 4)), 0.25)
    }

    static func displacementMagnitudes(
        refractiveIndex: Double,
        bandWidth: CGFloat = bandWidth,
        glassThickness: CGFloat = glassThickness,
        sampleCount: Int = sampleCount
    ) -> [Double] {
        let count = max(2, sampleCount)
        guard refractiveIndex > 1.000_001 else {
            return Array(repeating: 0, count: count)
        }

        let eta = 1 / refractiveIndex
        return (0..<count).map { index in
            let progress = Double(index) / Double(count - 1)
            let height = profileHeight(at: progress)
            let delta = progress < 1 ? 0.000_1 : -0.000_1
            let derivative = (
                profileHeight(at: progress + delta) - height
            ) / delta
            let normalLength = hypot(derivative, 1)
            let normalX = -derivative / normalLength
            let normalY = -1 / normalLength
            let normalDotIncident = normalY
            let refractionTerm = 1 - eta * eta
                * (1 - normalDotIncident * normalDotIncident)

            guard refractionTerm >= 0 else {
                return 0
            }

            let factor = eta * normalDotIncident
                + sqrt(refractionTerm)
            let refractedX = -factor * normalX
            let refractedY = eta - factor * normalY
            guard abs(refractedY) > 0.000_001 else {
                return 0
            }

            let depth = height * Double(bandWidth)
                + Double(glassThickness)
            return max(0, refractedX * depth / refractedY)
        }
    }

    static func normalizedDisplacement(
        at point: CGPoint,
        in size: CGSize,
        cornerRadius: CGFloat,
        refractiveIndex: Double,
        bandWidth requestedBandWidth: CGFloat = bandWidth
    ) -> CGVector? {
        let effectiveBandWidth = min(
            requestedBandWidth,
            min(size.width, size.height) / 2
        )
        guard effectiveBandWidth > 0,
              let boundary = boundarySample(
                  at: point,
                  in: size,
                  cornerRadius: cornerRadius
              ),
              boundary.distance <= effectiveBandWidth else {
            return nil
        }

        let magnitudes = displacementMagnitudes(
            refractiveIndex: refractiveIndex,
            bandWidth: effectiveBandWidth
        )
        let maximum = magnitudes.max() ?? 0
        guard maximum > 0.000_001 else {
            return .zero
        }

        let progress = boundary.distance / effectiveBandWidth
        let magnitude = interpolatedMagnitude(
            at: Double(progress),
            in: magnitudes
        ) / maximum
        return CGVector(
            dx: boundary.inwardNormal.dx * magnitude,
            dy: boundary.inwardNormal.dy * magnitude
        )
    }

    static func renderedMap(
        size: CGSize,
        cornerRadius: CGFloat,
        refractiveIndex: Double
    ) -> RenderedMap? {
        let width = max(1, Int(size.width.rounded(.up)))
        let height = max(1, Int(size.height.rounded(.up)))
        let renderedSize = CGSize(width: width, height: height)
        let effectiveBandWidth = min(
            bandWidth,
            min(renderedSize.width, renderedSize.height) / 2
        )
        let magnitudes = displacementMagnitudes(
            refractiveIndex: refractiveIndex,
            bandWidth: effectiveBandWidth
        )
        let maximum = magnitudes.max() ?? 0
        guard maximum > 0.000_001 else {
            return nil
        }

        var bitmap = Data(count: width * height * 4)
        bitmap.withUnsafeMutableBytes { rawBuffer in
            let pixels = rawBuffer.bindMemory(to: UInt8.self)
            for row in 0..<height {
                for column in 0..<width {
                    let offset = (row * width + column) * 4
                    pixels[offset] = 128
                    pixels[offset + 1] = 128
                    pixels[offset + 2] = 0
                    pixels[offset + 3] = 255

                    // CIImage bitmap rows start at the lower edge. Convert to
                    // SwiftUI's top-origin geometry before sampling the notch.
                    let point = CGPoint(
                        x: CGFloat(column) + 0.5,
                        y: renderedSize.height - CGFloat(row) - 0.5
                    )
                    guard let boundary = boundarySample(
                        at: point,
                        in: renderedSize,
                        cornerRadius: cornerRadius
                    ), boundary.distance <= effectiveBandWidth else {
                        continue
                    }

                    let progress = boundary.distance / effectiveBandWidth
                    let magnitude = interpolatedMagnitude(
                        at: Double(progress),
                        in: magnitudes
                    ) / maximum
                    let horizontal = boundary.inwardNormal.dx * magnitude
                    let vertical = -boundary.inwardNormal.dy * magnitude
                    pixels[offset] = displacementComponent(horizontal)
                    pixels[offset + 1] = displacementComponent(vertical)
                }
            }
        }

        let image = CIImage(
            bitmapData: bitmap,
            bytesPerRow: width * 4,
            size: renderedSize,
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return RenderedMap(
            image: image,
            maximumDisplacement: CGFloat(maximum)
        )
    }

    private struct BoundarySample {
        let distance: CGFloat
        let inwardNormal: CGVector
    }

    private static func boundarySample(
        at point: CGPoint,
        in size: CGSize,
        cornerRadius: CGFloat
    ) -> BoundarySample? {
        guard size.width > 0,
              size.height > 0,
              point.x >= 0,
              point.x <= size.width,
              point.y >= 0,
              point.y <= size.height else {
            return nil
        }

        let radius = min(
            max(0, cornerRadius),
            min(size.width, size.height) / 2
        )
        let cornerCenterY = size.height - radius

        if radius > 0, point.y > cornerCenterY {
            if point.x < radius {
                let distanceToCenter = hypot(
                    point.x - radius,
                    point.y - cornerCenterY
                )
                guard distanceToCenter <= radius else {
                    return nil
                }
            } else if point.x > size.width - radius {
                let distanceToCenter = hypot(
                    point.x - (size.width - radius),
                    point.y - cornerCenterY
                )
                guard distanceToCenter <= radius else {
                    return nil
                }
            }
        }

        var candidates = [BoundarySample(
            distance: point.y,
            inwardNormal: CGVector(dx: 0, dy: 1)
        )]

        if radius == 0 || point.y <= cornerCenterY {
            candidates.append(
                BoundarySample(
                    distance: point.x,
                    inwardNormal: CGVector(dx: 1, dy: 0)
                )
            )
            candidates.append(
                BoundarySample(
                    distance: size.width - point.x,
                    inwardNormal: CGVector(dx: -1, dy: 0)
                )
            )
        }

        if radius == 0 || (point.x >= radius
            && point.x <= size.width - radius) {
            candidates.append(
                BoundarySample(
                    distance: size.height - point.y,
                    inwardNormal: CGVector(dx: 0, dy: -1)
                )
            )
        }

        if radius > 0, point.y >= cornerCenterY {
            if point.x <= radius {
                appendCornerSample(
                    point: point,
                    center: CGPoint(x: radius, y: cornerCenterY),
                    radius: radius,
                    to: &candidates
                )
            }
            if point.x >= size.width - radius {
                appendCornerSample(
                    point: point,
                    center: CGPoint(
                        x: size.width - radius,
                        y: cornerCenterY
                    ),
                    radius: radius,
                    to: &candidates
                )
            }
        }

        return candidates.min { $0.distance < $1.distance }
    }

    private static func appendCornerSample(
        point: CGPoint,
        center: CGPoint,
        radius: CGFloat,
        to candidates: inout [BoundarySample]
    ) {
        let horizontal = point.x - center.x
        let vertical = point.y - center.y
        let radialDistance = hypot(horizontal, vertical)
        guard radialDistance > 0, radialDistance <= radius else {
            return
        }

        candidates.append(
            BoundarySample(
                distance: radius - radialDistance,
                inwardNormal: CGVector(
                    dx: -horizontal / radialDistance,
                    dy: -vertical / radialDistance
                )
            )
        )
    }

    private static func interpolatedMagnitude(
        at progress: Double,
        in magnitudes: [Double]
    ) -> Double {
        guard !magnitudes.isEmpty else {
            return 0
        }
        let position = min(1, max(0, progress))
            * Double(magnitudes.count - 1)
        let lowerIndex = Int(position.rounded(.down))
        let upperIndex = min(magnitudes.count - 1, lowerIndex + 1)
        guard lowerIndex != upperIndex else {
            return magnitudes[lowerIndex]
        }
        let fraction = position - Double(lowerIndex)
        return magnitudes[lowerIndex] * (1 - fraction)
            + magnitudes[upperIndex] * fraction
    }

    private static func displacementComponent(_ value: CGFloat) -> UInt8 {
        let clamped = min(1, max(-1, value))
        return UInt8(clamping: Int((128 + clamped * 127).rounded()))
    }
}

struct IslandNotchBackground: View {
    let isExpanded: Bool
    let appearance: WorkIslandAppearance
    let configuration: NotchGlassConfiguration

    @ViewBuilder
    var body: some View {
        let cornerRadius: CGFloat = isExpanded ? 25 : 14
        let shape = NotchShape(cornerRadius: cornerRadius)

        if IslandAppearancePolicy.usesLiquidNotchBackground(
            isExpanded: isExpanded,
            appearance: appearance
        ) {
            if #available(macOS 26.0, *) {
                shape
                    .fill(
                        Color.black.opacity(
                            IslandLiquidGlassStyle.shellBlackOpacity(
                                for: configuration
                            )
                        )
                    )
                    .background {
                        additionalBlurLayer(shape: shape)
                    }
                    .background { nativeGlassLayer(shape: shape) }
                    .overlay { liquidReflection(shape: shape) }
            } else {
                shape
                    .fill(Color.clear)
                    .background {
                        fallbackBaseMaterialLayer(shape: shape)
                    }
                    .background {
                        additionalBlurLayer(shape: shape)
                    }
                    .overlay {
                        shape.fill(
                            Color.black.opacity(
                                IslandLiquidGlassStyle.fallbackBlackOpacity(
                                    for: configuration
                                )
                            )
                        )
                    }
                    .overlay { liquidReflection(shape: shape) }
            }
        } else {
            shape.fill(Color.black)
        }
    }

    @ViewBuilder
    private func liquidReflection(shape: NotchShape) -> some View {
        let reflection = shape
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.18), location: 0),
                        .init(color: Color.white.opacity(0.04), location: 0.24),
                        .init(color: .clear, location: 0.58),
                        .init(
                            color: IslandLiquidGlassStyle.selectedActivityTint.opacity(
                                IslandLiquidGlassStyle.shellReflectionTintOpacity(
                                    for: configuration
                                )
                            ),
                            location: 1
                        )
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .blendMode(.screen)
        let blurRadius = IslandLiquidGlassStyle.reflectionBlurRadius(
            for: configuration
        )

        if blurRadius > 0 {
            reflection.blur(radius: blurRadius)
        } else {
            reflection
        }
    }

    @ViewBuilder
    @available(macOS 26.0, *)
    private func nativeGlassLayer(shape: NotchShape) -> some View {
        let opacity = IslandLiquidGlassStyle.nativeGlassOpacity(
            for: configuration
        )
        if opacity > 0 {
            shape
                .fill(Color.clear)
                .glassEffect(
                    Glass.regular.tint(
                        IslandLiquidGlassStyle.selectedActivityTint.opacity(
                            IslandLiquidGlassStyle.shellTintOpacity(
                                for: configuration
                            )
                        )
                    ),
                    in: shape
                )
                .opacity(opacity)
        }
    }

    @ViewBuilder
    private func additionalBlurLayer(shape: NotchShape) -> some View {
        let opacity = IslandLiquidGlassStyle.additionalBlurOpacity(
            for: configuration
        )
        if opacity > 0 {
            shape
                .fill(.regularMaterial)
                .opacity(opacity)
        }
    }

    @ViewBuilder
    private func fallbackBaseMaterialLayer(shape: NotchShape) -> some View {
        let opacity = IslandLiquidGlassStyle.fallbackBaseMaterialOpacity(
            for: configuration
        )
        if opacity > 0 {
            shape
                .fill(.ultraThinMaterial)
                .opacity(opacity)
        }
    }

}

struct TimerIslandView: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject var presentation: IslandPresentationState
    let openMainWindow: () -> Void
    @State private var isShowingDetails = false
    @State private var isChoosingDuration = false
    @State private var manualAddFeedbackPhase = ManualAddFeedbackPhase.idle
    @State private var isHoldingManualAddFeedbackInteraction = false
    @State private var manualAddFeedbackSequence = 0

    private var islandRecordingMode: ActivityRecordingMode {
        preferences.recordingMode.notchMode
    }

    var body: some View {
        ZStack(alignment: .top) {
            IslandNotchBackground(
                isExpanded: presentation.isExpanded,
                appearance: preferences.appearance,
                configuration: preferences.notchGlassConfiguration
            )

            TimelineView(.periodic(from: .now, by: 1)) { context in
                ZStack(alignment: .top) {
                    progressOverlay(at: context.date)

                    if presentation.isExpanded {
                        expandedContent(at: context.date)
                            .transition(
                                .opacity.animation(
                                    .easeOut(
                                        duration: NotchAnimationTiming
                                            .contentResponse
                                    )
                                )
                            )
                    } else {
                        Group {
                            if preferences.notchOpenMode != .doubleClick {
                                Button {
                                    presentation.isExpanded = true
                                } label: {
                                    compactContent
                                        .frame(
                                            maxWidth: .infinity,
                                            maxHeight: .infinity
                                        )
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Expand Work Island")
                                .accessibilityValue(
                                    presentation.compactStatus?.accessibilityValue
                                        ?? "Idle"
                                )
                            } else {
                                compactContent
                                    .frame(
                                        maxWidth: .infinity,
                                        maxHeight: .infinity
                                    )
                                    .contentShape(Rectangle())
                                    .accessibilityElement(children: .ignore)
                                    .accessibilityLabel("Expand Work Island")
                                    .accessibilityValue(
                                        presentation.compactStatus?.accessibilityValue
                                            ?? "Idle"
                                    )
                                    .onTapGesture(count: 2) {
                                        presentation.isExpanded = true
                                    }
                                    .accessibilityAction {
                                        presentation.isExpanded = true
                                    }
                            }
                        }
                        .transition(
                            .opacity.animation(
                                .easeOut(
                                    duration: NotchAnimationTiming
                                        .contentResponse
                                )
                            )
                        )
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onChange(of: preferences.recordingMode) { _ in
            isChoosingDuration = false
            cancelManualAddFeedback()
            isShowingDetails = false
        }
    }

    private var compactContent: some View {
        Color.clear
    }

    @ViewBuilder
    private func progressOverlay(at date: Date) -> some View {
        if let activeWork = store.activeWork,
           let progress = activeWork.progress(at: date),
           presentation.isExpanded || preferences.showsCompactProgress {
            if presentation.isExpanded {
                OpenNotchProgressShape(cornerRadius: 25)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)

                OpenNotchProgressShape(cornerRadius: 25)
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressColor(for: activeWork),
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            } else {
                OpenNotchProgressShape(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)

                OpenNotchProgressShape(cornerRadius: 16)
                    .trim(from: 0, to: progress)
                    .stroke(
                        progressColor(for: activeWork),
                        style: StrokeStyle(
                            lineWidth: 2.5,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
        } else if presentation.isExpanded {
            NotchShape(cornerRadius: 25)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
    }

    private func expandedContent(at date: Date) -> some View {
        VStack(spacing: 13) {
            HStack(spacing: 10) {
                Button(action: openMainWindow) {
                    Image(systemName: IslandHeaderLayout.openWindowSystemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(width: 30, height: 30)
                        .islandSurface(
                            in: Circle(),
                            classicFill: Color.white.opacity(0.08),
                            classicStroke: .clear,
                            liquidTint: .white
                        )
                }
                .buttonStyle(IslandButtonStyle())
                .accessibilityLabel("Open window")

                Text("Work Island")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)

                statusBadge

                Spacer()

                IslandRecordingModeMenu(presentation: presentation)

                if presentation.completionNotice != nil {
                    Button {
                        presentation.dismissCompletion()
                        presentation.isExpanded = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: 30, height: 30)
                            .islandSurface(
                                in: Circle(),
                                classicFill: Color.white.opacity(0.08),
                                classicStroke: .clear,
                                liquidTint: .white
                            )
                    }
                    .buttonStyle(IslandButtonStyle())
                    .accessibilityLabel("Dismiss")
                }
            }

            if let activeWork = store.activeWork {
                IslandCompletionRingingMotion(
                    isActive: presentation.completionNotice != nil,
                    trigger: presentation.completionNotice?.id
                ) {
                    HStack(alignment: .center, spacing: 14) {
                        IslandSessionIdentity(
                            eyebrow: activeEyebrow(activeWork),
                            title: activeWork.activityItemTitle.map {
                                "\(activeWork.subject) · \($0)"
                            } ?? activeWork.subject
                        )

                        Spacer()

                        Text(
                            WorkFormatting.clock(
                                activeWork.displayedDuration(at: date)
                            )
                        )
                        .font(
                            .system(
                                size: IslandDigitalClockLayout.activeFontSize,
                                weight: IslandDigitalClockLayout.fontWeight,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(height: IslandSessionIdentityLayout.activeRowHeight)
                }

                if activeWork.isRunning {
                    if store.canCompleteActiveItem {
                        GeometryReader { geometry in
                            let unitWidth = IslandActionLayout.completionUnitWidth(
                                totalWidth: geometry.size.width
                            )

                            HStack(
                                spacing: IslandActionLayout.completionSpacing
                            ) {
                                IslandActionButton(
                                    title: "Pause",
                                    systemName: "pause.fill",
                                    liquidTint: IslandLiquidGlassStyle.pauseActionTint,
                                    liquidTintOpacity: IslandLiquidGlassStyle.vividActionTintOpacity,
                                    usesHighContrastLiquidLabel: true,
                                    action: { pause(at: date) }
                                )
                                .frame(
                                    width: IslandActionLayout.runningCompletionPauseWidth(
                                        totalWidth: geometry.size.width
                                    )
                                )

                                IslandActionButton(
                                    title: "Finish",
                                    systemName: "stop.fill",
                                    tint: .indigo,
                                    liquidTint: IslandLiquidGlassStyle.finishActionTint,
                                    liquidTintOpacity: IslandLiquidGlassStyle.vividActionTintOpacity,
                                    usesHighContrastLiquidLabel: true,
                                    action: { finish(at: date) }
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Complete",
                                    systemName: "checkmark",
                                    tint: .green,
                                    action: { finish(at: date, completingItem: true) }
                                )
                                .frame(width: unitWidth)
                            }
                        }
                        .frame(height: 34)
                    } else {
                        HStack(spacing: IslandActionLayout.runningSpacing) {
                            IslandActionButton(
                                title: "Pause",
                                systemName: "pause.fill",
                                liquidTint: IslandLiquidGlassStyle.pauseActionTint,
                                liquidTintOpacity: IslandLiquidGlassStyle.vividActionTintOpacity,
                                usesHighContrastLiquidLabel: true,
                                action: { pause(at: date) }
                            )

                            IslandActionButton(
                                title: "Finish",
                                systemName: "checkmark",
                                tint: .indigo,
                                liquidTint: IslandLiquidGlassStyle.finishActionTint,
                                liquidTintOpacity: IslandLiquidGlassStyle.vividActionTintOpacity,
                                usesHighContrastLiquidLabel: true,
                                action: { finish(at: date) }
                            )
                        }
                        .frame(height: 34)
                    }
                } else {
                    if store.canCompleteActiveItem {
                        GeometryReader { geometry in
                            let unitWidth = IslandActionLayout.completionUnitWidth(
                                totalWidth: geometry.size.width
                            )

                            HStack(
                                spacing: IslandActionLayout.completionSpacing
                            ) {
                                IslandActionButton(
                                    title: "Resume",
                                    systemName: "play.fill",
                                    tint: .green,
                                    liquidTint: IslandLiquidGlassStyle.resumeActionTint,
                                    liquidTintOpacity: IslandLiquidGlassStyle.resumeActionTintOpacity,
                                    usesHighContrastLiquidLabel: true,
                                    action: { resume(at: date) }
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Discard",
                                    systemName: "trash.fill",
                                    tint: .red,
                                    liquidTint: IslandLiquidGlassStyle.discardActionTint,
                                    liquidTintOpacity: IslandLiquidGlassStyle.vividActionTintOpacity,
                                    usesHighContrastLiquidLabel: true,
                                    action: discard
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Finish",
                                    systemName: "stop.fill",
                                    tint: .indigo,
                                    liquidTint: IslandLiquidGlassStyle.finishActionTint,
                                    liquidTintOpacity: IslandLiquidGlassStyle.vividActionTintOpacity,
                                    usesHighContrastLiquidLabel: true,
                                    action: { finish(at: date) }
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Complete",
                                    systemName: "checkmark",
                                    tint: .green,
                                    action: { finish(at: date, completingItem: true) }
                                )
                                .frame(width: unitWidth)
                            }
                        }
                        .frame(height: 34)
                    } else {
                        GeometryReader { geometry in
                            let unitWidth = IslandActionLayout.pausedUnitWidth(
                                totalWidth: geometry.size.width
                            )

                            HStack(spacing: IslandActionLayout.pausedSpacing) {
                                IslandActionButton(
                                    title: "Resume",
                                    systemName: "play.fill",
                                    tint: .green,
                                    liquidTint: IslandLiquidGlassStyle.resumeActionTint,
                                    liquidTintOpacity: IslandLiquidGlassStyle.resumeActionTintOpacity,
                                    usesHighContrastLiquidLabel: true,
                                    action: { resume(at: date) }
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Discard",
                                    systemName: "trash.fill",
                                    tint: .red,
                                    liquidTint: IslandLiquidGlassStyle.discardActionTint,
                                    liquidTintOpacity: IslandLiquidGlassStyle.vividActionTintOpacity,
                                    usesHighContrastLiquidLabel: true,
                                    action: discard
                                )
                                .frame(width: unitWidth)

                                IslandActionButton(
                                    title: "Finish",
                                    systemName: "checkmark",
                                    tint: .indigo,
                                    liquidTint: IslandLiquidGlassStyle.finishActionTint,
                                    liquidTintOpacity: IslandLiquidGlassStyle.vividActionTintOpacity,
                                    usesHighContrastLiquidLabel: true,
                                    action: { finish(at: date) }
                                )
                                .frame(width: unitWidth * 2)
                            }
                        }
                        .frame(height: 34)
                    }
                }
            } else if let notice = presentation.completionNotice {
                completionContent(notice)
            } else {
                if isShowingDetails {
                    idleDetails(at: date)
                } else {
                    idleActivityPicker(at: date)
                }
            }
        }
        .padding(.top, 36)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    private func idleActivityPicker(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: IslandDetailsToggleLayout.rowSpacing) {
                IslandSessionIdentity(
                    eyebrow: idleEyebrow,
                    title: store.selectedTask?.name ?? "Choose an activity"
                )

                Spacer()

                switch islandRecordingMode {
                case .timer:
                    IslandDurationControl(
                        kind: .timer,
                        presentation: presentation,
                        isChoosingDuration: $isChoosingDuration
                    )
                case .manual:
                    IslandDurationControl(
                        kind: .manual,
                        presentation: presentation,
                        isChoosingDuration: $isChoosingDuration
                    )
                case .stopwatch, .pomodoro:
                    if let idleDigitalTime {
                        IslandIdleDigitalClock(value: idleDigitalTime)
                    }
                }

                idleTrailingActions(at: date, isShowingDetails: false)
            }
            .frame(height: IslandSessionIdentityLayout.idleRowHeight)

            if store.availableTasks.isEmpty {
                Text("Open the main window and create an activity first.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(store.availableTasks) { task in
                            IslandTaskChip(
                                task: task,
                                isSelected: store.selectedTaskID == task.id
                            ) {
                                store.selectTask(id: task.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private func idleDetails(at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: IslandDetailsToggleLayout.rowSpacing) {
                IslandActivityItemMenu(
                    presentation: presentation,
                    date: date
                )

                Spacer(minLength: 8)

                idleTrailingActions(at: date, isShowingDetails: true)
            }
            .frame(height: IslandSessionIdentityLayout.idleRowHeight)

            TextField(
                "Note",
                text: Binding(
                    get: { store.draftNote },
                    set: { store.updateNote($0) }
                )
            )
            .textFieldStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .islandSurface(
                in: RoundedRectangle(cornerRadius: 8),
                classicFill: Color.white.opacity(0.08),
                classicStroke: Color.white.opacity(0.12),
                liquidTint: .white
            )
        }
    }

    private func idleTrailingActions(
        at date: Date,
        isShowingDetails: Bool
    ) -> some View {
        HStack(spacing: IslandDetailsToggleLayout.actionSpacing) {
            Button {
                self.isShowingDetails.toggle()
            } label: {
                Image(
                    systemName: IslandDetailsToggleLayout.systemImage(
                        isShowingDetails: isShowingDetails
                    )
                )
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.76))
                .frame(
                    width: IslandDetailsToggleLayout.symbolCanvasSize,
                    height: IslandDetailsToggleLayout.symbolCanvasSize
                )
                .frame(
                    width: IslandDetailsToggleLayout.controlSize,
                    height: IslandDetailsToggleLayout.controlSize
                )
                .islandSurface(
                    in: Circle(),
                    classicFill: Color.white.opacity(0.09),
                    classicStroke: .clear,
                    liquidTint: .white
                )
            }
            .buttonStyle(IslandButtonStyle())
            .accessibilityLabel(
                isShowingDetails ? "Activities" : "Details"
            )

            idlePrimaryButton(at: date)
        }
        .frame(height: IslandSessionIdentityLayout.idleRowHeight)
    }

    private func finish(at date: Date, completingItem: Bool = false) {
        presentation.dismissCompletion()
        if completingItem {
            _ = store.finishAndComplete(at: date)
        } else {
            _ = store.finish(at: date)
        }
        if store.activeWork == nil {
            isShowingDetails = false
        }
    }

    private func pause(at date: Date) {
        presentation.dismissCompletion()
        store.pause(at: date)
    }

    private func resume(at date: Date) {
        presentation.dismissCompletion()
        store.resume(at: date)
    }

    private func discard() {
        presentation.dismissCompletion()
        if store.discardPausedWork() {
            isShowingDetails = false
        }
    }

    private func startSelectedMode(at date: Date) {
        presentation.dismissCompletion()
        let mode = islandRecordingMode
        if preferences.recordingMode != mode {
            preferences.recordingMode = mode
        }

        switch mode {
        case .stopwatch:
            store.start(at: date)
        case .timer:
            _ = store.startTimer(
                duration: TimeInterval(
                    preferences.timerDurationMinutes * 60
                ),
                at: date
            )
        case .pomodoro:
            _ = store.startPomodoro(
                configuration: preferences.pomodoroConfiguration,
                at: date
            )
        case .manual:
            break
        }
    }

    @ViewBuilder
    private func idlePrimaryButton(at date: Date) -> some View {
        if islandRecordingMode == .manual {
            IslandActionButton(
                title: manualAddFeedbackPhase.title,
                systemName: manualAddFeedbackPhase.systemName,
                labelOpacity: manualAddFeedbackPhase.labelOpacity,
                labelTransitionDuration:
                    manualAddFeedbackPhase.labelTransitionDuration,
                tint: .green,
                liquidTint: IslandLiquidGlassStyle.primaryActionTint,
                liquidTintOpacity: IslandLiquidGlassStyle.primaryActionTintOpacity,
                usesHighContrastLiquidLabel: true,
                isDisabled: !store.canStart,
                isInteractionLocked: manualAddFeedbackPhase.locksInteraction,
                action: { addManualSession(at: date) }
            )
            .frame(width: 112)
        } else {
            IslandActionButton(
                title: "Start",
                systemName: "play.fill",
                tint: .green,
                liquidTint: IslandLiquidGlassStyle.primaryActionTint,
                liquidTintOpacity: IslandLiquidGlassStyle.primaryActionTintOpacity,
                usesHighContrastLiquidLabel: true,
                isDisabled: !store.canStart,
                action: { startSelectedMode(at: date) }
            )
            .frame(width: 112)
        }
    }

    private func addManualSession(at date: Date) {
        guard manualAddFeedbackPhase == .idle else {
            return
        }

        guard store.addManualSession(
            duration: TimeInterval(preferences.manualDurationMinutes * 60),
            anchorDate: date,
            anchor: preferences.manualTimeAnchor,
            taskID: store.selectedTaskID,
            activityItemID: store.selectedActivityItemID,
            usesSelectedActivityItemWhenNil: false,
            note: store.draftNote
        ) != nil else {
            return
        }

        manualAddFeedbackSequence += 1
        let sequence = manualAddFeedbackSequence
        holdManualAddFeedbackInteraction()
        manualAddFeedbackPhase = .fadingOut
        isChoosingDuration = false

        DispatchQueue.main.asyncAfter(
            deadline: .now() + ManualAddFeedbackTiming.labelFadeOutDuration
        ) {
            guard manualAddFeedbackSequence == sequence else {
                return
            }
            manualAddFeedbackPhase = .confirmed
        }

        DispatchQueue.main.asyncAfter(
            deadline: .now() + ManualAddFeedbackTiming.confirmationDuration
        ) {
            guard manualAddFeedbackSequence == sequence else {
                return
            }
            presentation.isExpanded = false
            releaseManualAddFeedbackInteraction()
            resetManualAddStateAfterCollapse(sequence: sequence)
        }
    }

    private func resetManualAddStateAfterCollapse(sequence: Int) {
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ManualAddFeedbackTiming.resetDelayAfterCollapse
        ) {
            guard manualAddFeedbackSequence == sequence else {
                return
            }
            isShowingDetails = false
            manualAddFeedbackPhase = .idle
        }
    }

    private func holdManualAddFeedbackInteraction() {
        guard !isHoldingManualAddFeedbackInteraction else {
            return
        }
        isHoldingManualAddFeedbackInteraction = true
        presentation.beginInteraction()
    }

    private func releaseManualAddFeedbackInteraction() {
        guard isHoldingManualAddFeedbackInteraction else {
            return
        }
        isHoldingManualAddFeedbackInteraction = false
        presentation.endInteraction()
    }

    private func cancelManualAddFeedback() {
        manualAddFeedbackSequence += 1
        manualAddFeedbackPhase = .idle
        releaseManualAddFeedbackInteraction()
    }

    private func completionContent(
        _ notice: TimedActivityCompletion
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            IslandCompletionRingingMotion(
                isActive: true,
                trigger: notice.id
            ) {
                HStack(alignment: .center, spacing: 14) {
                    IslandSessionIdentity(
                        eyebrow: notice.title.uppercased(),
                        title: notice.activityTitle
                    )

                    Spacer()

                    Text("0:00")
                        .font(
                            .system(
                                size: IslandDigitalClockLayout.activeFontSize,
                                weight: IslandDigitalClockLayout.fontWeight,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(.white)
                }
                .frame(height: IslandSessionIdentityLayout.activeRowHeight)
            }

            IslandActionButton(
                title: "Done",
                systemName: "checkmark",
                tint: .green
            ) {
                presentation.dismissCompletion()
                presentation.isExpanded = false
            }
            .frame(height: 34)
        }
    }

    private var idleEyebrow: String {
        switch islandRecordingMode {
        case .stopwatch:
            return "STOPWATCH"
        case .manual:
            return "MANUAL"
        case .timer:
            return "TIMER"
        case .pomodoro:
            return "POMODORO"
        }
    }

    private var idleDigitalTime: String? {
        switch islandRecordingMode {
        case .pomodoro:
            return WorkFormatting.clock(
                TimeInterval(
                    preferences.pomodoroConfiguration.focusMinutes * 60
                )
            )
        case .stopwatch, .manual, .timer:
            return nil
        }
    }

    private func activeEyebrow(_ activeWork: ActiveWork) -> String {
        if let notice = presentation.completionNotice,
           let nextTitle = notice.nextTitle {
            return "\(notice.title.uppercased()) · \(nextTitle.uppercased())"
        }
        return activeWork.modeTitle.uppercased()
    }

    private func progressColor(for activeWork: ActiveWork) -> Color {
        switch activeWork.resolvedMode {
        case .stopwatch:
            return .indigo
        case .timer:
            return .indigo
        case .pomodoro:
            return activeWork.pomodoroPhase == .focus ? .green : .cyan
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let text = presentation.completionNotice != nil && store.activeWork == nil
            ? "DONE"
            : (store.isRunning ? "RUNNING" : (store.isPaused ? "PAUSED" : "READY"))
        let color: Color = presentation.completionNotice != nil && store.activeWork == nil
            ? .green
            : (store.isRunning ? .green : (store.isPaused ? .orange : .secondary))

        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(0.7)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .islandSurface(
                in: Capsule(),
                classicFill: color.opacity(0.13),
                classicStroke: .clear,
                liquidTint: color,
                isInteractive: false
            )
    }
}

private struct IslandCompletionRingingMotion<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt = Date()

    let isActive: Bool
    let trigger: UUID?
    let content: Content

    init(
        isActive: Bool,
        trigger: UUID?,
        @ViewBuilder content: () -> Content
    ) {
        self.isActive = isActive
        self.trigger = trigger
        self.content = content()
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 30.0,
                paused: reduceMotion || !isActive
            )
        ) { context in
            let amount = motionAmount(at: context.date)

            content
                .offset(
                    x: IslandCompletionMotion.horizontalAmplitude
                        * CGFloat(amount)
                )
                .rotationEffect(
                    .degrees(
                        IslandCompletionMotion.rotationAmplitude * amount
                    )
                )
        }
        .onAppear(perform: restart)
        .onChange(of: trigger) { _ in
            restart()
        }
    }

    private func motionAmount(at date: Date) -> Double {
        guard isActive, !reduceMotion else {
            return 0
        }
        return IslandCompletionMotion.amount(
            at: date.timeIntervalSince(startedAt)
        )
    }

    private func restart() {
        startedAt = Date()
    }
}

private enum IslandDurationKind {
    case timer
    case manual

    var accessibilityLabel: String {
        switch self {
        case .timer:
            return "Timer duration"
        case .manual:
            return "Manual duration"
        }
    }
}

private struct IslandDurationControl: View {
    @EnvironmentObject private var preferences: AppPreferences
    let kind: IslandDurationKind
    @ObservedObject var presentation: IslandPresentationState
    @Binding var isChoosingDuration: Bool
    @State private var isHoldingInteraction = false

    private var durationMinutes: Int {
        switch kind {
        case .timer:
            return preferences.timerDurationMinutes
        case .manual:
            return preferences.manualDurationMinutes
        }
    }

    private func setDuration(hours: Int, minutes: Int) {
        switch kind {
        case .timer:
            preferences.setTimerDuration(hours: hours, minutes: minutes)
        case .manual:
            preferences.setManualDuration(hours: hours, minutes: minutes)
        }
    }

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { durationMinutes / 60 },
            set: { hours in
                setDuration(
                    hours: hours,
                    minutes: durationMinutes % 60
                )
            }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { durationMinutes % 60 },
            set: { minutes in
                setDuration(
                    hours: durationMinutes / 60,
                    minutes: minutes
                )
            }
        )
    }

    var body: some View {
        Button(action: presentPicker) {
            ZStack(alignment: .trailing) {
                IslandIdleDigitalClock(
                    value: WorkFormatting.clock(
                        TimeInterval(durationMinutes * 60)
                    )
                )

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.46))
                    .padding(
                        .trailing,
                        IslandDigitalClockLayout.timerChevronTrailingInset
                    )
            }
            .frame(width: IslandDigitalClockLayout.idleWidth)
        }
        .buttonStyle(IslandButtonStyle())
        .accessibilityLabel(kind.accessibilityLabel)
        .accessibilityValue(
            WorkFormatting.clock(
                TimeInterval(durationMinutes * 60)
            )
        )
        .popover(isPresented: $isChoosingDuration, arrowEdge: .bottom) {
            DurationPicker(
                hours: hoursBinding,
                minutes: minutesBinding,
                step: preferences.durationMinuteStep
            )
            .padding(12)
            .onDisappear(perform: releaseInteraction)
        }
        .onDisappear(perform: releaseInteraction)
    }

    private func presentPicker() {
        guard !isChoosingDuration else {
            return
        }
        if !isHoldingInteraction {
            presentation.beginInteraction()
            isHoldingInteraction = true
        }
        isChoosingDuration = true
    }

    private func releaseInteraction() {
        guard isHoldingInteraction else {
            return
        }
        isHoldingInteraction = false
        presentation.endInteraction()
    }
}

private struct IslandIdleDigitalClock: View {
    let value: String

    var body: some View {
        Text(value)
            .font(
                .system(
                    size: IslandDigitalClockLayout.idleFontSize,
                    weight: IslandDigitalClockLayout.fontWeight,
                    design: .monospaced
                )
            )
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .frame(width: IslandDigitalClockLayout.idleWidth)
            .offset(x: IslandDigitalClockLayout.idleTextHorizontalOffset)
    }
}

private struct IslandRecordingModeMenu: View {
    @EnvironmentObject private var store: WorkTimerStore
    @EnvironmentObject private var preferences: AppPreferences
    @ObservedObject var presentation: IslandPresentationState

    private var currentMode: ActivityRecordingMode {
        guard let activeWork = store.activeWork else {
            return preferences.recordingMode.notchMode
        }
        switch activeWork.resolvedMode {
        case .stopwatch:
            return .stopwatch
        case .timer:
            return .timer
        case .pomodoro:
            return .pomodoro
        }
    }

    var body: some View {
        Button(action: showMenu) {
            HStack(spacing: 6) {
                Image(systemName: currentMode.systemImage)
                Text(currentMode.title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white.opacity(0.46))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, 10)
            .frame(height: 30)
            .islandSurface(
                in: Capsule(),
                classicFill: Color.white.opacity(0.08),
                classicStroke: Color.white.opacity(0.1),
                liquidTint: .white
            )
        }
        .buttonStyle(IslandButtonStyle())
        .disabled(store.activeWork != nil)
        .opacity(store.activeWork == nil ? 1 : 0.58)
        .accessibilityLabel("Method")
    }

    private func showMenu() {
        guard store.activeWork == nil else {
            return
        }

        presentation.beginInteraction()
        defer { presentation.endInteraction() }

        let menu = NSMenu(title: "Method")
        menu.autoenablesItems = false
        menu.minimumWidth = 150
        var positioningItem: NSMenuItem?

        for mode in ActivityRecordingMode.notchCases {
            let item = IslandSelectionMenuItem(
                title: mode.title,
                systemName: mode.systemImage,
                isSelected: currentMode == mode
            ) {
                preferences.recordingMode = mode
            }
            menu.addItem(item)
            if currentMode == mode {
                positioningItem = item
            }
        }

        _ = menu.popUp(
            positioning: positioningItem,
            at: NSEvent.mouseLocation,
            in: nil
        )
    }
}

private struct IslandActivityItemMenu: View {
    @EnvironmentObject private var store: WorkTimerStore
    @ObservedObject var presentation: IslandPresentationState
    let date: Date

    private var tasks: [ActivityItem] {
        guard let activityID = store.selectedTaskID else {
            return []
        }
        return store.selectableTasks(for: activityID, at: date)
    }

    private var routines: [ActivityItem] {
        guard let activityID = store.selectedTaskID else {
            return []
        }
        return store.selectableRoutines(for: activityID, at: date)
    }

    var body: some View {
        Button(action: showMenu) {
            HStack(spacing: 7) {
                Image(
                    systemName: store.selectedActivityItem?.kind.islandSystemImage
                        ?? "minus.circle"
                )
                Text(store.selectedActivityItem?.title ?? "None")
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.46))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(width: 232, height: 34)
            .islandSurface(
                in: Capsule(),
                classicFill: Color.white.opacity(0.08),
                classicStroke: Color.white.opacity(0.12),
                liquidTint: .white
            )
        }
        .buttonStyle(IslandButtonStyle())
        .accessibilityLabel("Item")
    }

    private func showMenu() {
        presentation.beginInteraction()
        defer { presentation.endInteraction() }

        let menu = NSMenu(title: "Item")
        menu.autoenablesItems = false
        menu.minimumWidth = 232
        var positioningItem: NSMenuItem?

        let noneItem = IslandSelectionMenuItem(
            title: "None",
            systemName: "minus.circle",
            isSelected: store.selectedActivityItemID == nil
        ) {
            store.selectActivityItem(id: nil, at: date)
        }
        menu.addItem(noneItem)
        if store.selectedActivityItemID == nil {
            positioningItem = noneItem
        }

        if !tasks.isEmpty || !routines.isEmpty {
            menu.addItem(.separator())
        }

        addSection(
            title: "Tasks",
            items: tasks,
            to: menu,
            positioningItem: &positioningItem
        )

        if !tasks.isEmpty && !routines.isEmpty {
            menu.addItem(.separator())
        }

        addSection(
            title: "Routines",
            items: routines,
            to: menu,
            positioningItem: &positioningItem
        )

        _ = menu.popUp(
            positioning: positioningItem,
            at: NSEvent.mouseLocation,
            in: nil
        )
    }

    private func addSection(
        title: String,
        items: [ActivityItem],
        to menu: NSMenu,
        positioningItem: inout NSMenuItem?
    ) {
        guard !items.isEmpty else {
            return
        }

        let header = NSMenuItem(
            title: title,
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        menu.addItem(header)

        for item in items {
            let menuItem = IslandSelectionMenuItem(
                title: item.title,
                systemName: item.kind.islandSystemImage,
                isSelected: store.selectedActivityItemID == item.id
            ) {
                store.selectActivityItem(id: item.id, at: date)
            }
            menu.addItem(menuItem)
            if store.selectedActivityItemID == item.id {
                positioningItem = menuItem
            }
        }
    }
}

private final class IslandSelectionMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(
        title: String,
        systemName: String,
        isSelected: Bool,
        handler: @escaping () -> Void
    ) {
        self.handler = handler
        super.init(title: title, action: nil, keyEquivalent: "")
        target = self
        action = #selector(performSelection(_:))
        state = isSelected ? .on : .off
        image = NSImage(
            systemSymbolName: systemName,
            accessibilityDescription: title
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func performSelection(_ sender: NSMenuItem) {
        handler()
    }
}

private struct IslandSessionIdentity: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(eyebrow)
                .font(.system(size: 9, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.42))

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

private struct IslandActionButton: View {
    @EnvironmentObject private var preferences: AppPreferences

    let title: String
    let systemName: String
    var labelOpacity = 1.0
    var labelTransitionDuration: TimeInterval = 0.2
    var tint: Color = .white
    var liquidTint: Color? = nil
    var liquidTintOpacity = 0.52
    var usesHighContrastLiquidLabel = false
    var isDisabled = false
    var isInteractionLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            actionLabel(title: title, systemName: systemName)
                .opacity(labelOpacity)
                .scaleEffect(labelOpacity == 0 ? 0.94 : 1)
                .offset(y: labelOpacity == 0 ? -2 : 0)
                .animation(
                    .easeInOut(duration: labelTransitionDuration),
                    value: labelOpacity
                )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .islandSurface(
                in: Capsule(),
                classicFill: tint.opacity(0.13),
                classicStroke: tint.opacity(0.18),
                liquidTint: liquidTint ?? tint,
                liquidTintOpacity: liquidTintOpacity
            )
        }
        .buttonStyle(IslandButtonStyle())
        .disabled(isDisabled || isInteractionLocked)
        .opacity(isDisabled ? 0.42 : 1)
        .accessibilityLabel(title)
    }

    private func actionLabel(
        title: String,
        systemName: String
    ) -> some View {
        return Label(title, systemImage: systemName)
            .font(.system(size: 12, weight: labelWeight))
            .foregroundStyle(labelColor)
            .shadow(
                color: highContrastLabel
                    ? .black.opacity(0.58)
                    : .clear,
                radius: highContrastLabel ? 0.8 : 0,
                y: highContrastLabel ? 0.5 : 0
            )
    }

    private var highContrastLabel: Bool {
        usesHighContrastLiquidLabel
            && preferences.appearance == .liquidGlass
    }

    private var labelColor: Color {
        highContrastLabel ? .white : tint
    }

    private var labelWeight: Font.Weight {
        highContrastLabel ? .bold : .semibold
    }
}

private struct IslandTaskChip: View {
    let task: WorkTask
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                }

                Text(task.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.64))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
                .islandSurface(
                    in: Capsule(),
                    classicFill: isSelected
                        ? Color.indigo.opacity(0.76)
                        : Color.white.opacity(0.08),
                    classicStroke: isSelected
                        ? Color.indigo.opacity(0.9)
                        : Color.white.opacity(0.1),
                    liquidTint: isSelected
                        ? IslandLiquidGlassStyle.selectedActivityTint
                        : .white,
                    liquidTintOpacity: isSelected
                        ? IslandLiquidGlassStyle.selectedActivityTintOpacity
                        : 0.07
                )
        }
        .buttonStyle(IslandButtonStyle())
        .accessibilityLabel(isSelected ? "Selected activity, \(task.name)" : "Select activity, \(task.name)")
    }
}

private struct IslandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.76 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct IslandAdaptiveSurface<S: Shape>: ViewModifier {
    @EnvironmentObject private var preferences: AppPreferences

    let shape: S
    let classicFill: Color
    let classicStroke: Color
    let liquidTint: Color
    let liquidTintOpacity: Double
    let isInteractive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if preferences.appearance == .liquidGlass {
            content
                .background(
                    Color.white.opacity(
                        IslandLiquidGlassStyle.controlWhiteOverlayOpacity
                    ),
                    in: shape
                )
                .background(liquidTint.opacity(liquidTintOpacity), in: shape)
                .background(
                    LinearGradient(
                        stops: [
                            .init(
                                color: Color.white.opacity(
                                    IslandLiquidGlassStyle.controlHighlightOpacity
                                ),
                                location: 0
                            ),
                            .init(color: .clear, location: 0.48),
                            .init(
                                color: liquidTint.opacity(
                                    IslandLiquidGlassStyle.controlTintReflectionOpacity
                                ),
                                location: 1
                            )
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: shape
                )
                .overlay { liquidBorder }
                .shadow(
                    color: .black.opacity(isInteractive ? 0.14 : 0.08),
                    radius: isInteractive ? 3 : 2,
                    y: 1
                )
        } else {
            content
                .background(classicFill, in: shape)
                .overlay {
                    shape.stroke(classicStroke, lineWidth: 1)
                }
        }
    }

    private var liquidBorder: some View {
        shape.stroke(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.44),
                    Color.white.opacity(0.09),
                    liquidTint.opacity(
                        IslandLiquidGlassStyle.controlTintBorderOpacity
                    )
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            lineWidth: 1
        )
    }
}

private extension View {
    func islandSurface<S: Shape>(
        in shape: S,
        classicFill: Color,
        classicStroke: Color,
        liquidTint: Color,
        liquidTintOpacity: Double = 0.16,
        isInteractive: Bool = true
    ) -> some View {
        modifier(
            IslandAdaptiveSurface(
                shape: shape,
                classicFill: classicFill,
                classicStroke: classicStroke,
                liquidTint: liquidTint,
                liquidTintOpacity: liquidTintOpacity,
                isInteractive: isInteractive
            )
        )
    }
}

private struct NotchShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(cornerRadius, min(rect.width, rect.height) / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

struct OpenNotchProgressShape: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: 1.5, dy: 1.5)
        let radius = min(
            cornerRadius,
            min(insetRect.width, insetRect.height) / 2
        )
        var path = Path()

        path.move(to: CGPoint(x: insetRect.maxX, y: insetRect.minY))
        path.addLine(to: CGPoint(x: insetRect.maxX, y: insetRect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.maxX - radius, y: insetRect.maxY),
            control: CGPoint(x: insetRect.maxX, y: insetRect.maxY)
        )
        path.addLine(to: CGPoint(x: insetRect.minX + radius, y: insetRect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: insetRect.minX, y: insetRect.maxY - radius),
            control: CGPoint(x: insetRect.minX, y: insetRect.maxY)
        )
        path.addLine(to: CGPoint(x: insetRect.minX, y: insetRect.minY))
        return path
    }
}
