"
Abstract superclass of all GraphQL AST nodes. Records the line/column of the node's first token.
"
Class {
	#name : 'GQLNode',
	#superclass : 'Object',
	#instVars : [
		'line',
		'column'
	],
	#category : 'GraphQL-Core-AST',
	#package : 'GraphQL-Core',
	#tag : 'AST'
}

{ #category : 'accessing' }
GQLNode >> column [

	^ column
]

{ #category : 'accessing' }
GQLNode >> column: anObject [

	column := anObject
]

{ #category : 'testing' }
GQLNode >> isDefinition [

	^ false
]

{ #category : 'testing' }
GQLNode >> isDocument [

	^ false
]

{ #category : 'testing' }
GQLNode >> isField [

	^ false
]

{ #category : 'testing' }
GQLNode >> isFragmentDefinition [

	^ false
]

{ #category : 'testing' }
GQLNode >> isFragmentSpread [

	^ false
]

{ #category : 'testing' }
GQLNode >> isInlineFragment [

	^ false
]

{ #category : 'testing' }
GQLNode >> isNull [

	^ false
]

{ #category : 'testing' }
GQLNode >> isOperationDefinition [

	^ false
]

{ #category : 'testing' }
GQLNode >> isSelection [

	^ false
]

{ #category : 'testing' }
GQLNode >> isTypeRef [

	^ false
]

{ #category : 'testing' }
GQLNode >> isValue [

	^ false
]

{ #category : 'testing' }
GQLNode >> isVariable [

	^ false
]

{ #category : 'accessing' }
GQLNode >> line [

	^ line
]

{ #category : 'accessing' }
GQLNode >> line: anObject [

	line := anObject
]

{ #category : 'accessing' }
GQLNode >> line: aLine column: aColumn [

	line := aLine.
	column := aColumn
]

{ #category : 'accessing' }
GQLNode >> location [
	"Answer a Dictionary suitable for the GraphQL error locations entry"

	^ Dictionary new
		  at: 'line' put: line;
		  at: 'column' put: column;
		  yourself
]
