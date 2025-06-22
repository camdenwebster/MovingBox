//
//  run-unit-tests.md
//  MovingBox
//
//  Created by Camden Webster on 6/22/25.
//

Use the following command to run unit tests:
xcodebuild test -project MovingBox.xcodeproj -scheme MovingBoxTests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

Fix any tests if they fail. Do not modify the main app code - only the unit tests (unit test files exist under the MovingBoxTests/ directory.)

Use the modern Swift Testing framework for all unit tests - do not use XCTest. More details can be found in the Apple Developer documentation: https://developer.apple.com/documentation/testing/
