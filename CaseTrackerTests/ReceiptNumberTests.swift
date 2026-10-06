import Testing
@testable import CaseTracker

struct ReceiptNumberTests {
    @Test func normalizesPastedInput() {
        #expect(ReceiptNumber.normalize(" ioe-091 234 5678 ") == "IOE0912345678")
    }

    @Test(arguments: ["IOE0912345678", "eac9999103402", "WAC 21 901 23456"])
    func acceptsValidReceipts(_ value: String) {
        #expect(ReceiptNumber.isValid(value))
    }

    @Test(arguments: ["", "IOE091234567", "IOE09123456789", "1230912345678", "IO10912345678"])
    func rejectsInvalidReceipts(_ value: String) {
        #expect(!ReceiptNumber.isValid(value))
    }

    @Test func mapsServiceCenterPrefix() {
        #expect(ReceiptNumber.serviceCenter(for: "EAC9999103402") == "Vermont Service Center")
        #expect(ReceiptNumber.serviceCenter(for: "ioe0912345678") == "USCIS Online (ELIS)")
        #expect(ReceiptNumber.serviceCenter(for: "ZZZ0912345678") == nil)
    }
}
