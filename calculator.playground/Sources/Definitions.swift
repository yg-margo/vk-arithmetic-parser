import Foundation

/// Ассоциативность оператора
public enum Associativity {
    case left, right, none
}

/// Оператор
public struct Operator<T: Numeric> {
    public let precedence: Int
    public let associativity: Associativity
    private let function: (T, T) throws -> T
    
    /// Конструктор с параметрами
    /// - Parameters:
    ///   - precedence: приоритет
    ///   - associativity: ассоциативность
    ///   - function: вычислимая бинарная функция
    public init(precedence: Int, associativity: Associativity, function: @escaping (T, T) -> T) {
        self.precedence = precedence
        self.associativity = associativity
        self.function = function
    }
    
    /// Применить оператор
    /// - Parameters:
    ///   - lhs: первый аргумент
    ///   - rhs: второй аргумент
    /// - Returns: результат, либо исключение
    public func apply(_ lhs: T, _ rhs: T) throws -> T {
        try self.function(lhs, rhs)
    }
}

extension String {
    func getCharAtIndex(_ index: Int) -> Character{
        return self[self.index(self.startIndex, offsetBy: index)]
    }

    subscript (bounds: CountableClosedRange<Int>) -> String {
            let start = index(startIndex, offsetBy: bounds.lowerBound)
            let end = index(startIndex, offsetBy: bounds.upperBound)
            return String(self[start...end])
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

struct Parser {
    var input: String
    var position: Int = 0;
    var operators: Dictionary<String, Operator<Int>>
    init(input: String, operators: Dictionary<String, Operator<Int>>) {
        self.input = input
        self.operators = operators
    }
    
    mutating func skip_ws() {
        while position < input.count && input.getCharAtIndex(position) == " " {
            position += 1
        }
    }
    
    mutating func parse_token() -> String {
        skip_ws()
        
        if(input.getCharAtIndex(position).isWholeNumber){
            var number: String = ""
            while position < input.count && (input.getCharAtIndex(position).isWholeNumber || input.getCharAtIndex(position) == ".") {
                number += String(input.getCharAtIndex(position))
                position += 1
            }
            return number
        }
        
        if(input.getCharAtIndex(position) == "(" || input.getCharAtIndex(position) == ")"){
            let token: String = String(input.getCharAtIndex(position))
            position += 1
            return token
        }
        
        for (token, _) in operators {
            if input[position...position + token.count - 1] == token {
                position += token.count
                return token
            }
        }
        
        return ""
    }
    
    mutating func parse_simple_expression() -> Expression {
        let token: String = parse_token();

        if token == "(" {
            return parse()
        }
        
        if token.getCharAtIndex(0).isWholeNumber {
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
        var left_expression : Expression = parse_simple_expression();
        while true {
            let op: String = parse_token()
            let precedence: Int = get_precedence(binary_op: op);
            if precedence <= min_priority {
                position -= op.count
                return left_expression
            }
            
            let right_expression = parse_binary_expression(min_priority: precedence)
            left_expression = Expression(token: op, expr1: left_expression, expr2: right_expression)
        }
    }
    
    mutating func parse() -> Expression {
        return parse_binary_expression(min_priority: 0);
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

/// Калькулятор
public protocol Calculator<Number> {
    /// Тип чисел, с которыми работает данный калькулятор
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
