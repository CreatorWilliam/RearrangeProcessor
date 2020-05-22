//
//  Rearranger.swift
//
//
//  Created by William Lee on 2019/10/8.
//

import UIKit

// MARK: - Rearranger
public class Rearranger {
  
  /// 是否可以进行重新排列，默认为false
  public var isEnable: Bool = false { didSet { isEnable ? enable() : disable() } }
  /// TODO：表示是否强制移动第一个Row时，移动Section，当row所在的section只有一个Row时，也会触发移动Section
  private var isForceMoveSectionWhenMoveFirstRow: Bool = false
  
  
  /// 接收排序事件的代理
  private weak var delegate: RearrangerDelegate?
  /// 要进行排序的列表视图
  private let tableView: UITableView
  /// 用于触发排序的手势
  private let longPressGR = UILongPressGestureRecognizer()
  
  
  /// 跟随手势移动的快照
  private var snapshotView: UIView?
  /// 记录移动过程中起始的索引
  private var sourceIndexPath: IndexPath?
  
  
  /// 表示是否正在滚动
  private var isScrolling: Bool = false
  /// 用于持续滚动
  private var scrollTimer: Timer?
  
  /// 默认的构造方法
  /// - Parameter tableView: 要进行排序的UITableView
  /// - Parameter delegate: 用于接收排序事件的代理
  public init(_ tableView: UITableView, delegate: RearrangerDelegate) {
    
    self.tableView = tableView
    self.delegate = delegate
    longPressGR.addTarget(self, action: #selector(longPress))
  }
  
}

// MARK: - Public
public extension Rearranger {
  
}

// MARK: - GestureRecognizer
private extension Rearranger {
  
  @objc func longPress(_ sender: UILongPressGestureRecognizer) {
    
    switch sender.state {
      
    case .began: startMove()
      
    case .changed: move()
      
    default: endMove()
    }
    
  }
  
  func startMove() {
    
    startTimer()
    
    sourceIndexPath = nil
    
    /// 配置快照
    setupSnapshot()
    
    /// 待移动视图浮起的动画
    UIView.animate(withDuration: 0.1, animations: {
      
      self.sourceView?.alpha = 0
      self.snapshotView?.alpha = 1
    })
    
  }
  
  func move() {
    
    /// 更新快照位置
    updateSnapshotViewPosition()
    
    /// 如果正在滚动，则不进行交换
    guard isScrolling == false else { return }
    
    /// 获取要交换位置
    guard let source = sourceIndexPath else { return }
    guard let destination = destinationIndexPath else { return }
    /// 过滤相同的索引
    guard destination != source else { return }
    
    if isMovingSection == true {
      
       moveSection(from: source, to: destination)
      
    } else {
      
      moveRow(from: source, to: destination)
    }
    
    sourceView?.alpha = 0
  }
  
  func endMove() {
    
    stopTimer()
    
    /// 获取要交换位置
    guard let source = sourceIndexPath else { return }
    guard let destination = destinationIndexPath else {
      
      self.sourceView?.alpha = 1
      self.snapshotView?.removeFromSuperview()
      self.snapshotView = nil
      self.sourceIndexPath = nil
      return
    }
    
    if isMovingSection == true {
      
      moveSection(from: source, to: destination)
      
    } else {
      
      moveRow(from: source, to: destination)
    }
    
    /// 移动完成后，生成移动Cell下沉的动画
    UIView.animate(withDuration: 0.1, animations: {
      
      self.sourceView?.alpha = 1
      self.snapshotView?.alpha = 0
      
    }, completion: { (_) in
      
      self.snapshotView?.removeFromSuperview()
      self.snapshotView = nil
      self.sourceIndexPath = nil
    })
  }
  
}

// MARK: - Timer
private extension Rearranger {
  
  func startTimer() {
    
    if scrollTimer != nil { scrollTimer?.invalidate() }
    let timer = Timer.scheduledTimer(timeInterval: 0.01,
                                     target: self,
                                     selector: #selector(scroll),
                                     userInfo: nil,
                                     repeats: true)
    scrollTimer = timer
  }
  
  func stopTimer() {
    
    scrollTimer?.invalidate()
    scrollTimer = nil
  }
  
  @objc func scroll(_ timer: Timer) {
    
    guard let window = tableView.window else { return }
    guard let snapshotView = self.snapshotView else { return }
    
    /// 更新快照的位置
    updateSnapshotViewPosition()
    
    /// 获取快照在window中的区域
    let frame = snapshotView.frame
    /// 获取TableView在window中区域
    let bound = window.convert(tableView.frame, to: window)
    /// 在内容太少的情况下，不会触发滚动
    if tableView.contentSize.height < tableView.bounds.height {
      
      isScrolling = false
      return
    }
    
    /// 在上边界触发滑动范围内
    if frame.minY - 5 <= bound.minY {
      
      /// 向下滑动
      var offsetY = tableView.contentOffset.y
      offsetY -= 3
      if offsetY < 0 {
        offsetY = 0
      }
      tableView.contentOffset.y = offsetY
      
      isScrolling = true
      
      return
    }
    
    /// 在下边界触发滑动范围内
    if frame.maxY + 5 >= bound.maxY {
      
      /// 向上滑动
      var offsetY = tableView.contentOffset.y
      offsetY += 3
      if offsetY > (tableView.contentSize.height - tableView.bounds.height) {
        offsetY = tableView.contentSize.height - tableView.bounds.height
      }
      tableView.contentOffset.y = offsetY
      
      isScrolling = true
      
      return
    }
    
    isScrolling = false
  }
  
}

// MARK: - Snapshot
private extension Rearranger {
  
  /// 配置快照
  func setupSnapshot() {
    
    /// 清除可能未移除的视图
    snapshotView?.removeFromSuperview()
    snapshotView = nil
    
    /// 根据手势在TableView位置获取对应的索引
    guard let indexPath = tableView.indexPathForRow(at: longPressGR.location(in: tableView)) else { return }
    
    /// 询问代理是否可以移动该行
    guard delegate?.rearranger(self, shouldMoveSectionAt: indexPath.section) == true else { return }
    guard delegate?.rearranger(self, shouldMoveRowAt: indexPath) == true else { return }
    
    /// 根据索引获取要移动的Cell
    guard let sourceCell = tableView.cellForRow(at: indexPath) else { return }
    /// 获取TableView的window，作为快照视图的载体
    guard let window = tableView.window else { return }
    
    /// 保存索引
    sourceIndexPath = indexPath
    
    
    /// 生成要移动Cell的快照，并添加到载体上
    let snapshotView = generateSnapshotView(for: sourceCell)
    snapshotView.frame = sourceCell.convert(sourceCell.bounds, to: window)
    snapshotView.alpha = 0
    self.snapshotView = snapshotView
    window.addSubview(snapshotView)
  }
  
  /// 更新快照位置
  func updateSnapshotViewPosition() {
    
    guard let window = tableView.window else { return }
    guard let snapshotView = self.snapshotView else { return }
    
    /// 获取快照在window中的区域
    var frame = snapshotView.frame
    frame.origin.y = longPressGR.location(in: window).y - frame.height / 2
    /// 获取TableView在window中区域
    let bound = window.convert(tableView.frame, to: window)
    
    if frame.minY - 5 <= bound.minY {
      /// 保证快照距离上边界保留5个点的空隙
      frame.origin.y = bound.minY + 5
    }
    
    if frame.maxY + 5 >= bound.maxY {
      /// 保证快照距离下边界保留5个点的空隙
      frame.origin.y = bound.maxY - 5 - frame.height
    }
    
    snapshotView.frame = frame
  }
  
}

// MARK: - Utility
private extension Rearranger {
  
  func enable() {
    
    tableView.addGestureRecognizer(longPressGR)
  }
  
  func disable() {
    
    tableView.removeGestureRecognizer(longPressGR)
  }
  
  /// 生成快照
  func generateSnapshotView(for view: UIView) -> UIView {
    
    UIGraphicsBeginImageContext(view.bounds.size)
    let context = UIGraphicsGetCurrentContext()
    view.layer.render(in: context!)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    let imageView = UIImageView()
    imageView.image = image
    
    imageView.layer.masksToBounds = false
    imageView.layer.cornerRadius = 0
    imageView.layer.shadowOffset = CGSize(width: -5, height: 0)
    imageView.layer.shadowRadius = 5
    imageView.layer.shadowOpacity = 0.4
    
    return imageView
  }
  
}

// MARK: - Move
private extension Rearranger {
  
  /// 源视图，要移动的Row或者Section
  var sourceView: UIView? {
    
    guard let indexPath = sourceIndexPath else { return nil }
    return tableView.cellForRow(at: indexPath)
  }
  
  /// 表示当前是否正在移动Section
  var isMovingSection: Bool {
    ///
    guard let index = sourceIndexPath?.section else { return false }
    
    /// 如果强制表示移动首行就移动Section，则只要移动首行，就是表示移动Section
    if isForceMoveSectionWhenMoveFirstRow == true {
      
      return sourceIndexPath?.row == 0
    }
    
    /// 如果不是强制的，则根据Section的Row个数是否为1表示是否移动Section
    return tableView.numberOfRows(inSection: index) == 1
  }
  
  var destinationIndexPath: IndexPath? {
    
    guard let source = self.sourceIndexPath else { return nil }
    guard let snapshotView = self.snapshotView else { return nil }
    
    /// 若果是移动Section
    if isMovingSection {
      
      return tableView.indexPathForRow(at: longPressGR.location(in: tableView))
    }
    
    /// 如果不是移动Section
    /// 先根据触控点获取目标索引
    if let destinationIndex = tableView.indexPathForRow(at: longPressGR.location(in: tableView)) {
      
      return destinationIndex
    }
    
    // 当使用触控点获取不到索引时(移动到Header或者Footer的时候)，使用区域获取索引
    let frameOfSnapshotInTable: CGRect = snapshotView.superview?.convert(snapshotView.frame, to: tableView) ?? .zero
    let indexPaths = tableView.indexPathsForRows(in: frameOfSnapshotInTable)
    
    guard var firstIndexPath = indexPaths?.first else { return nil }
    if firstIndexPath.section < source.section {
      firstIndexPath.row += 1
      return firstIndexPath
    }
    
    guard let lastIndexPath = indexPaths?.last else { return nil }
    return lastIndexPath
  }
  
  func moveSection(from source: IndexPath, to destination: IndexPath) {
    
    guard delegate?.rearranger(self, shouldMoveSectionAt: destination.section) == true else { return }
    
    delegate?.rearranger(self, moveSectionFrom: source.section, to: destination.section)
    tableView.moveSection(source.section, toSection: destination.section)
    
    sourceIndexPath = destination
  }
  
  func moveRow(from source: IndexPath, to destination: IndexPath) {
    
    guard delegate?.rearranger(self, shouldMoveSectionAt: destination.section) == true else { return }
    guard delegate?.rearranger(self, shouldMoveRowAt: destination) == true else { return }
    
    delegate?.rearranger(self, moveRowFrom: source, to: destination)
    tableView.moveRow(at: source, to: destination)
    
    sourceIndexPath = destination
  }
  
}
