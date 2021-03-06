import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public final class TabBarControllerTheme {
    public let backgroundColor: UIColor
    public let tabBarBackgroundColor: UIColor
    public let tabBarSeparatorColor: UIColor
    public let tabBarTextColor: UIColor
    public let tabBarSelectedTextColor: UIColor
    public let tabBarBadgeBackgroundColor: UIColor
    public let tabBarBadgeStrokeColor: UIColor
    public let tabBarBadgeTextColor: UIColor
    
    public init(backgroundColor: UIColor, tabBarBackgroundColor: UIColor, tabBarSeparatorColor: UIColor, tabBarTextColor: UIColor, tabBarSelectedTextColor: UIColor, tabBarBadgeBackgroundColor: UIColor, tabBarBadgeStrokeColor: UIColor, tabBarBadgeTextColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.tabBarBackgroundColor = tabBarBackgroundColor
        self.tabBarSeparatorColor = tabBarSeparatorColor
        self.tabBarTextColor = tabBarTextColor
        self.tabBarSelectedTextColor = tabBarSelectedTextColor
        self.tabBarBadgeBackgroundColor = tabBarBadgeBackgroundColor
        self.tabBarBadgeStrokeColor = tabBarBadgeStrokeColor
        self.tabBarBadgeTextColor = tabBarBadgeTextColor
    }
}

open class TabBarController: ViewController {
    private var validLayout: ContainerViewLayout?
    
    private var tabBarControllerNode: TabBarControllerNode {
        get {
            return super.displayNode as! TabBarControllerNode
        }
    }
    
    public private(set) var controllers: [ViewController] = []
    
    private var _selectedIndex: Int?
    public var selectedIndex: Int {
        get {
            if let _selectedIndex = self._selectedIndex {
                return _selectedIndex
            } else {
                return 0
            }
        } set(value) {
            let index = max(0, min(self.controllers.count - 1, value))
            if _selectedIndex != index {
                _selectedIndex = index
                
                self.updateSelectedIndex()
            }
        }
    }
    
    var currentController: ViewController?
    
    private let pendingControllerDisposable = MetaDisposable()
    
    private var theme: TabBarControllerTheme
    
    public init(navigationBarPresentationData: NavigationBarPresentationData, theme: TabBarControllerTheme) {
        self.theme = theme
        
        super.init(navigationBarPresentationData: navigationBarPresentationData)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.pendingControllerDisposable.dispose()
    }
    
    public func updateTheme(navigationBarPresentationData: NavigationBarPresentationData, theme: TabBarControllerTheme) {
        self.navigationBar?.updatePresentationData(navigationBarPresentationData)
        if self.theme !== theme {
            self.theme = theme
            if self.isNodeLoaded {
                self.tabBarControllerNode.updateTheme(theme)
            }
        }
    }
    
    private var debugTapCounter: (Double, Int) = (0.0, 0)
    
    override open func loadDisplayNode() {
        self.displayNode = TabBarControllerNode(theme: self.theme, itemSelected: { [weak self] index, longTap in
            if let strongSelf = self {
                if strongSelf.selectedIndex == index {
                    let timestamp = CACurrentMediaTime()
                    if strongSelf.debugTapCounter.0 < timestamp - 0.4 {
                        strongSelf.debugTapCounter.0 = timestamp
                        strongSelf.debugTapCounter.1 = 0
                    }
                        
                    if strongSelf.debugTapCounter.0 >= timestamp - 0.4 {
                        strongSelf.debugTapCounter.0 = timestamp
                        strongSelf.debugTapCounter.1 += 1
                    }
                    
                    if strongSelf.debugTapCounter.1 >= 10 {
                        strongSelf.debugTapCounter.1 = 0
                        
                        strongSelf.controllers[index].tabBarItemDebugTapAction?()
                    }
                }
                if let validLayout = strongSelf.validLayout {
                    strongSelf.controllers[index].containerLayoutUpdated(validLayout.addedInsets(insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 49.0, right: 0.0)), transition: .immediate)
                }
                strongSelf.pendingControllerDisposable.set((strongSelf.controllers[index].ready.get()
                |> deliverOnMainQueue).start(next: { _ in
                    if let strongSelf = self {
                        if strongSelf.selectedIndex == index {
                            if let controller = strongSelf.currentController {
                                if longTap {
                                    controller.longTapWithTabBar?()
                                } else {
                                    controller.scrollToTopWithTabBar?()
                                }
                            }
                        } else {
                            strongSelf.selectedIndex = index
                        }
                    }
                }))
            }
        })
        
        self.updateSelectedIndex()
        self.displayNodeDidLoad()
    }
    
    private func updateSelectedIndex() {
        if !self.isNodeLoaded {
            return
        }
        
        self.tabBarControllerNode.tabBarNode.selectedIndex = self.selectedIndex
        
        if let currentController = self.currentController {
            currentController.willMove(toParentViewController: nil)
            self.tabBarControllerNode.currentControllerView = nil
            currentController.removeFromParentViewController()
            currentController.didMove(toParentViewController: nil)
            
            self.currentController = nil
        }
        
        if let _selectedIndex = self._selectedIndex, _selectedIndex < self.controllers.count {
            self.currentController = self.controllers[_selectedIndex]
        }
        
        var displayNavigationBar = false
        if let currentController = self.currentController {
            currentController.willMove(toParentViewController: self)
            if let validLayout = self.validLayout {
                currentController.containerLayoutUpdated(validLayout.addedInsets(insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 49.0, right: 0.0)), transition: .immediate)
            }
            self.tabBarControllerNode.currentControllerView = currentController.view
            currentController.navigationBar?.isHidden = true
            self.addChildViewController(currentController)
            currentController.didMove(toParentViewController: self)
            
            currentController.navigationBar?.layoutSuspended = true
            currentController.navigationItem.setTarget(self.navigationItem)
            displayNavigationBar = currentController.displayNavigationBar
            currentController.displayNode.recursivelyEnsureDisplaySynchronously(true)
            self.statusBar.statusBarStyle = currentController.statusBar.statusBarStyle
        } else {
            self.navigationItem.title = nil
            self.navigationItem.leftBarButtonItem = nil
            self.navigationItem.rightBarButtonItem = nil
            self.navigationItem.titleView = nil
            self.navigationItem.backBarButtonItem = nil
            displayNavigationBar = false
        }
        if self.displayNavigationBar != displayNavigationBar {
            self.setDisplayNavigationBar(displayNavigationBar)
        }
        
        if let validLayout = self.validLayout {
            self.tabBarControllerNode.containerLayoutUpdated(validLayout, transition: .immediate)
        }
    }
    
    override open func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        
        self.tabBarControllerNode.containerLayoutUpdated(layout, transition: transition)
        
        if let currentController = self.currentController {
            currentController.view.frame = CGRect(origin: CGPoint(), size: layout.size)
            
            currentController.containerLayoutUpdated(layout.addedInsets(insets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 49.0, right: 0.0)), transition: transition)
        }
    }
    
    override open func navigationStackConfigurationUpdated(next: [ViewController]) {
        super.navigationStackConfigurationUpdated(next: next)
        for controller in self.controllers {
            controller.navigationStackConfigurationUpdated(next: next)
        }
    }
    
    override open func viewWillAppear(_ animated: Bool) {
        if let currentController = self.currentController {
            currentController.viewWillAppear(animated)
        }
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        if let currentController = self.currentController {
            currentController.viewDidAppear(animated)
        }
    }
    
    override open func viewDidDisappear(_ animated: Bool) {
        if let currentController = self.currentController {
            currentController.viewDidDisappear(animated)
        }
    }
    
    public func setControllers(_ controllers: [ViewController], selectedIndex: Int?) {
        var updatedSelectedIndex: Int? = selectedIndex
        if updatedSelectedIndex == nil, let selectedIndex = self._selectedIndex, selectedIndex < self.controllers.count {
            if let index = controllers.index(where: { $0 === self.controllers[selectedIndex] }) {
                updatedSelectedIndex = index
            } else {
                updatedSelectedIndex = 0
            }
        }
        self.controllers = controllers
        self.tabBarControllerNode.tabBarNode.tabBarItems = self.controllers.map({ $0.tabBarItem })
        
        if let updatedSelectedIndex = updatedSelectedIndex {
            self.selectedIndex = updatedSelectedIndex
            self.updateSelectedIndex()
        }
    }
}
