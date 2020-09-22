import Ufos
import XCTest

struct TestContainer {
    @Observed var property = 5
    @Observed var propertyC = ValueContainer(value1: 3, value2: 9)
    var signal = Signal<Int>()
    var signalC: Signal<ValueContainer> = .init()
    fileprivate(set) var signalVoid = Signal<Void>()
}

class TestObserver { }

struct ValueContainer {
    var value1: Int
    var value2: Int
}

func address<T: AnyObject>(_ o: T) -> Int {
    return unsafeBitCast(o, to: Int.self)
}

final class ufoObservedTests: XCTestCase {
    var container: TestContainer!
    
    override func setUp() {
        container = TestContainer()
    }
    
    func testDirectValueAccess() {
        XCTAssertNoThrow(container.property)
        container.property = 17
        XCTAssertEqual(container.property, 17)
    }
    
    func testFilter() {
        var evens: [Int] = []
        container.$property.observe(with: self, filter: { $0 % 2 == 0 }) { obj, value in
            evens.append(value)
        }
        var fives: [Int] = []
        container.$property.observe(with: self, filter: { $0 % 5 == 0 }) { obj, value in
            fives.append(value)
        }
        var sevens: [Int] = []
        container.$property.observe(with: self, filter: { $0 % 7 == 0 }) { obj, value in
            sevens.append(value)
        }
        let sample = [17, 42, -7, 0, 194]
        sample.forEach { container.property = $0 }
        XCTAssertEqual(evens, [42, 0, 194])
        XCTAssertEqual(fives, [5, 0])
        XCTAssertEqual(sevens, [42, -7, 0])
    }
    
    func testInitialValue() {
        var cachedValue = 0
        container.$property.observe(with: self) { (obj, value) in
            cachedValue = value
        }
        XCTAssertEqual(cachedValue, 5) // @Observed fires immeediatly on .observe
        container.property = 7
        XCTAssertEqual(cachedValue, 7)
        container.$property.observe(with: self) { (obj, value) in
            XCTAssertEqual(value, 7)
        }
    }
    
    func testNotification() {
        var receivedValues: [Int] = []
        container.$property.observe(with: self) { (obj, value) in
            receivedValues.append(value)
        }
        let sample = [17, 42, -7, 0, 194]
        sample.forEach { container.property = $0 }
        XCTAssertEqual(container.property, sample.last)
        XCTAssertEqual(receivedValues, [5] + sample)
    }
    
    func testObservationLifetime() {
        var observer1 = TestObserver()
        var observer2 = TestObserver()
        var receivedValues1: [Int] = []
        var receivedValues2: [Int] = []
        container.$property.observe(with: observer1) { (obj, value) in
            receivedValues1.append(value)
        }
        container.$property.observe(with: observer2) { (obj, value) in
            receivedValues2.append(value)
        }
        container.property = 99
        container.property = -18
        observer1 = TestObserver()
        container.property = 7
        container.property = 15
        observer2 = TestObserver()
        container.property = 12
        XCTAssertEqual(receivedValues1, [5, 99, -18])
        XCTAssertEqual(receivedValues2, [5, 99, -18, 7, 15])
    }
    
    func testValueKeyPath() {
        var values1: [Int] = []
        var values2: [Int] = []
        container.$propertyC.observe(\.value1, with: self) { (obj, value) in
            values1.append(value)
        }
        container.$propertyC.observe(\.value2, with: self) { (obj, value) in
            values2.append(value)
        }
        let sample: [ValueContainer] = [
            .init(value1: 1, value2: 12),
            .init(value1: 1, value2: -8),
            .init(value1: 7, value2: -8),
            .init(value1: 7, value2: -8),
            .init(value1: 3, value2: 17)
        ]
        sample.forEach { container.propertyC = $0 }
        XCTAssertEqual(values1, [3, 1, 7, 3])
        XCTAssertEqual(values2, [9, 12, -8, 17])
    }
}

final class ufoSignalTests: XCTestCase {
    var container: TestContainer!
    
    override func setUp() {
        container = TestContainer()
    }
    
    func testNoObserversOperation() {
        XCTAssertNoThrow(container.signal)
        XCTAssertNoThrow(container.signal.send(5))
    }
    
    func testFilter() {
        var evens: [Int] = []
        var fives: [Int] = []
        var sevens: [Int] = []
        var all: [Int] = []
        container.signal.observe(with: self, filter: { $0 % 2 == 0 }) { obj, value in
            evens.append(value)
        }
        container.signal.observe(with: self, filter: { $0 % 5 == 0 }) { obj, value in
            fives.append(value)
        }
        container.signal.observe(with: self, filter: { $0 % 7 == 0 }) { obj, value in
            sevens.append(value)
        }
        container.signal.observe(with: self) { obj, value in
            all.append(value)
        }
        let sample = [17, 42, -7, 0, 194]
        sample.forEach { container.signal.send($0) }
        XCTAssertEqual(evens, [42, 0, 194])
        XCTAssertEqual(fives, [0])
        XCTAssertEqual(sevens, [42, -7, 0])
        XCTAssertEqual(all, sample)
    }
    
    func testSignalVoid() {
        var fired = false
        container.signalVoid.observe(with: self) { _, _ in
            fired = true
        }
        XCTAssertFalse(fired)  // Signals do not fire until .send is called
        container.signalVoid.send()
        XCTAssertTrue(fired)
    }
    
    func testNotification() {
        var receivedValues: [Int] = []
        container.signal.observe(with: self) { (obj, value) in
            receivedValues.append(value)
        }
        let sample = [17, 42, -7, 0, 194]
        sample.forEach { container.signal.send($0) }
        XCTAssertEqual(receivedValues, sample)
    }
    
    func testObservationLifetime() {
        var observer1 = TestObserver()
        var observer2 = TestObserver()
        var receivedValues1: [Int] = []
        var receivedValues2: [Int] = []
        container.signal.observe(with: observer1) { (obj, value) in
            receivedValues1.append(value)
        }
        container.signal.observe(with: observer2) { (obj, value) in
            receivedValues2.append(value)
        }
        container.signal.send(99)
        container.signal.send(-18)
        observer1 = TestObserver()
        container.signal.send(7)
        container.signal.send(15)
        observer2 = TestObserver()
        container.signal.send(12)
        XCTAssertEqual(receivedValues1, [99, -18])
        XCTAssertEqual(receivedValues2, [99, -18, 7, 15])
    }
    
    func testValueKeyPath() {
        var values1: [Int] = []
        var values2: [Int] = []
        var values3: [Int] = []
        var values4: [Int] = []
        container.signalC.observe(\.value1, with: self) { (obj, value) in
            values1.append(value)
        }
        container.signalC.observe(\.value2, with: self) { (obj, value) in
            values2.append(value)
        }
        container.signalC.observe(\.value1, with: self, filter: { $0.value1 != 7}) { (obj, value) in
            values3.append(value)
        }
        container.signalC.observe(\.value1, with: self, filter: { $0.value1 != 3}) { (obj, value) in
            values4.append(value)
        }
        let sample: [ValueContainer] = [
            .init(value1: 1, value2: 12),
            .init(value1: 1, value2: -8),
            .init(value1: 7, value2: -8),
            .init(value1: 7, value2: -8),
            .init(value1: 3, value2: 17)
        ]
        sample.forEach { container.signalC.send($0) }
        XCTAssertEqual(values1, [1, 7, 3])
        XCTAssertEqual(values2, [12, -8, 17])
        XCTAssertEqual(values3, [1, 3])
        XCTAssertEqual(values4, [1, 7])
    }
    
    func testSelfKeyPath() {
        var receivedValues: [Int] = []
        container.signal.observe(\.self, with: self) { (obj, value) in
            receivedValues.append(value)
        }
        let sample = [4, 4, -7, -7, -7, 5, 3]
        sample.forEach { container.signal.send($0) }
        XCTAssertEqual(receivedValues, [4, -7, 5, 3])
    }
    
    func testUsesCurrentQueueByDefault() {
        let queueLabel = #function
        let labelKey = DispatchSpecificKey<String>()
        let queue = DispatchQueue(label: queueLabel, attributes: DispatchQueue.Attributes.concurrent)
        queue.setSpecific(key: labelKey, value: queueLabel)
        let expectation = self.expectation(description: "testUsesCurrentQueueByDefault")
        container.signal.observe(with: self) { (obj, value) in
            let currentQueueLabel = DispatchQueue.getSpecific(key: labelKey)
            XCTAssertEqual(currentQueueLabel, queueLabel)
            expectation.fulfill()
        }
        queue.async { [weak self] in
            self?.container.signal.send(10)
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testUsesCurrentQueueMain() {
        let queue = DispatchQueue(label: #function, attributes: DispatchQueue.Attributes.concurrent)
        let expectation = self.expectation(description: "testUsesCurrentQueueByDefault")
        container.signal.observe(with: self, queue: DispatchQueue.main) { (obj, value) in
            XCTAssertEqual(OperationQueue.current?.underlyingQueue, DispatchQueue.main)
            expectation.fulfill()
        }
        queue.async { [weak self] in
            self?.container.signal.send(10)
        }
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testListeningOnDispatchQueue() {
        let firstQueueLabel = "com.ufos.queue.first"
        let secondQueueLabel = "com.ufos.queue.second"
        
        let labelKey = DispatchSpecificKey<String>()
        let firstQueue = DispatchQueue(label: firstQueueLabel)
        firstQueue.setSpecific(key: labelKey, value: firstQueueLabel)
        let secondQueue = DispatchQueue(label: secondQueueLabel, attributes: DispatchQueue.Attributes.concurrent)
        secondQueue.setSpecific(key: labelKey, value: secondQueueLabel)
        let firstExpectation = expectation(description: "firstDispatchOnQueue")
        let secondExpectation = expectation(description: "secondDispatchOnQueue")
        
        container.signal.observe(with: self, queue: firstQueue) { (obj, value) in
            let currentQueueLabel = DispatchQueue.getSpecific(key: labelKey)
            XCTAssertEqual(currentQueueLabel, firstQueueLabel)
            firstExpectation.fulfill()
        }
        container.signal.observe(with: self, queue: secondQueue) { (obj, value) in
            let currentQueueLabel = DispatchQueue.getSpecific(key: labelKey)
            XCTAssertEqual(currentQueueLabel, secondQueueLabel)
            secondExpectation.fulfill()
        }
        container.signal.send(10)
        waitForExpectations(timeout: 10.0, handler: nil)
    }
    
    func testLifetimeQueued() {
        var values1: [Int] = []
        var observer1 = TestObserver()
        let labelKey = DispatchSpecificKey<String>()
        let firstQueueLabel = "com.ufos.queue.first"
        let firstQueue = DispatchQueue(label: firstQueueLabel)
        firstQueue.setSpecific(key: labelKey, value: firstQueueLabel)
        let firstExpectation = expectation(description: "firstDispatchOnQueue")
        let observerId = address(observer1)
        container.signal.observe(with: observer1, queue: firstQueue) { (obj, value) in
            let currentQueueLabel = DispatchQueue.getSpecific(key: labelKey)
            XCTAssertEqual(currentQueueLabel, firstQueueLabel)
            XCTAssertNotNil(obj)
            XCTAssertNoThrow(obj)
            XCTAssertEqual(observerId, address(obj))
            values1.append(value)
            firstExpectation.fulfill()
        }
        container.signal.send(12)
        observer1 = TestObserver()
        XCTAssertNotEqual(observerId, address(observer1))
        XCTAssertNotEqual(values1, [12])
        waitForExpectations(timeout: 10.0, handler: nil)
        container.signal.send(13)
        XCTAssertEqual(values1, [12])
    }
    
}
