import Foundation
import SwiftData

@Model
final class InsurancePolicy {
    var providerName: String = ""
    var policyNumber: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date().addingTimeInterval(365 * 24 * 60 * 60)
    var deductibleAmount: Decimal = 0
    var dwellingCoverageAmount: Decimal = 0
    var personalPropertyCoverageAmount: Decimal = 0
    var lossOfUseCoverageAmount: Decimal = 0
    var liabilityCoverageAmount: Decimal = 0
    var medicalPaymentsCoverageAmount: Decimal = 0
    
    init(
        providerName: String = "",
        policyNumber: String = "",
        startDate: Date = Date(),
        endDate: Date = Date().addingTimeInterval(365 * 24 * 60 * 60),
        deductibleAmount: Decimal = 0,
        dwellingCoverageAmount: Decimal = 0,
        personalPropertyCoverageAmount: Decimal = 0,
        lossOfUseCoverageAmount: Decimal = 0,
        liabilityCoverageAmount: Decimal = 0,
        medicalPaymentsCoverageAmount: Decimal = 0
    ) {
        self.providerName = providerName
        self.policyNumber = policyNumber
        self.startDate = startDate
        self.endDate = endDate
        self.deductibleAmount = deductibleAmount
        self.dwellingCoverageAmount = dwellingCoverageAmount
        self.personalPropertyCoverageAmount = personalPropertyCoverageAmount
        self.lossOfUseCoverageAmount = lossOfUseCoverageAmount
        self.liabilityCoverageAmount = liabilityCoverageAmount
        self.medicalPaymentsCoverageAmount = medicalPaymentsCoverageAmount
    }
}
