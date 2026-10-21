"
Abstract GraphQL type reference (named, list, non-null). printString answers the SDL form, e.g. [ID!]!
"
Class {
	#name : 'GQLTypeRef',
	#superclass : 'GQLNode',
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'printing' }
GQLTypeRef >> asGraphQLString [
	"SDL form, e.g. [ID!]!"

	^ self printString
]

{ #category : 'testing' }
GQLTypeRef >> isList [

	^ false
]

{ #category : 'testing' }
GQLTypeRef >> isNamed [

	^ false
]

{ #category : 'testing' }
GQLTypeRef >> isNonNull [

	^ false
]

{ #category : 'testing' }
GQLTypeRef >> isTypeRef [

	^ true
]

{ #category : 'accessing' }
GQLTypeRef >> namedType [
	"Answer the innermost GQLNamedTypeRef"

	^ self subclassResponsibility
]

{ #category : 'accessing' }
GQLTypeRef >> nullableType [
	"Answer the type without its outermost non-null wrapper"

	^ self
]

{ #category : 'accessing' }
GQLTypeRef >> typeName [
	"Answer the name of the innermost named type"

	^ self namedType name
]
