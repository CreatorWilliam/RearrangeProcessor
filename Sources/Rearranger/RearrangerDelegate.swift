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
  
  /// Section移动时会进行频繁回调
  /// - Parameter rearranger: 排序处理器
  /// - Parameter source: Section移动的源索引
  /// - Parameter destination: Section移动的目的地索引
  func rearranger(_ rearranger: Rearranger, shouldMoveSectionAt source: Int, to destination: Int?) -> Bool
  
  /// Section移动完成时才会回调
  /// - Parameter rearranger: 排序处理器
  /// - Parameter source: Section移动的源索引
  /// - Parameter destination: Section移动的目的地索引
  func rearranger(_ rearranger: Rearranger, moveSectionFrom source: Int, to destination: Int)
  
  /// Row移动时会进行频繁回调
  /// - Parameter rearranger: 排序处理器
  /// - Parameter source: Row移动的源索引
  /// - Parameter destination: Row移动的目的地索引
  func rearranger(_ rearranger: Rearranger, shouldMoveRowAt source: IndexPath, to destination: IndexPath?) -> Bool
  
  /// Row移动完成时才会回调
  /// - Parameter rearranger: 排序处理器
  /// - Parameter source: Row移动的源索引
  /// - Parameter destination: Row移动的目的地索引
  func rearranger(_ rearranger: Rearranger, moveRowFrom source: IndexPath, to destination: IndexPath)
  
}

// MARK: - RearrangerDelegate Default Implement
public extension RearrangerDelegate {
  
  func rearranger(_ rearranger: Rearranger, willFoldList isFold: Bool) {
    // Nothing
  }
  
  func rearranger(_ rearranger: Rearranger, shouldMoveSectionAt source: Int, to destination: Int?) -> Bool {
    
    return true
  }
  
  func rearranger(_ rearranger: Rearranger, shouldMoveRowAt source: IndexPath, to destination: IndexPath?) -> Bool {
    
    return true
  }
  
}
