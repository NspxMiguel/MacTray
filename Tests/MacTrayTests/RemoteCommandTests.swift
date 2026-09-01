import XCTest
@testable import MacTrayCore

final class RemoteCommandTests: XCTestCase {
    func testFromArgumentsToggle() {
        XCTAssertEqual(RemoteCommand.fromArguments(["MacTray", "--toggle"]), .toggle)
    }

    func testFromArgumentsShowAll() {
        XCTAssertEqual(RemoteCommand.fromArguments(["MacTray", "--show-all"]), .showAll)
    }

    func testFromArgumentsInvalid() {
        XCTAssertNil(RemoteCommand.fromArguments(["MacTray", "--nope"]))
    }

    func testWithArgumentPin() {
        let result = RemoteCommand.withArgument(["MacTray", "--pin", "Docker"])
        XCTAssertEqual(result?.0, .pin)
        XCTAssertEqual(result?.1, "Docker")
    }

    func testLoginItemOn() {
        XCTAssertEqual(LoginItemArgument.value("on"), true)
        XCTAssertEqual(LoginItemArgument.value("yes"), true)
    }

    func testLoginItemOff() {
        XCTAssertEqual(LoginItemArgument.value("off"), false)
        XCTAssertNil(LoginItemArgument.value("maybe"))
    }
}
