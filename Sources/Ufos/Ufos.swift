//  ufos.swift
//  Copyright © 2020 iosdev42. All rights reserved.

import Foundation

@propertyWrapper
public struct Atomic<Value> {
    private var lock = os_unfair_lock()
    private var value: Value

    public var wrappedValue: Value {
        mutating get { mutate { $0 } }
        set { mutate { $0 = newValue } }
    }
    
    public init(wrappedValue: Value) {
        value = wrappedValue
    }
    
    public mutating func mutate<T>(closure: (inout Value) throws -> T) rethrows -> T {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return try closure(&value)
    }
}

public class Signaler<Value> {
    @Atomic private var observers: [UInt64: (Value) -> Void] = [:]
    private var savedValue: Value?
    
    fileprivate init(_ initialValue: Value? = nil) {
        savedValue = initialValue
    }
    
    private func observe<Object: AnyObject, T>(with: Object,
                                               filter: ((Value) -> Bool)?,
                                               queue: DispatchQueue?,
                                               closure: @escaping (Object, T) -> Void,
                                               transform: @escaping (Value) -> T?) {
        let key = DispatchTime.now().uptimeNanoseconds // these keys might collide, after 584.54 years of uptime
        let observer: (Value) -> Void = { [weak self, weak with] value in
            guard let with = with else {
                self?.observers[key] = nil
                return
            }
            guard filter?(value) ?? true else { return }
            guard let value = transform(value) else { return }
            if let queue = queue {
                queue.async { closure(with, value) }
                return
            }
            closure(with, value)
        }
        observers[key] = observer
        if let savedValue = savedValue {
            observer(savedValue)
        }
    }
    /**
     Triggers the callback every time the source produces a value
     - Parameter with: An arbitrary object that limits the observation lifetime
     - Parameter closure: The subscription callback
     */
    public func observe<Object: AnyObject>(with: Object,
                                           filter: ((Value) -> Bool)? = nil,
                                           queue: DispatchQueue? = nil,
                                           closure: @escaping (Object, Value) -> Void) {
        observe(with: with, filter: filter, queue: queue, closure: closure) { $0 }
    }
    /**
     Observes the specified `Equatable` sub-value and triggers the callback when it changes
     - Parameter keyPath: A key path inside `Value` to a contained value type
     - Parameter with: An arbitrary object that limits the observation' lifetime
     - Parameter closure: The subscription callback
     */
    public func observe<Object: AnyObject, T: Equatable>(_ keyPath: KeyPath<Value, T>,
                                                         with: Object,
                                                         filter: ((Value) -> Bool)? = nil,
                                                         queue: DispatchQueue? = nil,
                                                         closure: @escaping (Object, T) -> Void) {
        var previous: T?
        let suppressor: (T?) -> T? = { value in
            defer { previous = value }
            return value == previous ? nil : value
        }
        observe(with: with, filter: filter, queue: queue, closure: closure) { suppressor($0[keyPath: keyPath]) }
    }
    /**
     Sends the event to all observers
     - Parameter value: The Value to send
     */
    fileprivate func send(_ value: Value) {
        if savedValue != nil {
            savedValue = value
        }
        observers.values.forEach { $0(value) }
    }
}

/**
 Observable value container. Use `$` prefix to access the Signaler.
 */
@propertyWrapper
public struct Observed<Value> {
    public let projectedValue: Signaler<Value>
    public var wrappedValue: Value {
        didSet { projectedValue.send(wrappedValue) }
    }
    
    public init(wrappedValue: Value) {
        self.projectedValue = .init(wrappedValue)
        self.wrappedValue = wrappedValue
    }
}

/**
 Observable event broadcaster.
 */
public struct Signal<Value> {
    private let impl = Signaler<Value>()
    
    public init() { }
    /**
     Triggers the callback every time the source produces a value
     - Parameter with: An arbitrary object that limits the observation lifetime
     - Parameter closure: The subscription callback
     */
    public func observe<Object: AnyObject>(with: Object,
                                           filter: ((Value) -> Bool)? = nil,
                                           queue: DispatchQueue? = nil,
                                           closure: @escaping (Object, Value) -> Void) {
        impl.observe(with: with, filter: filter, queue: queue, closure: closure)
    }
    /**
     Observes the specified `Equatable` sub-value and triggers the callback when it changes
     - Parameter keyPath: A key path inside `Value` to a contained value type
     - Parameter with: An arbitrary object that limits the observation' lifetime
     - Parameter closure: The subscription callback
     */
    public func observe<Object: AnyObject, T: Equatable>(_ keyPath: KeyPath<Value, T>,
                                                         with: Object,
                                                         filter: ((Value) -> Bool)? = nil,
                                                         queue: DispatchQueue? = nil,
                                                         closure: @escaping (Object, T) -> Void) {
        impl.observe(keyPath, with: with, filter: filter, queue: queue, closure: closure)
    }
    /**
     Sends the event to all observers
     - Parameter value: The Value to send
     */
    public mutating func send(_ value: Value) {
        impl.send(value)
    }
}

public extension Signal where Value == Void {
    @inline(__always) mutating func send() { send(()) }
}
