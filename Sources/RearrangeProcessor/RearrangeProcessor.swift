//
//  RearrangeProcessor.swift
//
//
//  Created by William Lee on 2019/10/8.
//

import UIKit

public protocol RearrangeProcessorDelegate: class {
  
  /// 当需要刷新数据源时进行
  /// - Parameter processor: 排序处理器
  /// - Parameter isFold: 是否折叠列表
  func rearrangeProcessor(_ processor: RearrangeProcessor, willFoldList isFold: Bool)
  
  /// 要移动Section时进行有回调
  /// - Parameter processor: 排序处理器
  /// - Parameter source: 要移动的Section的索引
  //func rearrangeProcessor(_ processor: RearrangeProcessor, shouldMoveSectionAt source: IndexPath) -> Bool
  
  /// 移动Section时才会回调，会频繁调用
  /// - Parameter processor: 排序处理器
  /// - Parameter source: 移动中Section的起始索引
  /// - Parameter destination: 移动中Section的目标索引
  func rearrangeProcessor(_ processor: RearrangeProcessor, moveSectionFrom source: IndexPath, to destination: IndexPath)
  
  /// 要移动Row的时候进行回调
  /// - Parameter processor: 排序处理器
  /// - Parameter source: 要移动行的索引
  //func rearrangeProcessor(_ processor: RearrangeProcessor, shouldMoveRowAt source: IndexPath) -> Bool
  
  /// 移动Row的时候进行回调，会频繁的调用
  /// - Parameter processor: 排序处理器
  /// - Parameter source: 移动中Row的起始索引
  /// - Parameter destination: 移动中Row的目标索引
  func rearrangeProcessor(_ processor: RearrangeProcessor, moveRowFrom source: IndexPath, to destination: IndexPath)
  
}

// MARK: - RearrangeProcessor
public class RearrangeProcessor {
  
  /// 是否可以进行重新排列，默认为false
  public var isEnable: Bool = false { didSet { isEnable ? enable() : disable() } }
  
  /// 表示移动第一个Row时，移动Section,
  /// 若设置为true，则代理回调中关于移动行时的索引Row都会+1，
  /// 默认为true
  public var isMoveSectionEnable: Bool = true
  
  /// 接收排序事件的代理
  private weak var delegate: RearrangeProcessorDelegate!
  /// 要进行排序的列表视图
  private let tableView: UITableView
  /// 用于触发排序的手势
  private let longPressGR = UILongPressGestureRecognizer()
  
  /// 跟随手势移动的缩略图
  private var snapshotView: UIView?
  
  /// 记录移动过程中起始的索引
  private var sourceIndexPath: IndexPath?
  
  private var isScrolling: Bool = false
  private var scrollTimer: Timer?
  
  /// 默认的构造方法
  /// - Parameter tableView: 要进行排序的UITableView
  /// - Parameter delegate: 用于接收排序事件的代理
  public init(_ tableView: UITableView, delegate: RearrangeProcessorDelegate) {
    
    self.tableView = tableView
    self.delegate = delegate
    longPressGR.addTarget(self, action: #selector(longPress))
  }
  
}

// MARK: - Public
public extension RearrangeProcessor {
  
}

// MARK: - GestureRecognizer
private extension RearrangeProcessor {
  
  @objc func longPress(_ sender: UILongPressGestureRecognizer) {
    
    switch sender.state {
    case .began:
      
      startTimer()
      
      sourceIndexPath = nil
      
      /// 根据手势在TableView位置获取对应的索引
      guard let indexPath = tableView.indexPathForRow(at: sender.location(in: tableView)) else { return }
      /// 根据索引获取要移动的Cell
      guard let sourceCell = tableView.cellForRow(at: indexPath) else { return }
      /// 获取TableView的window，作为快照视图的载体
      guard let window = tableView.window else { return }
      
      sourceIndexPath = indexPath
      
      /// 生成要移动Cell的快照，并添加到载体上
      let snapshotView = generateSnapshotView(for: sourceCell)
      snapshotView.frame = sourceCell.convert(sourceCell.bounds, to: window)
      snapshotView.alpha = 0
      self.snapshotView = snapshotView
      window.addSubview(snapshotView)
      
      /// 生成要待移动Cell浮起的动画
      UIView.animate(withDuration: 0.1, animations: {
        
        sourceCell.alpha = 0
        snapshotView.alpha = 1
      })
      
      /// 若是移动Section，则折叠列表刷新界面
      guard isMovingSection == true else { return }
      delegate.rearrangeProcessor(self, willFoldList: true)
      reload()
      
    case .changed:
      
      /// 获取快照视图的载体
      guard let window = tableView.window else { return }
      
      snapshotView?.center.y = longPressGR.location(in: window).y
      
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
      
    case .ended:
      
      stopTimer()
      
      /// 获取要交换位置
      guard let source = sourceIndexPath else { return }
      guard let destination = destinationIndexPath else { return }
      /// 过滤相同的索引
//      guard destination != source else { return }

      if isMovingSection == true {

        moveSection(from: source, to: destination)

      } else {

        moveRow(from: source, to: destination)
      }
      
      /// 移动完成后，生成移动Cell下沉的动画
      UIView.animate(withDuration: 0.1, animations: {
        
        self.tableView.cellForRow(at: destination)?.alpha = 1
        self.snapshotView?.alpha = 0
        
      }, completion: { (_) in
        
        self.snapshotView?.removeFromSuperview()
        self.snapshotView = nil
        self.sourceIndexPath = nil
      })
      
      /// 若是移动Section，则展开列表刷新界面
      guard isMovingSection == true else { return }
      delegate.rearrangeProcessor(self, willFoldList: false)
      reload()
      
    default:
      stopTimer()
    }
  }
  
}

// MARK: - Timer
private extension RearrangeProcessor {
  
  func startTimer() {
    
    if scrollTimer != nil { scrollTimer?.invalidate() }
    let timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(loop(_:)), userInfo: nil, repeats: true)
    scrollTimer = timer
  }
  
  func stopTimer() {
    
    scrollTimer?.invalidate()
    scrollTimer = nil
  }
  
  @objc func loop(_ timer: Timer) {
    
    guard let window = tableView.window else { return }
    guard let snapshotView = self.snapshotView else { return }
    
    /// 获取可移动范围
    var movableRect: CGRect = .zero
    movableRect.origin.y = tableView.contentOffset.y
    movableRect.size = tableView.bounds.size
    if movableRect.size.height > tableView.contentSize.height {
      movableRect.size.height = tableView.contentSize.height
    }
    
    /// 获取快照在window中的区域
    let frame = snapshotView.frame
    /// 获取TableView在window中区域
    var bound = window.convert(tableView.frame, to: window)
    if bound.height > tableView.contentSize.height {
         bound.size.height = tableView.contentSize.height
       }
    
    /// 在上边界触发滑动范围内
    if frame.minY - 5 <= bound.minY {
      
      /// 保证快照距离上边界保留5个点的空隙
      snapshotView.frame.origin.y = bound.minY + 5
      
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
      /// 保证快照距离下边界保留5个点的空隙
      snapshotView.frame.origin.y = bound.maxY - 5 - frame.height
      
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

// MARK: - Utility
private extension RearrangeProcessor {
  
  func enable() {
    
    tableView.addGestureRecognizer(longPressGR)
  }
  
  func disable() {
    
    tableView.removeGestureRecognizer(longPressGR)
  }
  
  func reload() {
    
    tableView.reloadSections(IndexSet(integersIn: 0..<tableView.numberOfSections), with: .automatic)
  }
  
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
private extension RearrangeProcessor {
  
  /// 表示当前是否正在移动Section
  var isMovingSection: Bool { return isMoveSectionEnable && (sourceIndexPath?.row == 0) }
  
  var destinationIndexPath: IndexPath? {
    
    if sourceIndexPath == nil { return nil }
    return isMovingSection ? sectionDestinationIndexPath : rowDestinationIndexPath
  }
  
  var sectionDestinationIndexPath: IndexPath? {
    
    return tableView.indexPathForRow(at: longPressGR.location(in: tableView))
  }
  
  var rowDestinationIndexPath: IndexPath? {
    
    guard let source = self.sourceIndexPath else { return nil }
    guard let snapshotView = self.snapshotView else { return nil }
    
    /// 如果移动Row的模式
    /// 先根据触控点获取目标索引
    if var destinationIndex = tableView.indexPathForRow(at: longPressGR.location(in: tableView)) {
      
      /// 如果是可以移动Section的模式，源行不为0，目标行为0的时候，不执行任何移动
      if isMoveSectionEnable == true && destinationIndex.row == 0 {
        
        destinationIndex.row += 1
        return destinationIndex
      }
      
      return destinationIndex
    }
    
    // 当使用触控点获取不到索引时(移动到Header或者Footer的时候)，使用区域获取索引
    let indexPaths = tableView.indexPathsForRows(in: snapshotView.frame)
    guard var firstIndexPath = indexPaths?.first else { return nil }
    guard firstIndexPath < source else { return nil }
    
    firstIndexPath.row += 1
    return firstIndexPath
  }
  
  func moveSection(from source: IndexPath, to destination: IndexPath) {
    
    delegate?.rearrangeProcessor(self, moveSectionFrom: source, to: destination)
    tableView.moveSection(source.section, toSection: destination.section)
    
    tableView.cellForRow(at: source)?.alpha = 1
    tableView.cellForRow(at: destination)?.alpha = 0
    sourceIndexPath = destination
  }
  
  func moveRow(from source: IndexPath, to destination: IndexPath) {
    
    delegate.rearrangeProcessor(self, moveRowFrom: source, to: destination)
    tableView.moveRow(at: source, to: destination)
    
    tableView.cellForRow(at: source)?.alpha = 1
    tableView.cellForRow(at: destination)?.alpha = 0
    sourceIndexPath = destination
  }
  
}
