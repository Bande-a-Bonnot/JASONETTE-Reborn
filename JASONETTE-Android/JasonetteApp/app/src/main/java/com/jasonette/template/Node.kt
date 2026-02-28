package com.jasonette.template

/** AST node types for parsed expressions. */
sealed class Node {
    data class Literal(val value: Any?) : Node()
    data class Identifier(val name: String) : Node()
    data class Member(val obj: Node, val property: String) : Node()
    data class ComputedMember(val obj: Node, val property: Node) : Node()
    data class Binary(val op: String, val left: Node, val right: Node) : Node()
    data class Unary(val op: String, val operand: Node) : Node()
    data class Ternary(val condition: Node, val consequent: Node, val alternate: Node) : Node()
    data class Call(val callee: Node, val args: List<Node>) : Node()
    data class ArrayLiteral(val elements: List<Node>) : Node()
}
