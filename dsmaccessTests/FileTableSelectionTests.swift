import Foundation
import Testing
@testable import dsmaccess

@MainActor
struct FileTableSelectionTests {
    @Test func rightClickingWithinMultipleSelectionPreservesEveryRow() {
        let selection = KeyboardTableView.contextMenuSelection(
            clickedRow: 3,
            currentSelection: IndexSet(integer: 3),
            selectionBeforeRightMouseDown: IndexSet([1, 3, 4])
        )

        #expect(selection == IndexSet([1, 3, 4]))
    }

    @Test func rightClickingOutsideMultipleSelectionUsesTheClickedRow() {
        let selection = KeyboardTableView.contextMenuSelection(
            clickedRow: 2,
            currentSelection: IndexSet(integer: 2),
            selectionBeforeRightMouseDown: IndexSet([1, 3, 4])
        )

        #expect(selection == IndexSet(integer: 2))
    }
}
