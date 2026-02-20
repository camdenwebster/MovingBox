import XCTest

class ImportScreen {
    let app: XCUIApplication

    let formatPicker: XCUIElement
    let itemsToggle: XCUIElement
    let locationsToggle: XCUIElement
    let labelsToggle: XCUIElement
    let homesToggle: XCUIElement
    let insurancePoliciesToggle: XCUIElement
    let selectFileButton: XCUIElement

    init(app: XCUIApplication) {
        self.app = app
        self.formatPicker = app.otherElements["import-format-picker"]
        // Use descendants to find the actual switch element within the toggle container
        self.itemsToggle =
            app.switches.matching(NSPredicate(format: "identifier == 'import-items-toggle'")).firstMatch
        self.locationsToggle =
            app.switches.matching(NSPredicate(format: "identifier == 'import-locations-toggle'"))
            .firstMatch
        self.labelsToggle =
            app.switches.matching(NSPredicate(format: "identifier == 'import-labels-toggle'")).firstMatch
        self.homesToggle =
            app.switches.matching(NSPredicate(format: "identifier == 'import-homes-toggle'")).firstMatch
        self.insurancePoliciesToggle =
            app.switches.matching(NSPredicate(format: "identifier == 'import-insurance-policies-toggle'"))
            .firstMatch
        self.selectFileButton =
            app.cells.containing(.button, identifier: "import-select-file-button").firstMatch
    }

    func isDisplayed() -> Bool {
        return selectFileButton.waitForExistence(timeout: 5)
            && app.navigationBars.staticTexts["Import Data"].exists
    }

    func tapSelectFileButton() {
        selectFileButton.tap()
    }

    func isFormatPickerVisible() -> Bool {
        formatPicker.waitForExistence(timeout: 5)
    }

    func selectCSVArchiveFormat() {
        formatPicker.tap()
        let option = app.buttons["CSV Archive"].firstMatch
        if option.waitForExistence(timeout: 2) {
            option.tap()
            return
        }
        let fallback = app.staticTexts["CSV Archive"].firstMatch
        if fallback.waitForExistence(timeout: 2) {
            fallback.tap()
        }
    }

    func selectDatabaseFormat() {
        formatPicker.tap()
        let option = app.buttons["MovingBox Database"].firstMatch
        if option.waitForExistence(timeout: 2) {
            option.tap()
            return
        }
        let fallback = app.staticTexts["MovingBox Database"].firstMatch
        if fallback.waitForExistence(timeout: 2) {
            fallback.tap()
        }
    }

    func toggleItems(_ enabled: Bool) {
        let currentValue = itemsToggle.value as? String
        let isCurrentlyOn = currentValue == "1"
        if isCurrentlyOn != enabled {
            itemsToggle.tap()
        }
    }

    func toggleLocations(_ enabled: Bool) {
        let currentValue = locationsToggle.value as? String
        let isCurrentlyOn = currentValue == "1"
        if isCurrentlyOn != enabled {
            locationsToggle.tap()
        }
    }

    func toggleLabels(_ enabled: Bool) {
        let currentValue = labelsToggle.value as? String
        let isCurrentlyOn = currentValue == "1"
        if isCurrentlyOn != enabled {
            labelsToggle.tap()
        }
    }

    func toggleHomes(_ enabled: Bool) {
        let currentValue = homesToggle.value as? String
        let isCurrentlyOn = currentValue == "1"
        if isCurrentlyOn != enabled {
            homesToggle.tap()
        }
    }

    func toggleInsurancePolicies(_ enabled: Bool) {
        let currentValue = insurancePoliciesToggle.value as? String
        let isCurrentlyOn = currentValue == "1"
        if isCurrentlyOn != enabled {
            insurancePoliciesToggle.tap()
        }
    }

    func enableAllOptions() {
        toggleItems(true)
        toggleLocations(true)
        toggleLabels(true)
        toggleHomes(true)
        toggleInsurancePolicies(true)
    }

    func disableAllOptions() {
        toggleItems(false)
        toggleLocations(false)
        toggleLabels(false)
        toggleHomes(false)
        toggleInsurancePolicies(false)
    }

    func selectOnlyItems() {
        disableAllOptions()
        toggleItems(true)
    }

    func selectOnlyLocations() {
        disableAllOptions()
        toggleLocations(true)
    }

    func selectOnlyLabels() {
        disableAllOptions()
        toggleLabels(true)
    }

    func isSelectFileButtonEnabled() -> Bool {
        return selectFileButton.isEnabled
    }

    func isSelectFileButtonDisabled() -> Bool {
        return !selectFileButton.isEnabled
    }

    func waitForDuplicateWarning() -> Bool {
        let alert = app.alerts.matching(NSPredicate(format: "label CONTAINS 'Warning'")).firstMatch
        return alert.waitForExistence(timeout: 5)
    }

    func acceptDuplicateWarning() {
        let continueButton = app.alerts.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 5) {
            continueButton.tap()
        }
    }

    func dismissDuplicateWarning() {
        let cancelButton = app.alerts.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 5) {
            cancelButton.tap()
        }
    }
}
