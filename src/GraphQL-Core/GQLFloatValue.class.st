Class {
	#name : 'GQLFloatValue',
	#superclass : 'GQLScalarValue',
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'printing' }
GQLFloatValue >> printGraphQLOn: aStream [

	aStream print: value asFloat
]
