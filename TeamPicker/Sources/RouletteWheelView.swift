import SwiftUI

struct RouletteWheelView: View {
    let participants: [Participant]
    let highlightedName: String
    let progress: Double
    let pointerAngle: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                progressRing

                if reduceMotion {
                    reducedMotionView
                } else {
                    wheelView
                }
            }
            .frame(width: 280, height: 280)

            // 현재 선택 표시
            VStack(spacing: 4) {
                Text("현재 선택")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(highlightedName)
                    .font(.title2.bold())
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.1), value: highlightedName)
            }
            .frame(height: 52)
        }
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.15), value: progress)
        }
    }

    // MARK: - Wheel (names fixed, pointer rotates)

    private var wheelView: some View {
        let size: CGFloat = 280
        let center = size / 2
        let nameRadius: CGFloat = 100
        let sliceDeg = participants.isEmpty ? 360.0 : 360.0 / Double(participants.count)

        return ZStack {
            // 배경 원
            Circle()
                .fill(.ultraThinMaterial)
                .padding(12)

            // 구분선 (각 영역 경계)
            ForEach(0..<participants.count, id: \.self) { i in
                let boundaryDeg = Double(i) * sliceDeg - sliceDeg / 2
                SliceLine()
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    .frame(width: size - 24, height: size - 24)
                    .rotationEffect(.degrees(boundaryDeg))
            }

            // 참가자 이름들 (고정, 상단 중심 기준 좌우 대칭)
            ForEach(Array(participants.enumerated()), id: \.element.id) { index, participant in
                let deg = Double(index) * sliceDeg
                let rad = deg * .pi / 180
                let isHighlighted = participant.name == highlightedName

                Text(participant.name)
                    .font(isHighlighted ? .headline : .caption)
                    .fontWeight(isHighlighted ? .bold : .regular)
                    .foregroundStyle(isHighlighted ? Color.accentColor : .secondary)
                    .scaleEffect(isHighlighted ? 1.15 : 0.85)
                    .position(
                        x: center + CGFloat(sin(rad)) * nameRadius,
                        y: center - CGFloat(cos(rad)) * nameRadius
                    )
                    .animation(.easeOut(duration: 0.1), value: isHighlighted)
            }

            // 포인터 (중심축에서 회전)
            PointerArm()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.15), Color.accentColor],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 14, height: 105)
                .position(x: center, y: center - 52.5)
                .rotationEffect(
                    .degrees(pointerAngle),
                    anchor: UnitPoint(x: 0.5, y: (center / size))
                )

            // 중심 허브 (피벗)
            Circle()
                .fill(Color.accentColor)
                .frame(width: 18, height: 18)
                .shadow(color: Color.accentColor.opacity(0.4), radius: 6)
        }
    }

    // MARK: - Reduced Motion 대체 뷰

    private var reducedMotionView: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .padding(12)

            VStack(spacing: 8) {
                Image(systemName: "shuffle")
                    .font(.title)
                    .foregroundStyle(.secondary)

                Text(highlightedName)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.2), value: highlightedName)

                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Helper Shapes

/// 중심에서 상단으로 뻗는 구분선
private struct SliceLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: 0))
        return path
    }
}

/// 포인터 화살표 (삼각형 팁 + 몸체)
private struct PointerArm: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tipWidth: CGFloat = 14
        let bodyWidth: CGFloat = 2
        let tipHeight: CGFloat = 14

        // 삼각형 팁 (상단)
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.midX - tipWidth / 2, y: tipHeight))
        path.addLine(to: CGPoint(x: rect.midX - bodyWidth / 2, y: tipHeight))

        // 몸체 (하단으로)
        path.addLine(to: CGPoint(x: rect.midX - bodyWidth / 2, y: rect.height))
        path.addLine(to: CGPoint(x: rect.midX + bodyWidth / 2, y: rect.height))
        path.addLine(to: CGPoint(x: rect.midX + bodyWidth / 2, y: tipHeight))

        // 팁 오른쪽
        path.addLine(to: CGPoint(x: rect.midX + tipWidth / 2, y: tipHeight))
        path.closeSubpath()
        return path
    }
}

#Preview {
    RouletteWheelView(
        participants: [
            Participant(name: "Alice"),
            Participant(name: "Bob"),
            Participant(name: "Carol"),
            Participant(name: "Dave"),
            Participant(name: "Eve")
        ],
        highlightedName: "Carol",
        progress: 0.6,
        pointerAngle: 144
    )
}
