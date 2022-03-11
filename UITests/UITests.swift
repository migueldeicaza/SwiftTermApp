//
//  UITests.swift
//  UITests
//
//  Created by Miguel de Icaza on 3/10/22.
//  Copyright © 2022 Miguel de Icaza. All rights reserved.
//

import XCTest

class UITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testAddHost() throws {
        
    }

    //let password = try String (contentsOf: URL (fileURLWithPath: "/Users/miguel/password"))

    func testAddHostLoginPassword() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()
        
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
                
        let tablesQuery = app.tables
        tablesQuery/*@START_MENU_TOKEN@*/.buttons["Hosts"]/*[[".cells[\"Hosts\"].buttons[\"Hosts\"]",".buttons[\"Hosts\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        tablesQuery.cells["Add, Add Host"].children(matching: .other).element(boundBy: 0).children(matching: .other).element.tap()
        let name = tablesQuery/*@START_MENU_TOKEN@*/.textFields["name"]/*[[".cells[\"Alias, name\"].textFields[\"name\"]",".textFields[\"name\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        name.tap()
        name.typeText("dbserver")
        
        tablesQuery/*@START_MENU_TOKEN@*/.textFields["192.168.1.100"]/*[[".cells[\"Host, 192.168.1.100\"].textFields[\"192.168.1.100\"]",".textFields[\"192.168.1.100\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        tablesQuery.textFields["192.168.1.100"].typeText("172.25.2.1")
        tablesQuery/*@START_MENU_TOKEN@*/.textFields["user"]/*[[".cells[\"Username, user\"].textFields[\"user\"]",".textFields[\"user\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        tablesQuery.textFields["user"].typeText("sa")
        tablesQuery/*@START_MENU_TOKEN@*/.secureTextFields["•••••••"]/*[[".cells[\"Password, •••••••, Show\"].secureTextFields[\"•••••••\"]",".secureTextFields[\"•••••••\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.tap()
        tablesQuery/*@START_MENU_TOKEN@*/.secureTextFields["•••••••"]/*[[".cells[\"Password, •••••••, Show\"].secureTextFields[\"•••••••\"]",".secureTextFields[\"•••••••\"]"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/.typeText("pass")
        let port: XCUIElement = tablesQuery.textFields ["22"]
        
        port.doubleTap()
        port.typeText ("2201")
        
        app.navigationBars["_TtGC7SwiftUI19UIHosting"].buttons["Save"].tap()
    }

    func testLogin () {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()
        
        app.tables.buttons["dbserver, 172.25.2.1"].tap()
        
        // Needed when we do not trust yet
        //app.buttons["Yes"].tap()
        
        app.typeText("mc\ncd /usr\n\tcd /usr/bin\n")
        print ("Here")
    }
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}
