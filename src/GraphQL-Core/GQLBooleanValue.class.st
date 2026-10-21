Class {
	#name : 'GQLBooleanValue',
	#superclass : 'GQLScalarValue',
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'printing' }
GQLBooleanValue >> printGraphQLOn: aStream [

	aStream nextPutAll: (value ifTrue: [ 'true' ] ifFalse: [ 'false' ])
]
