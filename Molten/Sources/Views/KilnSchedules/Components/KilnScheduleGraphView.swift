//
//  KilnScheduleGraphView.swift
//  Molten
//
//  Temperature/time graph visualization for kiln schedules
//

import SwiftUI

struct KilnScheduleGraphView: View {
    let segments: [KilnSegmentInput]
    let temperatureUnit: TemperatureUnit

    private struct TemperaturePoint {
        let time: TimeInterval  // Seconds from start
        let temperature: Decimal
        let isHeating: Bool
        let isHold: Bool  // Is this a hold segment?
    }

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let points = calculateTemperaturePoints()

                // Always show grid and labels, even with no data
                let maxTemp: Decimal = points.isEmpty ? 1500 : (points.map { $0.temperature }.max() ?? 1500)
                let minTemp: Decimal = 0
                let maxTime: TimeInterval = points.isEmpty ? 3600 : (points.last?.time ?? 1)

                // Draw grid
                drawGrid(context: context, size: size, maxTemp: maxTemp, maxTime: maxTime)

                // Draw temperature curve (if we have points)
                if !points.isEmpty {
                    drawTemperatureCurve(context: context, size: size, points: points, maxTemp: maxTemp, minTemp: minTemp, maxTime: maxTime)
                }

                // Draw labels
                drawLabels(context: context, size: size, maxTemp: maxTemp, maxTime: maxTime)
            }
            .frame(height: geometry.size.width * 0.375) // 2:0.75 aspect ratio
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .aspectRatio(2.0 / 0.75, contentMode: .fit)
    }

    private func calculateTemperaturePoints() -> [TemperaturePoint] {
        var points: [TemperaturePoint] = []
        var currentTime: TimeInterval = 0
        var currentTemp: Decimal = 20 // Room temperature

        // Start point
        points.append(TemperaturePoint(time: 0, temperature: currentTemp, isHeating: true, isHold: false))

        // Only process valid segments (with both rate and target)
        let validSegments = segments.filter { $0.targetTemperature > 0 && $0.rampRate > 0 }

        for segment in validSegments {
            let isHeating = segment.targetTemperature > currentTemp

            // Determine actual rate (handle 9999 special case)
            let actualRate: Decimal
            if segment.rampRate == 9999 {
                if isHeating {
                    actualRate = UserSettings.getHeatupRate(forTemperature: segment.targetTemperature)
                } else {
                    actualRate = UserSettings.getCooldownRate(forTemperature: currentTemp)
                }
            } else {
                actualRate = segment.rampRate
            }

            // Calculate ramp duration
            let tempDelta = abs(segment.targetTemperature - currentTemp)
            let rampHours = tempDelta / actualRate
            let rampSeconds = TimeInterval(truncating: rampHours * 3600 as NSNumber)

            // Add point at end of ramp
            currentTime += rampSeconds
            currentTemp = segment.targetTemperature
            points.append(TemperaturePoint(time: currentTime, temperature: currentTemp, isHeating: isHeating, isHold: false))

            // Add hold if present
            if segment.holdTime > 0 {
                let holdSeconds = TimeInterval(truncating: segment.holdTime * 60 as NSNumber)
                currentTime += holdSeconds
                points.append(TemperaturePoint(time: currentTime, temperature: currentTemp, isHeating: isHeating, isHold: true))
            }
        }

        return points
    }

    private func drawGrid(context: GraphicsContext, size: CGSize, maxTemp: Decimal, maxTime: TimeInterval) {
        var gridContext = context
        gridContext.opacity = 0.2

        // Horizontal grid lines (temperature)
        let tempStep = calculateTempStep(maxTemp: maxTemp)
        var temp: Decimal = 0
        while temp <= maxTemp {
            let y = yPosition(temp: temp, maxTemp: maxTemp, minTemp: 0, height: size.height)
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
            }
            gridContext.stroke(path, with: .color(.gray), lineWidth: 0.5)
            temp += tempStep
        }

        // Vertical grid lines (time)
        if maxTime > 0 {
            let timeStep = calculateTimeStep(maxTime: maxTime)
            var time: TimeInterval = 0
            while time <= maxTime {
                let x = xPosition(time: time, maxTime: maxTime, width: size.width)
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }
                gridContext.stroke(path, with: .color(.gray), lineWidth: 0.5)
                time += timeStep
            }
        }
    }

    private func drawTemperatureCurve(context: GraphicsContext, size: CGSize, points: [TemperaturePoint], maxTemp: Decimal, minTemp: Decimal, maxTime: TimeInterval) {
        guard points.count >= 2 else { return }

        // Draw segments with different colors for heating/cooling
        for i in 0..<points.count - 1 {
            let start = points[i]
            let end = points[i + 1]

            let startX = xPosition(time: start.time, maxTime: maxTime, width: size.width)
            let startY = yPosition(temp: start.temperature, maxTemp: maxTemp, minTemp: minTemp, height: size.height)
            let endX = xPosition(time: end.time, maxTime: maxTime, width: size.width)
            let endY = yPosition(temp: end.temperature, maxTemp: maxTemp, minTemp: minTemp, height: size.height)

            let path = Path { p in
                p.move(to: CGPoint(x: startX, y: startY))
                p.addLine(to: CGPoint(x: endX, y: endY))
            }

            // Color based on heating/cooling/hold
            let color: Color
            if end.isHold {
                color = .purple  // Hold segments are purple
            } else if end.isHeating {
                color = .red  // Heating is red
            } else {
                color = .blue  // Cooling is blue
            }
            context.stroke(path, with: .color(color), lineWidth: 2)

            // Draw point circles
            let circle = Path(ellipseIn: CGRect(x: endX - 3, y: endY - 3, width: 6, height: 6))
            context.fill(circle, with: .color(color))
        }
    }

    private func drawLabels(context: GraphicsContext, size: CGSize, maxTemp: Decimal, maxTime: TimeInterval) {
        // Temperature axis label (left side)
        let tempStep = calculateTempStep(maxTemp: maxTemp)
        var temp: Decimal = 0
        while temp <= maxTemp {
            let y = yPosition(temp: temp, maxTemp: maxTemp, minTemp: 0, height: size.height)
            let text = Text("\(Int(truncating: temp as NSNumber))°")
                .font(.caption2)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            context.draw(text, at: CGPoint(x: 20, y: y))
            temp += tempStep
        }

        // Time axis label (bottom)
        if maxTime > 0 {
            let timeStep = calculateTimeStep(maxTime: maxTime)
            var time: TimeInterval = 0
            while time <= maxTime {
                let x = xPosition(time: time, maxTime: maxTime, width: size.width)
                let hours = Int(time / 3600)
                let text = Text("\(hours)h")
                    .font(.caption2)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                context.draw(text, at: CGPoint(x: x, y: size.height - 10))
                time += timeStep
            }
        }
    }

    private func xPosition(time: TimeInterval, maxTime: TimeInterval, width: CGFloat) -> CGFloat {
        guard maxTime > 0 else { return 0 }
        let padding: CGFloat = 40
        let graphWidth = width - padding * 2
        return padding + CGFloat(time / maxTime) * graphWidth
    }

    private func yPosition(temp: Decimal, maxTemp: Decimal, minTemp: Decimal, height: CGFloat) -> CGFloat {
        let padding: CGFloat = 30
        let graphHeight = height - padding * 2
        let tempRange = maxTemp - minTemp
        guard tempRange > 0 else { return height / 2 }

        let normalizedTemp = (temp - minTemp) / tempRange
        let y = padding + graphHeight * (1 - CGFloat(truncating: normalizedTemp as NSNumber))
        return y
    }

    private func calculateTempStep(maxTemp: Decimal) -> Decimal {
        if maxTemp <= 500 { return 100 }
        if maxTemp <= 1000 { return 200 }
        if maxTemp <= 2000 { return 250 }
        return 500
    }

    private func calculateTimeStep(maxTime: TimeInterval) -> TimeInterval {
        let hours = maxTime / 3600
        if hours <= 2 { return 1800 } // 30 min
        if hours <= 6 { return 3600 } // 1 hour
        if hours <= 12 { return 7200 } // 2 hours
        return 14400 // 4 hours
    }
}

//#Preview {
//    VStack {
//        Text("Sample Kiln Schedule Graph")
//            .font(.headline)
//
//        KilnScheduleGraphView(
//            segments: [
//                KilnSegmentInput(targetTemperature: 1000, rampRate: 300, holdTime: 15),
//                KilnSegmentInput(targetTemperature: 1450, rampRate: 150, holdTime: 30),
//                KilnSegmentInput(targetTemperature: 900, rampRate: 200, holdTime: 0),
//                KilnSegmentInput(targetTemperature: 100, rampRate: 100, holdTime: 0)
//            ],
//            temperatureUnit: .fahrenheit
//        )
//        .padding()
//    }
//}
