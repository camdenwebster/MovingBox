import SQLiteData
import Testing
import UIKit

@testable import MovingBox

// HomeMigrationTests tested SwiftData Home model migration from legacy data to URL-based storage.
// The Home @Model class has been deleted and replaced with SQLiteHome @Table struct.
// SQLiteHome has no `.data` property and no `migrateImageIfNeeded()` method --
// the migration has already been completed. These tests are obsolete.
