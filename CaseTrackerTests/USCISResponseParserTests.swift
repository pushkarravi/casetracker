import Foundation
import Testing
@testable import CaseTracker

struct USCISResponseParserTests {
    @Test func parsesDocumentedSandboxResponse() throws {
        let json = """
        {
          "case_status": {
            "receiptNumber": "EAC9999103402",
            "formType": "I-130",
            "submittedDate": "09-05-2023 14:28:46",
            "modifiedDate": "09-05-2023 14:28:46",
            "current_case_status_text_en": "Case Approval Was Affirmed",
            "current_case_status_desc_en": "The approval of your case was affirmed.",
            "current_case_status_text_es": "Aprobación De Caso Reafirmada",
            "hist_case_status": null
          },
          "message": "Query was successful"
        }
        """
        let result = try USCISResponseParser.parse(Data(json.utf8), receiptNumber: "EAC9999103402")

        #expect(result.receiptNumber == "EAC9999103402")
        #expect(result.formType == "I-130")
        #expect(result.statusTitle == "Case Approval Was Affirmed")
        #expect(result.statusDetail == "The approval of your case was affirmed.")
        #expect(result.history.isEmpty)

        let components = Calendar(identifier: .gregorian)
            .dateComponents(in: TimeZone(identifier: "America/New_York")!, from: try #require(result.submittedDate))
        #expect(components.year == 2023 && components.month == 9 && components.day == 5 && components.hour == 14)
    }

    @Test func parsesHistoryAndSkipsUnusableEntries() throws {
        let json = """
        {
          "case_status": {
            "receiptNumber": "IOE0912345678",
            "current_case_status_text_en": "Case Was Approved",
            "hist_case_status": [
              { "date": "01-10-2024 09:00:00", "completed_text_en": "Case Was Received" },
              { "date": "02-20-2024 09:00:00", "completed_text_en": "" },
              { "date": null, "completed_text_en": "Interview Was Scheduled" }
            ]
          }
        }
        """
        let result = try USCISResponseParser.parse(Data(json.utf8), receiptNumber: "IOE0912345678")
        #expect(result.history.map(\.title) == ["Case Was Received"])
        #expect(result.formType == nil)
    }

    @Test func missingStatusIsCaseNotFound() {
        let json = #"{ "case_status": null, "message": "Receipt number not found" }"#
        #expect(throws: USCISError.caseNotFound("Receipt number not found")) {
            try USCISResponseParser.parse(Data(json.utf8), receiptNumber: "IOE0912345678")
        }
    }

    @Test func garbageIsInvalidResponse() {
        #expect(throws: USCISError.invalidResponse) {
            try USCISResponseParser.parse(Data("<html>".utf8), receiptNumber: "IOE0912345678")
        }
    }

    @Test func extractsErrorMessages() {
        #expect(USCISResponseParser.errorMessage(from: Data(#"{"message":"Bad receipt"}"#.utf8)) == "Bad receipt")
        #expect(USCISResponseParser.errorMessage(from: Data(#"{"errors":[{"message":"Nope"}]}"#.utf8)) == "Nope")
        #expect(USCISResponseParser.errorMessage(from: Data("not json".utf8)) == nil)
    }
}
