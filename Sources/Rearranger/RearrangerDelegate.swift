//
//  RearrangerDelegate.swift
//  
//
//  Created by William Lee on 2020/5/20.
//

import Foundation

public protocol RearrangerDelegate: class {
  
  /// 移动Section开始和结束时进行回调
  /// - Parameters:
  ///   - rearranger: 排序处理器
  ///   - isFold: 是否折叠
  func rearranger(_ rearranger: Rearranger, willFoldList isFold: Bool)
  
  /// 要移动Section时进行有回调
  /// - Parameter rearranger: 排序处理器
  /// - Parameter source: 要移动的Section的索引
  func rearranger(_ rearranger: Rearranger, shouldMoveSectionAt source: Int) -> Bool
  
  /// 移动Section时才会回调，会频繁调用
  /// - Parameter rearranger: 排序处理器
  /// - Parameter source: 移动中Section的起始索引
  /// - Parameter destination: 移动中Section的目标索引
  func rearranger(_ rearranger: Rearranger, moveSectionFrom source: Int, to destination: Int)
  
  /// 要移动Row的时候进行回调
  /// - Parameter rearranger: 排序处理器
  /// - Parameter source: 要移动行的索引
  func rearranger(_ rearranger: Rearranger, shouldMoveRowAt source: IndexPath) -> Bool
  
  /// 移动Row的时候进行回调，会频繁的调用
  /// - Parameter rearranger: 排序处理器
  /// - Parameter source: 移动中Row的起始索引
  /// - Parameter destination: 移动中Row的目标索引
  func rearranger(_ rearranger: Rearranger, moveRowFrom source: IndexPath, to destination: IndexPath)
  
}

// MARK: - RearrangerDelegate Default Implement
public extension RearrangerDelegate {
  
  func rearranger(_ rearranger: Rearranger, willFoldList isFold: Bool) {
    // Nothing
  }
  
  func rearranger(_ rearranger: Rearranger, shouldMoveSectionAt source: Int) -> Bool {
    
    return true
  }
  
  func rearranger(_ rearranger: Rearranger, shouldMoveRowAt source: IndexPath) -> Bool {
    
    return true
  }
  
}
