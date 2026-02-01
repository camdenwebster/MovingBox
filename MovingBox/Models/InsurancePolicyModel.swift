//
//  InsurancePolicyModel.swift
//  MovingBox
//
//  Created by Camden Webster on 3/7/25.
//

import Foundation
import SwiftData

@Model
class InsurancePolicy {
    // Properties with default values
    var providerName: String = ""
    var policyNumber: String = ""
    var deductibleAmount: Decimal = 0.00
    var dwellingCoverageAmount: Decimal = 0.00
    var personalPropertyCoverageAmount: Decimal = 0.00
    var lossOfUseCoverageAmount: Decimal = 0.00
    var liabilityCoverageAmount: Decimal = 0.00
    var medicalPaymentsCoverageAmount: Decimal = 0.00
    var startDate: Date = Date()
    var endDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    // Add insuredHome property with a relationship
    @Relationship(deleteRule: .nullify) var insuredHome: Home?

    // Default initializer will use the default values
    init() {}

    // Keep the full initializer for when you need to set all values
    init(
        providerName: String,
        policyNumber: String,
        deductibleAmount: Decimal,
        dwellingCoverageAmount: Decimal,
        personalPropertyCoverageAmount: Decimal,
        lossOfUseCoverageAmount: Decimal,
        liabilityCoverageAmount: Decimal,
        medicalPaymentsCoverageAmount: Decimal,
        startDate: Date,
        endDate: Date,
        insuredHome: Home? = nil
    ) {
        self.providerName = providerName
        self.policyNumber = policyNumber
        self.deductibleAmount = deductibleAmount
        self.dwellingCoverageAmount = dwellingCoverageAmount
        self.personalPropertyCoverageAmount = personalPropertyCoverageAmount
        self.lossOfUseCoverageAmount = lossOfUseCoverageAmount
        self.liabilityCoverageAmount = liabilityCoverageAmount
        self.medicalPaymentsCoverageAmount = medicalPaymentsCoverageAmount
        self.startDate = startDate
        self.endDate = endDate
        self.insuredHome = insuredHome
    }
}

extension Calendar {
    fileprivate static func date(byAddingYear years: Int, to date: Date) -> Date? {
        return Calendar.current.date(byAdding: .year, value: years, to: date)
    }
}
