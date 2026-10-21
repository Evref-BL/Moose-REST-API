Class {
	#name : 'GQLEnumValue',
	#superclass : 'GQLScalarValue',
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'printing' }
GQLEnumValue >> printGraphQLOn: aStream [

	aStream nextPutAll: value
]
