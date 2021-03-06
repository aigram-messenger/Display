import Foundation
import AsyncDisplayKit

open class GridItemNode: ASDisplayNode {
    open var isVisibleInGrid = false
    open var isGridScrolling = false
    
    final var cachedFrame: CGRect = CGRect()
    override open var frame: CGRect {
        get {
            return self.cachedFrame
        } set(value) {
            self.cachedFrame = value
            super.frame = value
        }
    }
}
