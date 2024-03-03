//
//  StayAwake.swift
//  Ollamac
//
//  Created by user on 2024-03-03.
//

import Foundation
import IOKit.pwr_mgt

class StayAwake {
    var pmAssertionID: IOPMAssertionID = 0
    var assertionIsActive: Bool = false

    var noSleepReturn: IOReturn? // Could probably be replaced by a boolean value, for example 'isBlockingSleep', just make sure 'IOPMAssertionRelease' doesn't get called, if 'IOPMAssertionCreateWithName' failed.

    init(reason: String) throws {
        let result = self.createAssertion(reason: reason)
        if !result {
            throw NSError(
                domain: "Ollamac StayAwake failed, original reason: \(reason)",
                code: 0)
        }
    }

    deinit {
        _ = self.destroyAssertion()
    }

    func createAssertion(reason: String) -> Bool {
        guard !assertionIsActive else { return false }

        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &pmAssertionID)
        if result == kIOReturnSuccess {
            assertionIsActive = true
        }

        return assertionIsActive
    }

    func destroyAssertion() -> Bool {
        if assertionIsActive {
            _ = IOPMAssertionRelease(pmAssertionID) == kIOReturnSuccess
            pmAssertionID = 0
            assertionIsActive = false
            return true
        }

        return false
    }
}
