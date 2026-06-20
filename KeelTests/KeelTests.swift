//
//  KeelTests.swift
//  KeelTests
//
//  Created by Ngonidzashe  Mangudya on 2026/06/20.
//

import XCTest
@testable import Keel

final class KeelTests: XCTestCase {

    func testMetricSparklineValuesAreDeterministicAndClamped() {
        let seeds = [
            "",
            "none",
            "network-in-none",
            "network-out-none",
            "Cudy_DL6950 (0x17E9:0x6000)",
            "Montr Virtual Display",
            String(repeating: "z", count: 1024)
        ]

        for seed in seeds {
            let values = MetricSparkline.generatedValues(for: seed)

            XCTAssertEqual(values.count, 18)
            XCTAssertEqual(values, MetricSparkline.generatedValues(for: seed))
            XCTAssertTrue(values.allSatisfy { $0 >= 0.08 && $0 <= 1 })
        }
    }

    func testMetricSparklineSupportsEmptyValueSets() {
        XCTAssertEqual(MetricSparkline.generatedValues(for: "container", count: 0), [])
    }

}
