import UIKit

class Client {
    let js = JS()
    let reader = Reader()

    var actions: Dictionary<InAction, (Reader) -> ()> = [:]
    var customFunctions: Dictionary<String, (_ args: [Any?]) -> Void> = [:]
    let onDataProcessed = Signal()

    private static let EventNilType = 0
    private static let EventBooleanType = 1
    private static let EventIntegerType = 2
    private static let EventFloatType = 3
    private static let EventStringType = 4

    var outActions: [Int] = []
    private var outActionsIndex = 0
    var outBooleans: [Bool] = []
    private var outBooleansIndex = 0
    var outIntegers: [Int] = []
    private var outIntegersIndex = 0
    var outFloats: [CGFloat] = []
    private var outFloatsIndex = 0
    var outStrings: [String] = []
    private var outStringsIndex = 0

    init() {
        self.js.addHandler("transferData", handler: {
            (message: AnyObject) in
            self.reader.reload(message)
            self.onData(self.reader)
        })

        actions[InAction.callFunction] = { (reader: Reader) in
            let name = reader.getString()
            let function = self.customFunctions[name]

            let argsLength = reader.getInteger()
            var args = [Any?](repeating: nil, count: argsLength)

            for i in 0..<argsLength {
                let argType = reader.getInteger()
                switch argType {
                case Client.EventNilType:
                    break
                case Client.EventBooleanType:
                    args[i] = reader.getBoolean()
                case Client.EventIntegerType:
                    args[i] = Number(reader.getInteger())
                case Client.EventFloatType:
                    args[i] = Number(reader.getFloat())
                case Client.EventStringType:
                    args[i] = reader.getString()
                default:
                    break
                }
            }

            if function != nil {
                function!(args)
            } else {
                print("Native function '\(name)' not found")
            }
        }
    }

    func onData(_ reader: Reader) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        while let action = reader.getAction() {
            let actionFunc = actions[action]
            if actionFunc != nil {
                actionFunc!(reader)
            } else {
                print("Not implemented action '\(action)'")
            }
        }
        sendData()
        onDataProcessed.emit()
    }

    private func pushIntoArray<T>(_ arr: inout [T], index: Int, val: T) {
        if arr.count > index {
            arr[index] = val
        } else {
            arr.append(val)
        }
    }

    func pushAction(_ val: OutAction) {
        pushIntoArray(&outActions, index: outActionsIndex, val: val.rawValue)
        outActionsIndex += 1
    }

    func pushBoolean(_ val: Bool) {
        pushIntoArray(&outBooleans, index: outBooleansIndex, val: val)
        outBooleansIndex += 1
    }

    func pushInteger(_ val: Int) {
        pushIntoArray(&outIntegers, index: outIntegersIndex, val: val)
        outIntegersIndex += 1
    }

    func pushFloat(_ val: CGFloat) {
        pushIntoArray(&outFloats, index: outFloatsIndex, val: val)
        outFloatsIndex += 1
    }

    func pushString(_ val: String) {
        pushIntoArray(&outStrings, index: outStringsIndex, val: val)
        outStringsIndex += 1
    }

    func pushEvent(_ name: String, args: [Any?]?) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        pushAction(OutAction.event)
        pushString(name)
        if args != nil {
            let length = args!.count
            pushInteger(length)
            for arg in args! {
                if arg == nil {
                    pushInteger(Client.EventNilType)
                } else if arg! is Bool {
                    pushInteger(Client.EventBooleanType)
                    pushBoolean(arg as! Bool)
                } else if arg! is Int {
                    pushInteger(Client.EventIntegerType)
                    pushInteger(arg as! Int)
                } else if arg! is CGFloat {
                    pushInteger(Client.EventFloatType)
                    pushFloat(arg as! CGFloat)
                } else if arg! is String {
                    pushInteger(Client.EventStringType)
                    pushString(arg as! String)
                } else {
                    pushInteger(Client.EventNilType)
                    print("Event can be pushed with a nil, Bool, Int, CGFloat or a String, but '\(arg)' given")
                }
            }
        } else {
            pushInteger(0)
        }
    }

    func addCustomFunction(_ name: String, function: @escaping (_ args: [Any?]) -> Void) {
        customFunctions[name] = function
    }

    /**
     Removes all elements after the given length.
     */
    private func cutDataArray<T>(_ arr: inout [T], length: Int) {
        if arr.count > length {
            arr.removeSubrange(length..<arr.count)
        }
    }

    func sendData() {
        guard outActionsIndex > 0 else { return; }

        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        cutDataArray(&outActions, length: outActionsIndex)
        cutDataArray(&outBooleans, length: outBooleansIndex)
        cutDataArray(&outIntegers, length: outIntegersIndex)
        cutDataArray(&outFloats, length: outFloatsIndex)
        cutDataArray(&outStrings, length: outStringsIndex)

        outActionsIndex = 0
        outIntegersIndex = 0
        outFloatsIndex = 0
        outBooleansIndex = 0
        outStringsIndex = 0

        self.js.proxy.dataCallback?.call(
            withArguments: [self.outActions, self.outBooleans, self.outIntegers, self.outFloats, self.outStrings]
        )
    }

    func onAction(_ action: InAction, _ handler: @escaping (Reader) -> Void) {
        App.getApp().client.actions[action] = {
            (reader: Reader) in
            handler(reader)
        }
    }

    func onAction(_ action: InAction, _ handler: @escaping () -> Void) {
        onAction(action) {
            (reader: Reader) in
            handler()
        }
    }

    func pushAction(_ action: OutAction, _ args: [Any]) {
        pushAction(action)
        for arg in args {
            if arg is Bool {
                pushBoolean(arg as! Bool)
            } else if arg is CGFloat {
                pushFloat(arg as! CGFloat)
            } else if arg is Int {
                pushInteger(arg as! Int)
            } else if arg is String {
                pushString(arg as! String)
            } else {
                fatalError("Action can be pushed with Bool, Int, CGFloat or String, but '\(arg)' given")
            }
        }
    }

    func pushAction(_ action: OutAction, _ args: Any...) {
        pushAction(action, args)
    }

    func destroy() {
        actions.removeAll()
        js.destroy()
    }
}
