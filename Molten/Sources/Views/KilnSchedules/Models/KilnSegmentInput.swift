//
//  KilnSegmentInput.swift
//  Molten
//
//  Input model for building kiln schedule segments in forms
//

import Foundation

/// Input model for building segments in the form
struct KilnSegmentInput: Identifiable {
    let id: UUID
    let targetTemperature: Decimal
    let rampRate: Decimal      // Degrees per hour (required)
    let holdTime: Decimal      // Minutes (default 0)

    init(id: UUID = UUID(), targetTemperature: Decimal, rampRate: Decimal, holdTime: Decimal = 0) {
        self.id = id
        self.targetTemperature = targetTemperature
        self.rampRate = rampRate
        self.holdTime = holdTime
    }

    func calculateDuration(from currentTemperature: Decimal) -> TimeInterval {
        var totalSeconds: TimeInterval = 0

        // Add ramp time (required)
        guard rampRate > 0 else { return 0 }

        // Special case: 9999 means use kiln's max rates from settings
        let actualRate: Decimal
        if rampRate == 9999 {
            let isHeatingUp = targetTemperature > currentTemperature
            if isHeatingUp {
                // Use appropriate heatup rate based on target temperature
                actualRate = UserSettings.getHeatupRate(forTemperature: targetTemperature)
            } else {
                // Use appropriate cooldown rate based on starting temperature
                actualRate = UserSettings.getCooldownRate(forTemperature: currentTemperature)
            }
        } else {
            actualRate = rampRate
        }

        let tempDelta = abs(targetTemperature - currentTemperature)
        let hours = tempDelta / actualRate
        totalSeconds += TimeInterval(truncating: hours * 3600 as NSNumber)

        // Add hold time (optional)
        if holdTime > 0 {
            totalSeconds += TimeInterval(truncating: holdTime * 60 as NSNumber)
        }

        return totalSeconds
    }
}
