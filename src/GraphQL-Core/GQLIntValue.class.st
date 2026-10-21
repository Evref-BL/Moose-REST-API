Class {
	#name : 'GQLIntValue',
	#superclass : 'GQLScalarValue',
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'printing' }
GQLIntValue >> printGraphQLOn: aStream [

	aStream print: value
]
