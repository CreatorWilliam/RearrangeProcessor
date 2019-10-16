//
//  ReorderProcessor.swift
//
//
//  Created by William Lee on 2019/10/8.
//

import UIKit

public protocol ReorderProcessorDelegate: class {
  
  /// 当需要刷新数据源时进行
  /// - Parameter processor: 排序处理器
  /// - Parameter isFold: 是否折叠列表
  func reorderProcessor(_ processor: ReorderProcessor, willFoldList isFold: Bool)
  
  /// 要移动Section时进行有回调
  /// - Parameter processor: 排序处理器
  /// - Parameter source: 要移动的Section的索引
  //func reorderProcessor(_ processor: ReorderProcessor, shouldMoveSectionAt source: IndexPath) -> Bool
  
  /// 移动Section时才会回调，会频繁调用
  /// - Parameter processor: 排序处理器
  /// - Parameter source: 移动中Section的起始索引
  /// - Parameter destination: 移动中Section的目标索引
  func reorderProcessor(_ processor: ReorderProcessor, moveSectionFrom source: IndexPath, to destination: IndexPath)
  
  /// 要移动Row的时候进行回调
  /// - Parameter processor: 排序处理器
  /// - Parameter source: 要移动行的索引
  //func reorderProcessor(_ processor: ReorderProcessor, shouldMoveRowAt source: IndexPath) -> Bool
  
  /// 移动Row的时候进行回调，会频繁的调用
  /// - Parameter processor: 排序处理器
  /// - Parameter source: 移动中Row的起始索引
  /// - Parameter destination: 移动中Row的目标索引
  func reorderProcessor(_ processor: ReorderProcessor, moveRowFrom source: IndexPath, to destination: IndexPath)
  
}

// MARK: - ReorderProcessorDelegate Default Implement
extension ReorderProcessorDelegate {
  
  //func reorderProcessor(_ processor: ReorderProcessor, shouldMoveSectionAt source: IndexPath) -> Bool { return true }
  
  //func reorderProcessor(_ processor: ReorderProcessor, shouldMoveRowAt source: IndexPath) -> Bool { return true }
  
}

// MARK: - ReorderProcessor
public class ReorderProcessor {
  
  /// 是否在移动Section时折叠所有Section的内容
  //public var isFoldSectionWhenMoveSection: Bool = true
  /// 表示移动第一个Row时，移动Section,
  /// 若设置为true，则代理回调中关于移动行时的索引Row都会+1，
  /// 默认为true
  private var isMoveSectionEnable: Bool = true
  
  /// 表示当前是否正在移动Section
  private var isMovingSection: Bool { return isMoveSectionEnable && sourceIndexPath?.row == 0 }
  
  /// 接收排序事件的代理
  private weak var delegate: ReorderProcessorDelegate!
  /// 要进行排序的列表视图
  private let tableView: UITableView
  /// 用于触发排序的手势
  private let longPressGR = UILongPressGestureRecognizer()
  
  /// 跟随手势移动的缩略图
  private var snapshotView: UIView?
  
  /// 记录移动过程中起始的索引
  private var sourceIndexPath: IndexPath?
  
  
  /// 默认的构造方法
  /// - Parameter tableView: 要进行排序的UITableView
  /// - Parameter delegate: 用于接收排序事件的代理
  public init(_ tableView: UITableView, delegate: ReorderProcessorDelegate) {
    
    self.tableView = tableView
    self.delegate = delegate
    longPressGR.addTarget(self, action: #selector(longPress))
  }
  
}

// MARK: - Public
public extension ReorderProcessor {
  
  func prepare() {
    
    tableView.addGestureRecognizer(longPressGR)
  }
  
}

// MARK: - Action
private extension ReorderProcessor {
  
  @objc func longPress(_ sender: UILongPressGestureRecognizer) {
    
    switch sender.state {
    case .began:
      
      guard let indexPath = tableView.indexPathForRow(at: sender.location(in: tableView)) else { return }
      guard let sourceCell = tableView.cellForRow(at: indexPath) else { return }
      
      sourceIndexPath = indexPath
      
      let snapshotView = generateSnapshotView(for: sourceCell)
      snapshotView.frame = sourceCell.convert(sourceCell.bounds, to: tableView)
      snapshotView.alpha = 0
      self.snapshotView = snapshotView
      tableView.addSubview(snapshotView)
      
      UIView.animate(withDuration: 0.5, animations: {
        
        sourceCell.alpha = 0
        snapshotView.alpha = 1
      })
      
      guard self.isMovingSection == true else { return }
      
      self.delegate.reorderProcessor(self, willFoldList: true)
      self.reload()
      
      
    case .changed:
      
      snapshotView?.center.y = sender.location(in: tableView).y
      
      /// 获取要交换位置及视图
      guard let source = self.sourceIndexPath else {
        print("\(Date()) No Source IndexPath")
        return }
      guard let destination = self.destinationIndexPath else {
        print("\(Date()) No Destination IndexPath")
        return }
      /// 过滤相同的索引
      guard destination != source else {
        print("\(Date()) Destination And Source are same")
        return }
      
      if isMovingSection == true {
        
        moveSection(from: source, to: destination)
        
      } else {
        
        moveRow(from: source, to: destination)
      }
      
    default:
      
      guard let source = sourceIndexPath else { return }
      
      UIView.animate(withDuration: 0.1, animations: {
        
        self.tableView.cellForRow(at: source)?.alpha = 1
        self.snapshotView?.alpha = 0
        
      }, completion: { (_) in
        
        self.snapshotView?.removeFromSuperview()
        self.snapshotView = nil
        self.sourceIndexPath = nil
      })
      
      guard self.isMovingSection == true else { return }
      self.delegate.reorderProcessor(self, willFoldList: false)
      self.reload()
      
    }
  }
  
}

// MARK: - Utility
private extension ReorderProcessor {
  
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
private extension ReorderProcessor {
  
  var destinationIndexPath: IndexPath? {
    
    guard let source = self.sourceIndexPath else { return nil }
    guard let snapshotView = self.snapshotView else { return nil }
    
    /// 优先使用触控点获取目标索引
    if var destinationIndex = tableView.indexPathForRow(at: longPressGR.location(in: tableView)) {
      
      /// 如果是可以移动Section的模式，源行为0，则是移动Section，直接返回索引
      if isMoveSectionEnable == true && source.row == 0 { return destinationIndex }
      
      /// 如果是可以移动Section的模式，源行不为0，目标行为0的时候，则在目标行后插入
      if isMoveSectionEnable == true && destinationIndex.row == 0 {
        
        destinationIndex.row += 1
        return destinationIndex
      }
      
      return destinationIndex
    }
    
    return nil
    
    // 获取首尾两个索引
    let indexPaths = tableView.indexPathsForRows(in: snapshotView.frame)
    guard let firstIndexPath = indexPaths?.first else { return nil }
    guard let lastIndexPath = indexPaths?.last else { return nil }
    
    /// 移动Section时
    if isMovingSection == true {
      
      return lastIndexPath
    }
    
    /// 当不支持移动Section时移动Row
    if isMoveSectionEnable == false {
      
      return lastIndexPath
    }
    
    /// 支持Section移动时移动Row
    if firstIndexPath == lastIndexPath {
      
    }
    
    
    /// 尾索引在源索引之前
    if lastIndexPath < source {
      
      /// 如果目标索引是Section的最后一个Row，则是追加模式
      if tableView.numberOfRows(inSection: lastIndexPath.section) == lastIndexPath.row + 1 {
        
        return IndexPath(row: lastIndexPath.row + 1, section: lastIndexPath.section)
      }
      
      /// 如果不是则是插入模式
      return lastIndexPath
    }
    
    /// 尾索引在源索引之后，首索引在源索引之前
    if firstIndexPath < source {
      
      return firstIndexPath
    }
    
    /// 首索引在源索引之后
    return IndexPath(row: firstIndexPath.row + 1, section: firstIndexPath.section)
  }
  
  func moveSection(from source: IndexPath, to destination: IndexPath) {
    
    delegate?.reorderProcessor(self, moveSectionFrom: source, to: destination)
    tableView.moveSection(source.section, toSection: destination.section)
    
    tableView.cellForRow(at: source)?.alpha = 1
    tableView.cellForRow(at: destination)?.alpha = 0
    self.sourceIndexPath = destination
  }
  
  func moveRow(from source: IndexPath, to destination: IndexPath) {
    
    delegate.reorderProcessor(self, moveRowFrom: source, to: destination)
    tableView.moveRow(at: source, to: destination)
    
    tableView.cellForRow(at: source)?.alpha = 1
    tableView.cellForRow(at: destination)?.alpha = 0
    self.sourceIndexPath = destination
  }
  
}
