import Testing
@testable import CaseTracker

struct StatusCategoryTests {
    @Test(arguments: [
        ("Case Was Received", StatusCategory.received),
        ("Fingerprint Fee Was Received", .received),
        ("Case Is Being Actively Reviewed By USCIS", .inProgress),
        ("Interview Was Scheduled", .inProgress),
        ("Response To USCIS' Request For Evidence Was Received", .inProgress),
        ("Request for Additional Evidence Was Sent", .actionNeeded),
        ("Notice Of Intent To Deny Was Sent", .actionNeeded),
        ("Case Was Approved", .approved),
        ("Case Approval Was Affirmed", .approved),
        ("New Card Is Being Produced", .approved),
        ("Card Was Mailed To Me", .completed),
        ("Card Was Delivered To Me By The Post Office", .completed),
        ("Case Was Denied", .denied),
        ("Case Rejected Because I Sent An Incorrect Fee", .denied),
    ])
    func categorizes(_ title: String, _ expected: StatusCategory) {
        #expect(StatusCategory(statusTitle: title) == expected)
    }

    @Test func emptyIsUnknown() {
        #expect(StatusCategory(statusTitle: nil) == .unknown)
        #expect(StatusCategory(statusTitle: "") == .unknown)
    }
}
