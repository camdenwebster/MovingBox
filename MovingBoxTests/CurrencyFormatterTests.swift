import Foundation
import Testing

@testable import MovingBox

@Suite struct CurrencyFormatterTests {
    var currencyFormatter = CurrencyFormatter()

    @Test("Test currency formatting with doubles")
    func testFormatCurrency() async throws {
        #expect(CurrencyFormatter.format(0.0) == "$0.00")
        #expect(CurrencyFormatter.format(1000.0) == "$1,000.00")
        #expect(CurrencyFormatter.format(1234.56) == "$1,234.56")
        #expect(CurrencyFormatter.format(-50.25) == "-$50.25")
    }

    @Test("Test currency formatting with decimals")
    func testDecimalFormatCurrency() async throws {
        let value1 = Decimal(0)
        let value2 = Decimal(1000)
        let value3 = Decimal(string: "1234.56")!
        let value4 = Decimal(string: "-50.25")!

        #expect(CurrencyFormatter.format(value1) == "$0.00")
        #expect(CurrencyFormatter.format(value2) == "$1,000.00")
        #expect(CurrencyFormatter.format(value3) == "$1,234.56")
        #expect(CurrencyFormatter.format(value4) == "-$50.25")
    }
}

// End of file. No additional code.
