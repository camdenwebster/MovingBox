import Foundation
import SQLiteData

@Table("insurancePolicies")
nonisolated struct SQLiteInsurancePolicy: Hashable, Identifiable {
    let id: UUID
    var providerName: String = ""
    var policyNumber: String = ""
    @Column(as: Decimal.TextRepresentation.self)
    var deductibleAmount: Decimal = 0
    @Column(as: Decimal.TextRepresentation.self)
    var dwellingCoverageAmount: Decimal = 0
    @Column(as: Decimal.TextRepresentation.self)
    var personalPropertyCoverageAmount: Decimal = 0
    @Column(as: Decimal.TextRepresentation.self)
    var lossOfUseCoverageAmount: Decimal = 0
    @Column(as: Decimal.TextRepresentation.self)
    var liabilityCoverageAmount: Decimal = 0
    @Column(as: Decimal.TextRepresentation.self)
    var medicalPaymentsCoverageAmount: Decimal = 0
    var startDate: Date = Date()
    var endDate: Date = Date()
}
