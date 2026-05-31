//
//  BaliTravelHealthTests.swift
//  BaliTravelHealthTests
//
//  Created by Bergz on 3/5/26.
//

import Testing
@testable import BaliTravelHealth

struct BaliTravelHealthTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func decodesAssessmentResponseWithRecommendationInRawAnalysis() throws {
        let data = """
        {
          "id": 42,
          "user_id": 7,
          "symptoms": [11, 14],
          "ai_analysis_raw": {
            "diagnosis": "Possible travel fever",
            "confidence_score": 0.82,
            "risk_level": "medium",
            "recommendation": "Rest and monitor symptoms."
          },
          "diagnosis": "Possible travel fever",
          "confidence_score": 0.82,
          "risk_level": "medium",
          "created_at": "2026-05-26T08:00:00Z"
        }
        """.data(using: .utf8)!

        let result = try BaliAPI.decoder.decode(AssessmentResult.self, from: data)

        #expect(result.id == 42)
        #expect(result.userId == 7)
        #expect(result.diagnosis == "Possible travel fever")
        #expect(result.confidenceScore == 0.82)
        #expect(result.riskLevel == .medium)
        #expect(result.recommendation == "Rest and monitor symptoms.")
        #expect(result.createdAt == "2026-05-26T08:00:00Z")
    }

    @Test func decodesIndonesianRiskLevelsFromExpertService() throws {
        let samples: [(String, RiskLevel)] = [
            ("Rendah", .low),
            ("Sedang", .medium),
            ("Tinggi", .high),
            ("Darurat", .emergency),
            ("low", .low),
            ("medium", .medium),
            ("high", .high)
        ]

        for (rawRisk, expected) in samples {
            let data = """
            {
              "id": 50,
              "user_id": 7,
              "ai_analysis_raw": {
                "diagnosis": "Expert diagnosis",
                "confidence_score": 0.91,
                "risk_level": "\(rawRisk)",
                "recommendation": "Follow expert advice."
              },
              "diagnosis": "Expert diagnosis",
              "confidence_score": 0.91,
              "risk_level": "\(rawRisk)",
              "created_at": "2026-05-26T08:00:00Z"
            }
            """.data(using: .utf8)!

            let result = try BaliAPI.decoder.decode(AssessmentResult.self, from: data)

            #expect(result.riskLevel == expected)
            #expect(result.recommendation == "Follow expert advice.")
        }
    }

    @Test func decodesAssessmentWithNullableExpertFields() throws {
        let data = """
        {
          "id": 43,
          "user_id": 7,
          "symptoms": [29],
          "diagnosis": null,
          "confidence_score": null,
          "risk_level": null,
          "created_at": "2026-05-26T09:00:00Z"
        }
        """.data(using: .utf8)!

        let result = try BaliAPI.decoder.decode(AssessmentResult.self, from: data)

        #expect(result.id == 43)
        #expect(result.diagnosis.isEmpty)
        #expect(result.confidenceScore == 0)
        #expect(result.riskLevel == .low)
        #expect(result.recommendation.isEmpty)
    }

    @Test func decodesIncompleteTravelerProfileAsOptionalFields() throws {
        let data = """
        {
          "id": 9,
          "user_id": 7,
          "nama_lengkap": "Ayu",
          "created_at": "2026-05-26T08:00:00Z",
          "updated_at": "2026-05-26T08:00:00Z"
        }
        """.data(using: .utf8)!

        let profile = try BaliAPI.decoder.decode(TravelerProfile.self, from: data)

        #expect(profile.namaLengkap == "Ayu")
        #expect(profile.tanggalLahir == nil)
        #expect(profile.kontakDarurat == nil)
    }

    @Test func decodesSymptomWhenOnlyIdIsPresent() throws {
        let data = """
        {
          "id": 11,
          "kode": "S_BERKERINGAT",
          "label_id": "Berkeringat berlebihan"
        }
        """.data(using: .utf8)!

        let symptom = try BaliAPI.decoder.decode(Symptom.self, from: data)

        #expect(symptom.id == 11)
        #expect(symptom.symptomID == 11)
        #expect(symptom.displayName == "Berkeringat berlebihan")
    }

    @Test func neverDisplaysRawSymptomCodeAsPrimaryLabel() throws {
        let data = """
        {
          "id": 12,
          "symptom_id": 12,
          "kode": "S_KELEMAHAN",
          "label_id": "S_KELEMAHAN",
          "label_en": "S_KELEMAHAN"
        }
        """.data(using: .utf8)!

        let symptom = try BaliAPI.decoder.decode(Symptom.self, from: data)

        #expect(symptom.primaryDisplayName == "Symptom 12")
        #expect(symptom.secondaryDisplayName == nil)
    }

    @Test func formatsDateOfBirthForSQLWithoutUTCDateShift() throws {
        let baliTimeZone = try #require(TimeZone(identifier: "Asia/Makassar"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = baliTimeZone

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = baliTimeZone
        components.year = 1997
        components.month = 5
        components.day = 31

        let selectedDOB = try #require(calendar.date(from: components))

        #expect(SQLDateFormatter.string(from: selectedDOB, timeZone: baliTimeZone) == "1997-05-31")
    }

    @Test func normalizesServerDateStringsToSQLDateOnly() {
        #expect(SQLDateFormatter.normalizedString(from: "1997-05-31") == "1997-05-31")
        #expect(SQLDateFormatter.normalizedString(from: "1997-05-31T00:00:00Z") == "1997-05-31")
        #expect(SQLDateFormatter.normalizedString(from: " 1997-05-31 ") == "1997-05-31")
    }

    @Test func decodesCachedProfileWithoutEmergencyContact() throws {
        struct LegacyProfile: Encodable {
            let name: String
            let countryCode: String
            let dateOfBirth: Date
            let gender: Gender
        }

        let data = try JSONEncoder().encode(
            LegacyProfile(
                name: "Made",
                countryCode: "ID",
                dateOfBirth: Date(timeIntervalSince1970: 0),
                gender: .male
            )
        )

        let profile = try JSONDecoder().decode(UserProfile.self, from: data)

        #expect(profile.name == "Made")
        #expect(profile.emergencyContact == nil)
    }

}
