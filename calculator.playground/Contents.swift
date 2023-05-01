import Cocoa
import Foundation

public enum Associativity {
    case left, right, none
}
public struct Operator<T: Numeric> {
    public let precedence: Int
    public let associativity: Associativity
    private let function: (T, T) throws -> T
    
    public init(precedence: Int, associativity: Associativity, function: @escaping (T, T) -> T) {
        self.precedence = precedence
        self.associativity = associativity
        self.function = function
    }
    
    public func apply(_ lhs: T, _ rhs: T) throws -> T {
        try self.function(lhs, rhs)
    }
}

struct Expression {
    var token: String
    var args = Array<Expression>();
    
    init(token: String){
        self.token = token
    }
    
    init(token: String, expr: Expression){
        self.token = token
        self.args.insert(expr, at: 0)
    }
    
    init(token: String, expr1: Expression, expr2: Expression) {
        self.token = token
        self.args.insert(expr1, at: 0)
        self.args.insert(expr2, at: 1)
    }
}

struct Parser<T: Numeric>{
    var input: String
    var stringIndex: String.Index
    var operators: Dictionary<String, Operator<T>>
    
    init(input: String, operators: Dictionary<String, Operator<T>>) {
        self.input = input
        self.operators = operators
        self.stringIndex = input.startIndex
    }
    
    mutating func skip_ws() {
        while input.indices.contains(stringIndex) && input[stringIndex] == " " {
            stringIndex = input.index(after: stringIndex)
        }
    }
    
    mutating func parse_token() -> String {
        skip_ws()
        if input.indices.contains(stringIndex) && input[stringIndex].isWholeNumber {
            var number: String = ""
            while input.indices.contains(stringIndex) && (input[stringIndex].isWholeNumber || input[stringIndex] == ".") {
                number += String(input[stringIndex])
                stringIndex = input.index(after: stringIndex)
            }
            return number
        }
        if input.indices.contains(stringIndex) && (input[stringIndex] == "(" || input[stringIndex] == ")") {
            let token: String = String(input[stringIndex])
            stringIndex = input.index(after: stringIndex)
            return token
        }
        for (token, _) in operators {
            let endIndex: String.Index? = input.index(stringIndex, offsetBy: token.count, limitedBy: input.endIndex)
            if let endIndex, input.indices.contains(endIndex) && input[stringIndex..<endIndex] == token {
                stringIndex = endIndex;
                return token
            }
        }
        
        return ""
    }
    
    mutating func parse_simple_expression() -> Expression {
        let token: String = parse_token();
        if token == "(" {
            var result: Expression = parse()
            assert(parse_token() == ")")
            return result
        }
        if token[token.startIndex].isWholeNumber {
            return Expression(token: token)
        }
        return Expression(token: token, expr: parse_simple_expression())
    }
    
    func get_precedence(binary_op: String) -> Int {
        for (token, operation) in operators {
            if(token == binary_op){
                return operation.precedence
            }
        }
        return 0
    }
    
    mutating func parse_binary_expression(min_priority: Int) -> Expression {
        var left_expression : Expression = parse_simple_expression()
        while true {
            let op: String = parse_token()
            let precedence: Int = get_precedence(binary_op: op)
            if precedence <= min_priority {
                stringIndex = input.index(stringIndex, offsetBy: -op.count)
                return left_expression
            }
            
            let right_expression = parse_binary_expression(min_priority: precedence)
            left_expression = Expression(token: op, expr1: left_expression, expr2: right_expression)
        }
    }
    
    mutating func parse() -> Expression {
        return parse_binary_expression(min_priority: 0)
    }

}

func eval(expression: Expression) -> Double {
    if(expression.args.count == 2){
        let a: Double = eval(expression: expression.args[0])
        let b: Double = eval(expression: expression.args[1])
        switch expression.token {
        case "+":
            return a + b
        case "-":
            return a - b
        case "*":
            return a * b
        case "/":
            return a / b
        default:
            return 0
        }
    } else if(expression.args.count == 1){
        let a: Double = eval(expression: expression.args[0])
        switch expression.token {
        case "+":
            return a
        case "-":
            return -a
        default:
            return 0
        }
    } else {
        return Double(expression.token)!
    }
}

public protocol Calculator<Number> {
    associatedtype Number: Numeric
    
    init(operators: Dictionary<String, Operator<Number>>)
    
    func evaluate(_ input: String) throws -> Number
}

struct IntegerCalculator: Calculator {
 
    typealias Number = Int
    var operators: Dictionary<String, Operator<Int>>
    
    init(operators: Dictionary<String, Operator<Int>>){
        self.operators = operators
    }
    
    func evaluate(_ input: String) throws -> Int {
        var parser: Parser = Parser(input: input, operators: operators)
        return Int(eval(expression: parser.parse()))
    }
}

struct RealCalculator: Calculator {
 
    typealias Number = Double
    var operators: Dictionary<String, Operator<Double>>
    
    init(operators: Dictionary<String, Operator<Double>>){
        self.operators = operators
    }
    
    func evaluate(_ input: String) throws -> Double {
        var parser: Parser = Parser(input: input, operators: operators)
        return Double(eval(expression: parser.parse()))
    }
}


func test(calculator type: (some Calculator<Int>).Type) {
    let calculator = type.init(operators: [
        "+": Operator(precedence: 10, associativity: .left, function: +),
        "-": Operator(precedence: 10, associativity: .left, function: -),
        "*": Operator(precedence: 20, associativity: .left, function: *),
        "/": Operator(precedence: 20, associativity: .left, function: /),
    ])
    
    let result1 = try! calculator.evaluate("4*(2*3)+10")
    print(result1)
    assert(result1 == 34)
}

func testReal(calculator type: (some Calculator<Double>).Type) {
    let calculator = type.init(operators: [
        "+": Operator(precedence: 10, associativity: .left, function: +),
        "-": Operator(precedence: 10, associativity: .left, function: -),
        "*": Operator(precedence: 20, associativity: .left, function: *),
        "/": Operator(precedence: 20, associativity: .left, function: /),
    ])
    
    let result1 = try! calculator.evaluate("4*((2*3)+10)")
    print(result1)
    assert(result1 == 64)
}

test(calculator: IntegerCalculator.self)
testReal(calculator: RealCalculator.self)
